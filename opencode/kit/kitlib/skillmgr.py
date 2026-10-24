"""Gestor de skills de OpenCode."""

from __future__ import annotations

import os
import shutil
import tempfile
import zipfile
from pathlib import Path

from . import common as c

VALID_ID = r"^[a-z0-9]+(?:-[a-z0-9]+)*$"


# --------------------------------------------------------------------------
# descubrimiento
# --------------------------------------------------------------------------

def scope_dir(scope: str, project: Path | None = None) -> Path:
    project = project or Path.cwd()
    return {
        "global": c.SKILLS_DIR,
        "shared": c.SHARED_SKILLS,
        "project": project / ".opencode" / "skills",
    }.get(scope, c.SKILLS_DIR)


def _skill_entry(path: Path, source: str, status: str) -> dict:
    meta, _ = c.parse_frontmatter(path)
    return {
        "id": path.parent.name if path.name == "SKILL.md" else path.stem,
        "name": meta.get("name", ""),
        "description": meta.get("description", ""),
        "path": str(path),
        "source": source,
        "status": status,
        "files": sum(1 for p in path.parent.rglob("*") if p.is_file())
        if path.name == "SKILL.md" else 1,
    }


def discover(project: Path | None = None) -> list[dict]:
    project = project or Path.cwd()
    found: list[dict] = []
    sources: list[tuple[Path, str, str]] = [
        (c.SKILLS_DIR, "global", "enabled"),
        (c.SKILLS_DISABLED, "global", "disabled"),
        (c.SHARED_SKILLS, "shared", "enabled"),
        (c.CLAUDE_SKILLS, "claude", "enabled"),
        (project / ".opencode" / "skills", "project", "enabled"),
        (project / ".claude" / "skills", "claude-project", "enabled"),
        (project / ".agents" / "skills", "agents-project", "enabled"),
    ]
    seen: set[str] = set()
    for root, label, status in sources:
        if not root.is_dir():
            continue
        for item in sorted(root.iterdir()):
            if item.name.startswith(".") or item.name == "node_modules":
                continue
            entry = None
            if item.is_dir() and (item / "SKILL.md").is_file():
                entry = _skill_entry(item / "SKILL.md", label, status)
            elif item.is_file() and item.suffix == ".md" and item.name != "SKILL.md":
                if root in (c.SKILLS_DIR, c.SKILLS_DISABLED):
                    entry = _skill_entry(item, label, status)
            if entry is None:
                continue
            # el mismo directorio puede ser fuente global-compat y proyecto a la vez
            real = str(Path(entry["path"]).resolve())
            if real in seen:
                continue
            seen.add(real)
            found.append(entry)
    return found


def installed() -> list[dict]:
    return [s for s in discover() if s["source"] in {"global", "shared"}]


# --------------------------------------------------------------------------
# orígenes
# --------------------------------------------------------------------------

def _github_parts(url: str) -> dict | None:
    import re
    match = re.match(
        r"https?://github\.com/(?P<owner>[\w.-]+)/(?P<repo>[\w.-]+?)"
        r"(?:\.git)?(?:/(?:tree|blob)/(?P<ref>[^/]+)(?:/(?P<path>.*?))?)?/?$",
        url.strip())
    if not match:
        return None
    return {
        "type": "git",
        "url": f"https://github.com/{match['owner']}/{match['repo']}.git",
        "repo": f"{match['owner']}/{match['repo']}",
        "ref": match["ref"],
        "path": match["path"],
    }


def classify_source(value: str) -> dict:
    if value.startswith(("http://", "https://")):
        gh = _github_parts(value)
        if gh:
            return gh
        if value.endswith(".git"):
            return {"type": "git", "url": value, "ref": None, "path": None, "repo": value}
        if "/blob/" in value or "/tree/" in value:
            return {"type": "git", "url": value, "ref": None, "path": None, "repo": value}
        c.die("URL no reconocida. Para skills usa un repositorio Git o una carpeta/zip local.")
    path = Path(value).expanduser()
    if path.is_file() and path.suffix.lower() == ".zip":
        return {"type": "zip", "path": path.resolve()}
    if path.is_dir():
        return {"type": "dir", "path": path.resolve()}
    c.die(f"ruta no encontrada: {value}")


