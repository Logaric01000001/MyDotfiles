import { Plugin } from "@opencode/plugin"

/**
 * Reconnects MCP servers that fail to come up during startup.
 *
 * Background: a remote server can answer the startup handshake with a transient
 * conflict (for example Canva returning HTTP 409 {"code":10} right after an
 * OAuth token refresh). OpenCode treats that as a hard failure and keeps the
 * server marked `failed` for the whole session, so its tools disappear until
 * the user reconnects it by hand from /mcps.
 *
 * This plugin watches `mcp.status.changed`, and if a configured server settles
 * as `failed` it disables and re-enables that server through an MCP transform
 * (which forces a clean reconnect), with exponential backoff and jitter.
 */

const DEFAULTS = {
  servers: ["canva"] as string[],
  maxAttempts: 5,
  baseDelayMs: 2_000,
  maxDelayMs: 60_000,
  settleTimeoutMs: 25_000,
  pollIntervalMs: 30_000,
}

type Status = { status: string; error?: string }

// A location can load the same plugin more than once (server reloads, multiple
// plugin hosts in one process). Only one retry loop per location may run, or the
// loops would fight over the same MCP server.
const active = ((globalThis as any).__opencodeMcpRetryActive ??= new Set<string>())

export default Plugin.define({
  id: "mcp-retry",
  async setup(ctx) {
    const location = (ctx as any).location?.directory ?? "default"
    if (active.has(location)) return
    active.add(location)

    const options = (ctx.options ?? {}) as Partial<typeof DEFAULTS>
    const servers = Array.isArray(options.servers) && options.servers.length > 0 ? options.servers : DEFAULTS.servers
    const maxAttempts = options.maxAttempts ?? DEFAULTS.maxAttempts
    const baseDelayMs = options.baseDelayMs ?? DEFAULTS.baseDelayMs
    const maxDelayMs = options.maxDelayMs ?? DEFAULTS.maxDelayMs
    const settleTimeoutMs = options.settleTimeoutMs ?? DEFAULTS.settleTimeoutMs
    const pollIntervalMs = options.pollIntervalMs ?? DEFAULTS.pollIntervalMs

    const abort = new AbortController()
    const attempts = new Map<string, number>()
    const timers = new Map<string, ReturnType<typeof setTimeout>>()
    const inflight = new Set<string>()
    const exhausted = new Set<string>()

    const log = (message: string) => console.log(`[mcp-retry] ${message}`)
    const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

    const statusOf = async (name: string): Promise<Status | undefined> => {
      try {
        const result = (await ctx.mcp.list()) as any
        const list: any[] = Array.isArray(result) ? result : (result?.data ?? [])
        return list.find((server) => server?.name === name)?.status
      } catch (error) {
        log(`could not read MCP status: ${error instanceof Error ? error.message : String(error)}`)
        return undefined
      }
    }

    const schedule = (name: string, delay: number) => {
      if (abort.signal.aborted) return
      const previous = timers.get(name)
      if (previous) clearTimeout(previous)
      // Jitter keeps two OpenCode locations from retrying the same endpoint at once.
      const wait = delay + Math.floor(Math.random() * 1_500)
      const timer = setTimeout(() => {
        timers.delete(name)
        void attempt(name)
      }, wait)
      timer.unref?.()
      timers.set(name, timer)
    }

    const waitForSettled = async (name: string) => {
      const deadline = Date.now() + settleTimeoutMs
      while (Date.now() < deadline && !abort.signal.aborted) {
        const status = await statusOf(name)
        if (status && status.status !== "pending") return status
        await sleep(500)
      }
      return statusOf(name)
    }

    const attempt = async (name: string) => {
      if (abort.signal.aborted || inflight.has(name)) return
      const status = await statusOf(name)
      if (!status || status.status === "connected") {
        attempts.delete(name)
        exhausted.delete(name)
        return
      }
      if (status.status !== "failed") return

      const count = (attempts.get(name) ?? 0) + 1
      if (count > maxAttempts) {
        if (!exhausted.has(name)) {
          exhausted.add(name)
          log(`${name}: still failing after ${maxAttempts} attempts (${status.error ?? "unknown error"}); waiting for a manual reconnect`)
        }
        return
      }
      attempts.set(name, count)
      inflight.add(name)
      try {
        log(`${name}: reconnecting (attempt ${count}/${maxAttempts}) after: ${status.error ?? "unknown error"}`)
        const registration = await ctx.mcp.transform((editor) => {
          editor.update(name, (server) => {
            server.disabled = true
          })
        })
        // Give the disconnect a moment, then re-enable by dropping the transform.
        await sleep(400)
        await registration.dispose()
        const settled = await waitForSettled(name)
        if (settled?.status === "connected") {
          attempts.delete(name)
          exhausted.delete(name)
          log(`${name}: reconnected on attempt ${count}`)
        } else {
          const delay = Math.min(baseDelayMs * 2 ** (count - 1), maxDelayMs)
          log(`${name}: attempt ${count} did not connect (${settled?.status ?? "unknown"}); retrying in ~${Math.round(delay / 1000)}s`)
          schedule(name, delay)
        }
      } catch (error) {
        const delay = Math.min(baseDelayMs * 2 ** (count - 1), maxDelayMs)
        log(`${name}: retry ${count} failed: ${error instanceof Error ? error.message : String(error)}`)
        schedule(name, delay)
      } finally {
        inflight.delete(name)
      }
    }

    const check = async () => {
      if (abort.signal.aborted) return
      for (const name of servers) {
        if (exhausted.has(name) || timers.has(name) || inflight.has(name)) continue
        const status = await statusOf(name)
        if (status?.status === "connected") {
          attempts.delete(name)
          exhausted.delete(name)
        } else if (status?.status === "failed") {
          schedule(name, 500)
        }
      }
    }

    // MCP status events tell us immediately when a server settles as failed.
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: abort.signal }) as any) {
          const type = event?.type
          if (type !== "mcp.status.changed") continue
          const data = typeof event.data === "string" ? safeParse(event.data) : event.data
          const name = data?.server
          if (typeof name !== "string" || !servers.includes(name)) continue
          if (timers.has(name) || inflight.has(name)) continue
          const status = await statusOf(name)
          if (status?.status === "failed") schedule(name, 500)
        }
      } catch {
        // Stream aborts on plugin unload; nothing to do.
      }
    })()

    // Fallback poll covers failures that happen before the subscription is live.
    const initial = setTimeout(() => void check(), 4_000)
    initial.unref?.()
    const poll = setInterval(() => void check(), pollIntervalMs)
    poll.unref?.()

    return () => {
      abort.abort()
      clearTimeout(initial)
      clearInterval(poll)
      for (const timer of timers.values()) clearTimeout(timer)
      timers.clear()
      active.delete(location)
    }
  },
})

function safeParse(value: string): any {
  try {
    return JSON.parse(value)
  } catch {
    return undefined
  }
}
