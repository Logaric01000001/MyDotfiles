"""Gestor de servidores MCP para OpenCode V2."""

from __future__ import annotations

import json
import os
import re
import select
import signal
import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from . import common as c

DEFAULT_PROFILES = {
    "minimal": [],
    "web": ["context7", "playwright", "fetch", "chrome-devtools"],
    "code": ["context7", "github", "filesystem", "git", "sequential-thinking"],
    "design": ["figma", "canva", "playwright", "context7"],
    "content": ["context7", "playwright", "figma", "canva", "fetch"],
    "devops": ["context7", "github", "filesystem", "sentry"],
    "security": ["context7", "filesystem", "git", "fetch"],
}

CATALOG = [
    {"name": "context7", "kind": "remote", "url": "https://mcp.context7.com/mcp",
     "why": "documentación actualizada de librerías", "profile": "web"},
    {"name": "playwright", "kind": "local", "command": ["npx", "-y", "@playwright/mcp@latest"],
     "why": "navegador real para pruebas web", "profile": "web"},
    {"name": "chrome-devtools", "kind": "local",
     "command": ["npx", "-y", "chrome-devtools-mcp@latest"],
     "why": "inspección de rendimiento y red", "profile": "web"},
    {"name": "github", "kind": "remote", "url": "https://api.githubcopilot.com/mcp/",
     "why": "repos, issues y PRs (OAuth)", "profile": "code"},
    {"name": "figma", "kind": "remote", "url": "https://mcp.figma.com/mcp",
     "why": "diseño y componentes (OAuth)", "profile": "design"},
    {"name": "canva", "kind": "remote", "url": "https://mcp.canva.com/mcp",
     "why": "diseño gráfico y exportaciones (OAuth)", "profile": "content"},
    {"name": "sentry", "kind": "remote", "url": "https://mcp.sentry.dev/mcp",
     "why": "errores de producción (OAuth)", "profile": "devops"},
    {"name": "filesystem", "kind": "local",
     "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "{cwd}"],
     "why": "acceso acotado a ficheros", "profile": "code"},
    {"name": "git", "kind": "local", "command": ["uvx", "mcp-server-git"],
     "why": "operaciones Git guiadas", "profile": "code"},
    {"name": "fetch", "kind": "local", "command": ["uvx", "mcp-server-fetch"],
     "why": "descarga y conversión de páginas", "profile": "web"},
    {"name": "time", "kind": "local", "command": ["uvx", "mcp-server-time"],
     "why": "zonas horarias", "profile": "code"},
    {"name": "sequential-thinking", "kind": "local",
     "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"],
     "why": "razonamiento estructurado", "profile": "code"},
    {"name": "memory", "kind": "local",
     "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
     "why": "grafo de memoria simple (SC ya cubre memoria; solo si lo necesitas)",
     "profile": "code"},
]


# --------------------------------------------------------------------------
# configuración
# --------------------------------------------------------------------------

def servers() -> dict:
    config = c.load_config()
    mcp = config.get("mcp") or {}
    if isinstance(mcp.get("servers"), dict):
        return mcp["servers"]
    # compatibilidad con V1: nombres directamente bajo mcp
    legacy = {k: v for k, v in mcp.items() if isinstance(v, dict) and k != "timeout"}
    return legacy


def _write_servers(data: dict) -> None:
    config = c.load_config()
    mcp = config.setdefault("mcp", {})
    if not isinstance(mcp, dict):
        mcp = {}
        config["mcp"] = mcp
    mcp["servers"] = data
    mcp.setdefault("timeout", {"startup": 30000, "catalog": 30000, "execution": 600000})
    c.save_config(config)


def registry() -> dict:
    return c.registry(c.MCP_REGISTRY, "servers")


def _reg_entry(name: str, entry: dict) -> None:
    data = registry()
    current = data["servers"].get(name, {})
    current.update(entry)
    current.setdefault("installed_at", c.now_iso())
    data["servers"][name] = current
    c.save_json(c.MCP_REGISTRY, data)


def mask(value: str) -> str:
    if value.startswith("{env:"):
        return value
    return value[:4] + "***" if len(value) > 6 else "***"


def _redact_server(entry: dict) -> dict:
    out = json.loads(json.dumps(entry))
    for key in ("headers", "environment"):
        if isinstance(out.get(key), dict):
            out[key] = {k: mask(str(v)) for k, v in out[key].items()}
    return out


# --------------------------------------------------------------------------
# cliente de prueba MCP (stdio y Streamable HTTP)
# --------------------------------------------------------------------------

