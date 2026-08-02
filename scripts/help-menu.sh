#!/usr/bin/env python3
import os
import re
import subprocess
import sys

CONFIG_PATHS = [
    os.path.expanduser("~/.config/niri/config.kdl"),
    os.path.expanduser("~/MyDotfiles/config.kdl")
]

# Descripciones limpias para acciones internas de Niri sin comentario
BUILTIN_DESCRIPTIONS = {
    "quit": "Cerrar sesión / Salir de Niri",
    "close-window": "Cerrar ventana activa",
    "maximize-column": "Maximizar columna (manteniendo barra)",
    "fullscreen-window": "Pantalla completa total",
    "center-column": "Centrar columna",
    "toggle-window-floating": "Alternar modo flotante",
    "switch-focus-between-floating-and-tiling": "Alternar foco entre flotante y mosaico",
    "switch-preset-column-width": "Alternar anchos predefinidos (33% / 50% / 66% / 100%)",
    "reset-window-height": "Restablecer altura de ventana",
    "focus-column-left": "Mover foco a la izquierda",
    "focus-column-right": "Mover foco a la derecha",
    "focus-window-down": "Mover foco abajo",
    "focus-window-up": "Mover foco arriba",
    "move-column-left": "Mover columna a la izquierda",
    "move-column-right": "Mover columna a la derecha",
    "move-window-down": "Mover ventana abajo",
    "move-window-up": "Mover ventana arriba",
    "focus-workspace-down": "Ir al espacio de trabajo inferior",
    "focus-workspace-up": "Ir al espacio de trabajo superior",
    "move-column-to-workspace-down": "Mover columna al espacio inferior",
    "move-column-to-workspace-up": "Mover columna al espacio superior",
    "screenshot": "Captura de pantalla",
    "screenshot-screen": "Captura de monitor completo",
    "screenshot-window": "Captura de ventana activa",
}

def format_key(key_str):
    parts = [p.strip() for p in key_str.split("+") if p.strip()]
    return " + ".join(parts)

def parse_niri_config():
    config_file = None
    for path in CONFIG_PATHS:
        if os.path.isfile(path):
            config_file = path
            break

    if not config_file:
        return []

    entries = []
    with open(config_file, "r", encoding="utf-8") as f:
        content = f.read()

    binds_match = re.search(r"binds\s*\{(.*)\}", content, re.DOTALL)
    if not binds_match:
        return []

    binds_block = binds_match.group(1)

    for raw_line in binds_block.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("//"):
            continue

        comment = ""
        if "//" in line:
            parts = line.split("//", 1)
            line = parts[0].strip()
            comment = parts[1].strip()

        m = re.match(r"^([\w\+\-_]+)(?:\s+[^\{]+)?\s*\{\s*(.+?);?\s*\}$", line)
        if not m:
            continue

        key_raw = m.group(1).strip()
        action_raw = m.group(2).strip().rstrip(";")

        # Omitir el propio lanzador de ayuda y simplificar números 2-9
        if key_raw in ["Mod+Shift+H", "Mod+Shift+Slash"]:
            continue

        if re.match(r"Mod(\+Shift)?\+[2-90]", key_raw):
            continue

        key_display = format_key(key_raw)
        if key_raw == "Mod+1":
            key_display = "Mod + 1 .. 9"
            comment = "Ir a espacio de trabajo 1 al 9"
        elif key_raw == "Mod+Shift+1":
            key_display = "Mod + Shift + 1 .. 9"
            comment = "Mover columna a espacio 1 al 9"

        exec_payload = None
        desc = comment

        spawn_match = re.match(r'^spawn\s+(.+)$', action_raw)
        if spawn_match:
            args_str = spawn_match.group(1)
            cmd_args = re.findall(r'"([^"]*)"', args_str)
            if cmd_args:
                exec_payload = ("exec", cmd_args)
                if not desc:
                    desc = " ".join(cmd_args)
            else:
                raw_cmd = args_str.replace('"', '').strip()
                exec_payload = ("shell", raw_cmd)
                if not desc:
                    desc = raw_cmd
        else:
            action_name = action_raw.split()[0]
            exec_payload = ("niri", action_raw)
            if not desc:
                desc = BUILTIN_DESCRIPTIONS.get(action_name, action_raw)

        desc = desc.strip()

        entries.append({
            "key": key_display,
            "desc": desc,
            "payload": exec_payload,
            "raw_key": key_raw
        })

    return entries

def main():
    entries = parse_niri_config()
    if not entries:
        sys.exit(0)

    # Alinear en dos columnas limpias
    max_key_len = max(len(e["key"]) for e in entries) + 4

    lines = []
    for e in entries:
        line = f"{e['key'].ljust(max_key_len)}{e['desc']}"
        lines.append(line)

    input_text = "\n".join(lines)

    rofi_cmd = [
        "rofi",
        "-dmenu",
        "-i",
        "-p", "Atajos",
        "-format", "i"
    ]

    proc = subprocess.Popen(rofi_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    stdout, _ = proc.communicate(input=input_text)

    if proc.returncode != 0 or not stdout.strip():
        sys.exit(0)

    try:
        selected_idx = int(stdout.strip())
        selected_entry = entries[selected_idx]
        payload = selected_entry["payload"]

        if not payload:
            sys.exit(0)

        kind, data = payload
        if kind == "exec":
            subprocess.Popen(data)
        elif kind == "shell":
            subprocess.Popen(data, shell=True)
        elif kind == "niri":
            niri_action = data.split()
            subprocess.Popen(["niri", "msg", "action"] + niri_action)
    except (ValueError, IndexError):
        pass

if __name__ == "__main__":
    main()
