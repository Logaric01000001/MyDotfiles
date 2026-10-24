---
description: "Produce un vídeo vertical (TikTok/Reels/Shorts)"
agent: sc-content
---

Produce un short vertical: $ARGUMENTS

1. Localiza o crea el proyecto (~/Contenido/<slug>).
2. Revisa assets/ y audio/. Ajusta scenes.json si hace falta.
3. Ejecuta `sc-kit content render <slug> --dry-run` y corrige el plan.
4. Renderiza con `sc-kit content render <slug>`.
5. Verifica con `sc-kit content probe <slug>/out/video.mp4`.
6. Genera miniatura con `sc-kit content thumb <slug> --format short`.
7. Indica qué falta (voz, música, grabaciones) sin inventar material.
