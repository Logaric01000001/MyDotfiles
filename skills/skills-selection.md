# Catálogo y Matriz de Selección de Agent Skills para Antigravity IDE

Este documento detalla la justificación técnica, origen, dependencias y resolución de duplicados para las **42 Agent Skills** comunitarias seleccionadas e integradas en el instalador.

---

## 1. Criterios de Selección

Para garantizar un entorno de desarrollo profesional, mantenible y libre de sobrecarga contextual, la selección de Skills se rige por:

1. **Relevancia Profesional**: Orientadas a ingeniería de software rigurosa, desarrollo web moderno, gráficos interactivos, calidad, seguridad defensiva y DevOps en Linux.
2. **Autoridad y Mantenimiento Upstream**: Preferencia estricta por los repositorios originales (canónicos) en lugar de copias o reempaquetados de terceros.
3. **Formato Estándar Agent Skills**: Validación obligatoria de `SKILL.md` con frontmatter YAML que especifique `name` y `description`.
4. **Ausencia de Riesgos**: Exclusión total de comandos destructivos, descargas remotas no controladas y técnicas de explotación hostil.
5. **Deduplicación Estricta**: Una sola Skill canónica para cada función específica.

---

## 2. Matriz de Skills Seleccionadas (42 en Total)

### A. Core Software Engineering (12 Skills)

| Skill | Repositorio Origen | Ruta Origen | Propósito y Justificación | Dependencias |
|---|---|---|---|---|
| `brainstorming` | `obra/superpowers` | `skills/brainstorming` | Flujo disciplinado de exploración y refinamiento previo a cualquier diseño de funcionalidad. | Ninguna |
| `writing-plans` | `obra/superpowers` | `skills/writing-plans` | Redacción de planes de implementación paso a paso testeables y con granularidad adecuada. | Ninguna |
| `executing-plans` | `obra/superpowers` | `skills/executing-plans` | Ejecución metódica de planes con registro de progreso y puntos de revisión. | Ninguna |
| `systematic-debugging` | `obra/superpowers` | `skills/systematic-debugging` | Proceso estructurado de 4 fases para aislar y resolver la causa raíz sin conjeturas. | Ninguna |
| `test-driven-development` | `obra/superpowers` | `skills/test-driven-development` | Ciclo riguroso red-green-refactor para desarrollo guiado por pruebas. | Ninguna |
| `requesting-code-review` | `obra/superpowers` | `skills/requesting-code-review` | Protocolo para preparar cambios y someterlos a revisión técnica. | `git` |
| `receiving-code-review` | `obra/superpowers` | `skills/receiving-code-review` | Protocolo para procesar sugerencias de revisión sin aceptar cambios apresurados. | Ninguna |
| `subagent-driven-development` | `obra/superpowers` | `skills/subagent-driven-development` | Orquestación coordinada de subagentes en tareas desacopladas. | Ninguna |
| `using-git-worktrees` | `obra/superpowers` | `skills/using-git-worktrees` | Aislamiento de ramas en carpetas independientes mediante Git Worktrees. | `git` |
| `finishing-a-development-branch` | `obra/superpowers` | `skills/finishing-a-development-branch` | Verificación final de tests, limpieza de historial y preparación de merge. | `git` |
| `verification-before-completion` | `obra/superpowers` | `skills/verification-before-completion` | Validación explícita y automatizada antes de reportar una tarea como completada. | Ninguna |
| `senior-architect` | `ForaeFactory` | `skills/senior-architect` | Principios de diseño de arquitectura modular, desacoplamiento y escalabilidad. | Ninguna |

---

### B. Web Development (3 Skills)

| Skill | Repositorio Origen | Ruta Origen | Propósito y Justificación | Dependencias |
|---|---|---|---|---|
| `senior-fullstack` | `ForaeFactory` | `skills/senior-fullstack` | Arquitectura fullstack moderna en TypeScript, React, Next.js, APIs y base de datos. | Node.js, npm/pnpm |
| `react-ui-patterns` | `ForaeFactory` | `skills/react-ui-patterns` | Patrones avanzados para carga diferida, gestión de errores (error boundaries) y hooks reactivos. | Node.js |
| `api-wrapper-builder` | `Nikoxkx` | `skills/ai-ml/api-wrapper-builder` | Generación de SDKs y clientes tipados limpios para APIs REST y GraphQL. | Python / Node.js |

