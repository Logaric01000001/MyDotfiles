---
description: "Instala una skill desde GitHub, carpeta o zip con auditoría"
agent: sc-build
---

Instala una skill desde: $ARGUMENTS

1. Identifica el tipo de entrada (repositorio Git, carpeta local, zip, enlace social).
2. Si es un enlace social o un post, localiza el repositorio original con websearch/webfetch. Si no existe un proyecto verificable, dilo y no inventes uno.
3. Ejecuta `sc-kit skill add '<fuente>'` citando siempre la ruta. Si el origen contiene varias skills, repite con `--path <subruta>`.
4. Lee la auditoría. Si hay hallazgos críticos, DETENTE y explícalos; no uses `--force` sin autorización.
5. Verifica con `sc-kit skill info <id>` y `sc-kit skill audit <id>`.
6. Resume: id, origen, ruta, riesgos reales y cómo cargarla (por nombre o `@id`).
