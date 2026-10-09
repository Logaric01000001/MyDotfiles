#!/usr/bin/env bash
# guarda bluetooth y dnd antes de apagar/reiniciar

STATE_FILE="$HOME/.local/state/system-state.conf"
mkdir -p "$(dirname "$STATE_FILE")"

if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "BLUETOOTH=on" > "$STATE_FILE"
else
    echo "BLUETOOTH=off" > "$STATE_FILE"
fi

if pgrep -x swaync &>/dev/null; then
    if [ "$(swaync-client -D 2>/dev/null)" = "true" ]; then
        echo "SWAYNC_DND=true" >> "$STATE_FILE"
    else
        echo "SWAYNC_DND=false" >> "$STATE_FILE"
    fi
fi

if pgrep -x noctalia &>/dev/null; then
    if [ "$(noctalia msg notification-dnd-status 2>/dev/null)" = "on" ]; then
        echo "NOCTALIA_DND=on" >> "$STATE_FILE"
    else
        echo "NOCTALIA_DND=off" >> "$STATE_FILE"
    fi
fi
