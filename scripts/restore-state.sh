#!/usr/bin/env bash
# restaura bluetooth y dnd al iniciar sesion

STATE_FILE="$HOME/.local/state/system-state.conf"
[ -f "$STATE_FILE" ] || exit 0

BLUETOOTH=""
SWAYNC_DND=""
NOCTALIA_DND=""
source "$STATE_FILE"

# Restaurar bluetooth respetando el estado guardado
if [ "$BLUETOOTH" = "on" ]; then
    rfkill unblock bluetooth 2>/dev/null || true
    bluetoothctl power on 2>/dev/null || true
elif [ "$BLUETOOTH" = "off" ]; then
    bluetoothctl power off 2>/dev/null || true
fi

if [ -n "$SWAYNC_DND" ] && pgrep -x swaync &>/dev/null; then
    if [ "$SWAYNC_DND" = "true" ]; then
        swaync-client -dn 2>/dev/null || true
    else
        swaync-client -df 2>/dev/null || true
    fi
fi

if [ -n "$NOCTALIA_DND" ] && pgrep -x noctalia &>/dev/null; then
    noctalia msg notification-dnd-set "$NOCTALIA_DND" 2>/dev/null || true
fi
