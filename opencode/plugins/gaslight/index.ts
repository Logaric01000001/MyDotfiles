import { Plugin } from "@opencode/plugin"
import { Gaslight } from "./rpc.js"

/**
 * Rewrites assistant text/reasoning parts in the transcript OpenCode sends to
 * the model. Persisted history is never touched, so the correction applies to
 * every future request in the session without mutating the database.
 */

type Override = {
  text?: string
  reasoning?: string
  updated: number
}

type SessionOverrides = Record<string, Override>

type ContentPart = { type: string; text?: string }
type MutableMessage = { id?: string; role: string; content: ContentPart[] }

const storageKey = (sessionID: string) => `session:${sessionID}`

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function sanitizeEntry(value: unknown): Override | undefined {
  if (!isRecord(value)) return undefined
  const entry: Override = { updated: typeof value.updated === "number" ? value.updated : 0 }
  if (typeof value.text === "string") entry.text = value.text
  if (typeof value.reasoning === "string") entry.reasoning = value.reasoning
  if (entry.text === undefined && entry.reasoning === undefined) return undefined
  return entry
}

function sanitize(raw: unknown): SessionOverrides {
  if (!isRecord(raw)) return {}
  const result: SessionOverrides = {}
  for (const [messageID, value] of Object.entries(raw)) {
    const entry = sanitizeEntry(value)
    if (entry) result[messageID] = entry
  }
  return result
}

function applyPart(message: MutableMessage, type: "text" | "reasoning", text: string) {
  const parts = message.content.filter((part) => part.type === type)
  if (parts.length === 0) return
  parts[0].text = text
  for (const part of parts.slice(1)) part.text = ""
}

function applyOverride(message: MutableMessage, override: Override) {
  if (typeof override.text === "string") applyPart(message, "text", override.text)
  if (typeof override.reasoning === "string") applyPart(message, "reasoning", override.reasoning)
}

/** RPC outputs are validated against the declared JSON Schema, so absent fields must not be sent as undefined. */
function toWire(messageID: string, entry: Override | undefined) {
  return {
    messageID,
    ...(typeof entry?.text === "string" ? { text: entry.text } : {}),
    ...(typeof entry?.reasoning === "string" ? { reasoning: entry.reasoning } : {}),
    updated: entry?.updated ?? 0,
  }
}

const plugin = Plugin.define({
  id: "gaslight.server",
  async setup(ctx) {
    // No in-process cache: the TUI and the server that runs the model hook can be
    // different processes, so every request reads the shared durable store.
    const read = async (sessionID: string): Promise<SessionOverrides> =>
      sanitize(await ctx.storage.get(storageKey(sessionID)))

    async function write(sessionID: string, value: SessionOverrides) {
      if (Object.keys(value).length === 0) await ctx.storage.remove(storageKey(sessionID))
      else await ctx.storage.set(storageKey(sessionID), value)
    }

    await ctx.rpc.register(Gaslight, {
      list: async (input) => {
        const { sessionID } = input as { sessionID: string }
        const overrides = await read(sessionID)
        return {
          overrides: Object.entries(overrides).map(([messageID, entry]) => toWire(messageID, entry)),
        }
      },
      set: async (input) => {
        const { sessionID, messageID, text, reasoning } = input as {
          sessionID: string
          messageID: string
          text?: string
          reasoning?: string
        }
        const overrides = { ...(await read(sessionID)) }
        const entry: Override = { updated: Date.now() }
        if (typeof text === "string") entry.text = text
        if (typeof reasoning === "string") entry.reasoning = reasoning
        if (entry.text === undefined && entry.reasoning === undefined) delete overrides[messageID]
        else overrides[messageID] = entry
        await write(sessionID, overrides)
        return toWire(messageID, overrides[messageID])
      },
      clear: async (input) => {
        const { sessionID, messageID } = input as { sessionID: string; messageID?: string }
        const overrides = { ...(await read(sessionID)) }
        if (messageID === undefined) {
          const removed = Object.keys(overrides).length
          await write(sessionID, {})
          return { removed }
        }
        const removed = messageID in overrides ? 1 : 0
        delete overrides[messageID]
        await write(sessionID, overrides)
        return { removed }
      },
    })

    const rewrite = async (event: { sessionID: string; messages: readonly unknown[] }) => {
      const overrides = await read(event.sessionID)
      if (Object.keys(overrides).length === 0) return
      for (const candidate of event.messages) {
        const message = candidate as MutableMessage
        if (message.role !== "assistant" || typeof message.id !== "string") continue
        const override = overrides[message.id]
        if (!override) continue
        applyOverride(message, override)
      }
    }

    const hooks = await Promise.all([
      ctx.session.hook("context", rewrite),
      ctx.session.hook("compaction", rewrite),
      ctx.session.hook("generate", rewrite),
    ])

    return async () => {
      for (const hook of hooks) await hook.dispose()
    }
  },
})

export default plugin
