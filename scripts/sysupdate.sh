#!/usr/bin/env bash
# Wrapper de compatibilidad para sysupdate.sh -> actualizacion
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
if [ -x "${DIR}/actualizacion" ]; then
    exec "${DIR}/actualizacion" "$@"
elif command -v actualizacion >/dev/null 2>&1; then
    exec actualizacion "$@"
else
    echo "Error: no se encontró el comando actualizacion en ${DIR} ni en PATH." >&2
    exit 1
fi
