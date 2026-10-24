---
description: "Actualiza una skill desde su origen registrado"
agent: sc-build
---

Actualiza la skill: $ARGUMENTS

1. Ejecuta `sc-kit skill update '<id>'` y muestra el diff de ficheros que propone.
2. Si el usuario no ha autorizado aún, pide confirmación antes de aplicar.
3. Tras actualizar, ejecuta `sc-kit skill audit '<id>'` y `sc-kit skill verify '<id>'`.
