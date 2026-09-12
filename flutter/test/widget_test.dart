// bcode boot smoke test — widgets only, no Material.
import 'package:flutter_test/flutter_test.dart';

import 'package:bcode/main.dart';

void main() {
  testWidgets('bcode boots to header + empty state', (tester) async {
    await tester.pumpWidget(const BcodeApp());
    await tester.pump();
    expect(find.text('bcode'), findsOneWidget);
    expect(find.textContaining('No session open'), findsOneWidget);
  });
}
