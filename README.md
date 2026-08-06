# 🌌 MyDotfiles — Niri Compositor & Catppuccin Mocha Work Environment

Un entorno de trabajo moderno, ultrarrápido y visualmente impresionante para **Arch Linux** y derivados, basado en el compositor **Niri (Wayland)**, la suite visual **Catppuccin Mocha**, la shell de escritorio **Noctalia**, la terminal **Kitty / Alacritty**, la shell **Zsh**, **Fastfetch**, **VSCodium** y la suite de utilidades personalizadas.

---

## 🚀 Instalación Rápida (Un Solo Comando)

Para instalar este entorno en una máquina nueva o restaurar tu configuración:

```bash
git clone https://github.com/Logaric01000001/MyDotfiles.git ~/MyDotfiles
cd ~/MyDotfiles
chmod +x install.sh
./install.sh
```

El script `install.sh` se encarga de:
1. Comprobar e instalar dependencias oficiales (`pacman`) y de la comunidad (`yay`/`paru`).
2. Crear un **respaldo automático fechado** (`~/.config/dotfiles_backup_YYYYMMDD_HHMMSS`) si detecta archivos existentes.
3. Copiar y enlazar todas las configuraciones en `~/.config/`, `~/.zsh`, `~/.local/bin` y `~/.zshrc`.
4. Configurar el servicio systemd de reanudación automática tras suspensión.
5. Recargar Niri al vuelo si ya está ejecutándose.

---

## 🗂️ Estructura del Repositorio

```text
MyDotfiles/
├── install.sh                  # Script maestro de instalación automatizada
├── README.md                   # Documentación principal y guía de uso
├── .gitignore                  # Reglas de privacidad y exclusión de secretos
├── config.kdl                  # Configuración principal del compositor Niri
├── dolphinrc                   # Configuración del navegador de archivos Dolphin (Fondo Sólido)
├── hyprlock.conf               # Pantalla de bloqueo elegante con Hyprlock
├── swaylock.conf               # Pantalla de bloqueo de respaldo con Swaylock
├── Kvantum/
│   └── kvantum.kvconfig        # Tema Qt/Kvantum sin transparencias en vistas
├── alacritty/                  # Configuración y temas de la terminal Alacritty
├── kitty/                      # Configuración y temas Catppuccin/Noctalia de Kitty
├── rofi/                       # Lanzador de aplicaciones y menú flotante
├── noctalia/                   # Shell de escritorio, barra y paneles
├── fastfetch/                  # Información del sistema estilo minimalista
├── zsh/                        # Shell Zsh modular (.zshrc, alias, funciones, p10k, starship)
├── vscode/                     # Preferencias visuales de VSCodium
├── scripts/                    # Utilidades ejecutables (~/.local/bin)
├── sddm/                       # Configuración de pantalla de inicio SDDM
└── systemd/                    # Servicios de sistema (Noctalia resume)
```

---

## ⌨️ Atajos de Teclado Principales

Los atajos de teclado usan la tecla **`Mod`** (Tecla Windows / Super):

| Atajo | Función / Aplicación |
| :--- | :--- |
| **`Mod + Shift + H`** | ❓ **Guía Interactiva en Pantalla** (Help Menu) |
| **`Mod + Enter`** | 💻 **Terminal** (Kitty / Alacritty) |
| **`Mod + E`** | 📁 **Navegador de Archivos** (Dolphin - Fondo Sólido) |
| **`Mod + C`** | 📝 **Editor de Código** (VSCodium) |
| **`Mod + B`** | 🌐 **Navegador Web** (Zen Browser) |
| **`Mod + D` / `Mod + Espacio`** | 🚀 **Lanzador de Aplicaciones** (Rofi) |
| **`Mod + S`** | ⚡ **Menú de Energía** (Apagar, Reiniciar, Bloquear, Cerrar sesión) |
| **`Mod + W`** | 🖼️ **Cambiar Fondo de Pantalla** |
| **`Mod + A`** | ⚙️ **Panel de Ajustes y Barra** (Noctalia) |
| **`Mod + L`** | 🔒 **Bloquear Pantalla** (Hyprlock) |
| **`Mod + F`** | 🔲 **Maximizar Columna** |
| **`Mod + Shift + F`** | 🖥️ **Pantalla Completa Total** |
| **`Mod + Q`** | ❌ **Cerrar Ventana Activa** |

---

## 📦 Paquetes y Componentes Utilizados

- **Compositor Wayland:** `niri`
- **Shell de Escritorio & Barra:** `noctalia`
- **Lanzador de Apps:** `rofi-wayland`
- **Terminales:** `kitty`, `alacritty`
- **Navegador de Archivos:** `dolphin` + `kvantum` (`KvArcDark` opaco)
- **Shell & Prompt:** `zsh`, `starship`, `powerlevel10k`, `eza`, `zoxide`
- **Portapapeles & Notificaciones:** `cliphist`, `wl-clipboard`, `fuzzel`
- **Capturas de Pantalla:** `grim`, `slurp`
- **Bloqueo de Pantalla:** `hyprlock`, `swaylock`

---

## 🔒 Garantía de Seguridad y Privacidad

Para garantizar que tus datos privados nunca se compartan al subir este repositorio a GitHub u otros servicios:
- El archivo `.gitignore` ignora automáticamente `.zsh_history`, `*.key`, `id_rsa`, `*.pem` y cualquier archivo de credenciales.
- Los scripts han sido sanitizados para no contener rutas absolutas fijas ni contraseñas.
