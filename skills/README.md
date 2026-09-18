# Antigravity Community Skills Installer for Arch Linux

Un instalador CLI profesional, idempotente y con análisis de seguridad integrado para desplegar la mejor selección comunitaria de **Agent Skills** compatibles con **Google Antigravity IDE** en **Arch Linux**.

---

## 🌟 Características Principales

- **Ejecución en un solo paso**: Clona, valida, audita por seguridad e instala 42 Agent Skills seleccionadas en `~/.gemini/antigravity/skills/`.
- **Compatibilidad real con Antigravity IDE**: Valida estrictamente el formato Agent Skills (`SKILL.md` con frontmatter YAML `name` y `description`).
- **Seguridad en profundidad**: Escanea activamente el contenido de los prompts y scripts en busca de patrones destructivos (`rm -rf /`), descargas remotas no verificadas (`curl | bash`), payloads de escalada ofensiva a root y exfiltración de llaves SSH.
- **Idempotente**: Puede ejecutarse tantas veces como sea necesario. Compara hashes SHA-256 para evitar duplicaciones o backups redundantes.
- **Sistema de Backups Automático**: Si una Skill ya existe y presenta cambios, crea un backup versionado con timestamp en `~/.gemini/antigravity/skills-backups/YYYYMMDD-HHMMSS/<skill-name>/`.
- **Rastreo con Manifest**: Cada Skill instalada queda registrada en `~/.gemini/antigravity/skills-manifest.txt` con el commit SHA exacto de Git del repositorio origen.
- **Desinstalación Segura**: Permite desinstalar (`--uninstall <skill>`) únicamente aquellas Skills gestionadas por el instalador, protegiendo las Skills locales creadas manualmente por el usuario.
- **Caché Inteligente**: Utiliza `~/.cache/antigravity-skills-installer/` para descargas eficientes (`--depth 1`) y soporte de ejecución sin conexión a internet.
- **Interfaz Terminal Adaptativa**: Detección automática de TTY con colores ANSI estilizados y salida limpia si se redirige a un archivo o pipeline.

---

## 📋 Requisitos del Sistema (Arch Linux)

El instalador utiliza únicamente herramientas estándar del entorno Linux / GNU:
- `bash` (v4.4+)
- `git`
- `find`
- `awk`, `sed`, `grep`
- `sha256sum`
- `mktemp`

Si alguna utilidad falta en una instalación mínima de Arch Linux, puedes instalarla con:
```bash
sudo pacman -S --needed bash git findutils gawk sed grep coreutils
```

## 🚀 Modo Súper Fácil (Comando Global)

El comando `skills` ya está en tu `$PATH`. Puedes ejecutarlo **desde cualquier carpeta de tu terminal** sin `./`:

```bash
skills
```
Se abrirá el **Panel de Control Interactivo** donde solo tienes que presionar un número y Enter:
```text
  1) 🚀 Instalar todo (Instala las 42 Skills curadas)
  2) 📋 Ver mis Skills instaladas (Muestra estado y skills activas)
  3) 🔄 Actualizar repositorios y Skills (Descarga novedades de Git)
  4) 🔍 Simular instalación (Dry-Run: ver qué cambiaría sin tocar nada)
  5) 🛡️  Escanear seguridad (Auditar repos en busca de riesgos)
  6) 🗑️  Desinstalar UNA Skill (Con backup automático)
  7) ⚠️  Desinstalar TODAS las Skills (Limpieza total con backup)
  0) 🚪 Salir
```

---

## ⚡ Comandos Directos (Sin `./` y sin menú)

| Acción | Comando Directo |
|---|---|
| **Ver estado de Skills** | `skills status` |
| **Instalar todo** | `skills install` |
| **Actualizar todo** | `skills update` |
| **Desinstalar TODO** | `skills uninstall-all` |
| **Desinstalar una** | `skills uninstall <nombre>` |
| **Simular sin cambios** | `skills dry-run` |
| **Escanear seguridad** | `skills scan` |
| **Ver catálogo** | `skills list` |
| **Ver ayuda rápida** | `skills help` |

---

## 📋 Requisitos del Sistema (Arch Linux)

### 2. Instalación Estándar
Instala la selección curada de 42 Skills en `~/.gemini/antigravity/skills/`:
```bash
bash install-antigravity-skills.sh
# o usando make
make install
```

### 3. Listar Skills Curadas
Consulta el catálogo de Skills organizadas por categoría técnica:
```bash
bash install-antigravity-skills.sh --list
# o usando make
make list
```

### 4. Actualizar Repositorios y Skills
Descarga los últimos commits de los repositorios comunitarios e instala las nuevas versiones actualizadas (realizando backup previo de las versiones reemplazadas):
```bash
bash install-antigravity-skills.sh --update
# o usando make
make update
```

