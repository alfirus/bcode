# bcode design tokens (shared: Acode CSS ↔ Flutter)

One minimalist futuristic theme, always dark. Two implementations, same numbers.
Change a value here → change it in both `android/src/bcode.css` (`--bc-*`)
and `flutter/lib/theme.dart` (`BcodeColors.*`).

## Color

| token     | hex       | use                              |
|-----------|-----------|----------------------------------|
| `bg`      | `#05070d` | app background                   |
| `surface` | `#0a0f1c` | header, tabs, composer field     |
| `card`    | `#0c1322` | assistant message cards          |
| `hairline`| `rgba(140,190,255,0.14)` | borders, dividers    |
| `cyan`    | `#38e1ff` | accent: send button, active tab, user bubbles (bg), focus rings |
| `cyanDim` | `rgba(56,225,255,0.14)` | active tab pill, soft highlights |
| `violet`  | `#7c5cff` | gradient partner (headers, glow) |
| `text`    | `#e8f1ff` | primary text                     |
| `muted`   | `#8ea3c7` | secondary text, timestamps       |
| `danger`  | `#ff5d6c` | stop button, deny, errors        |
| `ok`      | `#3ddc84` | online dot, approve              |
| `warn`    | `#ffb224` | connecting dot                   |

Header/title gradient: `cyan → violet`, 135deg. Message glow: soft cyan
`box-shadow` / `BoxShadow(blur 18, cyan @ 12%)` on assistant cards only.

## Shape & type

- Radius: cards 14, buttons/pills 10–999 (send button round 22), inputs 12
- Font: system stack (`-apple-system, Inter, Roboto…` / Flutter `fontFamily` unset = system)
- Sizes: title 15 semibold, tab 13, message 14/1.5, meta 11, input 14
- Spacing: screen padding 14, card padding 10–12, gaps 8–10

## Rules

- Always dark. Never inherit the host theme (no Acode theme vars, no `Theme.of`).
- No shadows except the cyan message glow. Hairlines do the separating.
- Verbatim message text in v0.1 on both (no markdown renderers yet).
- Status vocabulary shared: `online` (ok) / `connecting` (warn) / `offline` (muted).
