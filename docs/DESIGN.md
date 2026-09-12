# bcode design tokens v2 (shared: Acode CSS ↔ Flutter)

The AerosGeotech language: monochrome + one amber accent, strict
monospace, sharp edges. Change a value here → change it in both
`android/src/bcode.css` (`--bc-*`) and `flutter/lib/theme.dart`.

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
- glass ...... header + tab strip: white 4.5% top sheen over
  rgba(12,12,13,.72) + backdrop blur(16px) saturate(1.3),
  inset 1px top highlight, faint amber edge (18%) + ambient
  drop 0 10px 32px amber 9%. Permission card: amber-tinted
  gradient (amber 14% → card 85%) + blur(12px), amber border
  75%, halo 0 0 36px amber 18%. Screen sits under a faint top
  ambient: radial amber 11% fading by 60%. Blur is progressive
  enhancement — flat rgba fallback on old WebViews.
  (Flutter: BackdropFilter + same tokens.)
