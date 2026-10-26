# opencode-gaslight (port a OpenCode V2)

Edita una respuesta del asistente para que **las peticiones futuras al modelo** vean la versión
corregida. El historial persistido (la base de datos y lo que muestra el TUI) no se modifica.

Es un port local del plugin `opencode-gaslight` de Adam Kadaban, que solo funciona en OpenCode V1:
en V2 la API de plugins cambió y desapareció el endpoint `part.update` que usaba el original.

## Cómo funciona

| Pieza | Archivo | Rol |
| --- | --- | --- |
| Plugin de servidor | `index.ts` | Registra el hook `ctx.session.hook("context" / "compaction" / "generate")` y reescribe las partes `text` / `reasoning` de los mensajes del asistente justo antes de enviar el transcript al modelo. Guarda las ediciones en `ctx.storage` (persistente, por sesión). |
| RPC | `rpc.ts` | Métodos `gaslight.list`, `gaslight.set`, `gaslight.clear` para que el TUI lea y escriba las ediciones. |
| Plugin de TUI | `tui.tsx` | Comando `/gaslight`: elige una respuesta de la sesión, edita texto y/o thinking, guarda. |

Las ediciones se guardan en el storage del plugin en el servidor, así que sobreviven reinicios y
funcionan también con servidores remotos (el TUI solo habla por RPC).

## Uso

En una sesión con al menos una respuesta del asistente:

```
/gaslight
```

- Se abre un selector con las respuestas (la más reciente primero). `Response #N` es la posición
  real del mensaje en la sesión; `✎` indica que ya tiene una edición.
- `ctrl+d` quita la edición de la respuesta seleccionada. `ctrl+r` borra todas las ediciones de la sesión.
- En el editor: `Tab` alterna Response / Thinking, `ctrl+s` guarda, `Esc` cancela.

Después de guardar, el modelo "recuerda" la versión editada, pero el TUI sigue mostrando la original.

## Configuración

Está activado en dos archivos:

`~/.config/opencode/opencode.jsonc`
```jsonc
"plugins": ["~/.config/opencode/plugins/gaslight"]
```

`~/.config/opencode/cli.json`
```json
"plugins": ["~/.config/opencode/plugins/gaslight"]
```

Copia de seguridad de ambos antes del cambio: `~/.config/opencode/backups/*.pre-gaslight`.

Para desactivarlo, elimina la entrada `plugins` de esos dos archivos (o solo la de `cli.json` si
quieres conservar las ediciones ya guardadas sin el comando).

## Tipos / desarrollo

`@opencode/plugin` se resuelve en runtime desde OpenCode, así que el plugin no necesita
`node_modules` para funcionar. Para comprobar tipos:

```sh
cd ~/.config/opencode/plugins/gaslight
npm install --no-save @opencode/plugin@2.1.4 @opencode/client@2.1.4 solid-js @opentui/core @opentui/solid typescript
npx tsc -p tsconfig.json
rm -rf node_modules package-lock.json
```

Los cambios en `index.ts`, `rpc.ts` o `tui.tsx` recargan el plugin en caliente; el comando `/gaslight`
requiere reiniciar el TUI porque los comandos se registran al arrancar.

## Limitaciones

- Solo reescribe partes `text` y `reasoning` de mensajes del asistente; las llamadas a herramientas
  no se tocan.
- Las ediciones son por sesión y por `messageID`; si una sesión se compacta o bifurca, las ediciones
  siguen aplicando a los mensajes que conserven su ID.
- El original está pensado para investigación de seguridad (vencer el "refusal momentum"). Al revertir
  la respuesta de un modelo puedes estar saltándote sus propios criterios: úsalo en trabajo autorizado.
