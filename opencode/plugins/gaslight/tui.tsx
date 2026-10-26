/** @jsxImportSource @opentui/solid */
import { createSignal, Show } from "solid-js"
import { TextAttributes } from "@opentui/core"
import type { TextareaRenderable } from "@opentui/core"
import { useKeyboard } from "@opentui/solid"
import { Plugin, usePlugin } from "@opencode/plugin/tui"
import type { SessionMessageAssistant } from "@opencode/client"
import { Gaslight } from "./rpc.js"

type Editable = {
  id: string
  index: number
  agent: string
  text: string
  reasoning: string
  edited: boolean
}

function truncate(value: string, max: number): string {
  const oneline = value.replace(/\n/g, " ").replace(/\s+/g, " ").trim()
  if (oneline.length <= max) return oneline
  return oneline.slice(0, max - 1) + "…"
}

function collectText(message: SessionMessageAssistant, type: "text" | "reasoning"): string {
  return message.content
    .filter((part) => part.type === type)
    .map((part) => ("text" in part && typeof part.text === "string" ? part.text : ""))
    .join("")
}

// ── Tabbed editor: response + thinking in one dialog ─────────────────

function TabbedEditor(props: {
  initialText: string
  initialReasoning: string
  hasText: boolean
  hasReasoning: boolean
  onSave: (text: string, reasoning: string) => void
  onCancel: () => void
}) {
  const context = usePlugin()
  const [tab, setTab] = createSignal<"response" | "thinking">(props.hasText ? "response" : "thinking")
  const [savedText, setSavedText] = createSignal(props.initialText)
  const [savedReasoning, setSavedReasoning] = createSignal(props.initialReasoning)
  let ref: TextareaRenderable | undefined

  const accent = () => context.theme.text.action.primary.base
  const bright = () => context.theme.text.base
  const dim = () => context.theme.text.muted

  const capture = () => {
    const value = ref?.plainText ?? ""
    if (tab() === "response") setSavedText(value)
    else setSavedReasoning(value)
    return value
  }

  const switchTab = () => {
    if (!props.hasText || !props.hasReasoning) return
    capture()
    setTab(tab() === "response" ? "thinking" : "response")
  }

  const save = () => {
    const value = capture()
    const text = tab() === "response" ? value : savedText()
    const reasoning = tab() === "thinking" ? value : savedReasoning()
    props.onSave(text, reasoning)
  }

  useKeyboard((event) => {
    if (event.name === "tab") {
      event.preventDefault()
      event.stopPropagation()
      switchTab()
      return
    }
    if (event.name === "escape") {
      event.preventDefault()
      props.onCancel()
      return
    }
    if ((event.name === "s" && event.ctrl) || (event.name === "return" && event.meta)) {
      event.preventDefault()
      event.stopPropagation()
      save()
    }
  })

  const tabs = () => (
    <box flexDirection="row" gap={1} paddingBottom={1}>
      <text
        fg={tab() === "response" ? accent() : dim()}
        attributes={tab() === "response" ? TextAttributes.BOLD : 0}
      >
        {tab() === "response" ? "▸ Response" : "  Response"}
      </text>
      <text fg={dim()}>│</text>
      <text
        fg={tab() === "thinking" ? accent() : dim()}
        attributes={tab() === "thinking" ? TextAttributes.BOLD : 0}
      >
        {tab() === "thinking" ? "▸ Thinking" : "  Thinking"}
      </text>
    </box>
  )

  return (
    <box flexDirection="column" width="100%" paddingLeft={2} paddingRight={2} paddingBottom={1}>
      <box flexDirection="row" justifyContent="space-between" paddingBottom={1}>
        <text fg={bright()} attributes={TextAttributes.BOLD}>
          Gaslight · edit response
        </text>
        <text fg={dim()}>esc to cancel</text>
      </box>

      <Show when={props.hasText && props.hasReasoning}>{tabs()}</Show>

      <Show when={tab() === "response"}>
        <textarea
          ref={(value: TextareaRenderable) => {
            ref = value
            value.focus()
          }}
          initialValue={savedText()}
          height={8}
          placeholder="Response text"
          textColor={bright()}
          focusedTextColor={bright()}
          cursorColor={accent()}
        />
      </Show>
      <Show when={tab() === "thinking"}>
        <textarea
          ref={(value: TextareaRenderable) => {
            ref = value
            value.focus()
          }}
          initialValue={savedReasoning()}
          height={8}
          placeholder="Thinking text"
          textColor={bright()}
          focusedTextColor={bright()}
          cursorColor={accent()}
        />
      </Show>

      <box paddingTop={1}>
        <text fg={dim()}>
          {props.hasText && props.hasReasoning ? "Tab: switch · " : ""}
          ctrl+s: save · esc: cancel
        </text>
      </box>
    </box>
  )
}

// ── Plugin ───────────────────────────────────────────────────────────

