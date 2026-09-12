import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"

/**
 * bcode-remote — OpenCode server-side plugin, v0.1.
 *
 * Philosophy (from acode-ai-agent): phone is a thin approval UI.
 * Engine stays here. This plugin only adds:
 *  1. `bcode_pair` / `bcode_pair_redeem` / `bcode_pair_list` — short
 *     pairing codes shown on desktop, typed into the phone so raw
 *     passwords aren't pasted around. Single-use, 10 min TTL.
 *  2. `bcode_notify` tool — queue a short note the phone shows
 *     (turn done, needs approval). v0.2 forwards to a push relay.
 *  3. `permission.ask` hook — v0.1 observes (logs for the phone to surface
 *     Approve/Deny); per-device auto-policy lands in v0.2.
 */

type StoredPairing = { code: string; createdAt: number; label: string }

const pairings = new Map<string, StoredPairing>()
const PAIR_TTL_MS = 10 * 60 * 1000

function newCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString()
}

function pruneExpired(now = Date.now()): void {
  for (const [code, p] of pairings) {
    if (now - p.createdAt > PAIR_TTL_MS) pairings.delete(code)
  }
}

export const BcodePlugin: Plugin = async (_ctx, options) => {
  const opts = (options ?? {}) as { notifyUrl?: string }

  return {
    tool: {
      bcode_pair: tool({
        description: "Generate a pairing code for a bcode phone client (valid 10 min)",
        args: {
          label: tool.schema.string(),
        },
        async execute(args) {
          pruneExpired()
          const code = newCode()
          pairings.set(code, { code, createdAt: Date.now(), label: args.label })
          return `bcode pairing code for '${args.label}': ${code}. Valid 10 min. Enter it in the phone app along with the server URL.`
        },
      }),

      bcode_pair_redeem: tool({
        description: "Verify + consume a bcode phone pairing code (single-use, 10 min TTL). Returns the device label on success.",
        args: {
          code: tool.schema.string(),
        },
        async execute(args) {
          pruneExpired()
          const found = pairings.get(args.code.trim())
          if (!found) return "invalid or expired pairing code"
          pairings.delete(args.code.trim())
          return `paired: '${found.label}' (code accepted, single-use consumed)`
        },
      }),

      bcode_pair_list: tool({
        description: "List pending (unredeemed, unexpired) bcode pairing codes",
        args: {},
        async execute() {
          pruneExpired()
          if (pairings.size === 0) return "no pending pairing codes"
          return [...pairings.values()]
            .map((p) => `'${p.label}': ${p.code} (expires in ${Math.max(0, Math.round((PAIR_TTL_MS - (Date.now() - p.createdAt)) / 1000))}s)`)
            .join("\n")
        },
      }),

      bcode_notify: tool({
        description: "Queue a short notification for the paired bcode phone (turn done, needs approval)",
        args: {
          title: tool.schema.string(),
          body: tool.schema.string(),
        },
        async execute(args) {
          // v0.1: log only. v0.2 forwards to APNs/FCM relay at opts.notifyUrl.
          console.log(`[bcode notify] ${args.title}: ${args.body}`)
          if (opts.notifyUrl) {
            try {
              await fetch(opts.notifyUrl, {
                method: "POST",
                headers: { "content-type": "application/json" },
                body: JSON.stringify({ title: args.title, body: args.body }),
              })
            } catch {
              // best effort in v0.1
            }
          }
          return "queued"
        },
      }),
    },

    "permission.ask": async (input) => {
      // v0.1: observe only — phone surfaces Approve/Deny via the serve API.
      // v0.2: per-device policy can flip output.status to "allow" for safe tools.
      console.log("[bcode] permission asked — approve from phone:", JSON.stringify(input).slice(0, 500))
    },

    event: async ({ event }) => {
      const type = (event as { type?: string }).type ?? "unknown"
      if (type === "session.idle") {
        console.log("[bcode] session idle — phone may show turn-done state")
      }
    },
  }
}

export default BcodePlugin
