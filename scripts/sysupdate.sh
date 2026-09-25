#!/usr/bin/env bash
# =============================================================================
#   Arch Linux Intelligent Update Script
# =============================================================================

set -e

# Colores para la terminal
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Argumentos y ayuda rápida
EXTRA_ARGS=()
TARGET_PARALLEL=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            echo -e "${CYAN}Actualizador Inteligente de Sistema (Arch Linux)${NC}"
            echo -e "${BOLD}Uso:${NC} up [NÚMERO_DE_PAQUETES] [OPCIONES_PACMAN/PARU]"
            echo ""
            echo -e "${BOLD}Ejemplos:${NC}"
            echo -e "  ${GREEN}up${NC}                     -> Pregunta o mantiene la cantidad de paquetes simultáneos."
            echo -e "  ${GREEN}up 3${NC}                   -> Configura 3 paquetes a la vez e inicia la actualización."
            echo -e "  ${GREEN}up 1${NC}                   -> Descarga paquetes de 1 en 1 (ideal para internet lento)."
            echo -e "  ${GREEN}up --ignore seclists${NC}   -> Actualiza omitiendo paquetes que fallen o pesen mucho."
            echo -e "  ${GREEN}up 5 --ignore seclists${NC} -> 5 descargas simultáneas omitiendo seclists."
            exit 0
            ;;
        [1-9]|[1-9][0-9])
            TARGET_PARALLEL="$1"
            shift
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN}   Actualizador Inteligente de Sistema (Arch Linux) ${NC}"
echo -e "${CYAN}====================================================${NC}"

# 1. Comprobar base de datos bloqueada (db.lck)
if [ -f /var/lib/pacman/db.lck ]; then
    echo -e "${YELLOW}Aviso: El archivo de bloqueo de pacman (/var/lib/pacman/db.lck) está presente.${NC}"
    # Intentar ver si el proceso que lo creó sigue vivo
    LCK_PID=$(lsof -t /var/lib/pacman/db.lck 2>/dev/null || true)
    if [ -n "$LCK_PID" ] && ps -p "$LCK_PID" >/dev/null 2>&1; then
        echo -e "${RED}Error: El proceso pacman/paru (PID: $LCK_PID) se está ejecutando actualmente.${NC}"
        echo -e "Por favor, espera a que termine o detén ese proceso antes de continuar."
        exit 1
    else
        echo -e "${YELLOW}El archivo de bloqueo parece ser huérfano (no hay procesos ejecutándolo).${NC}"
        read -rp "¿Deseas eliminar el archivo db.lck para continuar? [s/N]: " rm_lock
        if [[ "$rm_lock" =~ ^[sS]$ ]]; then
            sudo rm -f /var/lib/pacman/db.lck
            echo -e "${GREEN}Archivo de bloqueo eliminado.${NC}"
        else
            echo -e "${RED}Actualización cancelada.${NC}"
            exit 1
        fi
    fi
fi

# 2. Elegir / Configurar paquetes simultáneos (ParallelDownloads en /etc/pacman.conf)
CURRENT_PARALLEL=$(grep -E "^[#[:space:]]*ParallelDownloads" /etc/pacman.conf 2>/dev/null | grep -o -E "[0-9]+" | head -n1 || echo "5")

if [ -n "$TARGET_PARALLEL" ]; then
    echo -e "${BLUE}Paquetes simultáneos solicitados por argumento:${NC} ${GREEN}${TARGET_PARALLEL}${NC}"
elif [ -t 0 ]; then
    echo -e "${BLUE}Paquetes simultáneos actuales (ParallelDownloads):${NC} ${GREEN}${CURRENT_PARALLEL}${NC}"
    read -rp "¿Cuántos paquetes deseas descargar a la vez? [1-20 / Enter para mantener ${CURRENT_PARALLEL}]: " input_parallel
    if [[ "$input_parallel" =~ ^[1-9][0-9]*$ ]]; then
        TARGET_PARALLEL="$input_parallel"
    elif [ -n "$input_parallel" ]; then
        echo -e "${YELLOW}Valor no válido. Se mantendrán ${CURRENT_PARALLEL} paquetes simultáneos.${NC}"
    fi
fi

if [ -n "$TARGET_PARALLEL" ] && [ "$TARGET_PARALLEL" -ne "$CURRENT_PARALLEL" ]; then
    if grep -q -E "^[#[:space:]]*ParallelDownloads" /etc/pacman.conf; then
        sudo sed -i -E "s/^[#[:space:]]*ParallelDownloads[[:space:]]*=.*/ParallelDownloads = $TARGET_PARALLEL/" /etc/pacman.conf
    else
        sudo sed -i "/\[options\]/a ParallelDownloads = $TARGET_PARALLEL" /etc/pacman.conf
    fi
    echo -e "${GREEN}✔ Configurado: Descargas paralelas establecidas en ${TARGET_PARALLEL}.${NC}"
else
    echo -e "${CYAN}✔ Descargas paralelas activas: ${CURRENT_PARALLEL}${NC}"
fi

# 3. Comprobar si hay paquetes ignorados en /etc/pacman.conf
IGNORED_PKGS=$(grep -E "^IgnorePkg" /etc/pacman.conf | cut -d= -f2- | xargs)
if [ -n "$IGNORED_PKGS" ]; then
    echo -e "${BLUE}Paquetes omitidos en pacman.conf:${NC} ${YELLOW}$IGNORED_PKGS${NC}"
