#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f /etc/arch-release ]; then
    echo "aviso: este script es para arch linux"
fi

if [ -f /var/lib/pacman/db.lck ]; then
    echo "pacman esta bloqueado (/var/lib/pacman/db.lck)"
    exit 1
fi

PKGS=(
    base-devel git niri hyprlock swaylock swaybg swayidle
    rofi-wayland wl-mirror kitty dolphin fastfetch zsh
    starship eza zoxide fuzzel cliphist kvantum kvantum-qt5
    pipewire wireplumber brightnessctl playerctl polkit-gnome
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    ttf-jetbrains-mono-nerd ttf-inter papirus-icon-theme
    wl-clipboard grim slurp
    bat btop fzf lazygit pacman-contrib lsof nwg-displays
    networkmanager pnpm python
)

OPT_NO_SUDO=false
OPT_YES=false

for arg in "$@"; do
    case "$arg" in
        --no-sudo) OPT_NO_SUDO=true ;;
        -y|--yes) OPT_YES=true ;;
    esac
done

CAN_SUDO=false
if [ "$OPT_NO_SUDO" = false ] && command -v sudo &>/dev/null; then
    if sudo -n true 2>/dev/null; then
        CAN_SUDO=true
    elif [ "$OPT_YES" = true ] && sudo -v 2>/dev/null; then
        CAN_SUDO=true
    elif [ -t 0 ]; then
        read -rp "¿Deseas instalar paquetes y configuraciones que requieren root (sudo)? [s/N]: " ask_sudo
        if [[ "$ask_sudo" =~ ^[sS]$ ]] && sudo -v 2>/dev/null; then
            CAN_SUDO=true
        fi
    fi
fi

echo "instalando paquetes..."
if command -v pacman &>/dev/null; then
    if [ "$CAN_SUDO" = true ]; then
        sudo pacman -S --needed --noconfirm "${PKGS[@]}" 2>/dev/null || true
    else
        echo "aviso: sin permisos de sudo inmediatos, se omiten paquetes de pacman que requieran root"
    fi
fi

# aur helper
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v pacman &>/dev/null; then
    echo "instalando yay..."
    TMP=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$TMP/yay-bin" 2>/dev/null || true
    (cd "$TMP/yay-bin" && makepkg -si --noconfirm 2>/dev/null) || true
    rm -rf "$TMP"
    AUR_HELPER="yay"
fi

if [ -n "$AUR_HELPER" ]; then
    command -v noctalia &>/dev/null || $AUR_HELPER -S --needed --noconfirm noctalia-bin || true
    command -v zen-browser &>/dev/null || $AUR_HELPER -S --needed --noconfirm zen-browser-bin || true
    command -v tty-clock &>/dev/null || $AUR_HELPER -S --needed --noconfirm tty-clock || true
    if ! command -v codium &>/dev/null && ! command -v vscodium &>/dev/null; then
        $AUR_HELPER -S --needed --noconfirm vscodium-bin || true
    fi
fi

# directorios
mkdir -p "$HOME/.config"/{niri,hypr,swaylock,rofi,noctalia,kitty,fastfetch,Kvantum,wireplumber/wireplumber.conf.d,opencode,pnpm}
mkdir -p "$HOME/.config"/VSCodium/User "$HOME/.config"/"Antigravity IDE"/User
mkdir -p "$HOME/.gemini/config/skills" "$HOME/.gemini/antigravity"
mkdir -p "$HOME/.zsh" "$HOME/.local/bin" "$HOME/.local/share/applications"
mkdir -p "$HOME/Imágenes"/{Capturas,Fondos} "$HOME/Descargas"

# backup e instalacion de archivos
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config/dotfiles_backup_$TIMESTAMP"

