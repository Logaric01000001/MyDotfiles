#!/usr/bin/env bash
# up [n] [opciones de paru]
#   up            pregunta cuantas descargas en paralelo
#   up 3          3 en paralelo
#   up --ignore seclists
set -e

EXTRA_ARGS=()
TARGET_PARALLEL=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            echo "uso: up [n] [opciones de paru]"
            echo "  up 1                   de a uno (internet lento)"
            echo "  up 5 --ignore seclists"
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

# db.lck colgado
if [ -f /var/lib/pacman/db.lck ]; then
    LCK_PID=$(lsof -t /var/lib/pacman/db.lck 2>/dev/null || true)
    if [ -n "$LCK_PID" ] && ps -p "$LCK_PID" >/dev/null 2>&1; then
        echo "pacman ya esta corriendo (pid $LCK_PID)"
        exit 1
    fi
    read -rp "db.lck huerfano, lo borro? [s/N]: " rm_lock
    if [[ "$rm_lock" =~ ^[sS]$ ]]; then
        sudo rm -f /var/lib/pacman/db.lck
    else
        exit 1
    fi
fi

# ParallelDownloads
CURRENT_PARALLEL=$(grep -E "^[#[:space:]]*ParallelDownloads" /etc/pacman.conf 2>/dev/null | grep -o -E "[0-9]+" | head -n1 || echo "5")

if [ -z "$TARGET_PARALLEL" ] && [ -t 0 ]; then
    read -rp "descargas en paralelo [$CURRENT_PARALLEL]: " input_parallel
    [[ "$input_parallel" =~ ^[1-9][0-9]*$ ]] && TARGET_PARALLEL="$input_parallel"
fi

if [ -n "$TARGET_PARALLEL" ] && [ "$TARGET_PARALLEL" -ne "$CURRENT_PARALLEL" ]; then
    if grep -q -E "^[#[:space:]]*ParallelDownloads" /etc/pacman.conf; then
        sudo sed -i -E "s/^[#[:space:]]*ParallelDownloads[[:space:]]*=.*/ParallelDownloads = $TARGET_PARALLEL/" /etc/pacman.conf
    else
        sudo sed -i "/\[options\]/a ParallelDownloads = $TARGET_PARALLEL" /etc/pacman.conf
    fi
    echo "ParallelDownloads = $TARGET_PARALLEL"
fi

IGNORED_PKGS=$(grep -E "^IgnorePkg" /etc/pacman.conf | cut -d= -f2- | xargs)
[ -n "$IGNORED_PKGS" ] && echo "IgnorePkg: $IGNORED_PKGS"

# desactivar paquetes -debug si no esta configurado (evita errores de gdb-add-index y DWO en binarios de AUR)
if [ ! -f "$HOME/.makepkg.conf" ] && [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/pacman/makepkg.conf" ]; then
    echo 'OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)' > "$HOME/.makepkg.conf"
fi

# keyrings + mirrors de blackarch
if grep -q "\[blackarch\]" /etc/pacman.conf; then
    ml=/etc/pacman.d/blackarch-mirrorlist
    if [ -f "$ml" ]; then
        # cedia se cae con archivos grandes (seclists)
        sudo sed -i 's/^Server = .*cedia.org.ec/#&/' "$ml" 2>/dev/null || true
        sudo sed -i '/#Server = https:\/\/www.blackarch.org/s/^#//' "$ml" 2>/dev/null || true
        sudo sed -i '/#Server = https:\/\/mirrors.ocf.berkeley.edu/s/^#//' "$ml" 2>/dev/null || true
        sudo sed -i '/#Server = https:\/\/ftp2.osuosl.org/s/^#//' "$ml" 2>/dev/null || true
    fi
    sudo pacman -Sy --needed --noconfirm archlinux-keyring blackarch-keyring 2>/dev/null || \
    sudo pacman -Sy --needed --noconfirm archlinux-keyring 2>/dev/null || true
else
    sudo pacman -Sy --needed --noconfirm archlinux-keyring 2>/dev/null || true
fi

UPDATE_FAILED=0
if command -v paru >/dev/null 2>&1; then
    paru -Syu "${EXTRA_ARGS[@]}" || UPDATE_FAILED=$?
elif command -v yay >/dev/null 2>&1; then
    yay -Syu "${EXTRA_ARGS[@]}" || UPDATE_FAILED=$?
else
    sudo pacman -Syu "${EXTRA_ARGS[@]}" || UPDATE_FAILED=$?
fi

if [ "$UPDATE_FAILED" -ne 0 ]; then
    echo
    echo "algun paquete fallo durante la actualizacion."
    if [ -t 0 ]; then
        read -rp "reintentar algun paquete? [nombre / N]: " retry_pkg
        while [[ -n "$retry_pkg" && ! "$retry_pkg" =~ ^[nN]$ ]]; do
            if [ -d "$HOME/.cache/paru/clone/$retry_pkg" ]; then
                echo "limpiando cache de $retry_pkg..."
                rm -rf "$HOME/.cache/paru/clone/$retry_pkg/src" "$HOME/.cache/paru/clone/$retry_pkg"/*.pkg.tar.zst 2>/dev/null || true
            fi
            if command -v paru >/dev/null 2>&1; then
                paru -S --rebuild "$retry_pkg" || echo "no se pudo instalar $retry_pkg"
            elif command -v yay >/dev/null 2>&1; then
                yay -S --rebuild "$retry_pkg" || echo "no se pudo instalar $retry_pkg"
            else
                sudo pacman -S "$retry_pkg" || echo "no se pudo instalar $retry_pkg"
            fi
            echo
            read -rp "reintentar otro paquete? [nombre / Enter para terminar]: " retry_pkg
        done
    fi
fi

ORPHANS=$(pacman -Qtdq || true)
if [ -n "$ORPHANS" ]; then
    echo
    echo "huerfanos:"
    echo "$ORPHANS"
    read -rp "borrarlos? [s/N]: " rm_orphans
    [[ "$rm_orphans" =~ ^[sS]$ ]] && (sudo pacman -Rns $ORPHANS || true)
fi

# hace falta reiniciar?
RUNNING_KERNEL=$(uname -r | cut -d- -f1)
INSTALLED_KERNEL=$(pacman -Q linux 2>/dev/null | awk '{print $2}' | cut -d. -f1-3 || true)
if [ -z "$INSTALLED_KERNEL" ]; then
    INSTALLED_KERNEL=$(pacman -Q linux-zen 2>/dev/null | awk '{print $2}' | cut -d. -f1-3 || \
                       pacman -Q linux-lts 2>/dev/null | awk '{print $2}' | cut -d. -f1-3 || true)
fi

if [ -n "$INSTALLED_KERNEL" ] && [[ "$RUNNING_KERNEL" != *"$INSTALLED_KERNEL"* ]]; then
    echo "kernel nuevo ($RUNNING_KERNEL -> $INSTALLED_KERNEL), reinicia"
elif tail -n 50 /var/log/pacman.log | grep -q -E "upgraded (systemd|niri|dbus)" 2>/dev/null; then
    echo "se actualizo systemd/niri/dbus, reinicia"
fi
