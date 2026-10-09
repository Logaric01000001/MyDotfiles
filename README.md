# MyDotfiles

Mis configuraciones para Arch Linux con el compositor Wayland Niri, barra Noctalia, Kitty y Zsh.

## Instalacion

```bash
git clone https://github.com/Logaric01000001/MyDotfiles.git ~/MyDotfiles
cd ~/MyDotfiles
chmod +x install.sh
./install.sh
```

El script instala los paquetes necesarios, respalda archivos anteriores en `~/.config/dotfiles_backup_*` y copia las configuraciones.

## Estructura

```text
MyDotfiles/
├── config.kdl        # Configuracion de Niri
├── install.sh        # Script de instalacion
├── hyprlock.conf     # Bloqueo de pantalla
├── swaylock.conf     # Bloqueo secundario
├── dolphinrc         # Dolphin
├── mimeapps.list     # Asociaciones de archivos
├── Kvantum/          # Tema Qt KvArcDark
├── kitty/            # Terminal Kitty
├── rofi/             # Menu de aplicaciones
├── noctalia/         # Barra y shell
├── fastfetch/        # Informacion del sistema
├── gtk/              # Tema GTK (Catppuccin)
├── vscode/           # Ajustes de VS Code / Codium
├── zsh/              # Zsh, alias y funciones
├── scripts/          # Scripts en ~/.local/bin
└── skills/           # Gestor de Agent Skills
```

## Atajos (Mod = Super/Windows)

| Atajo | Accion |
| :--- | :--- |
| `Mod + Return` | Terminal (Kitty) |
| `Mod + D` / `Mod + Espacio` | Menu de aplicaciones (Rofi) |
| `Mod + B` | Navegador (Zen Browser) |
| `Mod + E` | Gestor de archivos (Dolphin) |
| `Mod + C` | Editor de codigo |
| `Mod + Q` | Cerrar ventana |
| `Mod + F` | Maximizar columna |
| `Mod + Shift + F` | Pantalla completa |
| `Mod + L` | Bloquear pantalla (Hyprlock) |
| `Mod + S` | Menu de apagado (Power) |
| `Mod + P` | Modo de pantalla (Extend, Mirror, Laptop, Externo) |
| `Mod + W` | Cambiar fondo de pantalla |
| `Mod + A` | Ajustes de Noctalia |
| `Mod + Shift + H` | Menu interactivo de atajos |

## Scripts utiles

- `up`: actualizador inteligente de Arch (pacman/paru, limpia huerfanos y avisa si se actualizo el kernel).
- `set-wallpaper`: selector de fondo de escritorio y SDDM con Rofi.
- `display-mode.sh`: alterna entre extender pantalla, duplicar con wl-mirror o usar solo una pantalla.
- `conectar-audifonos`: emparejamiento y conexion automatica de audifonos Bluetooth.
- `fix-wifi-bluetooth.sh`: resuelve conflictos de WiFi y activa opciones estables para el chip Realtek RTL8821CE.
