# Política de Seguridad y Reglas de Auditoría Contextual

El instalador de Agent Skills de Antigravity aplica un modelo de **Zero-Trust** frente al ecosistema comunitario, tratando las Skills descargadas como código y documentación potencialmente no confiables.

---

## 1. Principios de Seguridad

1. **Aislamiento en Espacio de Usuario**: El instalador jamás invoca `sudo`, no escribe en directorios del sistema operativo (`/usr`, `/etc`, `/var`), ni altera el gestor de paquetes de Arch Linux (`pacman`).
2. **Evaluación Estática Previa a la Instalación**: Cada Skill candidata es inspeccionada en su totalidad (archivo `SKILL.md` y cualquier script o archivo complementario) antes de copiar ningún archivo al directorio de Antigravity.
3. **Análisis Contextual Razonable**: No se penalizan herramientas de desarrollo legítimas (como comandos `curl` documentados para APIs o invocaciones de `rm` dentro de subdirectorios de trabajo del proyecto). Se evalúa la estructura de comando completa y el objetivo de ejecución.
4. **Bloqueo Inmediato**: Si se detecta un patrón malicioso o de alto riesgo, la Skill se marca con `[BLOCKED]`, se rechaza su despliegue y se registra en el reporte de auditoría.

---

## 2. Vectores de Amenaza Auditados

### A. Ejecución Remota Piped No Verificada (`curl | bash`)
- **Riesgo**: Descarga e inyección directa en el intérprete de comandos de scripts remotos sin verificación criptográfica ni control de integridad.
- **Regla**:
  ```bash
  (curl|wget)[^|\n]+?\| *(sudo *)?(ba)?sh\b
  ```
- **Acción**: Bloqueo preventivo. Se exige que cualquier herramienta sea instalada a través de vías verificables o dependencias explícitas.

### B. Borrado Destructivo de Archivos del Sistema
- **Riesgo**: Eliminación accidental o malintencionada de la raíz del sistema o directorios clave del usuario.
- **Regla**:
  ```bash
  rm +-(rf|fr|r +-f) +(/( *$|\*)|~/? *$|\$HOME/? *|/(etc|usr|bin|sbin|boot|lib)\b)
  ```
- **Acción**: Bloqueo absoluto.

### C. Escalamiento Ofensivo de Privilegios Local (Root Exploits)
- **Riesgo**: Instrucciones orientadas a vulnerar el host local, buscar binarios SUID indebidos, explotar vulnerabilidades de kernel (`dirty cow`) o elevar privilegios a `root`.
- **Regla**:
  ```bash
  privilege[ -]escalation|get root access|find +/ +-perm +-4000|dirty[ -]?cow|linpeas\.sh
  ```
- **Distinción Contextual**: Habilidades defensivas de auditoría (por ejemplo, las emitidas por Trail of Bits para analizar código C/Rust) no son bloqueadas si su enfoque es puramente análisis de código fuente.

### D. Exfiltración y Manipulación de Credenciales SSH
- **Riesgo**: Búsqueda o lectura indebida de llaves privadas (`id_rsa`, `id_ed25519`) o inyección no supervisada de llaves públicas en `~/.ssh/authorized_keys`.
- **Regla**:
  ```bash
  (cat|grep|cp|curl|nc|base64) +.*(~?/\.ssh/id_[a-z0-9]+|\.ssh/authorized_keys)
  ```
- **Acción**: Bloqueo si no corresponde a una invocación legítima de `ssh-keygen`.

### E. Conexiones Interactivas Ocultas (Reverse Shells)
- **Riesgo**: Establecimiento de conexiones remotas directas hacia direcciones IP externas a través de `netcat` o descriptores `/dev/tcp/`.
- **Regla**:
  ```bash
  (nc|netcat|ncat) +-[ecl].*(sh|bash)|/dev/tcp/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+
  ```
- **Acción**: Bloqueo inmediato.

### F. Persistencia en Archivos de Configuración del Shell
- **Riesgo**: Inyección de payloads persistentes en `~/.bashrc`, `~/.zshrc` o `~/.profile`.
- **Regla**:
  ```bash
  (echo|printf) +.*>> *~?/\.(bashrc|zshrc|profile|bash_profile)
  ```
- **Acción**: Bloqueo si incluye decodificación en base64, `eval` o llamadas a red.

---

## 3. Registro de Skills Bloqueadas por Seguridad

Durante la auditoría global de los 8 repositorios analizados (924 Skills en total), el motor de seguridad identificó y bloqueó 11 Skills que infringían las políticas de protección del anfitrión:

| Skill Bloqueada | Repositorio | Amenaza Detectada |
|---|---|---|
| `linux-privilege-escalation` | `ForaeFactory` | Procedimientos ofensivos de escalada a root local y reverse shell. |
| `privilege-escalation-methods` | `ForaeFactory` | Explotación de permisos SUID y payload ofensivo de escalamiento. |
| `windows-privilege-escalation` | `ForaeFactory` | Vectores ofensivos de elevación de privilegios en el sistema. |
| `ssh-penetration-testing` | `ForaeFactory` | Patrones de extracción y recolección de llaves privadas SSH. |
| `cloud-penetration-testing` | `ForaeFactory` | Descarga de scripts remotos sin verificación (`curl \| bash`). |
| `ethical-hacking-methodology` | `ForaeFactory` | Procedimientos ofensivos de intrusión sobre el sistema anfitrión. |
| `skill-security-auditor` | `DavisChang` | Patrones de scripts piped remotos y reverse shells interactivos. |
| `security-defense` | `DavisChang` | Procedimientos de escalamiento ofensivo de privilegios. |
| `sharp-edges` | `trailofbits` | Eliminación destructiva dirigida a directorios raíz/sistema. |
| `libafl` | `trailofbits` | Script de instalación piped a shell sin verificación de integridad. |
| `agentic-actions-auditor` | `trailofbits` | Descarga remota directa sin control de integridad. |

---

## 4. Ejecución del Escáner de Seguridad

Puedes auditar de manera independiente todas las Skills descargadas en tu máquina ejecutando:
```bash
bash install-antigravity-skills.sh --security-scan
```
o bien:
```bash
make scan
```
El escáner recorrerá la totalidad de repositorios en `~/.cache/antigravity-skills-installer/repos/` y generará un informe de Skills conformes y no conformes.
