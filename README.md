# bcode — remote OpenCode for your phone

Use OpenCode running on your desktop/server from iOS or Android.

- Engine stays on the machine: `opencode serve` exposes an HTTP + OpenAPI + SSE API
- Phone is a thin client: list sessions, send prompts, stream replies, approve permissions
- Auth: Tailscale (private network) + `OPENCODE_SERVER_PASSWORD` basic auth
- No ports exposed to the internet

## Repo layout

- `plugin/` — OpenCode server-side plugin (`bcode-remote`): device pairing, permission queue, push hook
- `ios/` — native iOS client (SwiftUI, URLSession, SSE streaming)
- `android/` — Acode plugin client (JS, WebView-safe, HTTP SSE only — same transport as `acode-ai-agent`)
- `docs/` — protocol, Acode lessons, roadmap

## Quick start (MVP)

1. On desktop/server:
```sh
OPENCODE_SERVER_PASSWORD=secret opencode serve --hostname 0.0.0.0 --port 4096
```
2. Install plugin (optional but recommended):
```sh
opencode plugin ./plugin -g
```
3. On phone: open bcode, enter server URL (Tailscale IP) + password, chat.

## Why this shape (learned from Acode)

Acode (`Acode-Foundation/Acode`, Cordova + Ace Editor, 250+ community plugins) and
`acode-ai-agent` (Pi agent loop inside an Android WebView, no Node/daemon/IPC/sockets)
prove the pattern: keep the agent engine off the phone, talk HTTP SSE, store secrets
in plugin-scoped secure storage, gate every write/terminal action behind approval.
bcode copies that: OpenCode engine on desktop, phone does UI + approvals only.

See `docs/ACODE_LESSONS.md` and `docs/PROTOCOL.md`.
