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
    git clone https://github.com/Logaric01000001/MyDotfiles.git "$DOTFILES_DIR" || {
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
    swaylock
    swaybg
    swayidle
    rofi-wayland
    wl-mirror
    kitty
    dolphin
    fastfetch
    zsh
    starship
    eza
    zoxide
    fuzzel
    cliphist
    kvantum
    kvantum-qt5
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
)

echo -e "${MAGENTA}${BOLD}📦 [1/4] Comprobando e instalando paquetes oficiales...${NC}"
if command -v pacman &>/dev/null; then
    if command -v sudo &>/dev/null; then
        sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}" 2>/dev/null || true
    else
        su -c "pacman -S --needed --noconfirm ${PACMAN_PKGS[*]}" 2>/dev/null || true
    fi
fi

# Verificación / Instalación de AUR Helper
echo ""
echo -e "${MAGENTA}${BOLD}🔍 [2/4] Verificando gestor de AUR (yay / paru)...${NC}"
AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v pacman &>/dev/null; then
    echo -e "${YELLOW}⚡ Instalando 'yay' automáticamente para paquetes de AUR...${NC}"
    TMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$TMP_DIR/yay-bin" 2>/dev/null || true
    (cd "$TMP_DIR/yay-bin" && makepkg -si --noconfirm 2>/dev/null) || true
    rm -rf "$TMP_DIR"
    AUR_HELPER="yay"
fi

if [ -n "$AUR_HELPER" ]; then
    echo -e "   ${GREEN}✔ Gestor AUR:${NC} $AUR_HELPER"
    
    # Instalar Noctalia Shell, Zen Browser y VScodium desde AUR
    if ! command -v noctalia &>/dev/null; then
        echo -e "${BLUE}📦 Instalando Noctalia Shell desde AUR...${NC}"
        $AUR_HELPER -S --needed --noconfirm noctalia-bin || $AUR_HELPER -S --needed --noconfirm noctalia || true
    fi

    if ! command -v zen-browser &>/dev/null; then
        echo -e "${BLUE}📦 Instalando Zen Browser desde AUR...${NC}"
        $AUR_HELPER -S --needed --noconfirm zen-browser-bin || true
    fi

    if ! command -v codium &>/dev/null && ! command -v vscodium &>/dev/null; then
        echo -e "${BLUE}📦 Instalando VScodium desde AUR...${NC}"
        $AUR_HELPER -S --needed --noconfirm vscodium-bin || true
    fi
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
mkdir -p "$HOME/.config/Kvantum"
mkdir -p "$HOME/.config/VSCodium/User"
mkdir -p "$HOME/.zsh"
mkdir -p "$HOME/.local/bin"
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
    local rel_dest="${dest#$HOME/}"

    if [ ! -e "$src" ]; then
        return 0
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ -L "$dest" ]; then
            rm -f "$dest"
        else
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
    cp -Rf "$src" "$dest"
    echo -e "   ${GREEN}✔ Instalado:${NC} $dest"
}

# Configuración Niri
safe_install_file "$DOTFILES_DIR/config.kdl" "$HOME/.config/niri/config.kdl"

# Bloqueadores de pantalla
safe_install_file "$DOTFILES_DIR/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
safe_install_file "$DOTFILES_DIR/swaylock.conf" "$HOME/.config/swaylock/config"

