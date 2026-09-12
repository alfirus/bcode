# bcode — remote OpenCode for your phone

Use OpenCode running on your desktop/server from iOS or Android.

- Engine stays on the machine: `opencode serve` exposes an HTTP + OpenAPI + SSE API
- Phone is a thin client: list sessions, send prompts, stream replies, approve permissions
- Auth: Tailscale (private network) + `OPENCODE_SERVER_PASSWORD` basic auth
- No ports exposed to the internet

## Repo layout

- `plugin/` — OpenCode server-side plugin (`bcode-remote`, on npm as `0.1.0`):
  device pairing (6-digit codes, 10-min TTL, single-use, `node:crypto` randomness),
  permission queue, push hook
- `flutter/` — the one client for iOS + Android (widgets-only `WidgetsApp`,
  no Material anywhere; `ios/` + `android/` scaffolding generated,
  `flutter analyze` clean, boot smoke test in `test/`)
- `docs/` — protocol, design tokens + UI mockup, roadmap

(The old `android/` Acode client was deleted 2026-09-12 — Flutter replaces it.)

## How the client works

- Sends go `prompt_async` first (returns instantly, reply streams over global
  `/event` SSE) with blocking `sendMessage` as fallback; the turn stays
  "sending" until a matching `session.idle` event, timeout (10 min), or abort.
- Permissions poll the global `GET /permission` queue every 2s while online —
  approve (`once`) / deny (`reject`) works even mid-turn, no open session needed.
- History fetches cap at `?limit=100`; all calls carry 15s timeouts (SSE excluded).
- Sends while busy abort-then-resend; message text prefers `parts[]` over the
  top-level field so replies never render doubled.

## Quick start (MVP)

1. On desktop/server:
```sh
OPENCODE_SERVER_PASSWORD=secret opencode serve --hostname 0.0.0.0 --port 4096
```
2. Install plugin (recommended — pairing + permission queue):
```sh
npm i -g bcode-remote
```
3. Generate a pairing code on desktop, redeem from the phone once.
4. On phone: open bcode, enter server URL (Tailscale IP, e.g.
   `http://100.121.188.113:4096`) + password, chat.

## Known limitations (v0.1)

- Pairing codes live in server memory — a serve restart wipes pending codes.
- The plugin's `permission.ask` hook shape is verified against serve `v1.18.29`
  docs; live approval round-trip is proven at the next phone test.
- Canonical serve port is **4096** (one early smoke test used 4099).

## Why this shape (learned from Acode)

Acode (`Acode-Foundation/Acode`, Cordova + Ace Editor, 250+ community plugins) and
`acode-ai-agent` (Pi agent loop inside an Android WebView, no Node/daemon/IPC/sockets)
prove the pattern: keep the agent engine off the phone, talk HTTP SSE, store secrets
in plugin-scoped secure storage, gate every write/terminal action behind approval.
bcode copies that: OpenCode engine on desktop, phone does UI + approvals only.

See `docs/ACODE_LESSONS.md` and `docs/PROTOCOL.md`.