class ProbeError(RuntimeError):
    pass


def _read_line(stream, deadline: float) -> str:
    while time.time() < deadline:
        ready, _, _ = select.select([stream], [], [], max(0.05, deadline - time.time()))
        if not ready:
            continue
        line = stream.readline()
        if not line:
            raise ProbeError("el servidor cerró stdout")
        return line
    raise ProbeError("tiempo de espera agotado")


def _jsonrpc(stdin, stdout, message: dict, deadline: float, *, expect_id=None) -> dict:
    stdin.write(json.dumps(message) + "\n")
    stdin.flush()
    while time.time() < deadline:
        line = _read_line(stdout, deadline).strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "id" in payload and (expect_id is None or payload["id"] == expect_id):
            if "error" in payload:
                raise ProbeError(f"error JSON-RPC {payload['error'].get('code')}: "
                                 f"{payload['error'].get('message')}")
            return payload
    raise ProbeError("sin respuesta JSON-RPC")


def probe_stdio(command: list[str], env: dict | None = None,
                cwd: str | None = None, timeout: int = 25) -> dict:
    if not command:
        raise ProbeError("comando vacío")
    executable = shutil.which(command[0])
    if not executable:
        raise ProbeError(f"ejecutable no encontrado: {command[0]}")
    started = time.time()
    stderr_lines: list[str] = []

    try:
        proc = subprocess.Popen(
            command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, bufsize=1, cwd=cwd,
            env={**os.environ, **(env or {})},
            start_new_session=True,
        )
    except OSError as exc:
        raise ProbeError(str(exc))

    def drain():
        assert proc.stderr is not None
        for line in proc.stderr:
            stderr_lines.append(line.rstrip())
            if len(stderr_lines) > 60:
                stderr_lines.pop(0)

    thread = threading.Thread(target=drain, daemon=True)
    thread.start()
    deadline = time.time() + timeout
    try:
        assert proc.stdin is not None and proc.stdout is not None
        init = _jsonrpc(proc.stdin, proc.stdout, {
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {"roots": {"listChanged": False}},
                "clientInfo": {"name": "sc-kit", "version": "1.0"},
            },
        }, deadline, expect_id=1)
        proc.stdin.write(json.dumps({"jsonrpc": "2.0",
                                     "method": "notifications/initialized"}) + "\n")
        proc.stdin.flush()
        tools: list[dict] = []
        cursor = None
        for _ in range(10):
            params = {"cursor": cursor} if cursor else {}
            listing = _jsonrpc(proc.stdin, proc.stdout, {
                "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": params,
            }, deadline, expect_id=2)
            result = listing.get("result", {})
            tools.extend(result.get("tools", []))
            cursor = result.get("nextCursor")
            if not cursor:
                break
        info = init.get("result", {})
        return {
            "ok": True,
            "transport": "stdio",
            "server": info.get("serverInfo", {}),
            "protocol": info.get("protocolVersion"),
            "capabilities": sorted((info.get("capabilities") or {}).keys()),
            "tools": tools,
            "latency_ms": int((time.time() - started) * 1000),
            "stderr": stderr_lines[-5:],
        }
    except (ProbeError, OSError) as exc:
        raise ProbeError(f"{exc}. stderr: {' | '.join(stderr_lines[-3:]) or '(vacío)'}")
    finally:
        try:
            if proc.poll() is None:
                # mata el grupo completo: wine lanza procesos Windows hijos
                os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
                try:
                    proc.wait(timeout=4)
                except subprocess.TimeoutExpired:
                    os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        except (OSError, ProcessLookupError):
            pass


def _http_post(url: str, payload: dict, headers: dict, timeout: int,
               session: str | None = None) -> tuple[dict, dict]:
    body = json.dumps(payload).encode()
    request = urllib.request.Request(url, data=body, method="POST")
    request.add_header("Content-Type", "application/json")
    request.add_header("Accept", "application/json, text/event-stream")
    for key, value in headers.items():
        request.add_header(key, value)
    if session:
        request.add_header("Mcp-Session-Id", session)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode(errors="replace")
            meta = dict(response.headers)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:300]
        if exc.code in (401, 403):
            raise ProbeError(f"HTTP {exc.code}: requiere autenticación OAuth o cabeceras")
        raise ProbeError(f"HTTP {exc.code}: {detail}")
    except urllib.error.URLError as exc:
        raise ProbeError(f"sin conexión: {exc.reason}")
    if not raw.strip():
        return {}, meta
    if raw.lstrip().startswith("event:") or "\ndata:" in raw:
        for chunk in raw.split("\n\n"):
            for line in chunk.splitlines():
                if line.startswith("data:"):
                    candidate = line[5:].strip()
                    if candidate:
                        try:
                            return json.loads(candidate), meta
                        except json.JSONDecodeError:
                            continue
        return {}, meta
    try:
        return json.loads(raw), meta
    except json.JSONDecodeError:
        raise ProbeError(f"respuesta no JSON: {raw[:160]}")


