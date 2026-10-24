#!/usr/bin/env python3
"""sc-kit — administración reproducible de OpenCode V2 (skills, MCP, contenido)."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from kitlib import common as c            # noqa: E402
    from kitlib import contentmgr as content  # noqa: E402
    from kitlib import mcpmgr as mcp          # noqa: E402
    from kitlib import skillmgr as skills     # noqa: E402
else:  # pragma: no cover
    from .kitlib import common as c
    from .kitlib import contentmgr as content
    from .kitlib import mcpmgr as mcp
    from .kitlib import skillmgr as skills

VERSION = "1.0.0"


# --------------------------------------------------------------------------
# estado
# --------------------------------------------------------------------------

def _opencode_version() -> str:
    if not c.which("opencode"):
        return "no instalado"
    proc = c.run(["opencode", "--version"], timeout=30)
    raw = (proc.stdout or "").strip()
    match = __import__("re").search(r"(\d+\.\d+\.\d+\S*)", raw)
    return match.group(1) if match else (raw or "desconocida")


def _agents() -> list[dict]:
    if not c.which("opencode"):
        return []
    proc = c.run(["opencode", "debug", "agents"], timeout=60)
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []


def _agent_model(agent: dict) -> str:
    model = agent.get("model")
    if isinstance(model, dict):
        provider = model.get("providerID", "")
        name = model.get("id") or model.get("model", "")
        variant = model.get("variant")
        return f"{provider}/{name}" + (f"#{variant}" if variant else "")
    return model or "-"


def cmd_doctor(fix: bool = False) -> int:
    checks: list[tuple[str, bool, str]] = []
    config = c.load_config()
    version = _opencode_version()
    checks.append(("OpenCode instalado", c.which("opencode") is not None, version))
    v2 = version.startswith("v2") or version.startswith("2")
    checks.append(("Arquitectura V2", v2, version))

    path = c.config_file()
    checks.append(("Configuración global V2", path.name == "opencode.jsonc", str(path)))
    legacy = "permission" in config or "provider" in config or "agent" in config
    checks.append(("Sin claves V1 obsoletas", not legacy,
                   "usa permissions/providers/agents" if legacy else "correcto"))
    checks.append(("Compactación automática", bool(config.get("compaction", {}).get("auto")),
                   json.dumps(config.get("compaction", {}))))
    checks.append(("Límite de salida de herramientas",
                   "tool_output" in config,
                   json.dumps(config.get("tool_output", {}))))
    checks.append(("Ignorados del watcher", bool(config.get("watcher", {}).get("ignore")),
                   f"{len(config.get('watcher', {}).get('ignore', []))} patrones"))

    sc = Path(os.environ.get("SECOND_BRAIN", c.HOME / "Documentos" / "Segundo-Cerebro"))
    checks.append(("Segundo Cerebro presente", sc.is_dir(), str(sc)))
    webn = c.SKILLS_DIR / "webn-opt" / "SKILL.md"
    checks.append(("WEBN conservada", webn.is_file(),
                   f"{webn} · {len(list((webn.parent / 'references').glob('*.md'))) if webn.exists() else 0} referencias"))
    checks.append(("Instrucciones globales intactas", (c.CONFIG_DIR / "AGENTS.md").is_file(),
                   str(c.CONFIG_DIR / "AGENTS.md")))

    found = skills.discover()
    checks.append(("Skills descubiertas", len(found) > 0, f"{len(found)} skills"))
    servers = mcp.servers()
    checks.append(("MCP configurados", True,
                   f"{len(servers)} ({sum(1 for s in servers.values() if s.get('disabled'))} desactivados)"))

    agents = _agents()
    custom = [a["id"] for a in agents if a["id"].startswith("sc-")]
    checks.append(("Agentes sc-kit cargados", len(custom) >= 4, ", ".join(custom) or "ninguno"))

    tools = {"ffmpeg": "vídeo", "ffprobe": "metadatos", "magick": "imágenes",
             "node": "runtime JS", "pnpm": "paquetes", "rg": "búsqueda",
             "fd": "búsqueda", "jq": "JSON", "git": "control de versiones"}
    missing = [name for name in tools if not c.which(name)]
    checks.append(("Herramientas locales", not missing,
                   "faltan: " + ", ".join(missing) if missing else
                   ", ".join(tools)))

    if c.which("curl"):
        proc = c.run(["curl", "-s", "--max-time", "3",
                      "http://127.0.0.1:11434/api/tags"], timeout=10)
        ollama = proc.returncode == 0 and "models" in (proc.stdout or "")
        local = 0
        if ollama:
            try:
                local = len(json.loads(proc.stdout).get("models", []))
            except json.JSONDecodeError:
                pass
        checks.append(("Ollama activo", ollama, f"{local} modelos locales" if ollama else "no responde"))

    backups = c.list_backups()
    checks.append(("Backups disponibles", len(backups) > 0,
                   f"{len(backups)} · último {backups[-1].name}" if backups else "ninguno"))

    disk = shutil.disk_usage(c.HOME)
    free_gb = disk.free / 1e9
    checks.append(("Espacio libre", free_gb > 5, f"{free_gb:.1f} GB"))

    print(c.bold(f"sc-kit doctor — OpenCode {version}"))
    print()
    failures = 0
    for name, passed, detail in checks:
        mark = c.ok("OK  ") if passed else c.err("FALLA")
        if not passed:
            failures += 1
        print(f"  {mark} {name:<32} {c.dim(detail)}")
    print()
    if failures:
        print(c.warn(f"{failures} comprobaciones requieren atención"))
    else:
        print(c.ok("todo correcto"))
    if fix:
        print(c.dim("\n--fix no aplica cambios automáticos: revisa cada FALLA y usa "
                    "`sc-kit backup` antes de tocar la configuración."))
    return 1 if failures else 0


def cmd_status(as_json: bool = False) -> int:
    found = skills.discover()
    enabled = [s for s in found if s["status"] == "enabled"]
    servers = mcp.servers()
    live = mcp.live_status()
    settings = c.load_json(c.SETTINGS_FILE, {})
    backups = c.list_backups(include_safety=False)
    agents = [a for a in _agents() if not a.get("hidden")]
    payload = {
        "opencode": _opencode_version(),
        "config": str(c.config_file()),
        "skills": {
            "total": len(found),
            "enabled": len(enabled),
            "disabled": len(found) - len(enabled),
            "global": sum(1 for s in found if s["source"] == "global"),
            "project": sum(1 for s in found if s["source"] == "project"),
        },
        "mcp": {
            name: ("disabled" if entry.get("disabled") else live.get(name, "configurado"))
            for name, entry in servers.items()
        },
        "mcp_profile": settings.get("mcp_profile", "sin perfil"),
        "agents": {a["id"]: _agent_model(a) for a in agents},
        "content_root": str(content.root()),
        "backups": [b.name for b in backups[-3:]],
    }
    if as_json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0
    print(c.bold(f"OpenCode {payload['opencode']}"))
    print(f"  config       {payload['config']}")
    print(f"  skills       {enabled.__len__()} activas / {len(found)} descubiertas")
    print(f"  MCP          {len(servers)} configurados · perfil "
          f"{c.bold(str(payload['mcp_profile']))}")
    for name, state in payload["mcp"].items():
        print(f"    - {name}: {state}")
    print("  agentes      " + ", ".join(sorted(payload["agents"])) )
    print(f"  contenido    {payload['content_root']}")
    print(f"  backups      {', '.join(payload['backups']) or 'ninguno'}")
    print(c.dim("\nsc-kit doctor · sc-kit skill list · sc-kit mcp list · sc-kit content list"))
    return 0


def cmd_models() -> int:
    agents = [a for a in _agents() if not a.get("hidden")]
    if not agents:
        print("no se pudieron leer los agentes")
        return 1
    rows = [[a["id"], a.get("mode", "-"), _agent_model(a),
             str(a.get("steps", "-")), (a.get("description") or "")[:60]] for a in agents]
    c.table(rows, ["agente", "modo", "modelo", "pasos", "descripción"])
    print(c.dim("\nCambia de perfil desde el selector de agentes (Ctrl+X A o /agents) "
                "o invoca /sc-u-fast, /sc-u-build, /sc-u-deep."))
    return 0


def cmd_usage(as_json: bool = False, days: int | None = None) -> int:
    if not c.which("opencode"):
        c.die("opencode no está instalado")
    args = ["stats", "--cost", "--models", "--limit", "12"]
    if days is not None:
        args += ["--days", str(days)]
    if as_json:
        args += ["--json"]
    proc = c.run(["opencode", *args], timeout=90)
    output = (proc.stdout or "").strip()
    if not output:
        c.die((proc.stderr or "sin datos").strip())
    print(output)
    return 0 if proc.returncode == 0 else 1


def cmd_compat(link: bool = False) -> int:
    print(c.bold("compatibilidad entre agentes"))
    locations = [
        ("OpenCode global", c.SKILLS_DIR),
        ("OpenCode compartido", c.SHARED_SKILLS),
        ("Claude Code", c.CLAUDE_SKILLS),
        ("Instrucciones OpenCode", c.CONFIG_DIR / "AGENTS.md"),
        ("Codex CLI", c.HOME / ".codex" / "AGENTS.md"),
    ]
    for label, path in locations:
        state = "existe" if path.exists() else "no existe"
        print(f"  {label:<22} {state:<11} {c.dim(str(path))}")
    if link:
        c.CLAUDE_SKILLS.mkdir(parents=True, exist_ok=True)
        linked, skipped = 0, 0
        for item in sorted(c.SKILLS_DIR.iterdir()):
            if not (item.is_dir() and (item / "SKILL.md").is_file()):
                continue
            target = c.CLAUDE_SKILLS / item.name
            if target.exists() or target.is_symlink():
                skipped += 1
                continue
            target.symlink_to(item, target_is_directory=True)
            linked += 1
        print(f"\n{linked} enlaces creados en {c.CLAUDE_SKILLS}, {skipped} ya existían")
        c.log_event("compat-link", "claude-skills", f"{linked} enlaces")
    print(c.dim("\nLas skills de ~/.agents/skills y ~/.claude/skills las lee OpenCode. "
                "Claude Code solo lee ~/.claude/skills; usa --link para enlazarlas."))
    return 0


# --------------------------------------------------------------------------
# parser
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="sc-kit",
        description="Administrador de skills, MCP y contenido para OpenCode V2.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""ejemplos:
  sc-kit skill add https://github.com/obra/superpowers --path skills/brainstorming
  sc-kit skill list
  sc-kit mcp add context7 --url https://mcp.context7.com/mcp
  sc-kit mcp add playwright --package @playwright/mcp@latest
  sc-kit mcp profile apply web
  sc-kit content new mi-video
  sc-kit backup
""")
    parser.add_argument("--version", action="version", version=f"sc-kit {VERSION}")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("doctor", help="diagnóstico del entorno").add_argument(
        "--fix", action="store_true", help="mostrar sugerencias de reparación")
    status = sub.add_parser("status", help="panel breve del estado")
    status.add_argument("--json", action="store_true")
    sub.add_parser("models", help="agentes y modelos efectivos")
    usage = sub.add_parser("usage", help="consumo real de tokens y coste (según OpenCode)")
    usage.add_argument("--json", action="store_true")
    usage.add_argument("--days", type=int)
    compat = sub.add_parser("compat", help="rutas compartidas con otros agentes")
    compat.add_argument("--link", action="store_true",
                        help="enlazar skills globales en ~/.claude/skills")

    sub.add_parser("backup", help="crear copia de seguridad de la configuración")
    sub.add_parser("backups", help="listar copias de seguridad")
    rollback = sub.add_parser("rollback", help="restaurar una copia de seguridad")
    rollback.add_argument("ref", nargs="?", default="last",
                          help="nombre del backup o 'last'")
    rollback.add_argument("--dry-run", action="store_true")
    rollback.add_argument("--with-kit", action="store_true",
                          help="restaurar también el código del gestor")

    # skills
    skill = sub.add_parser("skill", help="gestor de skills")
    skill_sub = skill.add_subparsers(dest="skill_command", required=True)
    add = skill_sub.add_parser("add", help="instalar desde git, carpeta o zip")
    add.add_argument("source")
    add.add_argument("--name")
    add.add_argument("--scope", choices=["global", "shared", "project"], default="global")
    add.add_argument("--path", dest="subpath")
    add.add_argument("--force", action="store_true")
    add.add_argument("--yes", action="store_true")
    add.add_argument("--no-audit", action="store_true")
    lst = skill_sub.add_parser("list", help="listar skills")
    lst.add_argument("--json", action="store_true")
    info = skill_sub.add_parser("info", help="detalle de una skill")
    info.add_argument("id")
    for name, help_text in (("enable", "reactivar"), ("disable", "desactivar")):
        action = skill_sub.add_parser(name, help=help_text)
        action.add_argument("id")
    remove = skill_sub.add_parser("remove", help="archivar o purgar")
    remove.add_argument("id")
    remove.add_argument("--purge", action="store_true")
    remove.add_argument("--yes", action="store_true")
    update = skill_sub.add_parser("update", help="actualizar desde su origen")
    update.add_argument("id", nargs="?")
    update.add_argument("--yes", action="store_true")
    skill_sub.add_parser("update-all", help="actualizar todas")
    audit = skill_sub.add_parser("audit", help="auditoría estática")
    audit.add_argument("id", nargs="?")
    search = skill_sub.add_parser("search", help="buscar entre las instaladas")
    search.add_argument("query")
    verify = skill_sub.add_parser("verify", help="comprobar integridad")
    verify.add_argument("id", nargs="?")

    # mcp
    mcpp = sub.add_parser("mcp", help="gestor de servidores MCP")
    msub = mcpp.add_subparsers(dest="mcp_command", required=True)
    ml = msub.add_parser("list", help="listar servidores")
    ml.add_argument("--json", action="store_true")
    mi = msub.add_parser("info", help="detalle")
    mi.add_argument("name")
    ma = msub.add_parser("add", help="añadir servidor")
    ma.add_argument("name")
    ma.add_argument("--url")
    ma.add_argument("--stdio", help='comando local, p. ej. "npx -y paquete"')
    ma.add_argument("--package", help="paquete npm ejecutado con npx")
    ma.add_argument("--python", help="paquete PyPI ejecutado con uvx")
    ma.add_argument("--header", action="append", help="clave=valor (usa {env:VAR})")
    ma.add_argument("--env", action="append", help="clave=valor")
    ma.add_argument("--scope", default="global", choices=["global"])
    ma.add_argument("--yes", action="store_true")
    ma.add_argument("--no-test", action="store_true")
    ma.add_argument("--disable", action="store_true")
    for name, help_text in (("enable", "habilitar"), ("disable", "deshabilitar")):
        action = msub.add_parser(name, help=help_text)
        action.add_argument("name")
    mr = msub.add_parser("remove", help="eliminar")
    mr.add_argument("name")
    mr.add_argument("--yes", action="store_true")
    mr.add_argument("--logout", action="store_true")
    mt = msub.add_parser("test", help="probar conexión y herramientas")
    mt.add_argument("name")
    mt.add_argument("--timeout", type=int, default=30)
    mtools = msub.add_parser("tools", help="listar herramientas del servidor")
    mtools.add_argument("name")
    mtools.add_argument("--json", action="store_true")
    mdbg = msub.add_parser("debug", help="diagnóstico detallado")
    mdbg.add_argument("name")
    mauth = msub.add_parser("auth", help="instrucciones de autenticación OAuth")
    mauth.add_argument("name")
    mprof = msub.add_parser("profile", help="perfiles de herramientas")
    mprof.add_argument("action", choices=["list", "show", "apply", "save"])
    mprof.add_argument("name", nargs="?")
    msearch = msub.add_parser("search", help="catálogo y registro npm")
    msearch.add_argument("query")
    msearch.add_argument("--remote", action="store_true")
    maudit = msub.add_parser("audit", help="revisión de configuración")
    maudit.add_argument("name", nargs="?")
    mexp = msub.add_parser("export", help="exportar configuración")
    mexp.add_argument("file", nargs="?")
    mimp = msub.add_parser("import", help="importar configuración")
    mimp.add_argument("file")
    mimp.add_argument("--yes", action="store_true")
    mupd = msub.add_parser("update", help="comprobar versiones de paquetes")
    mupd.add_argument("name", nargs="?")
    mupd.add_argument("--apply", action="store_true")
    mres = msub.add_parser("resolve", help="analizar un enlace antes de instalar")
    mres.add_argument("url")

    # contenido
    cnt = sub.add_parser("content", help="Content Studio local")
    csub = cnt.add_subparsers(dest="content_command", required=True)
    cn = csub.add_parser("new", help="crear proyecto")
    cn.add_argument("slug")
    cn.add_argument("--title")
    cn.add_argument("--format", default="short", choices=sorted(content.FORMATS))
    csub.add_parser("list", help="listar proyectos")
    ct = csub.add_parser("thumb", help="generar miniatura")
    ct.add_argument("target")
    ct.add_argument("--title")
    ct.add_argument("--kicker")
    ct.add_argument("--format", default="short", choices=sorted(content.FORMATS))
    ct.add_argument("--image")
    ct.add_argument("--output")
    cs = csub.add_parser("subs", help="generar subtítulos SRT/ASS")
    cs.add_argument("target")
    cr = csub.add_parser("render", help="renderizar vídeo")
    cr.add_argument("target")
    cr.add_argument("--format", choices=sorted(content.FORMATS))
    cr.add_argument("--dry-run", action="store_true")
    cr.add_argument("--no-subs", action="store_true")
    cr.add_argument("--crf", type=int, default=23)
    cr.add_argument("--preset", default="veryfast")
    cc = csub.add_parser("carousel", help="generar carrusel desde un texto")
    cc.add_argument("target")
    cc.add_argument("--texts")
    cp = csub.add_parser("probe", help="analizar un archivo multimedia")
    cp.add_argument("file")
    co = csub.add_parser("optimize", help="optimizar para publicación")
    co.add_argument("file")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    c.ensure_dirs()

    try:
        if args.command == "doctor":
            return cmd_doctor(args.fix)
        if args.command == "status":
            return cmd_status(args.json)
        if args.command == "models":
            return cmd_models()
        if args.command == "usage":
            return cmd_usage(args.json, args.days)
        if args.command == "compat":
            return cmd_compat(args.link)
        if args.command == "backup":
            c.backup("manual")
            return 0
        if args.command == "backups":
            rows = []
            for item in c.list_backups():
                meta = c.load_json(item / "meta.json", {})
                rows.append([item.name, meta.get("label", "-"), meta.get("created", "-"),
                             str(meta.get("files", "-"))])
            c.table(rows, ["backup", "motivo", "fecha", "ficheros"])
            return 0
        if args.command == "rollback":
            c.rollback(args.ref, dry_run=args.dry_run, with_kit=args.with_kit)
            return 0

        if args.command == "skill":
            action = args.skill_command
            if action == "add":
                return skills.cmd_add(args.source, name=args.name, scope=args.scope,
                                      subpath=args.subpath, force=args.force,
                                      yes=args.yes, no_audit=args.no_audit)
            if action == "list":
                return skills.cmd_list(args.json)
            if action == "info":
                return skills.cmd_info(args.id)
            if action == "enable":
                return skills.cmd_enable(args.id)
            if action == "disable":
                return skills.cmd_disable(args.id)
            if action == "remove":
                return skills.cmd_remove(args.id, purge=args.purge, yes=args.yes)
            if action == "update":
                return skills.cmd_update(args.id, yes=args.yes)
            if action == "update-all":
                return skills.cmd_update(None, yes=False)
            if action == "audit":
                return skills.cmd_audit(args.id)
            if action == "search":
                return skills.cmd_search(args.query)
            if action == "verify":
                return skills.cmd_verify(args.id)

        if args.command == "mcp":
            action = args.mcp_command
            if action == "list":
                return mcp.cmd_list(args.json)
            if action == "info":
                return mcp.cmd_info(args.name)
            if action == "add":
                return mcp.cmd_add(args.name, url=args.url, stdio=args.stdio,
                                   headers=args.header, env=args.env, scope=args.scope,
                                   package=args.package, python=args.python,
                                   yes=args.yes, test=not args.no_test,
                                   disable=args.disable)
            if action == "enable":
                return mcp.cmd_enable(args.name, True)
            if action == "disable":
                return mcp.cmd_enable(args.name, False)
            if action == "remove":
                return mcp.cmd_remove(args.name, yes=args.yes, logout=args.logout)
            if action == "test":
                return mcp.cmd_test(args.name, args.timeout)
            if action == "tools":
                return mcp.cmd_tools(args.name, args.json)
            if action == "debug":
                return mcp.cmd_debug(args.name)
            if action == "auth":
                return mcp.cmd_auth(args.name)
            if action == "profile":
                return mcp.cmd_profile(args.action, args.name)
            if action == "search":
                return mcp.cmd_search(args.query, args.remote)
            if action == "audit":
                return mcp.cmd_audit(args.name)
            if action == "export":
                return mcp.cmd_export(args.file)
            if action == "import":
                return mcp.cmd_import(args.file, yes=args.yes)
            if action == "update":
                return mcp.cmd_update(args.name, apply=args.apply)
            if action == "resolve":
                return mcp.cmd_resolve(args.url)

        if args.command == "content":
            action = args.content_command
            if action == "new":
                return content.cmd_new(args.slug, args.title, args.format)
            if action == "list":
                return content.cmd_list()
            if action == "thumb":
                return content.cmd_thumb(args.target, title=args.title,
                                         kicker=args.kicker, fmt=args.format,
                                         image=args.image, output=args.output)
            if action == "subs":
                return content.cmd_subs(args.target)
            if action == "render":
                return content.cmd_render(args.target, fmt=args.format,
                                          dry_run=args.dry_run, no_subs=args.no_subs,
                                          crf=args.crf, preset=args.preset)
            if action == "carousel":
                return content.cmd_carousel(args.target, args.texts)
            if action == "probe":
                return content.cmd_probe(args.file)
            if action == "optimize":
                return content.cmd_optimize(args.file)

        parser.error("comando no implementado")
        return 2
    except KeyboardInterrupt:
        print("\ncancelado", file=sys.stderr)
        return 130
    except RuntimeError as exc:
        print(f"{c.err('error')}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
