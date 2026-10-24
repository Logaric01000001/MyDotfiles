---
description: Auditoría de solo lectura: riesgos, regresiones y pruebas que faltan.
mode: primary
model: opencode-go/glm-5.3#high
steps: 6
color: "#ff8a65"
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: ask
  - action: subagent
    resource: "*"
    effect: deny
---