def probe_remote(url: str, headers: dict | None = None, timeout: int = 25) -> dict:
    if not re.match(r"^https?://", url):
        raise ProbeError("la URL debe ser absoluta (http/https)")
    started = time.time()
    headers = headers or {}
    init, meta = _http_post(url, {
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {"roots": {"listChanged": False}},
            "clientInfo": {"name": "sc-kit", "version": "1.0"},
        },
    }, headers, timeout)
    if "error" in init:
        raise ProbeError(f"error initialize: {init['error'].get('message')}")
    session = None
    for key, value in meta.items():
        if key.lower() == "mcp-session-id":
            session = value
    try:
        _http_post(url, {"jsonrpc": "2.0", "method": "notifications/initialized"},
                   headers, timeout, session)
    except ProbeError:
        pass
    tools: list[dict] = []
    cursor = None
    for _ in range(10):
        params = {"cursor": cursor} if cursor else {}
        listing, _ = _http_post(url, {
            "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": params,
        }, headers, timeout, session)
        if "error" in listing:
            raise ProbeError(f"error tools/list: {listing['error'].get('message')}")
        result = listing.get("result", {})
        tools.extend(result.get("tools", []))
        cursor = result.get("nextCursor")
        if not cursor:
            break
    info = init.get("result", {})
    return {
        "ok": True,
        "transport": "remote",
        "server": info.get("serverInfo", {}),
        "protocol": info.get("protocolVersion"),
        "capabilities": sorted((info.get("capabilities") or {}).keys()),
        "tools": tools,
        "latency_ms": int((time.time() - started) * 1000),
        "stderr": [],
    }


def probe(name: str, timeout: int = 25) -> dict:
    entry = servers().get(name)
    if not entry:
        raise ProbeError(f"MCP no configurado: {name}")
    if entry.get("type") == "remote" or entry.get("url"):
        return probe_remote(entry["url"], entry.get("headers"), timeout)
    return probe_stdio(entry.get("command", []), entry.get("environment"),
                       entry.get("cwd"), timeout)


# --------------------------------------------------------------------------
# estado en el servicio en marcha
# --------------------------------------------------------------------------

def live_status() -> dict[str, str]:
    if not c.which("opencode"):
        return {}
    proc = c.run(["opencode", "api", "get", "/api/mcp"], timeout=30)
    if proc.returncode != 0 or not proc.stdout.strip():
        return {}
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {}
    status: dict[str, str] = {}
    for item in payload.get("data", []) or []:
        if not isinstance(item, dict):
            continue
        name = item.get("name") or item.get("id")
        state = item.get("status") or item.get("state") or item.get("type")
        if isinstance(state, dict):
            state = state.get("status") or state.get("type")
        if name:
            status[str(name)] = str(state or "configurado")
    return status


# --------------------------------------------------------------------------
# comandos
# --------------------------------------------------------------------------

def cmd_list(as_json: bool = False) -> int:
    data = servers()
    reg = registry()["servers"]
    live = live_status()
    rows = []
    for name, entry in sorted(data.items()):
        transport = entry.get("type") or ("remote" if entry.get("url") else "local")
        state = "disabled" if entry.get("disabled") else live.get(name, "configurado")
        target = entry.get("url") or " ".join(entry.get("command", []))
        tested = reg.get(name, {}).get("tested", {})
        rows.append([name, transport, state, str(len(tested.get("tools", [])) or "-"),
                     str(target)[:56]])
    if as_json:
        print(json.dumps({
            "servers": data,
            "live": live,
            "registry": {k: v for k, v in reg.items()},
        }, indent=2, ensure_ascii=False))
        return 0
    c.table(rows, ["nombre", "tipo", "estado", "tools", "destino"])
    if not data:
        print(c.dim("\nNo hay MCP configurados. Instala uno con: sc-kit mcp add <nombre> --url ..."))
    print(c.dim("\nPerfiles: sc-kit mcp profile list · Detalle: sc-kit mcp info <nombre>"))
    return 0


