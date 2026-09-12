# bcode roadmap

## v0.1 — remote chat (this scaffold)

- [ ] `plugin/`: pairing command + permission-policy hook, published as `bcode-remote`
- [ ] `ios/`: server config (Keychain) → session list → chat with SSE → approve/deny → abort
- [ ] `android/`: Acode plugin, same screens as webview UI, `plugin.zip` build
- [ ] smoke test against local `opencode serve` + Tailscale phone test

## v0.2 — trust + push

- device pairing codes (approve new phone from desktop)
- push relay on permission request / turn done (APNs / FCM via server hook)
- per-device permission policy (read auto-allow, edits/shell always queue)

## v0.3 — files + diffs

- `GET /session/:id/diff` view, file preview (read-only)
- share session (`POST /session/:id/share`), export JSON

Non-goals for now: running models on-device, terminal emulation on phone,
public-internet exposure without Tailscale/VPN.
