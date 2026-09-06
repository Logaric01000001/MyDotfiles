#!/usr/bin/env bash
# =============================================================================
#  save-state.sh — Guarda el estado actual de Bluetooth y Notificaciones (DND)
# =============================================================================

STATE_FILE="$HOME/.local/state/system-state.conf"
mkdir -p "$(dirname "$STATE_FILE")"

# 1. Guardar estado de Bluetooth
if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "BLUETOOTH=on" > "$STATE_FILE"
else
    echo "BLUETOOTH=off" > "$STATE_FILE"
fi

# 2. Guardar estado de DND (SwayNC si está activo)
if pgrep -x swaync &>/dev/null; then
    SWAYNC_DND=$(swaync-client -D 2>/dev/null)
    if [ "$SWAYNC_DND" = "true" ]; then
        echo "SWAYNC_DND=true" >> "$STATE_FILE"
    else
        echo "SWAYNC_DND=false" >> "$STATE_FILE"
    fi
fi

# 3. Guardar estado de DND (Noctalia)
if pgrep -x noctalia &>/dev/null; then
    NOCTALIA_DND=$(noctalia msg notification-dnd-status 2>/dev/null)
    if [ "$NOCTALIA_DND" = "on" ]; then
        echo "NOCTALIA_DND=on" >> "$STATE_FILE"
    else
        echo "NOCTALIA_DND=off" >> "$STATE_FILE"
    fi
fi