fi

# 4. Actualizar las llaves (keyrings) y optimizar mirrors de BlackArch
echo -e "\n${BLUE}Actualizando llaves del sistema (archlinux y blackarch keyrings)...${NC}"
# Comprobar si blackarch está en el pacman.conf para incluir su keyring y servidores de respaldo
if grep -q "\[blackarch\]" /etc/pacman.conf; then
    if [ -f /etc/pacman.d/blackarch-mirrorlist ]; then
        # Desactivar mirror de CEDIA (inestable para archivos grandes como seclists)
        if grep -q "^Server = .*cedia.org.ec" /etc/pacman.d/blackarch-mirrorlist; then
            echo -e "${YELLOW}Desactivando mirror inestable de CEDIA en BlackArch...${NC}"
            sudo sed -i 's/^Server = .*cedia.org.ec/#&/' /etc/pacman.d/blackarch-mirrorlist 2>/dev/null || true
        fi
        # Habilitar servidores oficiales HTTPS de alta velocidad
        sudo sed -i '/#Server = https:\/\/www.blackarch.org/s/^#//' /etc/pacman.d/blackarch-mirrorlist 2>/dev/null || true
        sudo sed -i '/#Server = https:\/\/mirrors.ocf.berkeley.edu/s/^#//' /etc/pacman.d/blackarch-mirrorlist 2>/dev/null || true
        sudo sed -i '/#Server = https:\/\/ftp2.osuosl.org/s/^#//' /etc/pacman.d/blackarch-mirrorlist 2>/dev/null || true
    fi
    sudo pacman -Sy --needed --noconfirm archlinux-keyring blackarch-keyring 2>/dev/null || \
    sudo pacman -Sy --needed --noconfirm archlinux-keyring 2>/dev/null || true
else
    sudo pacman -Sy --needed --noconfirm archlinux-keyring 2>/dev/null || true
fi

# 5. Ejecutar la actualización completa con paru (incluye repositorios oficiales y AUR)
echo -e "\n${BLUE}Iniciando actualización completa de paquetes (paru)...${NC}"
if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
    echo -e "${CYAN}Opciones adicionales pasadas a paru/pacman:${NC} ${YELLOW}${EXTRA_ARGS[*]}${NC}"
fi

if command -v paru >/dev/null 2>&1; then
    paru -Syu "${EXTRA_ARGS[@]}"
elif command -v yay >/dev/null 2>&1; then
    yay -Syu "${EXTRA_ARGS[@]}"
else
    sudo pacman -Syu "${EXTRA_ARGS[@]}"
fi

# 6. Limpiar huérfanos si el usuario quiere
ORPHANS=$(pacman -Qtdq || true)
if [ -n "$ORPHANS" ]; then
    echo -e "\n${YELLOW}Se encontraron paquetes huérfanos (instalados como dependencias pero ya no requeridos):${NC}"
    echo -e "$ORPHANS"
    read -rp "¿Deseas eliminar estos paquetes huérfanos? [s/N]: " rm_orphans
    if [[ "$rm_orphans" =~ ^[sS]$ ]]; then
        sudo pacman -Rns $ORPHANS
        echo -e "${GREEN}Paquetes huérfanos eliminados.${NC}"
    fi
fi

# 7. Comprobar si se necesita reiniciar (si el kernel, systemd o niri se actualizaron)
RUNNING_KERNEL=$(uname -r | cut -d- -f1)
INSTALLED_KERNEL=$(pacman -Q linux 2>/dev/null | awk '{print $2}' | cut -d. -f1-3 || true)
if [ -z "$INSTALLED_KERNEL" ]; then
    # Probar con linux-lts o linux-zen
    INSTALLED_KERNEL=$(pacman -Q linux-zen 2>/dev/null | awk '{print $2}' | cut -d. -f1-3 || \
                       pacman -Q linux-lts 2>/dev/null | awk '{print $2}' | cut -d. -f1-3 || true)
fi

REBOOT_REQUIRED=false

if [ -n "$INSTALLED_KERNEL" ] && [[ "$RUNNING_KERNEL" != *"$INSTALLED_KERNEL"* ]]; then
    echo -e "\n${RED}${BOLD}⚠ ATENCIÓN: El Kernel se ha actualizado (Ejecutando: $RUNNING_KERNEL, Instalado: $INSTALLED_KERNEL).${NC}"
    REBOOT_REQUIRED=true
fi

# Comprobar actualizaciones de systemd o niri
if tail -n 50 /var/log/pacman.log | grep -q -E "upgraded (systemd|niri|dbus)" 2>/dev/null; then
    echo -e "${RED}${BOLD}⚠ ATENCIÓN: Componentes críticos del sistema (systemd, niri o dbus) han sido actualizados.${NC}"
    REBOOT_REQUIRED=true
fi

if [ "$REBOOT_REQUIRED" = true ]; then
    echo -e "${YELLOW}Se recomienda reiniciar la computadora para aplicar todos los cambios de forma segura.${NC}"
fi

echo -e "\n${GREEN}¡Proceso de actualización finalizado con éxito!${NC}"