---

### C. UI/UX & Design Systems (3 Skills)

| Skill | Repositorio Origen | Ruta Origen | Propósito y Justificación | Dependencias |
|---|---|---|---|---|
| `ui-ux-pro-max` | `ForaeFactory` | `skills/ui-ux-pro-max` | Inteligencia de diseño integral: 50 estilos estéticos, 21 paletas cromáticas armónicas y tokens. | Ninguna |
| `figma-readiness-audit` | `DavisChang` | `.agent/skills/figma-readiness-audit` | Auditoría de componentes y variables en Figma previa a la codificación en frontend. | Ninguna |
| `canvas-design` | `ForaeFactory` | `skills/canvas-design` | Gráficos vectoriales e interactivos con Canvas HTML5 sin dependencias pesadas. | Ninguna |

---

### D. Web Experience & 3D (1 Skill)

| Skill | Repositorio Origen | Ruta Origen | Propósito y Justificación | Dependencias |
|---|---|---|---|---|
| `3d-web-experience` | `ForaeFactory` | `skills/3d-web-experience` | Experiencias inmersivas 3D, WebGL, shaders, React Three Fiber y Three.js. | Node.js, Three.js |

---

### E. Quality Assurance & Testing (4 Skills)

| Skill | Repositorio Origen | Ruta Origen | Propósito y Justificación | Dependencias |
|---|---|---|---|---|
| `playwright-skill` | `lackeyjb` | `skills/playwright-skill` | Automatización de navegador para pruebas End-to-End, capturas y aserciones en vivo. | Node.js, Playwright |
| `performance-profiling` | `ForaeFactory` | `skills/performance-profiling` | Auditoría de Core Web Vitals, scripts de Lighthouse y optimización de carga. | Python 3 |
| `accessibility-auditor` | `Nikoxkx` | `skills/web-development/accessibility-auditor` | Evaluación de conformidad WCAG 2.1 AA, navegación asistida y roles ARIA. | Ninguna |
| `seo-optimizer` | `Nikoxkx` | `skills/web-development/seo-optimizer` | SEO técnico: metadatos Open Graph, marcado estructurado JSON-LD y sitemaps. | Ninguna |

---

### F. Security & Auditing (9 Skills)

| Skill | Repositorio Origen | Ruta Origen | Propósito y Justificación | Dependencias |
|---|---|---|---|---|
| `semgrep` | `trailofbits` | `plugins/static-analysis/skills/semgrep` | Análisis estático de código fuente con el catálogo de reglas de Trail of Bits. | Semgrep CLI, Python 3 |
| `codeql` | `trailofbits` | `plugins/static-analysis/skills/codeql` | Consultas CodeQL de seguimiento de flujo de datos y sanitización de fuentes inseguras. | CodeQL CLI |
| `sarif-parsing` | `trailofbits` | `plugins/static-analysis/skills/sarif-parsing` | Agregación, descarte de falsos positivos y triaje de reportes en formato SARIF. | Python 3 |
| `supply-chain-risk-auditor` | `trailofbits` | `plugins/supply-chain-risk-auditor/skills/supply-chain-risk-auditor` | Análisis de riesgos en dependencias directas y transitivas de árboles de paquetes. | Python 3 |
| `audit-context-building` | `trailofbits` | `plugins/audit-context-building/skills/audit-context-building` | Mapeo de supuestos y límites de confianza antes de la búsqueda de vulnerabilidades. | Ninguna |
| `post-patch-validation` | `trailofbits` | `plugins/post-patch-validation/skills/post-patch-validation` | Validación sistemática de que un parche de seguridad no introduce regresiones. | Python 3 |
| `vulnerability-scanner` | `Nikoxkx` | `skills/security/vulnerability-scanner` | Escaneo automatizado de vulnerabilidades en dependencias y artefactos de software. | Trivy / npm audit |
| `api-security` | `itsual` | `skills/cybersecurity/api-security` | Hardening de endpoints, autenticación robusta y defensas contra OWASP API Top 10. | Ninguna |
| `application-security` | `itsual` | `skills/cybersecurity/application-security` | Integración de seguridad en el ciclo SDLC y modelado defensivo de amenazas. | Ninguna |