### 5. Escaneo Completo de Seguridad
Audita **todos** los repositorios comunitarios clonados en caché (más de 900 Skills) e informa de cualquier patrón sospechoso o script inseguro:
```bash
bash install-antigravity-skills.sh --security-scan
# o usando make
make scan
```

### 6. Desinstalación Segura

#### Desinstalar una Skill específica:
Desinstala de forma limpia una Skill gestionada por el instalador:
```bash
bash install-antigravity-skills.sh --uninstall playwright-skill
# o usando make
make uninstall SKILL=playwright-skill
```

#### Desinstalar TODAS las Skills gestionadas:
Desinstala de forma masiva todas las Skills comunitarias instaladas, archivando previamente un backup completo y limpiando el manifest:
```bash
bash install-antigravity-skills.sh --uninstall-all
# o usando make
make uninstall-all
```

> [!NOTE]
> El instalador valida siempre el archivo `skills-manifest.txt`. Si intentas desinstalar una Skill que tú creaste localmente o que no proviene de este instalador, la operación se rechazará para proteger tus archivos. Cada desinstalación crea un backup automático en `~/.gemini/antigravity/skills-backups/`.

---

## 📂 Estructura de Directorios

```
~/.gemini/antigravity/
├── skills/                          <-- Skills activas detectadas por Antigravity
│   ├── brainstorming/
│   │   └── SKILL.md
│   ├── playwright-skill/
│   │   ├── SKILL.md
│   │   ├── run.js
│   │   └── package.json
│   ├── semgrep/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   └── scripts/
│   └── ...
├── skills-manifest.txt              <-- Registro de origen, commit y hash SHA-256
├── skills-install-report.md         <-- Reporte detallado de la última ejecución
└── skills-backups/                  <-- Backups con timestamp antes de sobreescribir
    └── 20260916-090000/
        └── <skill-name>/
```

---

## 🌐 Repositorios Comunitarios Integrados

1. **[obra/superpowers](https://github.com/obra/superpowers)**: Repositorio canónico de flujos de trabajo de ingeniería por Jesse Vincent (`brainstorming`, `test-driven-development`, `systematic-debugging`, `using-git-worktrees`, `subagent-driven-development`, etc.).
2. **[lackeyjb/playwright-skill](https://github.com/lackeyjb/playwright-skill)**: Automatización completa de navegador para pruebas E2E interactivas.
3. **[trailofbits/skills](https://github.com/trailofbits/skills)**: Auditoría y seguridad de alta garantía por Trail of Bits (`semgrep`, `codeql`, `sarif-parsing`, `supply-chain-risk-auditor`, `post-patch-validation`).
4. **[Nikoxkx/Agent-Skills](https://github.com/Nikoxkx/Agent-Skills)**: Habilidades especializadas para desarrollo web, pipelines CI/CD y DevOps.
5. **[ForaeFactory/antigravity-skills](https://github.com/ForaeFactory/antigravity-skills)**: Habilidades avanzadas de frontend, WebGL / Three.js 3D, arquitectura de sistemas y diseño UI/UX.
6. **[DavisChang/antigravity-skills](https://github.com/DavisChang/antigravity-skills)**: Auditoría de diseño a código Figma.
7. **[aconture/skills-antigravity](https://github.com/aconture/skills-antigravity)**: Diagramación de arquitectura y framework Spec-Driven Development (SDD) en español.
8. **[itsual/agent-skills-collection](https://github.com/itsual/agent-skills-collection)**: Hardening de APIs y seguridad en el ciclo de vida del software (AppSec).

Para una justificación detallada de cada Skill seleccionada y los duplicados descartados, consulta [skills-selection.md](skills-selection.md).

---

## 🛡️ Política de Seguridad

Este instalador adopta un modelo de **Zero-Trust** respecto a los repositorios comunitarios:
- Nunca ejecuta `sudo`, no altera `/usr`, `/etc` ni instala paquetes del sistema operativo silenciosamente.
- Cada archivo dentro del directorio de la Skill es analizado antes de su despliegue.
- Se bloquean automáticamente habilidades con patrones ofensivos (escalada de privilegios a root local, reverse shells, exfiltración de llaves SSH, descargas piped `curl | bash`).

Para consultar la matriz completa de reglas y las Skills actualmente bloqueadas, consulta [security-policy.md](security-policy.md).

---

## 🔧 Cómo Agregar Nuevos Repositorios o Skills

Para registrar un nuevo repositorio comunitario:
1. Edita el archivo `install-antigravity-skills.sh`.
2. Añade la URL al array `COMMUNITY_REPOS`:
   ```bash
   "nombre_autor__nombre_repo|https://github.com/autor/repo"
   ```
3. Añade las Skills deseadas al array `CURATED_SKILLS`:
   ```bash
   "nombre-skill|nombre_autor__nombre_repo|ruta/relativa|Categoría|Descripción|dependencias"
   ```
4. Ejecuta `bash install-antigravity-skills.sh --dry-run` para validar compatibilidad y seguridad antes de instalar.
