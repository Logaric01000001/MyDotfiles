#!/usr/bin/env bash
# =============================================================================
#   🚀 ALL-IN-ONE INSTALLER — NIRI COMPOSITOR & CATPPUCCIN MOCHA DOTFILES
#   Instalador inteligente con prevención de conflictos y respaldo automático
# =============================================================================

set -e

# Colores para la terminal
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

clear 2>/dev/null || true

echo -e "${CYAN}╔═════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     🌌 INSTALADOR MAESTRO — DOTFILES NIRI & CATPPUCCIN MOCHA    ║${NC}"
echo -e "${CYAN}║     Instalación Segura, Cero Conflictos y Respaldo Automático   ║${NC}"
echo -e "${CYAN}╚═════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. DETERMINAR DIRECTORIO DE DOTFILES
# -----------------------------------------------------------------------------
if [ -n "$BASH_SOURCE" ] && [ -f "$BASH_SOURCE" ]; then
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    DOTFILES_DIR="$HOME/MyDotfiles"
fi

if [ ! -f "$DOTFILES_DIR/config.kdl" ]; then
    echo -e "${BLUE}📥 [Paso Previo] Descargando repositorio en ${DOTFILES_DIR}...${NC}"
    git clone https://github.com/tu-usuario/MyDotfiles.git "$DOTFILES_DIR" || {
        echo -e "${RED}❌ No se pudo descargar el repositorio. Verifica tu conexión a internet.${NC}"
        exit 1
    }
fi

# -----------------------------------------------------------------------------
# 2. VERIFICACIÓN DE SISTEMA Y PREVENCIÓN DE BLOQUEOS
# -----------------------------------------------------------------------------
if [ ! -f /etc/arch-release ]; then
    echo -e "${YELLOW}⚠️  Aviso: Este instalador está optimizado para Arch Linux y derivados (EndeavourOS, CachyOS, Manjaro).${NC}"
    if [ -t 0 ]; then
        read -rp "   ¿Deseas continuar de todas formas? [s/N]: " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            echo -e "${RED}Instalación cancelada por el usuario.${NC}"
            exit 0
        fi
    fi
fi

# Comprobar si pacman está bloqueado por otro proceso
if [ -f /var/lib/pacman/db.lck ]; then
    echo -e "${YELLOW}⚠️  El archivo de bloqueo de pacman (/var/lib/pacman/db.lck) está presente.${NC}"
    echo -e "   Es posible que otra actualización o instalación esté en curso."
    if [ -t 0 ]; then
        read -rp "   ¿Deseas esperar 5 segundos y reintentar? [S/n]: " retry
        if [[ ! "$retry" =~ ^[nN]$ ]]; then
            sleep 5
        fi
    fi
fi

# -----------------------------------------------------------------------------
# 3. GESTIÓN DE PAQUETES (PACMAN Y AUR SIN CONFLICTOS)
# -----------------------------------------------------------------------------
PACMAN_PKGS=(
    base-devel
    git
    niri
    hyprlock
    swaybg
    swayidle
    rofi-wayland
    kitty
    thunar
    firefox
    pipewire
    wireplumber
    brightnessctl
    playerctl
    polkit-gnome
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    ttf-jetbrains-mono-nerd
    ttf-inter
    papirus-icon-theme
    wl-clipboard
    grim
    slurp
    fastfetch
)

echo -e "${MAGENTA}${BOLD}📦 [1/4] Comprobando e instalando paquetes oficiales...${NC}"
if command -v sudo &>/dev/null; then
    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
else
    su -c "pacman -S --needed --noconfirm ${PACMAN_PKGS[*]}"
fi

