#!/usr/bin/env bash
# Menú de energía (Super+S): fila de botones con rofi (tema power.rasi).
export PATH="$HOME/.local/bin:$PATH"
command -v rofi >/dev/null || { echo "falta rofi" >&2; exit 1; }

THEME="$HOME/.config/rofi/power.rasi"
ICON='<span font_family="JetBrainsMono Nerd Font" size="18pt">%s</span>'
LABEL='<span size="9.5pt">%s</span>'

row() { printf "${ICON}\n${LABEL}|" "$1" "$2"; }

uptime_txt="Encendido $(uptime -p | sed 's/^up //; s/hours\?/h/; s/minutes\?/min/; s/days\?/d/; s/,//g')"

choice=$( { row "󰌾" "Bloquear"; row "󰤄" "Suspender"; row "󰍃" "Cerrar sesión"; row "󰜉" "Reiniciar"; row "󰐥" "Apagar"; } |
    rofi -dmenu -sep "|" -eh 3 -markup-rows -format i -no-custom -p "󰐥  Energía" \
         -theme "$THEME" -theme-str "textbox-hint { str: \"$uptime_txt\"; }" )

case "$choice" in
  0) lock-screen ;;
  1) save-state.sh; systemctl suspend ;;
  2) save-state.sh; niri msg action quit --skip-confirmation || loginctl terminate-session "$XDG_SESSION_ID" ;;
  3) save-state.sh; systemctl reboot ;;
  4) save-state.sh; systemctl poweroff ;;
  *) exit 0 ;;
esac
