# bcode Android client (Acode plugin)

Follows `Acode-Foundation/acode-plugin` packaging and `acode-ai-agent` runtime rules:

- WebView-safe: `fetch` + SSE reader only. No Node built-ins, no sockets, no daemons.
- Secrets via plugin-scoped secure storage (`getSecret`/`setSecret`).
- Approval-gated: permission Approve/Deny surfaces in UI, default-deny.

```sh
cd android
npm install
npm run build   # → dist/main.js, then zip with plugin.json as plugin.zip
```

Install: Acode → Settings → Plugins → + → LOCAL → pick `plugin.zip`.