def _clone(source: dict) -> tuple[Path, dict]:
    tmp = Path(tempfile.mkdtemp(prefix="sc-kit-skill-"))
    cmd = ["git", "clone", "--depth", "1", "--quiet"]
    if source.get("ref"):
        cmd += ["--branch", source["ref"]]
    cmd += [source["url"], str(tmp / "repo")]
    try:
        c.run(cmd, timeout=180, check=True)
    except RuntimeError as exc:
        shutil.rmtree(tmp, ignore_errors=True)
        c.die(f"no se pudo clonar: {exc}")
    commit = c.run(["git", "-C", str(tmp / "repo"), "rev-parse", "HEAD"],
                   timeout=30).stdout.strip()
    return tmp / "repo", {"commit": commit}


def _extract_zip(path: Path) -> tuple[Path, dict]:
    tmp = Path(tempfile.mkdtemp(prefix="sc-kit-skill-"))
    with zipfile.ZipFile(path) as archive:
        for member in archive.infolist():
            target = (tmp / member.filename).resolve()
            if not str(target).startswith(str(tmp.resolve())):
                shutil.rmtree(tmp, ignore_errors=True)
                c.die("el zip contiene rutas inseguras (path traversal)")
        archive.extractall(tmp)
    return tmp, {"commit": c.sha256_file(path)[:12]}


def _find_skills(root: Path) -> list[Path]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel = Path(dirpath).relative_to(root)
        if len(rel.parts) > 4:
            dirnames[:] = []
            continue
        dirnames[:] = [d for d in dirnames
                       if d not in {".git", "node_modules", ".venv", "__pycache__"}]
        if "SKILL.md" in filenames:
            found.append(Path(dirpath) / "SKILL.md")
    if not found:
        found = [p for p in root.iterdir()
                 if p.is_file() and p.suffix == ".md" and p.name.lower() not in
                 {"readme.md", "changelog.md", "license.md", "contributing.md"}]
        found = found[:1]
    return found


def _materialize(source: dict, subpath: str | None) -> tuple[Path, dict, Path]:
    """Devuelve (raíz temporal, procedencia, raíz de la skill)."""
    if source["type"] == "dir":
        root = source["path"]
        origin = {"type": "dir", "path": str(root)}
        cleanup = None
    elif source["type"] == "zip":
        root, origin = _extract_zip(source["path"])
        origin.update({"type": "zip", "path": str(source["path"])})
        cleanup = root.parent
    else:
        root, origin = _clone(source)
        origin.update({"type": "git", "url": source["url"], "repo": source.get("repo"),
                       "ref": source.get("ref")})
        cleanup = root.parent

    base = root
    wanted = subpath or (source.get("path") if source.get("type") == "git" else None)
    if wanted:
        candidate = (root / wanted).resolve()
        if not str(candidate).startswith(str(root.resolve())):
            c.die("la ruta indicada sale del repositorio")
        if not candidate.exists():
            c.die(f"subruta inexistente en el origen: {wanted}")
        base = candidate if candidate.is_dir() else candidate.parent

    if (base / "SKILL.md").is_file():
        return root, origin, base
    if base.is_file() and base.suffix == ".md":
        return root, origin, base
    candidates = _find_skills(base)
    if not candidates:
        if cleanup:
            shutil.rmtree(cleanup, ignore_errors=True)
        c.die("no se encontró ningún SKILL.md en el origen")
    if len(candidates) > 1:
        print("Se encontraron varias skills; elige con --path:")
        for cand in candidates:
            print(f"  - {cand.relative_to(base).parent.as_posix() or '.'}")
        if cleanup:
            shutil.rmtree(cleanup, ignore_errors=True)
        raise SystemExit(2)
    return root, origin, candidates[0].parent if candidates[0].name == "SKILL.md" else candidates[0]


# --------------------------------------------------------------------------
# comandos
# --------------------------------------------------------------------------