def cmd_info(name: str) -> int:
    entry = servers().get(name)
    if not entry:
        c.die(f"MCP no configurado: {name}")
    reg = registry()["servers"].get(name, {})
    print(c.bold(name))
    print(json.dumps(_redact_server(entry), indent=2, ensure_ascii=False))
    if reg:
        print(c.dim("registro:"))
        print(f"  origen     {reg.get('source', '-')}")
        print(f"  instalado  {reg.get('installed_at', '-')}")
        print(f"  probado    {reg.get('tested', {}).get('at', 'nunca')}")
    return 0


def _validate_command(command: list[str]) -> list[str]:
    problems = []
    if not command:
        problems.append("comando vacío")
        return problems
    if not shutil.which(command[0]):
        problems.append(f"ejecutable no encontrado: {command[0]}")
    if command[0] in {"npx", "npm", "pnpm", "bunx"}:
        pkg = next((a for a in command[1:]
                    if not a.startswith("-") and a not in {"dlx", "exec", "run", "x"}), None)
        if pkg and not re.search(r"@\d", pkg):
            problems.append(f"paquete sin versión fijada ({pkg}); una actualización puede cambiar el código")
    if any(a in {"--allow-all", "--dangerously-skip-permissions"} for a in command):
        problems.append("flag que desactiva salvaguardas")
    return problems


def cmd_add(name: str, *, url: str | None = None, stdio: str | None = None,
            headers: list[str] | None = None, env: list[str] | None = None,
            scope: str = "global", package: str | None = None,
            python: str | None = None, yes: bool = False, test: bool = True,
            disable: bool = False) -> int:
    c.ensure_dirs()
    if scope != "global":
        c.die("por ahora sc-kit escribe la configuración global; usa --global "
              "(el proyecto puede sobrescribir por nombre)")
    if not c.re.match(r"^[a-z0-9][a-z0-9-]{0,62}$", name):
        c.die("nombre inválido: usa minúsculas, números y guiones")

    existing = servers()
    if name in existing:
        c.die(f"ya existe un MCP llamado {name}. Usa `sc-kit mcp remove {name}` o elige otro nombre.")

    entry: dict
    source = ""
    if url:
        if not re.match(r"^https?://", url):
            c.die("la URL debe empezar por http:// o https://")
        entry = {"type": "remote", "url": url}
        if headers:
            entry["headers"] = dict(h.split("=", 1) for h in headers)
        source = url
        if url.startswith("http://"):
            print(c.warn("aviso: transporte remoto sin TLS (http://); no envíes credenciales."))
    elif package:
        entry = {"type": "local", "command": ["npx", "-y", package]}
        source = f"npm:{package}"
    elif python:
        entry = {"type": "local", "command": ["uvx", python]}
        source = f"pypi:{python}"
    elif stdio:
        import shlex
        entry = {"type": "local", "command": shlex.split(stdio)}
        source = f"cmd:{stdio}"
    else:
        c.die("indica --url, --package, --python o --stdio \"comando args\"")

    if env:
        entry["environment"] = dict(e.split("=", 1) for e in env)
    if disable:
        entry["disabled"] = True

    problems = _validate_command(entry.get("command", [])) if entry["type"] == "local" else []
    for key, value in (entry.get("headers") or {}).items():
        if re.search(r"(AUTH|TOKEN|KEY|SECRET|COOKIE|PASSWORD)", key, re.I) \
                and not str(value).startswith("{env:"):
            problems.append(f"cabecera {key} parece contener un secreto; usa {{env:VAR}}")
    for key, value in (entry.get("environment") or {}).items():
        if not str(value).startswith("{env:") and re.search(r"(KEY|TOKEN|SECRET|PASSWORD)", key):
            problems.append(f"variable {key} parece secreta y está en claro; usa {{env:{key}}}")

    print(c.bold(f"plan: {name}"))
    print(json.dumps(_redact_server(entry), indent=2, ensure_ascii=False))
    for problem in problems:
        print(c.warn(f"  aviso: {problem}"))

    probe_result = None
    if test:
        print(c.dim("probando conexión y catálogo de herramientas…"))
        try:
            result = probe_entry(entry, timeout=30)
            probe_result = result
            print(f"  {c.ok('conecta')} · {result['transport']} · "
                  f"{len(result['tools'])} herramientas · {result['latency_ms']} ms")
        except ProbeError as exc:
            print(f"  {c.err('fallo de conexión')}: {exc}")
            if not yes:
                answer = input("¿Guardar igualmente (podrás depurarlo)? [s/N] ").strip().lower()
                if answer not in {"s", "si", "sí", "y", "yes"}:
                    c.die("cancelado; no se escribió nada")

    if not yes:
        answer = input(f"¿Añadir {name} a la configuración global? [s/N] ").strip().lower()
        if answer not in {"s", "si", "sí", "y", "yes"}:
            c.die("cancelado")

    data = servers()
    data[name] = entry
    _write_servers(data)
    record = {"name": name, "source": source, "transport": entry["type"],
              "status": "disabled" if entry.get("disabled") else "enabled"}
    if probe_result:
        record["tested"] = {
            "at": c.now_iso(), "ok": True, "transport": probe_result["transport"],
            "server": probe_result.get("server", {}),
            "tools": [t.get("name") for t in probe_result["tools"]],
            "latency_ms": probe_result["latency_ms"],
        }
    _reg_entry(name, record)
    c.log_event("mcp-add", name, source)
    print(f"{c.ok('añadido')} {name}")
    print(c.dim("OpenCode reconecta al recargar la configuración (`opencode reload`) o al reiniciar."))
    return 0