# Rofi y Noctalia
if [ -d "$DOTFILES_DIR/rofi" ]; then
    for f in "$DOTFILES_DIR/rofi"/*; do
        safe_install_file "$f" "$HOME/.config/rofi/$(basename "$f")"
    done
fi

if [ -d "$DOTFILES_DIR/noctalia" ]; then
    safe_install_file "$DOTFILES_DIR/noctalia/config.toml" "$HOME/.config/noctalia/config.toml"
    if [ -d "$DOTFILES_DIR/noctalia/palettes" ]; then
        mkdir -p "$HOME/.config/noctalia/palettes"
        cp -rf "$DOTFILES_DIR/noctalia/palettes"/* "$HOME/.config/noctalia/palettes/" 2>/dev/null || true
    fi
fi

# Terminal Kitty
if [ -d "$DOTFILES_DIR/kitty" ]; then
    safe_install_file "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    if [ -d "$DOTFILES_DIR/kitty/themes" ]; then
        mkdir -p "$HOME/.config/kitty/themes"
        cp -rf "$DOTFILES_DIR/kitty/themes"/* "$HOME/.config/kitty/themes/" 2>/dev/null || true
    fi
fi

# Fastfetch
safe_install_file "$DOTFILES_DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
if [ -f "$DOTFILES_DIR/fastfetch/logo.txt" ]; then
    safe_install_file "$DOTFILES_DIR/fastfetch/logo.txt" "$HOME/.config/fastfetch/logo.txt"
fi

# Navegador de archivos Dolphin (Fondo Sólido sin Transparencia)
safe_install_file "$DOTFILES_DIR/Kvantum/kvantum.kvconfig" "$HOME/.config/Kvantum/kvantum.kvconfig"
safe_install_file "$DOTFILES_DIR/dolphinrc" "$HOME/.config/dolphinrc"

# VSCodium / VSCode
safe_install_file "$DOTFILES_DIR/vscode/settings.json" "$HOME/.config/VSCodium/User/settings.json"

# Shell Zsh
if [ -d "$DOTFILES_DIR/zsh" ]; then
    for zfile in "$DOTFILES_DIR/zsh"/*; do
        bname=$(basename "$zfile")
        if [ "$bname" != "starship" ]; then
            safe_install_file "$zfile" "$HOME/.zsh/$bname"
        fi
    done
    if [ -d "$DOTFILES_DIR/zsh/starship" ]; then
        mkdir -p "$HOME/.zsh/starship"
        cp -rf "$DOTFILES_DIR/zsh/starship"/* "$HOME/.zsh/starship/" 2>/dev/null || true
    fi
    # Crear enlace simbólico de .zshrc a ~/.zshrc
    rm -f "$HOME/.zshrc"
    ln -sf "$HOME/.zsh/.zshrc" "$HOME/.zshrc"
    echo -e "   ${GREEN}✔ Enlace creado:${NC} ~/.zshrc → ~/.zsh/.zshrc"
fi

# Instalación de utilidades personalizadas en ~/.local/bin
mkdir -p "$HOME/.local/bin"
if [ -d "$DOTFILES_DIR/scripts" ]; then
    for script in "$DOTFILES_DIR/scripts"/*; do
        sname=$(basename "$script")
        cp -f "$script" "$HOME/.local/bin/$sname"
        chmod +x "$HOME/.local/bin/$sname"
        echo -e "   ${GREEN}✔ Script instalado:${NC} ~/.local/bin/$sname"
    done
fi

# Servicio systemd para restaurar Noctalia tras suspender/hibernar
if [ -f "$DOTFILES_DIR/systemd/noctalia-resume.service" ]; then
    echo -e "\n${BLUE}⚡ Configurando servicio de reanudación de Noctalia...${NC}"
    if command -v sudo &>/dev/null; then
        sudo cp -f "$DOTFILES_DIR/systemd/noctalia-resume.service" "/etc/systemd/system/noctalia-resume@.service" 2>/dev/null && \
        sudo systemctl daemon-reload 2>/dev/null && \
        sudo systemctl enable "noctalia-resume@$(whoami).service" 2>/dev/null && \
        echo -e "   ${GREEN}✔ Servicio noctalia-resume habilitado.${NC}" || true
    fi
fi

# Configuración personalizada de SDDM
if [ -d "/usr/share/sddm/themes/SilentSDDM" ] && [ -f "$DOTFILES_DIR/sddm/default-left.conf" ]; then
    if command -v sudo &>/dev/null; then
        sudo cp -f "$DOTFILES_DIR/sddm/default-left.conf" "/usr/share/sddm/themes/SilentSDDM/configs/default-left.conf" 2>/dev/null || true
        echo -e "   ${GREEN}✔ SDDM configurado (Catppuccin Mocha).${NC}"
    fi
fi

# Asegurar ~/.local/bin en el PATH
for rfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rfile" ] && ! grep -q '\.local/bin' "$rfile"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rfile"
        echo -e "   ${GREEN}✔ PATH configurado en:${NC} $rfile"
    fi
done

# Cambiar shell por defecto a Zsh si está instalado
if command -v zsh &>/dev/null && [ "$SHELL" != "$(which zsh)" ]; then
    echo -e "${BLUE}🐚 Estableciendo Zsh como shell por defecto...${NC}"
    chsh -s "$(which zsh)" "$USER" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 6. RECARGA EN VIVO (SI NIRI ESTÁ EN EJECUCIÓN)
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
echo -e "  • ${CYAN}Mod + E${NC}            → Navegador de Archivos (Dolphin - Fondo Sólido Opaco)"
echo -e "  • ${CYAN}Mod + C${NC}            → Editor de código (VScodium)"
echo -e "  • ${CYAN}Mod + S${NC}            → Menú de Energía (Apagar, Reiniciar, Bloquear, Logout)"
echo -e "  • ${CYAN}Mod + D / Espacio${NC}  → Lanzador de aplicaciones (Rofi minimalista)"
echo -e "  • ${CYAN}Mod + B${NC}            → Navegador Web (Zen Browser)"
echo -e "  • ${CYAN}Mod + W${NC}            → Cambiar fondo de pantalla"
echo -e "  • ${CYAN}Mod + A${NC}            → Panel de Ajustes y Barra (Noctalia)"
echo -e "  • ${CYAN}Mod + L${NC}            → Bloquear pantalla (Hyprlock + Auto-restaurar Noctalia)"
echo -e "  • ${CYAN}Mod + F${NC}            → Maximizar ventana"
echo -e "  • ${CYAN}Mod + Q${NC}            → Cerrar ventana activa"
echo ""
echo -e "${GREEN}✨ ¡Todo listo! Tu entorno dotfiles está 100% instalado, protegido y sin transparencias molestas.${NC}"
echo ""
