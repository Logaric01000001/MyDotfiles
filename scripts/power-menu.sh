#!/usr/bin/env bash
# menu de energia con rofi

export PATH="$HOME/.local/bin:$PATH"

command -v rofi >/dev/null || { echo "falta rofi" >&2; exit 1; }

choice=$(printf "Lock\nShutdown\nReboot\nSuspend\nLogout\nCancel\n" | rofi -dmenu -i -p "Power")

case "$choice" in
  Lock)     lock-screen ;;
  Shutdown) save-state.sh && systemctl poweroff ;;
  Reboot)   save-state.sh && systemctl reboot ;;
  Suspend)  save-state.sh && systemctl suspend ;;
  Logout)   save-state.sh && (niri msg action quit || loginctl terminate-session "$XDG_SESSION_ID") ;;
  *) exit 0 ;;
esac