def cmd_add(src: str, *, name: str | None = None, scope: str = "global",
            subpath: str | None = None, force: bool = False, yes: bool = False,
            no_audit: bool = False, project: Path | None = None) -> int:
    c.ensure_dirs()
    source = classify_source(src)
    root, origin, skill_root = _materialize(source, subpath)
    cleanup = None if source["type"] == "dir" else root.parent

    try:
        if skill_root.is_file():
            skill_id = c.slugify(name or skill_root.stem)
            files = {"SKILL.md": skill_root}
        else:
            skill_id = c.slugify(name or skill_root.name)
            files = None

        if not c.re.match(VALID_ID, skill_id):
            c.die(f"ID inválido: {skill_id}")

        destination = scope_dir(scope, project) / skill_id
        if destination.exists():
            if not force:
                c.die(f"ya existe {destination}. Usa --force para reemplazar (se hará backup).")
            c.backup(f"skill-replace-{skill_id}", quiet=True)

        findings = [] if no_audit else (
            c.audit_tree(skill_root if skill_root.is_dir() else skill_root.parent))
        critical = [f for f in findings if f["level"] == "critical"]
        if findings:
            print(c.bold(f"auditoría de {skill_id}"))
            c.print_audit(findings)
        if critical and not force:
            c.die("instalación bloqueada por hallazgos críticos. Revisa el contenido; "
                  "usa --force solo si confías en el origen.")

        if not yes:
            print(f"\nInstalar {c.bold(skill_id)} en {destination} ({scope})")
            print(f"origen: {origin.get('url') or origin.get('path')}")
            answer = input("¿Continuar? [s/N] ").strip().lower()
            if answer not in {"s", "si", "sí", "y", "yes"}:
                c.die("cancelado")

        if destination.exists():
            shutil.rmtree(destination)
        destination.parent.mkdir(parents=True, exist_ok=True)

        if skill_root.is_file():
            destination.mkdir(parents=True)
            shutil.copy2(skill_root, destination / "SKILL.md")
        else:
            shutil.copytree(skill_root, destination,
                            ignore=shutil.ignore_patterns(".git", "node_modules",
                                                          ".venv", "__pycache__"))

        meta, _ = c.parse_frontmatter(destination / "SKILL.md")
        manifest = c.tree_manifest(destination)
        data = c.registry(c.SKILL_REGISTRY, "skills")
        data["skills"][skill_id] = {
            "id": skill_id,
            "name": meta.get("name", skill_id),
            "description": meta.get("description", ""),
            "scope": scope,
            "path": str(destination),
            "status": "enabled",
            "source": origin,
            "installed_at": c.now_iso(),
            "updated_at": c.now_iso(),
            "manifest": manifest,
            "digest": c.manifest_digest(manifest),
            "audit": {
                "critical": sum(1 for f in findings if f["level"] == "critical"),
                "high": sum(1 for f in findings if f["level"] == "high"),
                "medium": sum(1 for f in findings if f["level"] == "medium"),
                "at": c.now_iso(),
            },
            "files": len(manifest),
        }
        c.save_json(c.SKILL_REGISTRY, data)
        c.log_event("skill-add", skill_id, origin.get("url") or origin.get("path", ""))
        print(f"{c.ok('instalada')} {skill_id} -> {destination}")
        print(c.dim(f"ID para cargar: {skill_id}  |  verifica con: sc-kit skill info {skill_id}"))
        if not meta.get("description"):
            print(c.warn("aviso: SKILL.md sin 'description'; OpenCode no la anunciará al modelo."))
        return 0
    finally:
        if cleanup:
            shutil.rmtree(cleanup, ignore_errors=True)


def cmd_list(as_json: bool = False) -> int:
    items = discover()
    reg = c.registry(c.SKILL_REGISTRY, "skills")["skills"]
    if as_json:
        import json
        for item in items:
            entry = reg.get(item["id"], {})
            item["origin"] = entry.get("source", {})
        print(json.dumps(items, indent=2, ensure_ascii=False))
        return 0
    rows = []
    for item in items:
        origin = reg.get(item["id"], {}).get("source", {})
        label = origin.get("repo") or origin.get("path") or "-"
        mark = "" if item["status"] == "enabled" else c.dim("(off) ")
        rows.append([mark + item["id"], item["source"], item["status"],
                     str(item["files"]), str(label)[:48]])
    c.table(rows, ["id", "origen", "estado", "ficheros", "procedencia"])
    print(c.dim(f"\n{len(items)} skills visibles · gestor: sc-kit skill --help"))
    return 0


def cmd_info(skill_id: str) -> int:
    item = next((s for s in discover() if s["id"] == skill_id), None)
    if not item:
        c.die(f"skill no encontrada: {skill_id}")
    reg = c.registry(c.SKILL_REGISTRY, "skills")["skills"].get(skill_id, {})
    meta, body = c.parse_frontmatter(Path(item["path"]))
    print(c.bold(skill_id))
    print(f"  nombre      {meta.get('name', '-')}")
    print(f"  descripción {meta.get('description', '-')}")
    print(f"  estado      {item['status']} ({item['source']})")
    print(f"  ruta        {item['path']}")
    if reg:
        print(f"  origen      {reg.get('source', {}).get('url') or reg.get('source', {}).get('path')}")
        print(f"  instalada   {reg.get('installed_at', '-')}")
        print(f"  digest      {reg.get('digest', '-')[:16]}")
        audit = reg.get("audit", {})
        print(f"  auditoría   críticos={audit.get('critical', 0)} altos={audit.get('high', 0)}")
    print(f"  tamaño      {len(body)} caracteres de instrucciones")
    support = []
    path = Path(item["path"])
    if path.name == "SKILL.md":
        support = [str(p.relative_to(path.parent)) for p in path.parent.rglob("*")
                   if p.is_file() and p.name != "SKILL.md"][:12]
    if support:
        print("  adjuntos    " + ", ".join(support))
    return 0


