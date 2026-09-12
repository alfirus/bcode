# bcode design tokens v2 (Flutter only — the Acode client was deleted 2026-09-12)

The AerosGeotech language: monochrome + one amber accent, strict
monospace, sharp edges. Tokens live in `flutter/lib/theme.dart`.

- bg ......... #060606  app background, flat (no gradients)
- surface .... #0c0c0d  header / tab strip
- card ....... #111113  user bubble, permission card, empty mark bg
- input ...... #0a0a0b  text inputs, composer
- hairline ... #26262a  ALL borders, dividers, tab strip rule
- user-line .. #33363c  user bubble border (slightly lifted)
- ink ........ #f2f2f0  primary text
- dim ........ #9a9aa0  secondary text, labels, inactive tabs
- faint ...... #6e6e75  timestamps, session ids, who-labels
- accent ..... #e8b93e  THE only brand color: active tab underline,
  live tail rule, permission border, primary buttons, send icon,
  active session bar, logo mark. Amber fill always pairs with
  black (#000) text.
- ok ......... #34d399  status dot (online) + ok notes ONLY
- bad ........ #f87171  errors + stop + deny, text/border ONLY,
  never a fill
- type ....... JetBrains Mono stack, uppercase micro-labels with
  1.5–2px tracking for labels/tabs/status
- radius ..... 0–2px everywhere. Sharp. Pills and gradient text
  are banned.
- glass ...... header: diagonal white fill (135deg, 12%→2%)
  + 115deg sheen streak + rgba(12,12,13,.6) over blur(20px)
  saturate(1.6); top inner highlight white 22%, amber bottom
  edge 35%, shadow 0 8px 32px black 45% + amber glow.
  Permission card (hero, like the ref debit card): triple fill
  (white sheen 12% streak + white 14%→3% + amber 20%→6%),
  amber luminous border 55%, radius 14px, inner top white 35%,
  deep shadow + amber halo 0 0 28px 22%. Text on glass gets
  0 1px 4px black shadow. Screen ambient: amber orb 24%
  top-left (light source) + 9% bottom-right + whisper white 5%
  top-right; content layer transparent so orbs show through.
  Composer: dark glass rgba(10,10,11,.55) + blur(24px).
  Blur is progressive enhancement — flat rgba on old WebViews.
  (Flutter: BackdropFilter + same tokens.)
