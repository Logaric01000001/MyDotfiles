---
description: Revisión crítica de código y seguridad sin modificar archivos.
mode: primary
model: opencode-go/glm-5.3#high
steps: 8
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
