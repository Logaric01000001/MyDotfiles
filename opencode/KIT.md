# OpenCode Kit — guía operativa

Sistema instalado y verificado sobre **OpenCode 2.1.3 (arquitectura V2)**.
Fecha de auditoría: 2026-10-23.

---

## 1. Qué se ha cambiado (y qué no)

### Se conserva intacto
- `AGENTS.md` (instrucciones del Segundo Cerebro).
- Las 20 skills globales, incluida **WEBN** (`webn-opt` + 12 referencias).
- Todos los comandos previos (`/webn`, `/webn-master`, `/sc-u-*`, `/memoria`, …).
- El Segundo Cerebro y su configuración.
- `sc-ultimate/` y su lanzador (siguen en disco, sin cambios).

Verificación: **35/35 ficheros** del manifiesto original conservan su SHA-256.
El único cambio respecto al manifiesto es `sc-ultimate/overlay.json`, editado
por el usuario antes de esta auditoría, no por el kit.

### Se añade (sin sobrescribir)
| Elemento | Ruta |
| --- | --- |
| Configuración V2 nativa | `~/.config/opencode/opencode.jsonc` |
| Agentes de perfil | `~/.config/opencode/agents/sc-*.md` |
| Comandos nuevos | `~/.config/opencode/commands/{skill,mcp,content}-*.md` |
| Gestor `sc-kit` | `~/.config/opencode/kit/` + `~/.local/bin/sc-kit` |
| Registro de instalaciones | `~/.config/opencode/registry/` |
| Copias de seguridad | `~/.config/opencode/backups/` |

La configuración anterior está guardada en el primer backup
(`backups/20261023-152134/config-opencode.tar.gz`).

### Hallazgos de la auditoría
- `~/.config/opencode/config.json` es un enlace al Segundo Cerebro, pero **V2 no
  lee ese nombre**: solo `opencode.json(c)`. Se dejó intacto.
- El overlay de `sc-ultimate` **no está activo** al ejecutar `opencode`; solo se
  aplica al lanzar `sc-ultimate`. Ahora los agentes `sc-*` existen globalmente.
- No había ningún MCP configurado.
- El permiso global anterior era `bash: allow` sin restricciones.
- Quedan ~26 GB libres: se descartaron Playwright/Remotion y otros stacks
  pesados. El Content Studio usa FFmpeg + ImageMagick, ya instalados.

---

## 2. Perfiles de modelo

| Perfil | Agente | Modelo | Entrada/Salida USD por 1M* | Pasos |
| --- | --- | --- | --- | --- |
| FAST | `sc-quick` | `opencode-go/deepseek-v4.1-flash#low` | 0.15 / 0.60 | 5 |
| BUILD | `sc-build` (por defecto) | `opencode-go/deepseek-v4.1-flash#high` | 0.15 / 0.60 | 16 |
| DEEP | `sc-deep` | `opencode-go/deepseek-v4-pro#high` | 0.66 / 1.98 | 20 |
| REVIEW | `sc-review` | `opencode-go/glm-5.3#high` | 1.40 / 4.40 | 8 |
| REVIEW RO | `sc-audit` | `opencode-go/glm-5.3#high` | 1.40 / 4.40 | 6 |
| LOCAL | `sc-local` | `ollama/qwen3:4b` | 0 (local) | 6 |
| CONTENT | `sc-content` | `opencode-go/deepseek-v4-pro#high` | 0.66 / 1.98 | 14 |

\* Precios del catálogo del proveedor; las variantes de razonamiento pueden
cambiar el consumo real. No se garantiza ningún ahorro porcentual.

Los agentes de mantenimiento (`title`, `summary`, `compaction`) usan
`opencode-go/claude-haiku-5-5` (0.10 / 0.50) para abaratar llamadas auxiliares.

Cambiar de perfil: selector de agentes de la TUI, o comandos `/sc-u-quick`,
`/sc-u-build`, `/sc-u-deep`, `/sc-u-audit`.

`sc-review` y `sc-audit` no pueden editar ni lanzar subagentes. `sc-local` no
tiene acceso web.

---

## 3. Optimización aplicada

En `opencode.jsonc`:
- `compaction.auto: true`, `keep.tokens: 12000`, `buffer: 20000`.
- `experimental.background_compaction: true` (resumen en segundo plano).
- `tool_output` limitado a 1500 líneas / 40 KB por resultado.
- `watcher.ignore` para `node_modules`, `dist`, `.git`, `out`, bases SQLite, etc.
- `share: "disabled"`.
- Skills bajo demanda (el cuerpo solo se carga al invocar la skill).
- MCP con Code Mode por defecto; solo se instala lo que aporta valor.
- Sin subagentes automáticos: `subagent: ask`.