install_file() {
    local src="$1"
    local dest="$2"
    [ -e "$src" ] || return 0

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        if ! cmp -s "$src" "$dest"; then
            mkdir -p "$BACKUP_DIR/$(dirname "${dest#$HOME/}")"
            cp -a "$dest" "$BACKUP_DIR/${dest#$HOME/}"
        fi
    fi
    mkdir -p "$(dirname "$dest")"
    cp -Rf "$src" "$dest"
}

echo "copiando configuraciones..."
install_file "$DOTFILES_DIR/config.kdl" "$HOME/.config/niri/config.kdl"
install_file "$DOTFILES_DIR/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
install_file "$DOTFILES_DIR/swaylock.conf" "$HOME/.config/swaylock/config"

if [ -d "$DOTFILES_DIR/rofi" ]; then
    for f in "$DOTFILES_DIR/rofi"/*; do
        install_file "$f" "$HOME/.config/rofi/$(basename "$f")"
    done
fi

if [ -d "$DOTFILES_DIR/noctalia" ]; then
    install_file "$DOTFILES_DIR/noctalia/config.toml" "$HOME/.config/noctalia/config.toml"
    if [ -d "$DOTFILES_DIR/noctalia/palettes" ]; then
        mkdir -p "$HOME/.config/noctalia/palettes"
        cp -rf "$DOTFILES_DIR/noctalia/palettes"/* "$HOME/.config/noctalia/palettes/" 2>/dev/null || true
    fi
fi

if [ -d "$DOTFILES_DIR/kitty" ]; then
    install_file "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    if [ -d "$DOTFILES_DIR/kitty/themes" ]; then
        mkdir -p "$HOME/.config/kitty/themes"
        cp -rf "$DOTFILES_DIR/kitty/themes"/* "$HOME/.config/kitty/themes/" 2>/dev/null || true
    fi
fi

install_file "$DOTFILES_DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
[ -f "$DOTFILES_DIR/fastfetch/logo.txt" ] && install_file "$DOTFILES_DIR/fastfetch/logo.txt" "$HOME/.config/fastfetch/logo.txt"

install_file "$DOTFILES_DIR/Kvantum/kvantum.kvconfig" "$HOME/.config/Kvantum/kvantum.kvconfig"
install_file "$DOTFILES_DIR/dolphinrc" "$HOME/.config/dolphinrc"
install_file "$DOTFILES_DIR/mimeapps.list" "$HOME/.config/mimeapps.list"

# wireplumber, opencode y pnpm
[ -f "$DOTFILES_DIR/wireplumber/wireplumber.conf.d/51-disable-hsp-hfp.conf" ] && install_file "$DOTFILES_DIR/wireplumber/wireplumber.conf.d/51-disable-hsp-hfp.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/51-disable-hsp-hfp.conf"
[ -f "$DOTFILES_DIR/opencode/sc-deepseek-overlay.json" ] && install_file "$DOTFILES_DIR/opencode/sc-deepseek-overlay.json" "$HOME/.config/opencode/sc-deepseek-overlay.json"
[ -f "$DOTFILES_DIR/opencode/opencode.jsonc" ] && install_file "$DOTFILES_DIR/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
[ -f "$DOTFILES_DIR/pnpm/config.yaml" ] && install_file "$DOTFILES_DIR/pnpm/config.yaml" "$HOME/.config/pnpm/config.yaml"

# tema gtk (FlatColor dependia de pywal y dejaba las apps transparentes)
install_file "$DOTFILES_DIR/gtk/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
install_file "$DOTFILES_DIR/gtk/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
fi

# terminal por defecto para kde/dolphin
if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
    kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop
elif command -v kwriteconfig5 &>/dev/null; then
    kwriteconfig5 --file kdeglobals --group General --key TerminalApplication kitty
    kwriteconfig5 --file kdeglobals --group General --key TerminalService kitty.desktop
fi

if [ -d "$DOTFILES_DIR/applications" ]; then
    for app in "$DOTFILES_DIR/applications"/*; do
        install_file "$app" "$HOME/.local/share/applications/$(basename "$app")"
    done
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

install_file "$DOTFILES_DIR/vscode/settings.json" "$HOME/.config/VSCodium/User/settings.json"
install_file "$DOTFILES_DIR/vscode/settings.json" "$HOME/.config/Antigravity IDE/User/settings.json"

# zsh
if [ -d "$DOTFILES_DIR/zsh" ]; then
    for zfile in "$DOTFILES_DIR/zsh"/*; do
        bname=$(basename "$zfile")
        [ "$bname" != "starship" ] && install_file "$zfile" "$HOME/.zsh/$bname"
    done
    if [ -d "$DOTFILES_DIR/zsh/starship" ]; then
        mkdir -p "$HOME/.zsh/starship"
        cp -rf "$DOTFILES_DIR/zsh/starship"/* "$HOME/.zsh/starship/" 2>/dev/null || true
    fi
    rm -f "$HOME/.zshrc"
    ln -sf "$HOME/.zsh/.zshrc" "$HOME/.zshrc"
fi

# makepkg.conf
if [ -f "$DOTFILES_DIR/makepkg.conf" ]; then
    ln -sf "$DOTFILES_DIR/makepkg.conf" "$HOME/.makepkg.conf"
fi

# scripts
if [ -d "$DOTFILES_DIR/scripts" ]; then
    for script in "$DOTFILES_DIR/scripts"/*; do
        [ -f "$script" ] || continue
        sname=$(basename "$script")
        cp -f "$script" "$HOME/.local/bin/$sname"
        chmod +x "$HOME/.local/bin/$sname"
        [ -d "$HOME/.gemini/antigravity-ide/bin" ] && ln -sf "$HOME/.local/bin/$sname" "$HOME/.gemini/antigravity-ide/bin/$sname" 2>/dev/null || true
    done
fi

# skills
if [ -d "$DOTFILES_DIR/skills" ]; then
    chmod +x "$DOTFILES_DIR/skills/skills" "$DOTFILES_DIR/skills/install-antigravity-skills.sh" 2>/dev/null || true
    ln -sf "$DOTFILES_DIR/skills/skills" "$HOME/.local/bin/skills"
    [ -d "$HOME/.gemini/antigravity-ide/bin" ] && ln -sf "$DOTFILES_DIR/skills/skills" "$HOME/.gemini/antigravity-ide/bin/skills" 2>/dev/null || true
    if [ ! -e "$HOME/.gemini/antigravity/skills" ]; then
        ln -sf "$HOME/.gemini/config/skills" "$HOME/.gemini/antigravity/skills" 2>/dev/null || true
    fi
fi

# silentsddm si existe
if [ -d "/usr/share/sddm/themes/SilentSDDM" ] && [ -f "$DOTFILES_DIR/sddm/default-left.conf" ]; then
    if [ "$CAN_SUDO" = true ]; then
        sudo cp -f "$DOTFILES_DIR/sddm/default-left.conf" "/usr/share/sddm/themes/SilentSDDM/configs/default-left.conf" 2>/dev/null || true
    fi
fi

# path
for rfile in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.zshenv"; do
    if [ -f "$rfile" ] && ! grep -q '\.local/bin' "$rfile"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rfile"
    fi
done

# zsh por defecto
if command -v zsh &>/dev/null && [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)" "$USER" 2>/dev/null || true
fi

# bluetooth y wifi (rtl8821ce)
if [ "$CAN_SUDO" = true ]; then
    conf=/etc/bluetooth/main.conf
    if [ -f "$conf" ]; then
        sudo sed -i -E 's/^[#[:space:]]*ControllerMode[[:space:]]*=.*/ControllerMode = bredr/' "$conf" 2>/dev/null || true
        sudo sed -i -E 's/^[#[:space:]]*FastConnectable[[:space:]]*=.*/FastConnectable = false/' "$conf" 2>/dev/null || true
        sudo sed -i -E 's/^[#[:space:]]*AutoEnable[[:space:]]*=.*/AutoEnable = false/' "$conf" 2>/dev/null || true
        sudo sed -i 's/#NameResolving = true/NameResolving = true/' "$conf" 2>/dev/null || true
        sudo sed -i 's/#RemoteNameRequestRetryDelay = 300/RemoteNameRequestRetryDelay = 5/' "$conf" 2>/dev/null || true
        sudo sed -i -E 's/^[#[:space:]]*FilterDiscoverable[[:space:]]*=.*/FilterDiscoverable = true/' "$conf" 2>/dev/null || true
        sudo sed -i -E 's/^[#[:space:]]*TemporaryTimeout[[:space:]]*=.*/TemporaryTimeout = 10/' "$conf" 2>/dev/null || true
        grep -q "JustWorksRepairing" "$conf" || sudo sed -i '/\[General\]/a JustWorksRepairing = always' "$conf" 2>/dev/null || true
        echo "options btusb enable_autosuspend=n" | sudo tee /etc/modprobe.d/btusb.conf >/dev/null 2>&1 || true
        sudo systemctl restart bluetooth 2>/dev/null || true
    fi

    # iwd entra en conflicto con wpa_supplicant en networkmanager
    if systemctl list-unit-files NetworkManager.service &>/dev/null; then
        sudo systemctl disable --now iwd 2>/dev/null || true
        sudo systemctl mask iwd 2>/dev/null || true
        printf '[device]\nwifi.backend=wpa_supplicant\n' | sudo tee /etc/NetworkManager/conf.d/wifi-backend.conf >/dev/null 2>&1 || true
        if lspci 2>/dev/null | grep -qi "RTL8821CE"; then
            sudo rm -f /etc/modprobe.d/rtl8821ce.conf
            printf 'options rtw88_pci disable_aspm=y\noptions rtw88_core disable_lps_deep=y\n' | sudo tee /etc/modprobe.d/rtw88.conf >/dev/null 2>&1 || true
        fi
    fi

    # evitar suspension automatica al cerrar la tapa o por inactividad
    if [ -f "$DOTFILES_DIR/systemd/logind.conf.d/00-no-sleep.conf" ]; then
        sudo mkdir -p /etc/systemd/logind.conf.d
        sudo cp -f "$DOTFILES_DIR/systemd/logind.conf.d/00-no-sleep.conf" /etc/systemd/logind.conf.d/00-no-sleep.conf 2>/dev/null || true
        sudo systemctl reload systemd-logind 2>/dev/null || true
    fi
else
    echo "aviso: sin permisos de root/sudo en este momento; se omiten configuraciones del sistema (/etc/)"
fi

# no cambiar a perfil headset en wireplumber
if command -v wpctl &>/dev/null; then
    wpctl settings --save bluetooth.autoswitch-to-headset-profile false 2>/dev/null || true
fi

# recargar niri si esta corriendo
if pgrep -x niri &>/dev/null; then
    niri msg action load-config-file 2>/dev/null || true
fi

[ -d "$BACKUP_DIR" ] && echo "backup guardado en $BACKUP_DIR"
echo "instalacion completa"
