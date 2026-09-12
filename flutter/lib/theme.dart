// bcode theme — same tokens as docs/DESIGN.md. Widgets only, no Material.
import 'package:flutter/widgets.dart';

class BcodeColors {
  BcodeColors._();
  static const bg = Color(0xFF05070D);
  static const surface = Color(0xFF0A0F1C);
  static const card = Color(0xFF0C1322);
  static const hairline = Color(0x245ABEFF);
  static const cyan = Color(0xFF38E1FF);
  static const cyanDim = Color(0x2438E1FF);
  static const violet = Color(0xFF7C5CFF);
  static const text = Color(0xFFE8F1FF);
  static const muted = Color(0xFF8EA3C7);
  static const danger = Color(0xFFFF5D6C);
  static const ok = Color(0xFF3DDC84);
  static const warn = Color(0xFFFFB224);
}

class BcodeRadii {
  BcodeRadii._();
  static const card = 14.0;
  static const input = 12.0;
  static const pill = 999.0;
}

class BcodeText {
  BcodeText._();
  static const title = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BcodeColors.text);
  static const tab = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BcodeColors.muted);
  static const message = TextStyle(fontSize: 14, height: 1.5, color: BcodeColors.text);
  static const meta = TextStyle(fontSize: 11, color: BcodeColors.muted);
  static const input = TextStyle(fontSize: 14, color: BcodeColors.text);
}
