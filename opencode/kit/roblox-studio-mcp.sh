#!/usr/bin/env bash
# Lanza el servidor MCP integrado de Roblox Studio dentro del Wine de Vinegar.
# Resuelve la versión instalada en cada arranque para sobrevivir a actualizaciones.
set -euo pipefail

BASE="$HOME/.var/app/org.vinegarhq.Vinegar/data/vinegar"
WINE="$BASE/kombucha/bin/wine"
PREFIX="$BASE/prefixes/studio"

if [[ ! -x "$WINE" ]]; then
  echo "No se encontró el Wine de Vinegar en $WINE" >&2
  exit 1
fi
if [[ ! -d "$PREFIX" ]]; then
  echo "No se encontró el prefix de Studio en $PREFIX" >&2
  exit 1
fi

EXE="$(ls -t "$BASE"/versions/version-*/StudioMCP.exe 2>/dev/null | head -1 || true)"
if [[ -z "$EXE" ]]; then
  echo "No se encontró StudioMCP.exe; abre Vinegar una vez para completar la instalación." >&2
  exit 1
fi

export WINEPREFIX="$PREFIX"
export WINEDEBUG="${WINEDEBUG:--all}"
# El .bat oficial hace "cd /d %LOCALAPPDATA%\Roblox": auth.token y tools-cache viven ahí.
cd "$BASE/appdata/Roblox"
exec "$WINE" "$EXE" "$@"