No se ha medido una reducción porcentual porque no existe una línea base fiable
del mismo trabajo. Lo que sí es verificable: menos resultados gigantes en
contexto, compactación activa y modelos auxiliares baratos.

---

## 4. `sc-kit` — administración

```bash
sc-kit status              # panel general
sc-kit doctor              # diagnóstico con comprobaciones reales
sc-kit models              # agentes y modelos efectivos
sc-kit usage [--days N]    # coste y tokens reales que reporta OpenCode
sc-kit compat              # rutas compartidas con Claude Code / Codex
sc-kit backup              # copia de seguridad
sc-kit backups             # listar copias
sc-kit rollback last       # restaurar (conserva el código del kit)
```

### Skills

```bash
sc-kit skill list
sc-kit skill search <texto>
sc-kit skill info <id>
sc-kit skill add <url|ruta|zip> [--name id] [--scope global|shared|project] [--path subruta]
sc-kit skill add <origen> --yes          # sin preguntas
sc-kit skill disable <id>                # deja de anunciarse, no se borra
sc-kit skill enable <id>
sc-kit skill update <id> [--yes]
sc-kit skill update-all
sc-kit skill verify <id>                 # detecta modificaciones locales
sc-kit skill audit <id>                  # análisis estático
sc-kit skill remove <id>                 # archiva en backups/removed
```

Comportamiento:
- Instala desde Git, carpeta o zip; detecta `SKILL.md` y subrutas.
- Audita antes de instalar y **bloquea** hallazgos críticos.
- Registra origen, commit, fecha, hash y manifiesto de ficheros.
- `disable` mueve a `skills-disabled/` (reversible).
- `remove` archiva; `--purge` borra definitivamente.
- `update` compara origen y detecta también modificaciones locales.

### MCP

```bash
sc-kit mcp list
sc-kit mcp info <nombre>
sc-kit mcp search <texto> [--remote]
sc-kit mcp resolve <url>                       # analiza un repo antes de instalar
sc-kit mcp add <nombre> --url https://…/mcp
sc-kit mcp add <nombre> --package @scope/paquete@1.2.3
sc-kit mcp add <nombre> --python paquete
sc-kit mcp add <nombre> --stdio "comando args"
sc-kit mcp add … --header 'X-API-KEY={env:VAR}' --yes
sc-kit mcp test <nombre>                       # handshake + tools/list reales
sc-kit mcp tools <nombre> [--json]
sc-kit mcp debug <nombre>
sc-kit mcp auth <nombre>                       # instrucciones OAuth
sc-kit mcp enable|disable <nombre>
sc-kit mcp profile list|show|apply|save [perfil]
sc-kit mcp audit [nombre]
sc-kit mcp update [nombre] [--apply]
sc-kit mcp export [fichero] / import <fichero>
sc-kit mcp remove <nombre> [--logout]
```

Perfiles: `minimal`, `web`, `code`, `design`, `content`, `devops`, `security`
y los que guardes con `profile save`.

Detalles comprobados:
- Transportes `stdio` y Streamable HTTP.
- OAuth: el kit **no** ejecuta el flujo interactivo; te indica abrir `/mcps`.
- Los secretos deben ir como `{env:VAR}`; el kit avisa de secretos literales.
- `add` prueba la conexión antes de escribir. Si falla, pregunta.
- Cambiar perfiles o servidores requiere `opencode reload` o reiniciar.

### MCP conectados

| Servidor | Transporte | Auth | Herramientas |
| --- | --- | --- | --- |
| `context7` | HTTP | — | 2 |
| `canva` | HTTP | OAuth | 49 |
| `notion` | HTTP | OAuth | 65 |
| `roblox-studio` | stdio (Wine) | — | 28 |
| `playwright` | stdio (npx) | — | 25 |
| `chrome-devtools` | stdio (npx) | — | 32 |
| `github` | stdio (Docker) | token de `gh` | 47 |
| `serena` | stdio (uv) | — | 3 (REPL con acceso completo) |
| `rea` | stdio (npx fijado 6.7.0) | — | 207 (desactivado por defecto) |

- **Playwright / Chrome DevTools**: usan `/usr/bin/chromium` en modo headless
  aislado. Chrome DevTools oficialmente soporta Chrome; Chromium funciona en
  las pruebas realizadas.
- **GitHub**: `kit/github-mcp.sh` ejecuta el servidor oficial en Docker y toma
  el token de `gh auth token` en cada arranque; el token no se guarda en la
  configuración. Toolsets limitados a `context,repos,issues,pull_requests,actions`.
- **Serena**: modo REPL de Serena 2.x. Las herramientas simbólicas se usan a
  través de `serena_repl`; requiere `activate_project` o `--project-from-cwd`.
