import 'package:flutter_test/flutter_test.dart';

import 'package:spy_android/main.dart';

void main() {
  testWidgets('app shows monitoring controls', (tester) async {
    await tester.pumpWidget(const ShadowTrackApp());
    await tester.pumpAndSettle();

    expect(find.text('Device Monitor'), findsWidgets);
    expect(find.text('Monitoring is off'), findsOneWidget);
    expect(find.text('Start Monitoring'), findsOneWidget);
  });
}
