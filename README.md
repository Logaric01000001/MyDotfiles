# MyDotfiles

Mis configuraciones para Arch Linux con el compositor Wayland Niri, barra Noctalia, Kitty y Zsh.

## Instalación Rápida

Puedes instalar y recuperar todo el entorno con un solo comando:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Logaric01000001/MyDotfiles/main/install.sh)"
```

O clonando manualmente el repositorio:

```bash
git clone https://github.com/Logaric01000001/MyDotfiles.git ~/MyDotfiles
cd ~/MyDotfiles
chmod +x install.sh
./install.sh
```

> **Recuperación tras `archinstall`**:
> 1. Completa la instalación base con `archinstall` (crea tu usuario con privilegios `sudo`).
> 2. Inicia sesión en tu usuario y ejecuta el comando de instalación.
> 3. El script instala automáticamente los paquetes de Pacman y AUR, configura Wayland (Niri), pantalla de bloqueo (Hyprlock/Swaylock), barra (Noctalia), audio (Pipewire), Bluetooth, tema de inicio de sesión (SilentSDDM), fondo de pantalla y habilita los servicios para reiniciar directamente en el entorno gráfico.

## Estructura

```text
MyDotfiles/
├── config.kdl        # Configuración de Niri (Wayland compositor)
├── install.sh        # Script de instalación y bootstrap automático
├── hyprlock.conf     # Bloqueo de pantalla estético (Hyprlock)
├── swaylock.conf     # Bloqueo secundario (Swaylock-effects)
├── dolphinrc         # Ajustes de Dolphin File Manager
├── mimeapps.list     # Asociaciones de archivos por defecto
├── Kvantum/          # Tema Qt KvArcDark
├── kitty/            # Terminal Kitty y temas
├── rofi/             # Menú de aplicaciones y lanzador
├── noctalia/         # Barra superior y widgets
├── fastfetch/        # Información estética del sistema
├── gtk/              # Tema GTK (Catppuccin Mocha)
├── vscode/           # Ajustes de VS Code / Codium / Antigravity
├── zsh/              # Zsh, alias limpios y funciones portables
├── scripts/          # Scripts de utilidad en ~/.local/bin
├── skills/           # Gestor de Agent Skills para IA
├── gemini/           # Plantillas seguras de MCP para IA
└── wallpapers/       # Fondos de pantalla predeterminados
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
