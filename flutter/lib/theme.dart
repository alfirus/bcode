// bcode theme v2 — same tokens as docs/DESIGN.md. Widgets only, no Material.
import 'package:flutter/widgets.dart';

class BcodeColors {
  BcodeColors._();
  static const bg = Color(0xFF060606);
  static const surface = Color(0xFF0C0C0D);
  static const card = Color(0xFF111113);
  static const input = Color(0xFF0A0A0B);
  static const hairline = Color(0xFF26262A);
  static const userLine = Color(0xFF33363C);
  static const ink = Color(0xFFF2F2F0);
  static const dim = Color(0xFF9A9AA0);
  static const faint = Color(0xFF6E6E75);
  static const accent = Color(0xFFE8B93E);
  static const ok = Color(0xFF34D399);
  static const bad = Color(0xFFF87171);
  static const onAccent = Color(0xFF000000);

  // Compat aliases — old scaffold used cyan/violet names; everything maps to
  // the single amber accent (mono-first, amber-second, per docs/DESIGN.md).
  static const cyan = accent;
  static const cyanDim = Color(0x1FE8B93E);
  static const violet = accent;
  static const warn = accent;
  static const muted = faint;
  static const text = ink;
  static const danger = bad;
}

/// Monospace stack per platform. Pass to TextStyle(fontFamily: ...).
/// Web + Android resolve the first available entry.
const bcodeMonoStack = <String>[
  'JetBrains Mono',
  'monospace',
];

/// Sharp edges: 0–2px radii everywhere. Pills and gradients are banned.
class BcodeRadii {
  BcodeRadii._();
  static const sharp = Radius.zero;
  static const card = BorderRadius.all(Radius.circular(2));
  static const pill = BorderRadius.all(Radius.circular(2));
  static const input = BorderRadius.all(Radius.circular(2));
}

class BcodeSpace {
  BcodeSpace._();
  static const pad = 14.0;
  static const gap = 12.0;
}

/// Text styles — message/input are mono-first, headers plain.
class BcodeText {
  BcodeText._();
  static const title = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w700, color: BcodeColors.ink);
  static const message = TextStyle(
      fontSize: 14, color: BcodeColors.ink, fontFamily: 'JetBrains Mono');
  static const input = TextStyle(
      fontSize: 14, color: BcodeColors.ink, fontFamily: 'JetBrains Mono');
  static const tab =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const meta = TextStyle(fontSize: 12, color: BcodeColors.dim);
}