def probe_entry(entry: dict, timeout: int = 30) -> dict:
    if entry.get("type") == "remote" or entry.get("url"):
        return probe_remote(entry["url"], entry.get("headers"), timeout)
    return probe_stdio(entry.get("command", []), entry.get("environment"),
                       entry.get("cwd"), timeout)


def cmd_test(name: str, timeout: int = 30) -> int:
    try:
        result = probe(name, timeout)
    except ProbeError as exc:
        print(c.err(f"fallo: {exc}"))
        _reg_entry(name, {"tested": {"at": c.now_iso(), "ok": False,
                                     "error": str(exc)[:300]}})
        return 1
    server = result.get("server", {})
    print(f"{c.ok('conecta')} · {result['transport']} · {result['latency_ms']} ms")
    print(f"  servidor   {server.get('name', '?')} {server.get('version', '')}")
    print(f"  protocolo  {result.get('protocol')}")
    print(f"  capacidades {', '.join(result.get('capabilities') or []) or '-'}")
    print(f"  herramientas {len(result['tools'])}")
    reg = registry()["servers"].get(name, {})
    _reg_entry(name, {
        "tested": {
            "at": c.now_iso(), "ok": True, "transport": result["transport"],
            "server": server, "tools": [t.get("name") for t in result["tools"]],
            "latency_ms": result["latency_ms"],
        },
        "status": "enabled" if not reg.get("disabled") else "disabled",
    })
    return 0


def cmd_tools(name: str, as_json: bool = False, timeout: int = 30) -> int:
    try:
        result = probe(name, timeout)
    except ProbeError as exc:
        c.die(str(exc))
    tools = result["tools"]
    if as_json:
        print(json.dumps(tools, indent=2, ensure_ascii=False))
        return 0
    rows = []
    for tool in tools:
        schema = tool.get("inputSchema") or {}
        params = ", ".join((schema.get("properties") or {}).keys())
        rows.append([tool.get("name", "?"), (tool.get("description") or "")[:70], params[:50]])
    c.table(rows, ["tool", "descripción", "parámetros"])
    print(c.dim(f"\n{len(tools)} herramientas en {name}"))
    return 0


def cmd_debug(name: str) -> int:
    entry = servers().get(name)
    if not entry:
        c.die(f"MCP no configurado: {name}")
    print(c.bold(f"debug {name}"))
    print(json.dumps(_redact_server(entry), indent=2, ensure_ascii=False))
    if entry.get("type") == "local":
        binary = entry.get("command", [None])[0]
        print(f"  ejecutable: {shutil.which(binary) if binary else '?'}")
        if binary and shutil.which(binary) is None:
            print(c.err("  el ejecutable no existe en PATH"))
    live = live_status()
    print(f"  estado en servicio: {live.get(name, 'no reportado')}")
    print(c.dim("  prueba directa:"))
    code = cmd_test(name)
    log = c.DATA_DIR / "log" / "opencode.log"
    if log.exists():
        lines = [ln for ln in log.read_text(encoding="utf-8", errors="ignore").splitlines()
                 if name in ln][-8:]
        if lines:
            print(c.dim("  últimas líneas de log relacionadas:"))
            for line in lines:
                print("   " + line[:220])
    return code


