#!/usr/bin/env bash
# =============================================================================
#  lock-and-restore.sh — Bloquea con hyprlock y restaura Noctalia al desbloquear
# =============================================================================

# Ensure the cache directory exists
CACHE_DIR="$HOME/.cache"
mkdir -p "$CACHE_DIR"
LOGFILE="$CACHE_DIR/lock-and-restore.log"

# Marca de inicio
echo "$(date +'%Y-%m-%d %H:%M:%S') – Bloqueando con hyprlock" >> "$LOGFILE"

# Ejecutar hyprlock (bloquea hasta que el usuario desbloquee)
hyprlock

# Marca de desbloqueo
echo "$(date +'%Y-%m-%d %H:%M:%S') – Desbloqueado, ejecutando fix-noctalia-resume.sh" >> "$LOGFILE"

# Ejecutar el script de restauración (ruta absoluta)
"$HOME/.local/bin/fix-noctalia-resume.sh" >> "$LOGFILE" 2>&1

exit 0
