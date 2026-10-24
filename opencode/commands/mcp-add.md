---
description: "Instala y verifica un servidor MCP de forma segura"
agent: sc-build
---

Instala un servidor MCP desde: $ARGUMENTS

1. Identifica el origen real (GitHub, npm/PyPI, endpoint remoto, documentación). Usa `sc-kit mcp resolve '<url>'` cuando sea un repositorio.
2. Comprueba transporte, autenticación, permisos y actividad del proyecto. No asumas compatibilidad.
3. Elige un nombre corto y ejecuta la variante correcta:
   - remoto: `sc-kit mcp add <nombre> --url <url>`
   - npm: `sc-kit mcp add <nombre> --package paquete@version`
   - Python: `sc-kit mcp add <nombre> --python paquete`
   - comando local: `sc-kit mcp add <nombre> --stdio "cmd args"`
4. Nunca escribas secretos en claro: usa `--header 'X={env:VAR}'` o `--env KEY={env:VAR}`.
5. sc-kit prueba la conexión antes de guardar. Si falla, diagnóstica con `sc-kit mcp debug <nombre>`; no fuerces.
6. Tras instalar: `sc-kit mcp test <nombre>`, `sc-kit mcp tools <nombre>`, `sc-kit mcp audit <nombre>`.
7. Si corresponde, aplica un perfil: `sc-kit mcp profile apply <perfil>`.
8. Resume herramientas reales, estado y cómo usarlo. Recuerda que OpenCode debe recargar la configuración.