def _move(skill_id: str, from_dir: Path, to_dir: Path, status: str) -> int:
    src = from_dir / skill_id
    if not src.exists():
        c.die(f"no existe {src}")
    to_dir.mkdir(parents=True, exist_ok=True)
    if (to_dir / skill_id).exists():
        c.die(f"ya existe {to_dir / skill_id}")
    shutil.move(str(src), str(to_dir / skill_id))
    data = c.registry(c.SKILL_REGISTRY, "skills")
    if skill_id in data["skills"]:
        data["skills"][skill_id]["status"] = status
        data["skills"][skill_id]["path"] = str(to_dir / skill_id)
        c.save_json(c.SKILL_REGISTRY, data)
    c.log_event(f"skill-{status}", skill_id)
    print(f"{c.ok(status)} {skill_id}")
    return 0


def cmd_enable(skill_id: str) -> int:
    return _move(skill_id, c.SKILLS_DISABLED, c.SKILLS_DIR, "enabled")


def cmd_disable(skill_id: str) -> int:
    return _move(skill_id, c.SKILLS_DIR, c.SKILLS_DISABLED, "disabled")


def cmd_remove(skill_id: str, purge: bool = False, yes: bool = False) -> int:
    data = c.registry(c.SKILL_REGISTRY, "skills")
    entry = data["skills"].get(skill_id, {})
    location = None
    for root in (c.SKILLS_DIR, c.SKILLS_DISABLED, c.SHARED_SKILLS):
        if (root / skill_id).exists():
            location = root / skill_id
            break
    if not location:
        c.die(f"skill no encontrada: {skill_id}")
    if not yes:
        answer = input(f"¿Eliminar {skill_id} de {location.parent}? [s/N] ").strip().lower()
        if answer not in {"s", "si", "sí", "y", "yes"}:
            c.die("cancelado")
    if purge:
        shutil.rmtree(location)
        print(c.warn(f"purgada {skill_id} (sin copia)"))
    else:
        archive = c.BACKUP_DIR / "removed" / f"{c.timestamp()}-{skill_id}"
        archive.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(location), str(archive))
        print(f"{c.ok('archivada')} {archive}")
    data["skills"].pop(skill_id, None)
    c.save_json(c.SKILL_REGISTRY, data)
    c.log_event("skill-remove", skill_id, "purge" if purge else "archive")
    return 0


def cmd_audit(skill_id: str | None) -> int:
    targets: list[tuple[str, Path]] = []
    if skill_id:
        item = next((s for s in discover() if s["id"] == skill_id), None)
        if not item:
            c.die(f"skill no encontrada: {skill_id}")
        targets.append((skill_id, Path(item["path"]).parent))
    else:
        for item in installed():
            targets.append((item["id"], Path(item["path"]).parent))
    worst = 0
    for name, path in targets:
        print(c.bold(f"\n{name}  {c.dim(str(path))}"))
        worst = max(worst, c.print_audit(c.audit_tree(path)))
    return worst