- **Roblox Studio**: usa `kit/roblox-studio-mcp.sh`, que resuelve la versión
  instalada en Vinegar y fija `WINEPREFIX`. Requiere Studio abierto, un place
  cargado y “Enable Studio as MCP server” activo. Si `list_roblox_studios`
  devuelve `[]`, Studio no está abierto o el proxy no ha reconectado.
- **REA (Reverse Engineer Anything)**: MCP oficial `rea-agents@6.7.0` con 207
  herramientas. Lanzador `kit/rea-mcp.sh`, que fija los proveedores locales:
  **Ghidra 12.1.2 + JDK 21** (`~/opt`, verificado `healthy`), **JADX headless
  0.7.1** (`~/.local/share/rea/android`, SHA-256 verificado), **jadx CLI 1.5.6**,
  **apktool 3.0.3** y **adb 37.0.1** en `~/.local/bin`. Hopper, IDA y Kuna no
  están instalados (comerciales u opcionales). Incluye la skill
  `reverse-engineer-anything` y un permiso `rea_* = ask` para que cada acción
  pida aprobación. Úsalo solo sobre software propio o con autorización.
- **Perfiles**: `todo` (los 9), `re`, `dev`, `web`, `social`, `roblox`,
  `trabajo`, `diseno`, `juegos`, `minimal`. Aplica con
  `sc-kit mcp profile apply <perfil>`.
- Nueve servidores simultáneos suman ~450 herramientas. Para trabajo real aplica
  un perfil reducido: menos herramientas = mejor selección y menos contexto.

### Contenido

```bash
sc-kit content new <slug> [--format short|wide]
sc-kit content list
sc-kit content render <slug> --dry-run
sc-kit content render <slug> [--format wide] [--no-subs]
sc-kit content subs <slug>
sc-kit content thumb <slug> --format short|wide|carousel --title "…"
sc-kit content carousel <slug> --texts out/slides.md
sc-kit content probe <archivo>
sc-kit content optimize <archivo>
```

Flujo:
1. `content new` crea `~/Contenido/<slug>/{assets,audio,out}` con `scenes.json`,
   `brand.json`, `brief.md`.
2. Coloca imágenes/vídeos en `assets/` y voz/música en `audio/` (`voice.*`,
   `music.*`).
3. Ajusta `scenes.json`: `text`, `duration`, `image`/`video`, `overlay` opcional.
4. Previsualiza con `--dry-run` (no renderiza).
5. Renderiza: H.264/AAC, 1080×1920 o 1920×1080, subtítulos incrustados.

Verificado en este equipo: un vídeo de 9 s a 1080×1920 tardó ~6,5 s y produjo
H.264 + AAC con subtítulos. La miniatura se genera a 1080×1920 (JPG ~300 KB).

El render usa solo recursos locales. No hay TTS ni transcripción automática:
los subtítulos salen del texto de las escenas, no de audio.

---

## 5. Comandos de OpenCode

Hay 36 comandos nuevos además de los existentes:

- `/skill-add`, `/skill-list`, `/skill-search`, `/skill-info`, `/skill-enable`,
  `/skill-disable`, `/skill-update`, `/skill-update-all`, `/skill-remove`,
  `/skill-audit`
- `/mcp-add`, `/mcp-list`, `/mcp-search`, `/mcp-info`, `/mcp-enable`,
  `/mcp-disable`, `/mcp-remove`, `/mcp-update`, `/mcp-test`, `/mcp-debug`,
  `/mcp-auth`, `/mcp-tools`, `/mcp-profile`, `/mcp-audit`, `/mcp-export`,
  `/mcp-import`
- `/content-ideas`, `/content-trends`, `/content-script`, `/content-short`,
  `/content-video`, `/content-thumbnail`, `/content-carousel`,
  `/content-repurpose`, `/content-analyze`, `/content-brand`

Los de solo lectura muestran la salida real del CLI. Los que modifican algo
investigan, ejecutan `sc-kit`, verifican y resumen; no inventan resultados.

---

## 6. Ejemplos reales

### Instalar una skill

```bash
# 1) ver qué contiene el repo antes de instalar
sc-kit skill add https://github.com/usuario/repo --path skills/mi-skill

# 2) instalar una skill concreta
sc-kit skill add https://github.com/usuario/repo --path skills/mi-skill --yes

# 3) comprobar
sc-kit skill info mi-skill
sc-kit skill audit mi-skill
```

Prueba ejecutada: instalación desde carpeta local, zip y repositorio Git;
detección de modificaciones locales; desactivación/reactivación; archivado.
Una skill con `curl … | sh` fue **bloqueada** por la auditoría.

### Instalar un MCP

```bash
sc-kit mcp resolve https://github.com/microsoft/playwright-mcp
sc-kit mcp add playwright --package @playwright/mcp@latest --yes
sc-kit mcp test playwright
sc-kit mcp tools playwright
sc-kit mcp audit playwright
```

