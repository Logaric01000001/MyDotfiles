---
description: "Produce un vídeo horizontal largo"
agent: sc-content
---

Produce un vídeo horizontal: $ARGUMENTS

1. Proyecto en ~/Contenido/<slug> con scenes.json en formato wide.
2. `sc-kit content render <slug> --format wide --dry-run` y ajusta.
3. Renderiza, verifica con `sc-kit content probe` y genera miniatura wide.
4. No inventes demostraciones ni resultados que no existan en assets/.
