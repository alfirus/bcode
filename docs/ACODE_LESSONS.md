# What bcode copies from Acode

Source: `Acode-Foundation/Acode` (Cordova Android editor, Ace v1.22, 250+ plugins),
`acode-plugin` template, `acode-ai-agent` (Pi agent loop in a WebView).

## 1. Engine off the phone

- `acode-ai-agent` runs the Pi model loop in the WebView but does file/shell work
  through host bridges (`fsOperation`, optional Terminal-executor `bash`).
  No Node.js, no daemon, no IPC, no sockets, no real `cwd`.
- bcode goes one step further: the OpenCode engine stays on desktop/server
  (`opencode serve`). The phone never runs models or shell — it only calls
  the serve HTTP API. Less battery, less sandbox pain, works on iOS too.

## 2. Transport: HTTP SSE only

- `acode-ai-agent` pins transport to HTTP SSE; WebSockets not required
  (works in Android WebView and behind plain HTTPS).
- bcode does the same: `GET /event`, `GET /global/event`, `POST /session/:id/message`,
  `POST /session/:id/prompt_async`. iOS `URLSession.bytes` and JS `fetch` readers
  both handle SSE without extra deps.

## 3. Secrets in secure storage, never in logs

- Acode plugins use `PluginContext.getSecret/setSecret` (plugin-scoped secure storage).
  Keys never touch localStorage, settings JSON, session history, or tool results.
- bcode: iOS stores server URL + password in Keychain; Acode client stores them
  via `getSecret/setSecret`. Server password = HTTP basic auth
  (`OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD`).

## 4. Approval-gated side effects

- `acode-ai-agent`: writes/edits sequential and gated, terminal commands
  approval-gated unless full-access mode; tool paths must be workspace-relative
  POSIX (no `..`, no absolute paths, no URI schemes — keeps SFTP URLs with
  credentials away from the model).
- bcode: permission requests (`POST /permission/:requestID/reply`
  with `once` / `always` / `reject`)
  surface as Approve/Deny buttons on the phone. Default-deny. Plugin can add
  policy (auto-allow read-only tools, always queue edits/shell for the phone).

## 5. Distribution like Acode plugins

- Acode: `plugin.json` + esbuild IIFE bundle + `plugin.zip`, installed from the
  store or Settings → Plugins → LOCAL. Dev via `npm run dev` (port 3000 reload).
  Budget enforced (ai-agent: 1.92 MB `dist/main.js`, Chrome 90 target).
- bcode server plugin ships as an npm package (`plugin/`), installed via
  `opencode plugin <module> -g`. The Flutter phone client ships via the
  app stores (one codebase, iOS + Android).

## 6. Extension points (dropped with the Acode client)

- `acode-ai-agent` exposes `acode.require("acode.ai.agent.runtime")` with
  `registerTool / registerProvider / registerContext / registerFeature / open()`.
- The Acode client (and its `bcode.require("bcode.runtime")` extension point)
  was deleted 2026-09-12 when Flutter became the one client. If the Flutter
  app ever needs third-party extensions, design them fresh — don't resurrect
  the WebView bridge.