def cmd_enable(name: str, enabled: bool) -> int:
    data = servers()
    if name not in data:
        c.die(f"MCP no configurado: {name}")
    data[name].pop("disabled", None) if enabled else data[name].update({"disabled": True})
    _write_servers(data)
    reg = registry()
    if name in reg["servers"]:
        reg["servers"][name]["status"] = "enabled" if enabled else "disabled"
        c.save_json(c.MCP_REGISTRY, reg)
    c.log_event("mcp-enable" if enabled else "mcp-disable", name)
    print(f"{c.ok('habilitado' if enabled else 'deshabilitado')} {name}")
    return 0


def cmd_remove(name: str, yes: bool = False, logout: bool = False) -> int:
    data = servers()
    if name not in data:
        c.die(f"MCP no configurado: {name}")
    if not yes:
        answer = input(f"¿Eliminar {name} de la configuración? [s/N] ").strip().lower()
        if answer not in {"s", "si", "sí", "y", "yes"}:
            c.die("cancelado")
    removed = data.pop(name)
    _write_servers(data)
    archive = c.BACKUP_DIR / "removed" / f"{c.timestamp()}-mcp-{name}.json"
    archive.parent.mkdir(parents=True, exist_ok=True)
    c.save_json(archive, removed)
    reg = registry()
    if name in reg["servers"]:
        reg["servers"][name]["status"] = "removed"
        reg["servers"][name]["removed_at"] = c.now_iso()
        c.save_json(c.MCP_REGISTRY, reg)
    if logout and c.which("opencode"):
        c.opencode_json(["mcp", "logout", name], timeout=60)
    c.log_event("mcp-remove", name, str(archive))
    print(f"{c.ok('eliminado')} {name} (copia: {archive})")
    return 0


def cmd_auth(name: str) -> int:
    entry = servers().get(name)
    if not entry:
        c.die(f"MCP no configurado: {name}")
    if entry.get("type") != "remote":
        c.die("solo los servidores remotos usan OAuth")
    print("La autenticación OAuth es interactiva y debe iniciarla el cliente:")
    print(f"  1. abre OpenCode\n  2. ejecuta /mcps\n  3. selecciona {name} y completa el navegador")
    print(c.dim("  Alternativa CLI: opencode mcp auth " + name + " (solo en terminal interactiva)"))
    if entry.get("headers"):
        print(c.dim(f"  Este servidor también tiene cabeceras configuradas: "
                    f"{', '.join(entry['headers'])}"))
    return 0


# --------------------------------------------------------------------------
# perfiles
# --------------------------------------------------------------------------

def _profiles() -> dict[str, list[str]]:
    data = c.load_json(c.PROFILES_FILE, {})
    profiles = dict(DEFAULT_PROFILES)
    for name, value in (data.get("profiles") or {}).items():
        if isinstance(value, list):
            profiles[name] = value
    return profiles


def _save_profiles(profiles: dict[str, list[str]]) -> None:
    c.save_json(c.PROFILES_FILE, {"profiles": profiles})


def cmd_profile(action: str, name: str | None = None) -> int:
    data = servers()
    profiles = _profiles()
    settings = c.load_json(c.SETTINGS_FILE, {})
    if action in {"list", "ls"}:
        active = settings.get("mcp_profile", "-")
        rows = [[("● " if p == active else "  ") + p,
                 ", ".join(members) or "(ninguno)"] for p, members in profiles.items()]
        c.table(rows, ["perfil", "servidores"])
        print(c.dim(f"\nactivo: {active} · aplica con: sc-kit mcp profile apply <perfil>"))
        return 0
    if action in {"show", "info"}:
        if not name or name not in profiles:
            c.die(f"perfil desconocido: {name}")
        print(", ".join(profiles[name]) or "(ninguno)")
        return 0
    if action == "save":
        if not name:
            c.die("indica un nombre de perfil")
        profiles[name] = sorted(k for k, v in data.items() if not v.get("disabled"))
        _save_profiles(profiles)
        print(f"{c.ok('guardado')} perfil {name}: {', '.join(profiles[name]) or '(vacío)'}")
        return 0
    if action != "apply":
        c.die("acciones: list, show, apply, save")
    if not name or name not in profiles:
        c.die(f"perfil desconocido: {name}. Disponibles: {', '.join(profiles)}")
    wanted = set(profiles[name])
    changed, missing = [], [w for w in sorted(wanted) if w not in data]
    for server, entry in data.items():
        should_enable = server in wanted if name != "custom" else not entry.get("disabled")
        if should_enable and entry.get("disabled"):
            entry.pop("disabled", None)
            changed.append(("on", server))
        elif not should_enable and not entry.get("disabled"):
            entry["disabled"] = True
            changed.append(("off", server))
    if changed:
        c.backup(f"mcp-profile-{name}", quiet=True)
        _write_servers(data)
    settings["mcp_profile"] = name
    c.save_json(c.SETTINGS_FILE, settings)
    print(f"{c.ok('perfil aplicado')} {name}")
    for state, server in changed:
        print(f"  {state} {server}")
    if missing:
        print(c.warn(f"  no instalados: {', '.join(missing)}"))
        print(c.dim("  instálalos con: sc-kit mcp add <nombre> --url/--package …"))
    c.log_event("mcp-profile", name, f"changed={len(changed)}")
    return 0


