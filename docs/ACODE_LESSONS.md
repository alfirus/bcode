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
- bcode: permission requests (`POST /session/:id/permissions/:permissionID`)
  surface as Approve/Deny buttons on the phone. Default-deny. Plugin can add
  policy (auto-allow read-only tools, always queue edits/shell for the phone).

## 5. Distribution like Acode plugins

- Acode: `plugin.json` + esbuild IIFE bundle + `plugin.zip`, installed from the
  store or Settings → Plugins → LOCAL. Dev via `npm run dev` (port 3000 reload).
  Budget enforced (ai-agent: 1.92 MB `dist/main.js`, Chrome 90 target).
- bcode android client ships the same way: `android/plugin.json` + bundled
  `dist/main.js` + `plugin.zip`. OpenCode server plugin ships as npm package
  (`plugin/`), installed via `opencode plugin <module> -g`.

## 6. Extension points

- `acode-ai-agent` exposes `acode.require("acode.ai.agent.runtime")` with
  `registerTool / registerProvider / registerContext / registerFeature / open()`.
- bcode android client exposes `bcode.require("bcode.runtime")` with
  `registerContext` + `open()` so other Acode plugins can add project context.
