"""Utilidades compartidas de sc-kit. Solo biblioteca estándar de Python."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path

HOME = Path.home()


def _xdg(var: str, default: Path) -> Path:
    value = os.environ.get(var)
    return Path(value).expanduser() if value else default


CONFIG_DIR = _xdg("XDG_CONFIG_HOME", HOME / ".config") / "opencode"
DATA_DIR = _xdg("XDG_DATA_HOME", HOME / ".local" / "share") / "opencode"
STATE_DIR = _xdg("XDG_STATE_HOME", HOME / ".local" / "state") / "opencode"

KIT_DIR = CONFIG_DIR / "kit"
REGISTRY_DIR = CONFIG_DIR / "registry"
BACKUP_DIR = CONFIG_DIR / "backups"
SKILLS_DIR = CONFIG_DIR / "skills"
SKILLS_DISABLED = CONFIG_DIR / "skills-disabled"
AGENTS_DIR = CONFIG_DIR / "agents"
COMMANDS_DIR = CONFIG_DIR / "commands"
PROFILES_FILE = KIT_DIR / "mcp-profiles.json"
SETTINGS_FILE = KIT_DIR / "settings.json"
LOG_FILE = REGISTRY_DIR / "installs.log"
SKILL_REGISTRY = REGISTRY_DIR / "skills.json"
MCP_REGISTRY = REGISTRY_DIR / "mcp.json"

SHARED_SKILLS = HOME / ".agents" / "skills"
CLAUDE_SKILLS = HOME / ".claude" / "skills"

NULL_DEVICE = "NUL" if os.name == "nt" else "/dev/null"


# --------------------------------------------------------------------------
# salida
# --------------------------------------------------------------------------

def _tty() -> bool:
    return sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def _c(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _tty() else text


def bold(text: str) -> str:
    return _c(text, "1")


def dim(text: str) -> str:
    return _c(text, "2")


def ok(text: str) -> str:
    return _c(text, "32")


def warn(text: str) -> str:
    return _c(text, "33")


def err(text: str) -> str:
    return _c(text, "31")


def die(message: str, code: int = 1) -> "NoReturn":  # type: ignore[name-defined]
    sys.stdout.flush()
    print(err(f"error: {message}"), file=sys.stderr)
    raise SystemExit(code)


def info(message: str) -> None:
    print(message)


def table(rows: list[list[str]], headers: list[str]) -> None:
    if not rows:
        print(dim("(vacío)"))
        return
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))
    print("  ".join(h.ljust(widths[i]) for i, h in enumerate(headers)))
    print("  ".join("-" * w for w in widths))
    for row in rows:
        print("  ".join(str(c).ljust(widths[i]) for i, c in enumerate(row)))


def human_bytes(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f}{unit}" if unit == "B" else f"{n:.1f}{unit}"
        n /= 1024
    return f"{n}B"


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def timestamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


# --------------------------------------------------------------------------
# procesos
# --------------------------------------------------------------------------

def run(cmd: list[str], *, cwd: Path | None = None, timeout: int = 120,
        env: dict[str, str] | None = None, check: bool = False,
        capture: bool = True) -> subprocess.CompletedProcess:
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            timeout=timeout,
            env={**os.environ, **(env or {})},
            text=True,
            capture_output=capture,
        )
    except FileNotFoundError:
        raise RuntimeError(f"no se encontró el ejecutable: {cmd[0]}")
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"tiempo agotado tras {timeout}s: {' '.join(cmd[:3])}")
    if check and proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip().splitlines()[-3:]
        raise RuntimeError(f"falló ({proc.returncode}): {' '.join(cmd[:3])} :: {' | '.join(detail)}")
    return proc


def which(binary: str) -> str | None:
    return shutil.which(binary)


def opencode_json(args: list[str], timeout: int = 90) -> tuple[bool, str]:
    """Ejecuta `opencode ...` y devuelve (ok, salida)."""
    if not which("opencode"):
        return False, "opencode no está en PATH"
    proc = run(["opencode", *args], timeout=timeout, check=False)
    out = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode == 0, out.strip()


# --------------------------------------------------------------------------
# ficheros y json
# --------------------------------------------------------------------------

def ensure_dirs() -> None:
    for path in (KIT_DIR, REGISTRY_DIR, BACKUP_DIR, SKILLS_DIR,
                 SKILLS_DISABLED, AGENTS_DIR, COMMANDS_DIR):
        path.mkdir(parents=True, exist_ok=True)


def atomic_write(path: Path, text: str, mode: int | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        if mode is not None:
            os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def load_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return default


def save_json(path: Path, data) -> None:
    atomic_write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_manifest(root: Path) -> dict[str, str]:
    manifest: dict[str, str] = {}
    for path in sorted(root.rglob("*")):
        if path.is_file() and ".git" not in path.parts:
            manifest[str(path.relative_to(root))] = sha256_file(path)
    return manifest


def manifest_digest(manifest: dict[str, str]) -> str:
    body = "\n".join(f"{k}:{v}" for k, v in sorted(manifest.items()))
    return hashlib.sha256(body.encode()).hexdigest()


# --------------------------------------------------------------------------
# JSONC (lectura) — conserva URLs; elimina comentarios y comas finales
# --------------------------------------------------------------------------

def strip_jsonc(text: str) -> str:
    out: list[str] = []
    i, quoted, escape = 0, False, False
    while i < len(text):
        ch = text[i]
        if quoted:
            out.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                quoted = False
            i += 1
            continue
        if ch == '"':
            quoted = True
            out.append(ch)
            i += 1
            continue
        if text.startswith("//", i):
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                raise ValueError("comentario /* sin cierre")
            i = end + 2
            continue
        out.append(ch)
        i += 1

    text = "".join(out)
    out = []
    i, quoted, escape = 0, False, False
    while i < len(text):
        ch = text[i]
        if quoted:
            out.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                quoted = False
            i += 1
            continue
        if ch == '"':
            quoted = True
            out.append(ch)
            i += 1
            continue
        if ch == ",":
            j = i + 1
            while j < len(text) and text[j].isspace():
                j += 1
            if j < len(text) and text[j] in "}]":
                i += 1
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def read_jsonc(path: Path) -> dict:
    return json.loads(strip_jsonc(path.read_text(encoding="utf-8")))


def config_file() -> Path:
    """Fichero de configuración global realmente usado por OpenCode V2."""
    jsonc = CONFIG_DIR / "opencode.jsonc"
    plain = CONFIG_DIR / "opencode.json"
    if jsonc.exists():
        return jsonc
    if plain.exists():
        return plain
    return jsonc


def load_config() -> dict:
    path = config_file()
    if not path.exists():
        return {}
    try:
        return read_jsonc(path)
    except (json.JSONDecodeError, ValueError) as exc:
        die(f"configuración inválida en {path}: {exc}")


def has_jsonc_comments(text: str) -> bool:
    """Detecta comentarios reales (ignora // dentro de cadenas como https://)."""
    i, quoted, escape = 0, False, False
    while i < len(text):
        ch = text[i]
        if quoted:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                quoted = False
            i += 1
            continue
        if ch == '"':
            quoted = True
            i += 1
            continue
        if text.startswith("//", i) or text.startswith("/*", i):
            return True
        i += 1
    return False


def save_config(config: dict) -> Path:
    path = config_file()
    raw = path.read_text(encoding="utf-8") if path.exists() else ""
    if has_jsonc_comments(raw):
        backup("auto-config", quiet=True)
        print(warn("aviso: el fichero tenía comentarios JSONC; se normaliza a JSON (backup guardado)."))
    else:
        backup("auto-config", quiet=True)
    atomic_write(path, json.dumps(config, indent=2, ensure_ascii=False) + "\n")
    return path


# --------------------------------------------------------------------------
# frontmatter markdown
# --------------------------------------------------------------------------

_FM = re.compile(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", re.S)


def parse_frontmatter(path: Path) -> tuple[dict[str, str], str]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}, ""
    match = _FM.match(text)
    if not match:
        return {}, text
    meta: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        meta[key.strip()] = value.strip().strip("\"'")
    return meta, text[match.end():]


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")[:64] or "skill"


# --------------------------------------------------------------------------
# registro y log
# --------------------------------------------------------------------------

def registry(path: Path, key: str) -> dict:
    data = load_json(path, {})
    if not isinstance(data.get(key), dict):
        data[key] = {}
    return data


def log_event(action: str, subject: str, detail: str = "") -> None:
    ensure_dirs()
    line = f"{now_iso()}\t{action}\t{subject}\t{detail}".rstrip("\t")
    with LOG_FILE.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


# --------------------------------------------------------------------------
# backups / rollback
# --------------------------------------------------------------------------

def backup(label: str = "manual", quiet: bool = False) -> Path:
    ensure_dirs()
    stamp = timestamp()
    target = BACKUP_DIR / stamp
    suffix = 1
    while target.exists():
        suffix += 1
        target = BACKUP_DIR / f"{stamp}-{suffix}"
    target.mkdir(parents=True)
    archive = target / "config-opencode.tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        for path in sorted(CONFIG_DIR.rglob("*")):
            rel = path.relative_to(CONFIG_DIR)
            if rel.parts and rel.parts[0] in {"backups", "node_modules"}:
                continue
            if ".git" in rel.parts:
                continue
            tar.add(path, arcname=str(Path(".") / rel), recursive=False)
    version = "desconocida"
    if which("opencode"):
        proc = run(["opencode", "--version"], timeout=30)
        version = (proc.stdout or "").strip()
    meta = {
        "label": label,
        "created": now_iso(),
        "opencode": version,
        "archive": archive.name,
        "files": sum(1 for p in CONFIG_DIR.rglob("*")
                     if p.is_file() and "backups" not in p.parts
                     and "node_modules" not in p.parts),
    }
    save_json(target / "meta.json", meta)
    (BACKUP_DIR / ".last").write_text(target.name + "\n", encoding="utf-8")
    if not quiet:
        print(f"{ok('backup')} {target} ({human_bytes(archive.stat().st_size)})")
    return target


def list_backups(include_safety: bool = True) -> list[Path]:
    if not BACKUP_DIR.exists():
        return []
    items = sorted((p for p in BACKUP_DIR.iterdir()
                    if p.is_dir() and (p / "config-opencode.tar.gz").exists()),
                   key=lambda p: p.name)
    if include_safety:
        return items
    return [p for p in items
            if load_json(p / "meta.json", {}).get("label") != "pre-rollback"]


def latest_backup() -> Path | None:
    items = list_backups(include_safety=False)
    return items[-1] if items else None


def resolve_backup(ref: str) -> Path:
    if ref in {"last", "latest"}:
        found = latest_backup()
        if not found:
            die("no hay backups disponibles")
        return found
    candidates = [p for p in list_backups() if p.name == ref or p.name.startswith(ref)]
    if len(candidates) == 1:
        return candidates[0]
    if not candidates:
        die(f"backup no encontrado: {ref}")
    die(f"referencia ambigua: {ref} -> {', '.join(p.name for p in candidates)}")
    raise AssertionError


def _trusted_member(member, dest):
    """Acepta el backup propio, rechazando rutas absolutas o con traversal."""
    name = Path(member.name)
    if name.is_absolute() or ".." in name.parts:
        raise tarfile.TarError(f"entrada insegura en el backup: {member.name}")
    return member


def rollback(ref: str = "last", *, dry_run: bool = False, with_kit: bool = False) -> None:
    source = resolve_backup(ref)
    archive = source / "config-opencode.tar.gz"
    print(f"restaurando {bold(source.name)}")
    if dry_run:
        with tarfile.open(archive) as tar:
            names = tar.getnames()
        print(f"  {len(names)} entradas; vista previa:")
        for name in names[:20]:
            print(f"  {name}")
        if not with_kit:
            print(dim("  el código del kit se conserva (usa --with-kit para restaurarlo)"))
        return
    safety = backup("pre-rollback", quiet=True)
    tmp = Path(tempfile.mkdtemp(prefix="sc-kit-rollback-"))
    try:
        with tarfile.open(archive) as tar:
            tar.extractall(tmp, filter=_trusted_member)
        for item in tmp.iterdir():
            target = CONFIG_DIR / item.name
            if item.name == "kit" and not with_kit:
                # conserva el código del gestor; restaura solo sus datos
                target.mkdir(parents=True, exist_ok=True)
                for sub in item.iterdir():
                    if sub.name in {"sc_kit.py", "kitlib", "tests"}:
                        continue
                    dest = target / sub.name
                    if sub.is_dir():
                        if dest.exists():
                            shutil.rmtree(dest)
                        shutil.copytree(sub, dest, symlinks=True)
                    else:
                        if dest.exists() or dest.is_symlink():
                            dest.unlink()
                        shutil.copy2(sub, dest, follow_symlinks=False)
                continue
            if item.is_dir():
                if target.exists():
                    shutil.rmtree(target)
                shutil.copytree(item, target, symlinks=True)
            else:
                if target.exists() or target.is_symlink():
                    target.unlink()
                shutil.copy2(item, target, follow_symlinks=False)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    log_event("rollback", source.name, f"safety={safety.name}")
    print(f"{ok('restaurado')} copia de seguridad previa: {safety}")


# --------------------------------------------------------------------------
# auditoría estática
# --------------------------------------------------------------------------

AUDIT_RULES: list[tuple[re.Pattern, str, str]] = [
    (re.compile(r"(curl|wget)[^\n|]{0,200}\|\s*(sudo\s+)?(ba)?sh\b"), "critical",
     "descarga y ejecuta shell remoto"),
    (re.compile(r"\brm\s+-rf?\s+(/|~|\$HOME)(\s|$|\*)"), "critical",
     "borrado recursivo de rutas raíz o home"),
    (re.compile(r"\b(mkfs|dd\s+if=.*of=/dev/|shred\s+/dev/)"), "critical",
     "operación destructiva sobre dispositivos"),
    (re.compile(r"(id_rsa|id_ed25519|\.ssh/|\.aws/credentials|\.gnupg/|"
                r"auth\.json|\.netrc|keychain)", re.I), "high",
     "acceso a credenciales locales"),
    (re.compile(r"(OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|"
                r"api[_-]?key\s*=\s*['\"][A-Za-z0-9_\-]{12,})", re.I), "high",
     "posible secreto embebido o lectura de claves"),
    (re.compile(r"\beval\s*\(|\bexec\s*\(\s*(base64|bytes\.fromhex)"), "high",
     "ejecución dinámica de código"),
    (re.compile(r"base64\s+(-d|--decode)"), "medium", "decodificación base64 opaca"),
    (re.compile(r"(ignore|olvida|ignora)\s+(all\s+|todas\s+)?(previous|prior|las\s+)?"
                r"(instructions|instrucciones)", re.I), "high",
     "posible inyección de prompt"),
    (re.compile(r"(exfiltrat|enviar?\s+.*(token|clave|credencial))", re.I), "high",
     "posible exfiltración de datos"),
    (re.compile(r"\bsudo\b"), "medium", "requiere privilegios elevados"),
    (re.compile(r"(chmod\s+777|--insecure|verify\s*=\s*False|ssl_verify\s*=\s*False)"),
     "medium", "debilita la seguridad"),
    (re.compile(r"(curl|wget|Invoke-WebRequest|urllib\.request|requests\.(get|post))"),
     "low", "acceso de red"),
]


def audit_text(name: str, text: str) -> list[dict[str, str]]:
    findings: list[dict[str, str]] = []
    for lineno, line in enumerate(text.splitlines(), 1):
        if len(line) > 2000:
            line = line[:2000]
        for pattern, level, message in AUDIT_RULES:
            if pattern.search(line):
                findings.append({
                    "file": name, "line": str(lineno), "level": level,
                    "message": message, "excerpt": line.strip()[:160],
                })
    return findings


def audit_tree(root: Path) -> list[dict[str, str]]:
    findings: list[dict[str, str]] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".gif", ".webp",
                                   ".mp4", ".mp3", ".wav", ".zip", ".pdf",
                                   ".woff", ".woff2", ".ttf", ".otf"}:
            continue
        if path.stat().st_size > 1_500_000:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        findings.extend(audit_text(str(path.relative_to(root)), text))
    return findings


def print_audit(findings: list[dict[str, str]]) -> int:
    weights = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    findings = sorted(findings, key=lambda f: weights.get(f["level"], 9))
    if not findings:
        print(ok("sin hallazgos en el análisis estático"))
        return 0
    for finding in findings:
        color = {"critical": err, "high": warn, "medium": warn,
                 "low": dim}.get(finding["level"], dim)
        print(f"{color(finding['level'].upper()):<18} {finding['file']}:{finding['line']}  "
              f"{finding['message']}")
        if finding["excerpt"]:
            print(f"  {dim(finding['excerpt'])}")
    critical = sum(1 for f in findings if f["level"] == "critical")
    high = sum(1 for f in findings if f["level"] == "high")
    print(f"\n{len(findings)} hallazgos ({critical} críticos, {high} altos)")
    return 2 if critical else (1 if high else 0)
