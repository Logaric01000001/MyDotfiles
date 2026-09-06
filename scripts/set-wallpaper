#!/usr/bin/env bash
# =============================================================================
#   🎨 SET-WALLPAPER — Gestor Universal de Fondos de Pantalla
#   Integrado con Noctalia Shell (Escritorio) y SilentSDDM (Pantalla de inicio).
# =============================================================================

set -e

WALLPAPERS_DIR="$HOME/Imágenes/Fondos"
CURRENT_DESKTOP_WP="$HOME/.config/current_wallpaper"
SDDM_THEME_DIR="/usr/share/sddm/themes/SilentSDDM"
SDDM_BG_DIR="$SDDM_THEME_DIR/backgrounds"
SDDM_CONF_FILE="$SDDM_THEME_DIR/configs/default-left.conf"

mkdir -p "$WALLPAPERS_DIR"
mkdir -p "$HOME/.config"

# Notificación visual limpia
notify() {
    local title="$1"
    local msg="$2"
    if command -v notify-send &>/dev/null; then
        notify-send -a "Fondos" -i "preferences-desktop-wallpaper" "$title" "$msg" 2>/dev/null || true
    fi
}

# Obtener lista de imágenes disponibles
get_images() {
    local imgs
    mapfile -t imgs < <(find "$WALLPAPERS_DIR" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)
    
    if [ ${#imgs[@]} -eq 0 ]; then
        if [ -d "$SDDM_BG_DIR" ]; then
            cp -n "$SDDM_BG_DIR"/* "$WALLPAPERS_DIR/" 2>/dev/null || true
            mapfile -t imgs < <(find "$WALLPAPERS_DIR" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)
        fi
    fi
    printf "%s\n" "${imgs[@]}"
}

# Selector interactivo de imagen vía Rofi
prompt_image() {
    local prompt_title="$1"
    local images=()
    while IFS= read -r line; do
        [ -n "$line" ] && images+=("$line")
    done < <(get_images)

    if [ ${#images[@]} -eq 0 ]; then
        notify "Fondos de Pantalla" "No hay imágenes en $WALLPAPERS_DIR"
        exit 0
    fi

    local names=()
    for f in "${images[@]}"; do
        names+=("$(basename "$f")")
    done

    local selected_name
    selected_name=$(printf "%s\n" "${names[@]}" | rofi -dmenu -i -p "$prompt_title")
    [ -z "$selected_name" ] && exit 0

    for f in "${images[@]}"; do
        if [ "$(basename "$f")" = "$selected_name" ]; then
            echo "$f"
            return 0
        fi
    done
}

# Aplicar fondo al Escritorio (Adentro) vía Noctalia
set_inside() {
    local img="$1"
    if [ ! -f "$img" ]; then
        echo "Error: Imagen no encontrada: $img"
        exit 1
    fi

    # Guardar copia de referencia
    cp -f "$img" "$CURRENT_DESKTOP_WP"

    # 1. Cambiar fondo nativo mediante Noctalia
    if command -v noctalia &>/dev/null && pgrep -x noctalia &>/dev/null; then
        noctalia msg wallpaper-set "$img" 2>/dev/null || true
        # Asegurar que swaybg no cree conflictos
        pkill -x swaybg 2>/dev/null || true
    else
        # Fallback si Noctalia no está en ejecución
        pkill -x swaybg 2>/dev/null || true
        swaybg -i "$CURRENT_DESKTOP_WP" -m fill &>/dev/null &
        disown
    fi

    echo "Fondo de escritorio actualizado: $img"
    notify "Fondo de Pantalla" "Fondo de escritorio (adentro) actualizado."
}

# Aplicar fondo a la Pantalla de Inicio SDDM (Afuera)
set_outside() {
    local img="$1"
    if [ ! -f "$img" ]; then
        echo "Error: Imagen no encontrada: $img"
        exit 1
    fi

    local ext="${img##*.}"
    local target_filename="current_wallpaper.${ext}"
    local target_path="$SDDM_BG_DIR/$target_filename"

    if [ -d "$SDDM_THEME_DIR" ]; then
        if [ -w "$SDDM_BG_DIR" ]; then
            cp -f "$img" "$target_path"
        else
            if command -v pkexec &>/dev/null; then
                pkexec cp -f "$img" "$target_path"
            elif command -v sudo &>/dev/null; then
                sudo cp -f "$img" "$target_path"
            fi
        fi

        if [ -f "$SDDM_CONF_FILE" ]; then
            if [ -w "$SDDM_CONF_FILE" ]; then
                sed -i "s|^background = .*|background = \"$target_filename\"|g" "$SDDM_CONF_FILE"
            else
                if command -v pkexec &>/dev/null; then
                    pkexec sed -i "s|^background = .*|background = \"$target_filename\"|g" "$SDDM_CONF_FILE"
                elif command -v sudo &>/dev/null; then
                    sudo sed -i "s|^background = .*|background = \"$target_filename\"|g" "$SDDM_CONF_FILE"
                fi
            fi
        fi

        echo "Fondo de inicio SDDM actualizado: $img"
        notify "Pantalla de Inicio" "Fondo de pantalla de inicio (SDDM) actualizado."
    else
        echo "Aviso: Tema SilentSDDM no encontrado en $SDDM_THEME_DIR"
    fi
}

# Aplicar a ambos (Adentro y Afuera)
set_all() {
    local img="$1"
    set_inside "$img"
    set_outside "$img"
    notify "Fondo de Pantalla" "Fondo actualizado en todo el sistema (Escritorio + SDDM)."
}

# --- Procesamiento de argumentos y atajos CLI ---
MODE="${1:-}"
IMAGE="${2:-}"

case "$MODE" in
    select-all|menu-all)
        chosen=$(prompt_image "Fondo para Todo (Escritorio + SDDM):")
        [ -n "$chosen" ] && set_all "$chosen"
        ;;

    select-inside|menu-inside|select-desktop)
        chosen=$(prompt_image "Fondo para Escritorio (Adentro):")
        [ -n "$chosen" ] && set_inside "$chosen"
        ;;

    select-outside|menu-outside|select-sddm)
        chosen=$(prompt_image "Fondo para Pantalla de Inicio (Afuera):")
        [ -n "$chosen" ] && set_outside "$chosen"
        ;;

    all|todo|both)
        if [ -z "$IMAGE" ]; then
            chosen=$(prompt_image "Fondo para Todo:")
            [ -n "$chosen" ] && set_all "$chosen"
        else
            set_all "$IMAGE"
        fi
        ;;

    inside|desktop|dentro)
        if [ -z "$IMAGE" ]; then
            chosen=$(prompt_image "Fondo para Escritorio:")
            [ -n "$chosen" ] && set_inside "$chosen"
        else
            set_inside "$IMAGE"
        fi
        ;;

    outside|sddm|fuera|login)
        if [ -z "$IMAGE" ]; then
            chosen=$(prompt_image "Fondo para Pantalla de Inicio:")
            [ -n "$chosen" ] && set_outside "$chosen"
        else
            set_outside "$IMAGE"
        fi
        ;;

    menu|interactive|"")
        chosen=$(prompt_image "Seleccionar Fondo:")
        [ -z "$chosen" ] && exit 0

        target=$(printf "Todo (Escritorio + Pantalla de Inicio)\nSolo Escritorio (Adentro)\nSolo Pantalla de Inicio (Afuera)" | rofi -dmenu -i -p "Aplicar en:")
        case "$target" in
            "Todo"*) set_all "$chosen" ;;
            "Solo Escritorio"*) set_inside "$chosen" ;;
            "Solo Pantalla de Inicio"*) set_outside "$chosen" ;;
        esac
        ;;

    *)
        if [ -f "$MODE" ]; then
            set_all "$MODE"
        else
            echo "Uso: set-wallpaper [select-all|select-inside|select-outside|all|inside|outside] [ruta-imagen]"
        fi
        ;;
esac