Prueba ejecutada con un servidor MCP local propio (ciclo completo: alta,
`tools/list`, llamada real a la herramienta, perfil, export/import, baja) y con
**Context7** remoto por HTTPS (2 herramientas, ~0,9 s).

### Vídeo y miniatura

```bash
sc-kit content new demo --title "Demo"
sc-kit content render demo --dry-run
sc-kit content render demo
sc-kit content thumb demo --title "Demo" --format short
sc-kit content probe demo/out/video.mp4
```

---

## 7. Seguridad

Permisos globales (última regla gana):
- Lectura denegada de `.env`, `.ssh`, `.aws`, `.gnupg` y `auth.json`.
- `sudo`, `mkfs`, `dd of=/dev/*`, apagado/reinicio, `git push --force` y
  borrados de `/` o `~` están denegados.
- Resto del shell permitido para mantener la autonomía.
- Subagentes: preguntar.

El kit:
- No ejecuta scripts de terceros al instalar skills (solo analiza).
- No imprime ni almacena secretos; los enmascara.
- Hace backup antes de cada escritura de configuración.
- No escribe en la configuración de otros agentes sin `sc-kit compat --link`.

Limitación conocida: el escáner de shell puede interpretar como comando un
ejemplo destructivo escrito dentro de un heredoc; en ese caso bloquea la
operación completa. Es una precaución deliberada.

---

## 8. Compatibilidad y mantenimiento

- Skills compartidas: `~/.agents/skills` (OpenCode ya las lee).
- Claude Code solo lee `~/.claude/skills`; si quieres reutilizarlas:
  `sc-kit compat --link` (crea enlaces, no copias).
- Codex/Gemini: reutilizan `AGENTS.md`, no las skills de OpenCode.
- `sc-ultimate` sigue disponible, pero es redundante: `opencode` ya carga los
  agentes `sc-*` y la configuración optimizada.

Rutina recomendada:
```bash
sc-kit doctor          # tras actualizar OpenCode
sc-kit backup          # antes de cambios grandes
sc-kit skill audit     # tras instalar skills externas
sc-kit mcp audit       # tras instalar MCP
sc-kit mcp update      # revisar versiones, aplicar solo tras leer cambios
```

Si algo falla:
```bash
sc-kit mcp debug <nombre>
sc-kit skill verify <id>
sc-kit rollback last --dry-run
sc-kit rollback last
```

---

## 9. Validación ejecutada (2026-10-23)

| Prueba | Resultado |
| --- | --- |
| Configuración V2 válida | `opencode debug config` carga solo `opencode.jsonc` |
| Agentes | 7 agentes `sc-*` visibles, con modelo y variante correctos |
| Comandos | 36 comandos nuevos registrados en `/api/command` |
| Skills | 20 globales + 5 compartidas detectadas, sin duplicados |
| Alta de skill (carpeta, zip, Git local) | correcta, con hash y manifiesto |
| Skill peligrosa (`curl … \| sh`) | bloqueada por auditoría (exit 1) |
| Deriva local de skill | detectada y reparada desde el origen |
| Desactivar/reactivar/archivar | correcto y reversible |
| MCP local (stdio) | conexión, `tools/list`, llamada real `echo` |
| MCP remoto (Context7) | conexión HTTPS, 2 herramientas, consulta real |
| Perfil MCP | `web` aplicado; desactivación y reactivación correctas |
| Export/import MCP | ida y vuelta correcta |
| Backup/rollback | restauración verificada; el código del kit se conserva |
| Content Studio | vídeo 1080×1920 de 9 s, H.264+AAC, subtítulos, miniaturas y carrusel |
| `sc-kit usage` | coste y tokens reales del proveedor |

Nota: la auditoría marca un hallazgo crítico en la skill `gepeto`
(`~/.agents/skills`). Es una línea de documentación sobre instaladores `bash`,
no un script ejecutado. No se ha modificado esa skill.

Nota de entorno: el disco estaba al 98 % al terminar (≈15 GB libres). No lo
causó el kit (sus datos ocupan ~10 MB); conviene revisar `~/.cache/paru`.

---

## 10. Limitaciones honestas

- OAuth de MCP remotos exige interacción en `/mcps`.
- No existe un tope de gasto local fiable: `sc-kit usage` informa, pero no
  bloquea. Para límites duros hay que usar los presupuestos del Console del
  proveedor. El kit no simula bloqueos que no puede garantizar.
- El catálogo de `mcp search` son sugerencias; `add` comprueba la conexión real.
- No se instalan navegadores de Playwright ni Remotion por espacio en disco.
- No hay transcripción de audio a subtítulos (falta Whisper); se puede añadir
  después sin tocar el resto.
- El render es CPU: vídeos largos tardan proporcionalmente más.
- Los precios mostrados son del catálogo, no una factura.