export default Plugin.define({
  id: "gaslight.cli",
  setup(context) {
    const rpc = context.client.rpc(Gaslight)

    type OverrideEntry = { messageID: string; text?: string; reasoning?: string }

    const listOverrides = (sessionID: string) =>
      rpc.list({ sessionID }) as Promise<{ overrides: OverrideEntry[] }>
    const setOverride = (input: {
      sessionID: string
      messageID: string
      text?: string
      reasoning?: string
    }) => rpc.set(input) as Promise<unknown>
    const clearOverrides = (input: { sessionID: string; messageID?: string }) =>
      rpc.clear(input) as Promise<{ removed: number }>

    const toast = (message: string, variant: "info" | "success" | "warning" | "error" = "info") =>
      context.ui.toast.show({ message, variant })

    async function editMessage(sessionID: string, message: SessionMessageAssistant, edited: boolean) {
      const hasText = collectText(message, "text").trim().length > 0
      const hasReasoning = collectText(message, "reasoning").trim().length > 0
      if (!hasText && !hasReasoning) {
        toast("No editable content in that response", "warning")
        return
      }

      let current: { text?: string; reasoning?: string } = {}
      try {
        const result = await listOverrides(sessionID)
        current = result.overrides.find((entry) => entry.messageID === message.id) ?? {}
      } catch (error) {
        toast(`Gaslight server unavailable: ${String(error)}`, "error")
        return
      }

      context.ui.dialog.set({ size: "large" })
      context.ui.dialog.show(
        () => (
          <TabbedEditor
            hasText={hasText}
            hasReasoning={hasReasoning}
            initialText={current.text ?? collectText(message, "text")}
            initialReasoning={current.reasoning ?? collectText(message, "reasoning")}
            onCancel={() => context.ui.dialog.clear()}
            onSave={async (text, reasoning) => {
              context.ui.dialog.clear()
              try {
                await setOverride({
                  sessionID,
                  messageID: message.id,
                  ...(hasText ? { text } : {}),
                  ...(hasReasoning ? { reasoning } : {}),
                })
                toast(edited ? "Response edit updated" : "Response edited for future requests", "success")
              } catch (error) {
                toast(`Failed to apply edit: ${String(error)}`, "error")
              }
            }}
          />
        ),
        () => {},
      )
    }

    async function open() {
      const route = context.ui.router.current()
      if (route.type !== "session") {
        toast("Open a session first", "warning")
        return
      }
      const sessionID = route.sessionID

      await context.data.session.message.sync(sessionID)
      const messages = (context.data.session.message.list(sessionID) ?? []).filter(
        (message): message is SessionMessageAssistant => message.type === "assistant",
      )

      let overrides = new Map<string, { text?: string; reasoning?: string }>()
      try {
        const result = await listOverrides(sessionID)
        overrides = new Map(result.overrides.map((entry) => [entry.messageID, entry]))
      } catch (error) {
        toast(`Gaslight server unavailable: ${String(error)}`, "error")
        return
      }

      const editable: Editable[] = messages
        .map((message, index): Editable | undefined => {
          const text = collectText(message, "text")
          const reasoning = collectText(message, "reasoning")
          if (text.trim().length === 0 && reasoning.trim().length === 0) return undefined
          return {
            id: message.id,
            index,
            agent: message.agent,
            text,
            reasoning,
            edited: overrides.has(message.id),
          }
        })
        .filter((entry): entry is Editable => entry !== undefined)
        .reverse()

      if (editable.length === 0) {
        toast("No assistant responses in this session yet", "warning")
        return
      }

      const byID = new Map(messages.map((message) => [message.id, message]))

      const selected = await context.ui.dialog.select<string>({
        title: "Gaslight · select a response",
        placeholder: "Search responses…",
        current: editable[0].id,
        options: editable.map((entry) => {
          const badges = [
            entry.edited ? "[edited]" : "",
            entry.reasoning.trim().length > 0 ? "[has thinking]" : "",
          ]
            .filter(Boolean)
            .join(" ")
          const preview =
            entry.text.trim().length > 0 ? truncate(entry.text, 80) : "(thinking only)"
          return {
            title: `Response #${entry.index + 1}${entry.edited ? " ✎" : ""}`,
            value: entry.id,
            description: `${entry.agent} · ${preview}${badges ? ` ${badges}` : ""}`,
          }
        }),
        actions: [
          {
            bind: "ctrl+r",
            title: "Clear edits",
            side: "right",
            selection: "none",
            onTrigger: async () => {
              try {
                const result = await clearOverrides({ sessionID })
                context.ui.dialog.clear()
                toast(`Cleared ${result.removed} edit${result.removed === 1 ? "" : "s"}`, "success")
              } catch (error) {
                toast(`Failed to clear edits: ${String(error)}`, "error")
              }
            },
          },
          {
            bind: "ctrl+d",
            title: "Undo this edit",
            selection: "required",
            onTrigger: async (messageID) => {
              try {
                const result = await clearOverrides({ sessionID, messageID })
                context.ui.dialog.clear()
                toast(result.removed > 0 ? "Edit removed" : "That response was not edited", "success")
              } catch (error) {
                toast(`Failed to remove edit: ${String(error)}`, "error")
              }
            },
          },
        ],
      })

      if (selected === undefined) return
      const message = byID.get(selected)
      if (!message) {
        toast("That response is no longer available", "warning")
        return
      }
      await editMessage(sessionID, message, overrides.has(message.id))
    }

    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "gaslight.open",
          title: "Gaslight: edit an assistant response",
          description: "Rewrite a previous response in this session's model context",
          group: "Session",
          slash: { name: "gaslight" },
          palette: true,
          enabled: () => context.ui.router.current().type === "session",
          run: () => void open(),
        },
      ],
    }))
  },
})
