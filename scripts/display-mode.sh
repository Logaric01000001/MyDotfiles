#!/usr/bin/env bash
# =============================================================================
#  display-mode.sh — Selector interactivo de modo de pantalla (Rofi)
#  Permite cambiar entre Extendido, Duplicado, Solo Laptop o Solo HDMI fácilmente
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

# Opciones del menú de pantallas
options="1. 🖥️ Extend (Extender escritorio a la derecha)\n2. 🪞 Mirror (Duplicar pantalla - Mismo contenido)\n3. 💻 Laptop Only (Solo pantalla de la laptop)\n4. 📺 External Only (Solo monitor HDMI/TV)"

choice=$(echo -e "$options" | rofi -dmenu -i -p "Modo de Pantalla")

case "$choice" in
  *"Extend"*)
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output eDP-1 on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 1366 0 2>/dev/null || true
    if [ -f "$HOME/.config/current_wallpaper" ]; then
        noctalia msg wallpaper-set "$HOME/.config/current_wallpaper" 2>/dev/null || true
    fi
    notify-send -a "Pantallas" -i "display" "Modo Extendido Activado" "Escritorio extendido a la derecha (HDMI)" 2>/dev/null || true
    ;;
  *"Mirror"*)
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output eDP-1 on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 0 0 2>/dev/null || true
    if [ -f "$HOME/.config/current_wallpaper" ]; then
        noctalia msg wallpaper-set "$HOME/.config/current_wallpaper" 2>/dev/null || true
    fi
    notify-send -a "Pantallas" -i "display" "Modo Duplicado Activado" "Mismo contenido en laptop y HDMI" 2>/dev/null || true
    ;;
  *"Laptop Only"*)
    niri msg output "$EXT_OUTPUT" off 2>/dev/null || true
    niri msg output eDP-1 on 2>/dev/null || true
    notify-send -a "Pantallas" -i "display" "Solo Laptop" "Pantalla externa desactivada" 2>/dev/null || true
    ;;
  *"External Only"*)
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 0 0 2>/dev/null || true
    niri msg output eDP-1 off 2>/dev/null || true
    notify-send -a "Pantallas" -i "display" "Solo Monitor Externo" "Pantalla de laptop desactivada" 2>/dev/null || true
    ;;
  *) exit 0 ;;
esac
