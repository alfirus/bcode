// bcode — remote OpenCode chat. Widgets only, no Material.
import 'package:flutter/widgets.dart';

import 'chat_screen.dart';
import 'store.dart';
import 'theme.dart';

void main() => runApp(const BcodeApp());

class BcodeApp extends StatefulWidget {
  const BcodeApp({super.key});

  @override
  State<BcodeApp> createState() => _BcodeAppState();
}

class _BcodeAppState extends State<BcodeApp> {
  final _store = BcodeStore();

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BcodeColors.bg,
      child: SafeArea(
        child: BcodeScreen(store: _store),
      ),
    );
  }
}
