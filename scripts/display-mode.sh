#!/usr/bin/env bash
# extender / espejo / solo laptop / solo externo

export PATH="$HOME/.local/bin:$PATH"

command -v rofi >/dev/null || { echo "falta rofi" >&2; exit 1; }

EXT_OUTPUT=$(niri msg outputs 2>/dev/null | grep -E '^Output ' | grep -v 'eDP' | head -n 1 | awk -F '"' '{print $4}')
[ -z "$EXT_OUTPUT" ] && EXT_OUTPUT="HDMI-A-1"

PRIMARY_OUTPUT=$(niri msg outputs 2>/dev/null | grep -E '^Output ' | grep 'eDP' | head -n 1 | awk -F '"' '{print $4}')
[ -z "$PRIMARY_OUTPUT" ] && PRIMARY_OUTPUT="eDP-1"

choice=$(printf "Extend\nMirror\nLaptop Only\nExternal Only\n" | rofi -dmenu -i -p "Pantalla")

notify() { notify-send -a "Pantallas" -i display "$@" 2>/dev/null || true; }

case "$choice" in
  "Extend")
    pkill -x wl-mirror 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output "$PRIMARY_OUTPUT" on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 1366 0 2>/dev/null || true
    if [ -f "$HOME/.config/current_wallpaper" ]; then
        noctalia msg wallpaper-set "$HOME/.config/current_wallpaper" 2>/dev/null || true
    fi
    notify "Extendido" "$EXT_OUTPUT a la derecha"
    ;;
  "Mirror")
    pkill -x wl-mirror 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output "$PRIMARY_OUTPUT" on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 1366 0 2>/dev/null || true
    if command -v wl-mirror &>/dev/null; then
        wl-mirror --fullscreen-output "$EXT_OUTPUT" "$PRIMARY_OUTPUT" &>/dev/null &
        disown
        notify "Espejo" "$PRIMARY_OUTPUT -> $EXT_OUTPUT"
    else
        notify -u critical "Falta wl-mirror" "sudo pacman -S wl-mirror"
    fi
    ;;
  "Laptop Only")
    pkill -x wl-mirror 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" off 2>/dev/null || true
    niri msg output "$PRIMARY_OUTPUT" on 2>/dev/null || true
    notify "Solo laptop"
    ;;
  "External Only")
    pkill -x wl-mirror 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" on 2>/dev/null || true
    niri msg output "$EXT_OUTPUT" position set 0 0 2>/dev/null || true
    niri msg output "$PRIMARY_OUTPUT" off 2>/dev/null || true
    notify "Solo externo"
    ;;
  *) exit 0 ;;
esac