# Verificación / Instalación de AUR Helper
echo ""
echo -e "${MAGENTA}${BOLD}🔍 [2/4] Verificando gestor de AUR (yay / paru)...${NC}"
AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
else
    echo -e "${YELLOW}⚡ Instalando 'yay' automáticamente para paquetes de AUR...${NC}"
    TMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$TMP_DIR/yay-bin"
    (cd "$TMP_DIR/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$TMP_DIR"
    AUR_HELPER="yay"
fi
echo -e "   ${GREEN}✔ Gestor AUR:${NC} $AUR_HELPER"

# Instalar Noctalia Shell y Zen Browser desde AUR
if ! command -v noctalia &>/dev/null; then
    echo -e "${BLUE}📦 Instalando Noctalia Shell desde AUR...${NC}"
    $AUR_HELPER -S --needed --noconfirm noctalia-bin || $AUR_HELPER -S --needed --noconfirm noctalia || true
fi

if ! command -v zen-browser &>/dev/null; then
    echo -e "${BLUE}📦 Instalando Zen Browser desde AUR...${NC}"
    $AUR_HELPER -S --needed --noconfirm zen-browser-bin || true
fi

# -----------------------------------------------------------------------------
# 4. CREACIÓN DE DIRECTORIOS Y SISTEMA DE RESPALDO SEGURO
# -----------------------------------------------------------------------------
echo ""
echo -e "${MAGENTA}${BOLD}📂 [3/4] Preparando carpetas y gestionando respaldos...${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config/dotfiles_backup_$TIMESTAMP"
HAS_BACKUP=false

mkdir -p "$HOME/.config/niri"
mkdir -p "$HOME/.config/hypr"
mkdir -p "$HOME/.config/swaylock"
mkdir -p "$HOME/.config/rofi"
mkdir -p "$HOME/.config/noctalia"
mkdir -p "$HOME/.config/kitty"
mkdir -p "$HOME/.config/fastfetch"
mkdir -p "$HOME/Imágenes/Capturas"
mkdir -p "$HOME/Imágenes/Fondos"
mkdir -p "$HOME/Descargas"

# -----------------------------------------------------------------------------
# 5. COPIA SEGURA DE ARCHIVOS (RESOLUCIÓN DE CONFLICTOS)
# -----------------------------------------------------------------------------
echo ""
echo -e "${MAGENTA}${BOLD}📋 [4/4] Instalando archivos de configuración (Copia directa)...${NC}"

safe_install_file() {
    local src="$1"
    local dest="$2"
    local rel_dest="${dest#$HOME/.config/}"

    # Si el destino ya existe
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # Si es un enlace simbólico, simplemente lo eliminamos para colocar el archivo real
        if [ -L "$dest" ]; then
            rm -f "$dest"
        else
            # Si es un archivo físico existente con contenido diferente, creamos respaldo
            if ! cmp -s "$src" "$dest"; then
                mkdir -p "$BACKUP_DIR/$(dirname "$rel_dest")"
                cp -a "$dest" "$BACKUP_DIR/$rel_dest"
                HAS_BACKUP=true
                echo -e "   ${YELLOW}📦 Respaldo creado:${NC} $dest → $BACKUP_DIR/$rel_dest"
            fi
            rm -f "$dest"
        fi
    fi

    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
    echo -e "   ${GREEN}✔ Instalado:${NC} $dest"
}

# Instalación de cada configuración
safe_install_file "$DOTFILES_DIR/config.kdl" "$HOME/.config/niri/config.kdl"
safe_install_file "$DOTFILES_DIR/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
safe_install_file "$DOTFILES_DIR/swaylock.conf" "$HOME/.config/swaylock/config"
safe_install_file "$DOTFILES_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
safe_install_file "$DOTFILES_DIR/noctalia/config.toml" "$HOME/.config/noctalia/config.toml"
safe_install_file "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
safe_install_file "$DOTFILES_DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
if [ -f "$DOTFILES_DIR/fastfetch/logo.txt" ]; then
    safe_install_file "$DOTFILES_DIR/fastfetch/logo.txt" "$HOME/.config/fastfetch/logo.txt"
fi

# Instalar utilidades personalizadas (help-menu y set-wallpaper)
mkdir -p "$HOME/.local/bin"
if [ -f "$DOTFILES_DIR/scripts/set-wallpaper.sh" ]; then
    cp -f "$DOTFILES_DIR/scripts/set-wallpaper.sh" "$HOME/.local/bin/set-wallpaper"
    chmod +x "$HOME/.local/bin/set-wallpaper"
    echo -e "   ${GREEN}✔ Utilidad instalada:${NC} ~/.local/bin/set-wallpaper"
fi

if [ -f "$DOTFILES_DIR/scripts/help-menu.sh" ]; then
    cp -f "$DOTFILES_DIR/scripts/help-menu.sh" "$HOME/.local/bin/help-menu"
    chmod +x "$HOME/.local/bin/help-menu"
    echo -e "   ${GREEN}✔ Guía interactiva instalada:${NC} ~/.local/bin/help-menu"
fi

if [ -f "$DOTFILES_DIR/scripts/fix-noctalia-resume.sh" ]; then
    cp -f "$DOTFILES_DIR/scripts/fix-noctalia-resume.sh" "$HOME/.local/bin/fix-noctalia-resume.sh"
    chmod +x "$HOME/.local/bin/fix-noctalia-resume.sh"
    echo -e "   ${GREEN}✔ Script de reanudación instalado:${NC} ~/.local/bin/fix-noctalia-resume.sh"
fi

# Servicio systemd para restaurar Noctalia tras suspender/hibernar
if [ -f "$DOTFILES_DIR/systemd/noctalia-resume.service" ]; then
    echo -e "\n${BLUE}⚡ Configurando servicio de reanudación de Noctalia...${NC}"
    sudo cp -f "$DOTFILES_DIR/systemd/noctalia-resume.service" "/etc/systemd/system/noctalia-resume@.service" 2>/dev/null && \
    sudo systemctl daemon-reload 2>/dev/null && \
    sudo systemctl enable "noctalia-resume@$(whoami).service" 2>/dev/null && \
    echo -e "   ${GREEN}✔ Servicio noctalia-resume habilitado (Noctalia se restaura automáticamente al abrir la tapa).${NC}" || \
    echo -e "   ${YELLOW}⚠️  No se pudo instalar el servicio systemd (requiere permisos de administrador).${NC}"
fi

# Configuración personalizada de pantalla de inicio SDDM
if [ -d "/usr/share/sddm/themes/SilentSDDM" ] && [ -f "$DOTFILES_DIR/sddm/default-left.conf" ]; then
    if [ -w "/usr/share/sddm/themes/SilentSDDM/configs" ]; then
        cp -f "$DOTFILES_DIR/sddm/default-left.conf" "/usr/share/sddm/themes/SilentSDDM/configs/default-left.conf"
        echo -e "   ${GREEN}✔ Pantalla de inicio SDDM configurada (Catppuccin Mocha).${NC}"
    elif command -v sudo &>/dev/null; then
        sudo cp -f "$DOTFILES_DIR/sddm/default-left.conf" "/usr/share/sddm/themes/SilentSDDM/configs/default-left.conf" 2>/dev/null || true
    fi
fi

# Copiar fondos de ejemplo si la carpeta está vacía
if [ -d "/usr/share/sddm/themes/SilentSDDM/backgrounds" ]; then
    cp -n /usr/share/sddm/themes/SilentSDDM/backgrounds/* "$HOME/Imágenes/Fondos/" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 6. RECARGA EN VIVO (SI NIRI O NOCTALIA YA ESTÁN EN EJECUCIÓN)
# -----------------------------------------------------------------------------
if pgrep -x niri &>/dev/null; then
    echo ""
    echo -e "${BLUE}⚡ Niri está en ejecución. Recargando configuración al vuelo...${NC}"
    niri msg action load-config-file 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 7. RESUMEN FINAL
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}╔═════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 ¡INSTALACIÓN COMPLETADA SIN CONFLICTOS!            ║${NC}"
echo -e "${GREEN}╚═════════════════════════════════════════════════════════════════╝${NC}"
echo ""
if [ "$HAS_BACKUP" = true ]; then
    echo -e "${YELLOW}📁 Tus configuraciones anteriores se guardaron de forma segura en:${NC}"
    echo -e "   ${BOLD}$BACKUP_DIR${NC}"
    echo ""
fi

echo -e "${BOLD}Resumen de atajos configurados:${NC}"
echo -e "  • ${CYAN}Mod + Shift + H${NC}    → Guía interactiva de atajos en pantalla (Help)"
echo -e "  • ${CYAN}Mod + Enter${NC}        → Terminal (Kitty)"
echo -e "  • ${CYAN}Mod + D / Espacio${NC}  → Lanzador de aplicaciones (Rofi minimalista)"
echo -e "  • ${CYAN}Mod + B${NC}            → Navegador Web (Zen Browser)"
echo -e "  • ${CYAN}Mod + W${NC}            → Cambiar fondo de TODO (Escritorio + Pantalla de inicio)"
echo -e "  • ${CYAN}Mod + Ctrl + W${NC}     → Cambiar SOLO fondo de ADENTRO (Escritorio)"
echo -e "  • ${CYAN}Mod + Alt + W${NC}      → Cambiar SOLO fondo de AFUERA (Pantalla de inicio SDDM)"
echo -e "  • ${CYAN}Mod + A${NC}            → Panel de Ajustes y Barra (Noctalia)"
echo -e "  • ${CYAN}Mod + L${NC}            → Bloquear pantalla (Hyprlock)"
echo -e "  • ${CYAN}Mod + F${NC}            → Maximizar columna (manteniendo barra)"
echo -e "  • ${CYAN}Mod + Shift + F${NC}    → Pantalla completa total"
echo -e "  • ${CYAN}Mod + Q${NC}            → Cerrar ventana activa"
echo ""
echo -e "${GREEN}✨ ¡Todo listo para disfrutar de tu entorno!${NC}"
echo ""