---

### G. DevOps & Infrastructure (5 Skills)

| Skill | Repositorio Origen | Ruta Origen | Propósito y Justificación | Dependencias |
|---|---|---|---|---|
| `bash-linux` | `ForaeFactory` | `skills/bash-linux` | Prácticas idiomáticas de shell, control de pipes, traps y scripts robustos en Linux. | Bash |
| `docker-expert` | `ForaeFactory` | `skills/docker-expert` | Contenedorización segura, builds multi-etapa y reducción de superficie de ataque. | Docker |
| `docker-compose-generator` | `Nikoxkx` | `skills/devops/docker-compose-generator` | Creación de entornos multi-contenedor reproducibles con redes y volúmenes aislados. | docker-compose |
| `github-actions-pipeline` | `Nikoxkx` | `skills/devops/github-actions-pipeline` | Pipelines CI/CD reproducibles con etapas de lint, test, build y release. | Ninguna |
| `vercel-deployment` | `ForaeFactory` | `skills/vercel-deployment` | Despliegue de aplicaciones frontend modernas en entornos serverless. | Vercel CLI |

---

### H. Research & Spec-Driven Development (5 Skills)

| Skill | Repositorio Origen | Ruta Origen | Propósito y Justificación | Dependencias |
|---|---|---|---|---|
| `architecture-diagram` | `aconture` | `Skills no-SDD/.agent/skills/architecture-diagram` | Generación de diagramas de arquitectura SVG/HTML interactivos con tema oscuro. | Ninguna |
| `sdd-explore` | `aconture` | `Esquema SDD/skills/sdd-explore` | Fase exploratoria previa a la definición de requerimientos técnicos. | Ninguna |
| `sdd-spec` | `aconture` | `Esquema SDD/skills/sdd-spec` | Redacción de especificaciones de cambio y escenarios de prueba asociados. | Ninguna |
| `sdd-verify` | `aconture` | `Esquema SDD/skills/sdd-verify` | Verificación sistemática del código final frente a las especificaciones aprobadas. | Ninguna |
| `defuddle` | `aconture` | `Skills no-SDD/.agent/skills/obsidian-defuddle` | Extracción y limpieza de artículos y documentación web en Markdown legible. | Defuddle CLI |

---

## 3. Resolución de Conflictos y Duplicados

Se identificaron 27 colisiones de nombres entre los repositorios comunitarios. Las decisiones de descarte fueron:

1. **Workflows de Jesse Vincent (`superpowers`) vs `ForaeFactory`**:
   - `ForaeFactory` clonó directamente las habilidades de `superpowers` (`brainstorming`, `writing-plans`, `executing-plans`, `systematic-debugging`, `test-driven-development`, etc.).
   - **Decisión**: Conservar `obra/superpowers` (upstream canónico, mantenido activamente con tests unitarios). Descartar las copias en `ForaeFactory`.
2. **`playwright-skill` (`lackeyjb` vs `ForaeFactory`)**:
   - `lackeyjb/playwright-skill` es el repositorio original que incluye los scripts auxiliares `run.js` y `lib/helpers.js`.
   - **Decisión**: Conservar `lackeyjb/playwright-skill`. Descartar el fork incompleto.
3. **`vulnerability-scanner` (`Nikoxkx` vs `ForaeFactory`)**:
   - La versión de `Nikoxkx` está organizada por categorías y optimizada para modelos tipo Gemini/Claude con triggers claros.
   - **Decisión**: Conservar la versión de `Nikoxkx`.
4. **`skill-creator` (`aconture` vs `itsual` vs `ForaeFactory`)**:
   - La versión de `aconture` está específicamente validada para el árbol de Antigravity IDE y el estricto cumplimiento de frontmatter YAML.
   - **Decisión**: Conservar la implementación de `aconture`.
