#!/usr/bin/env bash
# =============================================================================
#   🔄 FIX-NOCTALIA-RESUME — Auto-restaurar la barra Noctalia tras suspender/tapa
# =============================================================================

export PATH="$HOME/.local/bin:$PATH"

# Asegurar variables de Wayland si se ejecuta desde un contexto sin ellas (ej. systemd)
if [ -z "$WAYLAND_DISPLAY" ]; then
    WAYLAND_DISPLAY=$(find "/run/user/$(id -u)/" -name "wayland-*" 2>/dev/null | head -n 1 | xargs -r basename)
    [ -n "$WAYLAND_DISPLAY" ] && export WAYLAND_DISPLAY
fi

if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

# Pequeña pausa para que los monitores y Wayland se sincronicen tras despertar
sleep 0.8

# Si Niri está en ejecución, reiniciar Noctalia de forma limpia
if pgrep -x niri &>/dev/null; then
    # Intentar cerrar ordenadamente para permitir que libere recursos
    pkill -15 -x noctalia 2>/dev/null || true
    for i in {1..15}; do
        pgrep -x noctalia &>/dev/null || break
        sleep 0.1
    done
    # Si sigue vivo, forzar con SIGKILL
    pgrep -x noctalia &>/dev/null && pkill -9 -x noctalia 2>/dev/null || true

    sleep 0.5
    nohup noctalia >/dev/null 2>&1 &
    disown

    # Dar un momento a Noctalia para inicializarse, luego restaurar estados
    sleep 1.5
    "$HOME/.local/bin/restore-state.sh" || true
fi
