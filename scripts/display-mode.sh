#!/usr/bin/env bash
# =============================================================================
#  display-mode.sh — Selector interactivo de modo de pantalla (Rofi)
#  Permite cambiar entre Extendido, Duplicado (wl-mirror), Solo Laptop o Solo HDMI
# =============================================================================

export PATH="$HOME/.local/bin:$PATH"

if ! command -v rofi >/dev/null 2>&1; then
    echo "Error: rofi no está instalado." >&2
    exit 1
fi

# Detectar el nombre del monitor externo (HDMI-A-1, HDMI-A-2, DP-1, etc.)
EXT_OUTPUT=$(niri msg outputs 2>/dev/null | grep -E '^Output ' | grep -v 'eDP' | head -n 1 | awk -F '"' '{print $4}')
if [ -z "$EXT_OUTPUT" ]; then
    EXT_OUTPUT="HDMI-A-1"
fi

PRIMARY_OUTPUT=$(niri msg outputs 2>/dev/null | grep -E '^Output ' | grep 'eDP' | head -n 1 | awk -F '"' '{print $4}')
if [ -z "$PRIMARY_OUTPUT" ]; then
    PRIMARY_OUTPUT="eDP-1"
fi

# Opciones del menú de pantallas
options="1. 🖥️ Extend (Extender escritorio a la derecha)\n2. 🪞 Mirror (Duplicar pantalla - Mismo contenido)\n3. 💻 Laptop Only (Solo pantalla de la laptop)\n4. 📺 External Only (Solo monitor HDMI/TV)"

choice=$(echo -e "$options" | rofi -dmenu -i -p "Modo de Pantalla")

case "$choice" in
  *"Extend"*)
    pkill -x wl-mirror 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output "$PRIMARY_OUTPUT" on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 1366 0 2>/dev/null || true
    if [ -f "$HOME/.config/current_wallpaper" ]; then
        noctalia msg wallpaper-set "$HOME/.config/current_wallpaper" 2>/dev/null || true
    fi
    notify-send -a "Pantallas" -i "display" "Modo Extendido Activado" "Escritorio extendido a la derecha (HDMI)" 2>/dev/null || true
    ;;
  *"Mirror"*)
    pkill -x wl-mirror 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output "$PRIMARY_OUTPUT" on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 1366 0 2>/dev/null || true
    
    if command -v wl-mirror &>/dev/null; then
        wl-mirror --fullscreen-output "$EXT_OUTPUT" "$PRIMARY_OUTPUT" &>/dev/null &
        disown
        notify-send -a "Pantallas" -i "display" "Modo Espejo (Duplicado) Activado" "Transmitiendo $PRIMARY_OUTPUT -> $EXT_OUTPUT en tiempo real" 2>/dev/null || true
    else
        notify-send -a "Pantallas" -u critical -i "display" "Requiere wl-mirror" "Instala wl-mirror ejecutando: sudo pacman -S wl-mirror" 2>/dev/null || true
    fi
    ;;
  *"Laptop Only"*)
    pkill -x wl-mirror 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" off 2>/dev/null || true
    niri msg output "$PRIMARY_OUTPUT" on 2>/dev/null || true
    notify-send -a "Pantallas" -i "display" "Solo Laptop" "Pantalla externa desactivada" 2>/dev/null || true
    ;;
  *"External Only"*)
    pkill -x wl-mirror 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 0 0 2>/dev/null || true
    niri msg output "$PRIMARY_OUTPUT" off 2>/dev/null || true
    notify-send -a "Pantallas" -i "display" "Solo Monitor Externo" "Pantalla de laptop desactivada" 2>/dev/null || true
    ;;
  *) exit 0 ;;
esac
