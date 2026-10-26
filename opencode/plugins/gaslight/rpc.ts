import { Rpc } from "@opencode/plugin/rpc"

const override = {
  type: "object",
  properties: {
    messageID: { type: "string" },
    text: { type: "string" },
    reasoning: { type: "string" },
    updated: { type: "number" },
  },
  required: ["messageID"],
  additionalProperties: false,
} as const

export const Gaslight = Rpc.define({
  id: "gaslight",
  methods: {
    list: {
      input: {
        type: "object",
        properties: { sessionID: { type: "string" } },
        required: ["sessionID"],
        additionalProperties: false,
      },
      output: {
        type: "object",
        properties: { overrides: { type: "array", items: override } },
        required: ["overrides"],
        additionalProperties: false,
      },
    },
    set: {
      input: {
        type: "object",
        properties: {
          sessionID: { type: "string" },
          messageID: { type: "string" },
          text: { type: "string" },
          reasoning: { type: "string" },
        },
        required: ["sessionID", "messageID"],
        additionalProperties: false,
      },
      output: override,
    },
    clear: {
      input: {
        type: "object",
        properties: {
          sessionID: { type: "string" },
          messageID: { type: "string" },
        },
        required: ["sessionID"],
        additionalProperties: false,
      },
      output: {
        type: "object",
        properties: { removed: { type: "number" } },
        required: ["removed"],
        additionalProperties: false,
      },
    },
  },
  events: {},
})
