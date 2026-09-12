# bcode roadmap

## v0.1 — remote chat (this scaffold)

- [x] `plugin/`: pairing command + permission-policy hook, published as `bcode-remote`
  (code complete + smoke-tested 2026-09-12: pair → list → redeem →
  double-redeem rejected; npm publish still to do)
- [ ] `ios/`: server config (Keychain) → session list → chat with SSE → approve/deny → abort
- [ ] `android/`: Acode plugin, same screens as webview UI, `plugin.zip` build
- [x] Live smoke test vs local `opencode serve` (done 2026-09-12, v1.18.29:
  health/session/prompt_async/status/abort verified; all 4 bcode tools in
  `/experimental/tool/ids`; pair→redeem→list + permission reject over live
  turns at zero cost; Tailscale phone test still to do)
- [ ] Phone test over Tailscale (needs Alfirus's phone in hand)

## v0.2 — trust + push

- device pairing codes (approve new phone from desktop)
- push relay on permission request / turn done (APNs / FCM via server hook)
- per-device permission policy (read auto-allow, edits/shell always queue)

## v0.3 — files + diffs

- `GET /session/:id/diff` view, file preview (read-only)
- share session (`POST /session/:id/share`), export JSON

Non-goals for now: running models on-device, terminal emulation on phone,
public-internet exposure without Tailscale/VPN.
