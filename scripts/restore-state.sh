#!/usr/bin/env bash
# =============================================================================
#  restore-state.sh — Restaura el estado de Bluetooth y Notificaciones (DND)
# =============================================================================

STATE_FILE="$HOME/.local/state/system-state.conf"

if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

# Cargar estados guardados de forma segura
BLUETOOTH=""
SWAYNC_DND=""
NOCTALIA_DND=""

source "$STATE_FILE"

# 1. Restaurar Bluetooth
if [ "$BLUETOOTH" = "on" ]; then
    bluetoothctl power on 2>/dev/null || true
elif [ "$BLUETOOTH" = "off" ]; then
    bluetoothctl power off 2>/dev/null || true
fi

# 2. Restaurar DND (SwayNC si está activo)
if [ -n "$SWAYNC_DND" ] && pgrep -x swaync &>/dev/null; then
    if [ "$SWAYNC_DND" = "true" ]; then
        swaync-client -dn 2>/dev/null || true
    else
        swaync-client -df 2>/dev/null || true
    fi
fi

# 3. Restaurar DND (Noctalia)
if [ -n "$NOCTALIA_DND" ] && pgrep -x noctalia &>/dev/null; then
    if [ "$NOCTALIA_DND" = "on" ]; then
        noctalia msg notification-dnd-set on 2>/dev/null || true
    else
        noctalia msg notification-dnd-set off 2>/dev/null || true
    fi
fi
