# bcode Android client (Acode plugin)

Our own chat UI for talking to `opencode serve` on your machine.
Minimalist, futuristic, always dark — no Acode theme inheritance, no Material,
no copied templates. The phone is a thin remote: engine, files, and keys stay
on the desktop/server.

```sh
cd android
npm install
npm run build   # typecheck → dist/main.js → plugin.zip (packs itself)
npm run pack    # re-zip only
npm run icon    # regenerate icon.png
```

Install: Acode → Settings → Plugins → + → LOCAL → pick `plugin.zip`.
Then command palette → **bcode: open remote chat**.

## UI

- Header: bolt mark + `bcode` wordmark, live status dot (online / connecting / offline)
- Tabs: **Chat / Sessions / Settings**
- Chat: assistant messages left on glass cards, yours right on cyan; verbatim
  text (no markdown in v0.1, `textContent` only — a hostile model reply can't
  inject markup); streaming tail while the model works; ↑ send button flips to
  ■ stop; permission requests render as Approve / Deny cards, default-deny
- Sessions: list with active highlight, ＋ New, tap to open, ⌦ delete
- Settings: server URL + password (plugin-scoped secret storage), Save & connect

## Rules

- WebView-safe: `fetch` + streaming reader only. No Node built-ins, no sockets,
  no daemons — the esbuild `forbid-node` plugin fails the build otherwise.
- Secrets via `getSecret`/`setSecret`. Nothing secrets-shaped in plain storage.
- Server JSON is read defensively (several key spellings) — shapes are pinned
  against live `/doc`, see `docs/PROTOCOL.md`.

## Files

- `src/main.ts` — entry: `setPluginInit` + `bcode: open remote chat` command
- `src/ui.ts` — the UI (vanilla DOM)
- `src/bcode.css` — theme (tokens shared with Flutter, see `docs/DESIGN.md`)
- `src/api.ts` — `serve` client (fetch + SSE)
- `src/store.ts` — state + secret-backed server config
- `scripts/make-icon.mjs` — zero-dependency icon generator
