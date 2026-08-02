# 🌌 MyDotfiles — Niri Compositor & Catppuccin Mocha

Configuración completa, estética y ultra rápida para el compositor scrollable **[Niri](https://github.com/YaLTeR/niri)** en **Arch Linux**, con la paleta de colores **Catppuccin Mocha**, esquinas redondeadas, animaciones suaves y pantalla de bloqueo moderna.

---

## ✨ Características

* **Compositor**: [Niri](https://github.com/YaLTeR/niri) con scroll infinito horizontal y soporte para columnas dinámicas.
* **Paleta de Colores**: [Catppuccin Mocha](https://github.com/catppuccin/catppuccin) (`#cba6f7` Mauve, `#89b4fa` Blue).
* **Borde Activo (Focus Ring)**: Anillo de 3px con gradiente llamativo a 45°.
* **Esquinas Redondeadas**: Radio de 12px con recorte automático (`geometry-corner-radius 12`).
* **Desktop Shell / Barra**: Compatible con [Noctalia](https://github.com/noctalia-dev/noctalia) o Waybar vía layer-shell.
* **Pantalla de Bloqueo**: [Hyprlock](https://github.com/hyprwm/hyprlock) y [Swaylock-effects](https://github.com/mortie/swaylock-effects) con efecto *frosted glass* (desenfoque de cristal), reloj central y soporte para bloqueo por inactividad con `swayidle`.
* **Teclado & Touchpad**: Distribución dual `latam,es` (conmutación con <kbd>Alt+Shift</kbd>), `tap-to-click` y `natural-scroll`.
* **Información del Sistema**: [Fastfetch](https://github.com/fastfetch-cli/fastfetch) con diseño minimalista, iconos limpios y paleta Catppuccin Mocha.

---

## ⌨️ Atajos de Teclado Principales (<kbd>Mod</kbd> = Tecla Super/Windows)

### 🚀 Lanzadores de Aplicaciones
| Atajo | Acción |
| :--- | :--- |
| <kbd>Mod</kbd> + <kbd>Return</kbd> | Abrir Terminal (Kitty / Alacritty) |
| <kbd>Mod</kbd> + <kbd>D</kbd> o <kbd>Mod</kbd> + <kbd>Espacio</kbd> | Lanzador de Aplicaciones (Rofi / Noctalia) |
| <kbd>Mod</kbd> + <kbd>B</kbd> | **Navegador Web** (Zen Browser) |
| <kbd>Mod</kbd> + <kbd>E</kbd> | Gestor de Archivos (Thunar / Dolphin) |
| <kbd>Mod</kbd> + <kbd>W</kbd> | **Cambiar TODO** (Fondo Escritorio + Pantalla de Inicio) |
| <kbd>Mod</kbd> + <kbd>Ctrl</kbd> + <kbd>W</kbd> | **Cambiar SOLO Adentro** (Fondo del Escritorio) |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>W</kbd> | **Cambiar SOLO Afuera** (Fondo de Pantalla de Inicio SDDM) |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> | **Mostrar Guía de Atajos en Pantalla** (*Help Overlay*) |
| <kbd>Mod</kbd> + <kbd>A</kbd> | **Panel de Ajustes de Noctalia** (`settings-open`) |

### 🪟 Gestión de Ventanas y Pantallas
| Atajo | Acción |
| :--- | :--- |
| <kbd>Mod</kbd> + <kbd>Q</kbd> / <kbd>Mod+Shift+Q</kbd> | Cerrar ventana activa |
| <kbd>Mod</kbd> + <kbd>F</kbd> | **Maximizar columna** (pantalla completa respetando la barra superior) |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>F</kbd> | **Pantalla completa total** (fullscreen ocultando barras) |
| <kbd>Mod</kbd> + <kbd>L</kbd> | **Bloquear pantalla al instante** (Hyprlock) |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Alternar modo flotante en una ventana |
| <kbd>Mod</kbd> + <kbd>R</kbd> | Alternar anchos de columna predefinidos (33%, 50%, 66%, 100%) |
| <kbd>Mod</kbd> + <kbd>-</kbd> / <kbd>+</kbd> | Reducir / Aumentar ancho de columna (-10% / +10%) |

### 🧭 Navegación y Workspaces
| Atajo | Acción |
| :--- | :--- |
| <kbd>Mod</kbd> + <kbd>←</kbd> / <kbd>→</kbd> | Mover foco entre columnas (Izquierda / Derecha) |
| <kbd>Mod</kbd> + <kbd>↑</kbd> / <kbd>↓</kbd> | Mover foco dentro de la columna (Arriba / Abajo) |
| <kbd>Mod</kbd> + <kbd>H</kbd> / <kbd>J</kbd> / <kbd>K</kbd> | Navegación direccional alternativa |
| <kbd>Mod</kbd> + <kbd>1</kbd> - <kbd>9</kbd> | Cambiar al espacio de trabajo (Workspace) 1 - 9 |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd> - <kbd>9</kbd> | Mover columna actual al espacio de trabajo 1 - 9 |
| <kbd>Mod</kbd> + <kbd>Ctrl</kbd> + <kbd>↑</kbd> / <kbd>↓</kbd> | Subir / Bajar de espacio de trabajo |

### 🔊 Multimedia y Brillo
| Tecla | Acción |
| :--- | :--- |
| <kbd>XF86AudioRaiseVolume</kbd> / <kbd>LowerVolume</kbd> | Subir / Bajar volumen (WirePlumber) |
| <kbd>XF86AudioMute</kbd> / <kbd>MicMute</kbd> | Silenciar altavoces / Silenciar micrófono |
| <kbd>XF86MonBrightnessUp</kbd> / <kbd>Down</kbd> | Subir / Bajar brillo de pantalla |
| <kbd>Print</kbd> / <kbd>Ctrl+Print</kbd> | Captura interactiva / Captura de pantalla completa |

---

## ⚡ ¿Cómo añadir nuevos atajos de teclado fácilmente?

En el archivo `~/.config/niri/config.kdl` (o dentro de este repositorio en `config.kdl`), busca la sección:
```kdl
// ⭐ SECCIÓN DE ATAJOS PERSONALIZADOS
```

Solo agrega una línea con tu combinación preferida:

```kdl
// Abrir una aplicación:
Mod+C       { spawn "code"; }             // Abrir VS Code
Mod+M       { spawn "spotify"; }          // Abrir Spotify
Mod+T       { spawn "telegram-desktop"; } // Abrir Telegram

// Ejecutar un script personal:
Mod+Shift+S { spawn "bash" "/home/usuario/scripts/mi-script.sh"; }
```

> **Nota:** Al guardar el archivo (`Ctrl+S`), Niri **recarga automáticamente** la nueva configuración al instante sin necesidad de reiniciar.
> Además, puedes presionar <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> en cualquier momento para ver la lista completa de todos los atajos en pantalla (*Help Overlay*).

---

## 🖼️ Gestión de Fondos de Pantalla (Escritorio y Pantalla de Inicio)

Puedes cambiar los fondos de manera gráfica o por línea de comandos:

### 1. Con Atajos de Teclado Directos:
* **<kbd>Mod</kbd> + <kbd>W</kbd>**: Abre el selector de Rofi y cambia el fondo de **TODO** (Escritorio + Pantalla de Inicio) al instante.
* **<kbd>Mod</kbd> + <kbd>Ctrl</kbd> + <kbd>W</kbd>**: Abre el selector y cambia **SOLO el fondo de adentro** (Escritorio).
* **<kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>W</kbd>**: Abre el selector y cambia **SOLO el fondo de afuera** (Pantalla de inicio SDDM).

### 2. Por línea de comandos:
```bash
# Cambiar en TODO el sistema (Escritorio + Pantalla de inicio):
set-wallpaper all ~/Imágenes/mi-fondo.jpg

# Cambiar SOLO el fondo del escritorio (adentro):
set-wallpaper inside ~/Imágenes/mi-fondo.jpg

# Cambiar SOLO el fondo de inicio de sesión SDDM (afuera):
set-wallpaper outside ~/Imágenes/mi-fondo.jpg
```

---

## ⚡ Personalizar Fastfetch en Segundos

El archivo `fastfetch/config.jsonc` (instalado en `~/.config/fastfetch/config.jsonc`) viene completamente comentado y ordenado por secciones lógicas:

1. **Activar/Desactivar Módulos**: Solo agrega `//` al inicio de cualquier línea o bloque para ocultarlo (por ejemplo para ocultar la GPU, paquetes o uptime).
2. **Cambiar Colores de Iconos**: Cada módulo tiene `"keyColor": "cyan"`, `"blue"`, `"magenta"`, `"green"`, o `"yellow"`.
3. **Probar Cambios al Instante**: Simplemente ejecuta `fastfetch` en tu terminal para ver el resultado.

---

## 📦 Instalación en 1 Solo Paso (Arch Linux)

Cualquier persona solo necesita ejecutar un solo comando en su terminal:

```bash
# Opción A (Directo con 1 solo comando):
bash <(curl -s https://raw.githubusercontent.com/tu-usuario/MyDotfiles/main/install.sh)

# Opción B (Clonando manualmente):
git clone https://github.com/tu-usuario/MyDotfiles.git ~/MyDotfiles
cd ~/MyDotfiles
./install.sh
```

El script se encarga de **todo** de manera 100% automatizada:
1. Instala paquetes oficiales con `pacman` (Niri, Hyprlock, Kitty, Thunar, fuentes, portales, utilidades multimedia).
2. Detecta o instala un gestor de AUR (`yay`) e instala **Noctalia Shell** y **Zen Browser**.
3. Realiza copias de seguridad (`.bak`) de configuraciones antiguas.
4. **Copia directamente los archivos físicos** a `~/.config/` (independiente, sin enlaces simbólicos).

---

## 🛠️ Estructura del Repositorio

```text
MyDotfiles/
├── config.kdl              # Configuración maestra para Niri
├── hyprlock.conf            # Pantalla de bloqueo moderna con reloj gigante y blur
├── swaylock.conf            # Alternativa con swaylock-effects
├── kitty/
│   └── kitty.conf          # Configuración de terminal (sin sonido de campana)
├── fastfetch/
│   ├── config.jsonc        # Resumen del sistema modular y fácil de personalizar
│   └── logo.txt            # Logo ASCII personalizable (Log4ric por defecto)
├── rofi/
│   └── config.rasi         # Menú y lanzador de aplicaciones (Catppuccin Mocha)
├── noctalia/
│   └── config.toml         # Configuración de barra superior, widgets y espaciado
├── sddm/
│   └── default-left.conf   # Pantalla de inicio SDDM personalizada (Catppuccin Mocha)
├── scripts/
│   ├── set-wallpaper.sh    # Gestor universal de fondos (Adentro, Afuera o Todo)
│   ├── help-menu.sh        # Menú interactivo de ayuda y lanzador (Mod+Shift+H)
│   └── fix-noctalia-resume.sh  # Restaura Noctalia al abrir la tapa del laptop
├── systemd/
│   └── noctalia-resume.service  # Servicio systemd para restaurar la barra tras suspender
├── install.sh               # Script instalador automático
└── README.md                # Documentación y atajos
```

