#!/usr/bin/env bash
# =============================================================================
#  power-menu.sh — Menú rápido de apagado/reinicio/suspend/logout usando rofi
# =============================================================================

export PATH="$HOME/.local/bin:$PATH"

# Verificar que rofi está disponible
if ! command -v rofi >/dev/null 2>&1; then
  echo "Error: rofi no está instalado." >&2
  exit 1
fi

# Mostrar las opciones correctamente en renglones separados
choice=$(echo -e "Lock\nShutdown\nReboot\nSuspend\nLogout\nCancel" | rofi -dmenu -i -p "Power Menu")

case "$choice" in
  Lock)     lock-and-restore.sh ;;               # Bloquear pantalla y restaurar Noctalia
  Shutdown) systemctl poweroff ;;                 # Apagar el equipo
  Reboot)   systemctl reboot   ;;                 # Reiniciar el equipo
  Suspend)  systemctl suspend  ;;                 # Suspender
  Logout)   niri msg action quit || loginctl terminate-session "$XDG_SESSION_ID" ;; # Cerrar sesión
  *) exit 0 ;;                                    # Cancelar o salir
esac

