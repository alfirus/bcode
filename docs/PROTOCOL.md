# bcode protocol (MVP v0.1)

Base: OpenCode `serve` HTTP API (OpenAPI 3.1 at `http://<host>:<port>/doc`).
bcode adds nothing to the wire for v0.1 — it is a well-behaved `serve` client.
The `plugin/` adds optional pairing/policy endpoints later; clients must work
without them.

## Server

```sh
OPENCODE_SERVER_PASSWORD=<secret> opencode serve --hostname 0.0.0.0 --port 4096
```

Recommended: bind Tailscale IP only, connect phone over Tailnet. No public ports.

## Client calls (v0.1)

- `GET /global/health` → `{ healthy, version }` — connection test
- `GET /session` → list sessions
- `POST /session` `{ title? }` → new session
- `GET /session/:id/message?limit=` → history
- `POST /session/:id/message` `{ model?, agent?, parts }` → send + wait for reply
- `POST /session/:id/prompt_async` (same body) → send, stream via SSE instead
- `POST /session/:id/abort` → stop running turn (returns `true`, idempotent)
- `GET /permission` → global pending queue (poll this; `[]` when empty).
  Item: `{id, sessionID, permission, patterns, metadata, tool:{messageID, callID}}`
- `POST /permission/:requestID/reply` `{reply:"once"|"always"|"reject", message?}` → `true`
  (session-scoped twins: `GET /api/session/:id/permission`,
  `POST /api/session/:id/permission/:requestID/reply` — always use the `/api`
  prefix; the non-`/api` path serves the web UI, not JSON)
- `GET /event` (per-session SSE) + `GET /global/event` (server SSE) → live updates

Parts model (send text): `{ parts: [{ type: "text", text: "..." }] }`.

## Auth

HTTP basic auth. Username defaults to `opencode`, override with
`OPENCODE_SERVER_USERNAME`. Password from `OPENCODE_SERVER_PASSWORD`.
Clients store both in secure storage (iOS Keychain / Android Keystore).

## Rules for clients

1. Default-deny on permissions — always show Approve/Deny, never auto-allow in v0.1.
2. Sequential sends per session — one running turn at a time; Abort before resend.
3. Never log secrets, server URLs with credentials, or full message bodies in crash logs.
4. Paths shown are server-side paths — display only, never execute locally.
5. SSE reconnect with backoff; `prompt_async` + SSE is the primary send path on mobile.
