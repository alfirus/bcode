# bcode Flutter app (iOS + Android, one codebase)

Our own chat UI for talking to `opencode serve` on your machine.
**Widgets only — no Material anywhere.** No `Scaffold`, no `AppBar`, no
`TextField`, no `InkWell`. Minimalist futuristic theme, tokens in
`docs/DESIGN.md`.

## Run it

No Flutter SDK on the build box, so this is scaffolded by hand and
**not yet analyzed**. On your machine:

```sh
cd flutter
flutter pub get
flutter analyze
flutter run -d <your-phone>
```

## Layout

- `lib/main.dart` — entry, `ColoredBox` root + `SafeArea`
- `lib/chat_screen.dart` — header, tabs, chat, sessions, settings (`EditableText`, `GestureDetector`, custom containers)
- `lib/serve_client.dart` — `serve` client (`package:http` + SSE stream, shapes per `docs/PROTOCOL.md`)
- `lib/store.dart` — state (`ChangeNotifier`) + server config in `flutter_secure_storage` (Keychain / Keystore)
- `lib/theme.dart` — `BcodeColors` / `BcodeText` per `docs/DESIGN.md`

## Rules

- `uses-material-design: false`. Never import `material.dart` — not in app code, not in tests.
- Secrets only in secure storage. Never in prefs, never in logs.
- Permissions default-deny: Approve / Deny cards, nothing auto-approves.
