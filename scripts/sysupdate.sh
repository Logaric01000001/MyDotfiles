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

# 2. Comprobar descargas paralelas en /etc/pacman.conf
if grep -q "ParallelDownloads = 1" /etc/pacman.conf; then
    echo -e "${YELLOW}Optimización disponible: Tienes ParallelDownloads = 1 en /etc/pacman.conf.${NC}"
    echo -e "Esto hace que las descargas de paquetes sean lentas (uno a uno)."
    read -rp "¿Deseas acelerar las descargas configurando ParallelDownloads = 5? [S/n]: " set_parallel
    if [[ ! "$set_parallel" =~ ^[nN]$ ]]; then
        sudo sed -i 's/ParallelDownloads = 1/ParallelDownloads = 5/' /etc/pacman.conf
        echo -e "${GREEN}¡Optimizado! Descargas paralelas configuradas en 5.${NC}"
    fi
fi

# 3. Comprobar si hay paquetes ignorados en /etc/pacman.conf
IGNORED_PKGS=$(grep -E "^IgnorePkg" /etc/pacman.conf | cut -d= -f2- | xargs)
if [ -n "$IGNORED_PKGS" ]; then
    echo -e "${BLUE}Paquetes omitidos en pacman.conf:${NC} ${YELLOW}$IGNORED_PKGS${NC}"
fi

# 4. Actualizar las llaves (keyrings) primero para prevenir errores de firma
echo -e "\n${BLUE}Actualizando llaves del sistema (archlinux y blackarch keyrings)...${NC}"
# Comprobar si blackarch está en el pacman.conf para incluir su keyring
if grep -q "\[blackarch\]" /etc/pacman.conf; then
    sudo pacman -Sy --needed --noconfirm archlinux-keyring blackarch-keyring 2>/dev/null || \
    sudo pacman -Sy --needed --noconfirm archlinux-keyring 2>/dev/null || true
else
    sudo pacman -Sy --needed --noconfirm archlinux-keyring 2>/dev/null || true
fi

# 5. Ejecutar la actualización completa con paru (incluye repositorios oficiales y AUR)
echo -e "\n${BLUE}Iniciando actualización completa de paquetes (paru)...${NC}"
if command -v paru >/dev/null 2>&1; then
    paru -Syu
elif command -v yay >/dev/null 2>&1; then
    yay -Syu
else
    sudo pacman -Syu
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