def _update_one(skill_id: str, yes: bool) -> bool:
    data = c.registry(c.SKILL_REGISTRY, "skills")
    entry = data["skills"].get(skill_id)
    if not entry:
        print(c.warn(f"{skill_id}: sin procedencia registrada; no se puede actualizar"))
        return False
    origin = entry.get("source", {})
    if origin.get("type") == "git":
        source = {"type": "git", "url": origin["url"], "repo": origin.get("repo"),
                  "ref": origin.get("ref"), "path": origin.get("path")}
    elif origin.get("type") == "dir" and Path(origin.get("path", "")).is_dir():
        source = {"type": "dir", "path": Path(origin["path"])}
    elif origin.get("type") == "zip" and Path(origin.get("path", "")).is_file():
        source = {"type": "zip", "path": Path(origin["path"])}
    else:
        print(c.warn(f"{skill_id}: origen no disponible ({origin.get('type')})"))
        return False

    root, fresh, skill_root = _materialize(source, origin.get("path") if source["type"] == "git" else None)
    try:
        new_manifest = c.tree_manifest(skill_root if skill_root.is_dir() else skill_root.parent)
        old_manifest = entry.get("manifest", {})
        destination = Path(entry["path"])
        local_manifest = c.tree_manifest(destination) if destination.exists() else {}
        drift = sorted(k for k in set(local_manifest) | set(old_manifest)
                       if local_manifest.get(k) != old_manifest.get(k))
        added = sorted(set(new_manifest) - set(old_manifest))
        removed = sorted(set(old_manifest) - set(new_manifest))
        changed = sorted(k for k in set(new_manifest) & set(old_manifest)
                         if new_manifest[k] != old_manifest[k])
        if not (added or removed or changed):
            if not drift:
                print(f"{c.ok('al día')} {skill_id}")
                return False
            print(c.warn(f"{skill_id}: copia instalada modificada "
                         f"({len(drift)} ficheros) y origen sin cambios"))
            for name in drift[:10]:
                print(f"  {name}")
            print(c.dim("  restaurar desde el origen sobrescribe esas modificaciones"))
            if not yes:
                answer = input("¿Restaurar desde el origen? [s/N] ").strip().lower()
                if answer not in {"s", "si", "sí", "y", "yes"}:
                    print("omitida")
                    return False
        else:
            print(f"{c.bold(skill_id)}: +{len(added)} ~{len(changed)} -{len(removed)} ficheros")
            for name in (added + changed + removed)[:12]:
                print(f"  {name}")
            if not yes:
                answer = input("¿Aplicar actualización? [s/N] ").strip().lower()
                if answer not in {"s", "si", "sí", "y", "yes"}:
                    print("omitida")
                    return False
        c.backup(f"skill-update-{skill_id}", quiet=True)
        staging = destination.with_name(destination.name + ".new")
        if staging.exists():
            shutil.rmtree(staging)
        shutil.copytree(skill_root, staging, ignore=shutil.ignore_patterns(
            ".git", "node_modules", ".venv", "__pycache__"))
        shutil.rmtree(destination)
        staging.rename(destination)
        manifest = c.tree_manifest(destination)
        entry.update({
            "manifest": manifest,
            "digest": c.manifest_digest(manifest),
            "files": len(manifest),
            "updated_at": c.now_iso(),
        })
        if fresh.get("commit"):
            entry["source"]["commit"] = fresh["commit"]
        c.save_json(c.SKILL_REGISTRY, data)
        c.log_event("skill-update", skill_id, entry["digest"][:12])
        print(f"{c.ok('actualizada')} {skill_id}")
        return True
    finally:
        if source["type"] != "dir":
            shutil.rmtree(root.parent, ignore_errors=True)


def cmd_update(skill_id: str | None, yes: bool = False) -> int:
    if skill_id:
        _update_one(skill_id, yes)
        return 0
    changed = 0
    for item in installed():
        if item["status"] != "enabled":
            continue
        if _update_one(item["id"], yes):
            changed += 1
    print(f"\n{changed} skills actualizadas")
    return 0


def cmd_verify(skill_id: str | None) -> int:
    data = c.registry(c.SKILL_REGISTRY, "skills")["skills"]
    ids = [skill_id] if skill_id else list(data)
    bad = 0
    for sid in ids:
        entry = data.get(sid)
        if not entry:
            c.die(f"sin registro: {sid}")
        path = Path(entry["path"])
        if not path.exists():
            print(c.err(f"{sid}: ruta inexistente {path}"))
            bad += 1
            continue
        current = c.tree_manifest(path)
        if current == entry.get("manifest"):
            print(f"{c.ok('ok')} {sid}")
        else:
            diff = [k for k in current if entry.get("manifest", {}).get(k) != current[k]]
            print(c.warn(f"modificada {sid}: {len(diff)} ficheros cambiados"))
            for name in diff[:8]:
                print(f"  {name}")
            bad += 1
    return 1 if bad else 0


def cmd_search(query: str) -> int:
    query = query.lower()
    rows = []
    for item in discover():
        haystack = f"{item['id']} {item['name']} {item['description']}".lower()
        if query in haystack:
            rows.append([item["id"], item["source"], item["description"][:80]])
    c.table(rows, ["id", "origen", "descripción"])
    if not rows:
        print(c.dim("sin resultados locales. Busca en GitHub/agentskills.io y añade con "
                    "/skill-add <url>."))
    return 0