# --------------------------------------------------------------------------
# catálogo, búsqueda, exportación
# --------------------------------------------------------------------------

def cmd_search(query: str, remote: bool = False) -> int:
    query = query.lower()
    rows = []
    installed_names = set(servers())
    for item in CATALOG:
        haystack = f"{item['name']} {item['why']} {item.get('url','')}".lower()
        if query in haystack:
            rows.append([item["name"], item["kind"],
                         "instalado" if item["name"] in installed_names else "-",
                         item["why"]])
    c.table(rows, ["nombre", "tipo", "estado", "para qué"])
    if remote:
        print(c.dim("\nconsultando el registro npm…"))
        try:
            url = ("https://registry.npmjs.org/-/v1/search?size=10&text="
                   + urllib.parse.quote(f"{query} mcp"))
            with urllib.request.urlopen(url, timeout=15) as response:
                payload = json.loads(response.read().decode())
            print()
            for obj in payload.get("objects", [])[:10]:
                pkg = obj["package"]
                print(f"  {pkg['name']}@{pkg.get('version','?')}  "
                      f"{c.dim((pkg.get('description') or '')[:90])}")
        except (urllib.error.URLError, json.JSONDecodeError, KeyError) as exc:
            print(c.warn(f"  no se pudo consultar npm: {exc}"))
    print(c.dim("\nEl catálogo son sugerencias verificables, no una garantía. "
                "`sc-kit mcp add` prueba la conexión antes de guardar."))
    return 0


def cmd_resolve(url: str) -> int:
    print(f"analizando {url}")
    github = re.match(r"https?://github\.com/([\w.-]+)/([\w.-]+)", url)
    if github:
        repo = f"{github.group(1)}/{github.group(2).removesuffix('.git')}"
        print(f"  repositorio: {repo}")
        if c.which("gh"):
            proc = c.run(["gh", "api", f"repos/{repo}",
                          "--jq", "{name,description,stars:.stargazers_count,"
                                  "updated:.pushed_at,archived,license:.license.spdx_id,"
                                  "default_branch}"], timeout=40)
            if proc.returncode == 0:
                print("  " + proc.stdout.strip().replace("\n", "\n  "))
            proc = c.run(["gh", "api", f"repos/{repo}/readme", "--jq", ".content"],
                         timeout=40)
            if proc.returncode == 0:
                import base64
                try:
                    readme = base64.b64decode(proc.stdout.strip()).decode(errors="replace")
                except Exception:
                    readme = ""
                hints = re.findall(r"(npx[^\n`]{0,120}|uvx[^\n`]{0,120}|"
                                   r"docker run[^\n`]{0,140}|https://[^\s`\"]+mcp[^\s`\"]*)",
                                   readme)
                if hints:
                    print("  pistas de instalación encontradas:")
                    for hint in dict.fromkeys(hints[:6]):
                        print("   - " + hint.strip())
                if "mcp" not in readme.lower():
                    print(c.warn("  el README no menciona MCP; probablemente no sea un servidor MCP"))
        return 0
    if url.startswith(("http://", "https://")):
        print("  parece un endpoint remoto; prueba con: sc-kit mcp add <nombre> --url " + url)
        return 0
    print("  entrada no reconocida; usa URL de GitHub o endpoint MCP")
    return 1


def cmd_audit(name: str | None) -> int:
    data = servers()
    targets = [name] if name else list(data)
    if not targets:
        print("no hay MCP configurados")
        return 0
    worst = 0
    for server in targets:
        entry = data.get(server)
        if not entry:
            c.die(f"MCP no configurado: {server}")
        print(c.bold(f"\n{server}"))
        problems: list[tuple[str, str]] = []
        if entry.get("type") == "remote":
            if not entry.get("url", "").startswith("https://"):
                problems.append(("high", "transporte remoto sin TLS"))
            if entry.get("oauth") is False and not entry.get("headers"):
                problems.append(("medium", "OAuth desactivado sin credencial alternativa"))
        else:
            for problem in _validate_command(entry.get("command", [])):
                problems.append(("medium" if "versión" in problem else "high", problem))
        for key, value in (entry.get("environment") or {}).items():
            if re.search(r"(KEY|TOKEN|SECRET|PASSWORD)", key) and not str(value).startswith("{env:"):
                problems.append(("critical", f"secreto literal en environment.{key}"))
        for key, value in (entry.get("headers") or {}).items():
            if not str(value).startswith("{env:"):
                problems.append(("high", f"secreto literal en headers.{key}"))
        if entry.get("disabled"):
            problems.append(("low", "servidor deshabilitado (no consume contexto)"))
        if not problems:
            print(c.ok("  sin hallazgos"))
        for level, message in problems:
            print(f"  {level.upper():<9} {message}")
            worst = max(worst, {"critical": 2, "high": 1}.get(level, 0))
    return worst


def cmd_export(target: str | None) -> int:
    data = {
        "format": "sc-kit-mcp/1",
        "exported_at": c.now_iso(),
        "servers": servers(),
        "profiles": _profiles(),
    }
    text = json.dumps(data, indent=2, ensure_ascii=False)
    if target:
        path = Path(target).expanduser()
        c.atomic_write(path, text + "\n", mode=0o600)
        print(f"{c.ok('exportado')} {path}")
    else:
        print(text)
    return 0


def cmd_import(source: str, yes: bool = False) -> int:
    path = Path(source).expanduser()
    if not path.is_file():
        c.die(f"fichero no encontrado: {source}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        c.die(f"JSON inválido: {exc}")
    incoming = payload.get("servers") or payload
    if not isinstance(incoming, dict):
        c.die("formato no reconocido")
    data = servers()
    added = []
    for name, entry in incoming.items():
        if not isinstance(entry, dict) or "type" not in entry:
            print(c.warn(f"omitido {name}: entrada inválida"))
            continue
        if name in data:
            print(c.dim(f"ya existe {name}; se conserva"))
            continue
        data[name] = entry
        added.append(name)
    if not added:
        print("nada que importar")
        return 0
    print("se añadirán: " + ", ".join(added))
    if not yes:
        answer = input("¿Continuar? [s/N] ").strip().lower()
        if answer not in {"s", "si", "sí", "y", "yes"}:
            c.die("cancelado")
    _write_servers(data)
    for name in added:
        _reg_entry(name, {"name": name, "source": "import", "transport": data[name]["type"]})
    if isinstance(payload.get("profiles"), dict):
        profiles = _profiles()
        profiles.update({k: v for k, v in payload["profiles"].items()
                         if isinstance(v, list)})
        _save_profiles(profiles)
    c.log_event("mcp-import", source, ",".join(added))
    print(f"{c.ok('importados')} {len(added)} servidores")
    return 0


def cmd_update(name: str | None, apply: bool = False) -> int:
    data = servers()
    targets = [name] if name else list(data)
    updates = 0
    for server in targets:
        entry = data.get(server, {})
        command = entry.get("command") or []
        pkg = next((a for a in command if re.match(r"^(@[\w.-]+/)?[\w.-]+(@[\d.]+)?$", a)
                    and not a.startswith("-") and a not in {"npx", "uvx", "npm", "pnpm"}),
                   None)
        if not pkg:
            continue
        base = pkg.split("@")[0] if pkg.startswith("@") else pkg.split("@")[0]
        try:
            url = f"https://registry.npmjs.org/{urllib.parse.quote(base, safe='@')}/latest"
            with urllib.request.urlopen(url, timeout=15) as response:
                version = json.loads(response.read().decode()).get("version")
        except Exception:
            print(c.warn(f"{server}: no se pudo consultar npm para {base}"))
            continue
        current = pkg.split("@")[-1] if "@" in pkg[1:] else "sin fijar"
        if current != version:
            print(f"{server}: {base} {current} -> {version}")
            updates += 1
            if apply:
                new_cmd = [a if a != pkg else f"{base}@{version}" for a in command]
                data[server]["command"] = new_cmd
                print(c.dim("  fijada la nueva versión"))
        else:
            print(f"{c.ok('al día')} {server}: {base}@{version}")
    if apply and updates:
        c.backup("mcp-update", quiet=True)
        _write_servers(data)
    elif updates:
        print(c.dim(f"\n{updates} actualizaciones disponibles; aplica con --apply"))
    return 0
