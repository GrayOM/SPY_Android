import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spy_android/main.dart';

void main() {
  testWidgets('app shows guardian location sharing controls', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ShadowTrackApp());
    await tester.pumpAndSettle();

    expect(find.text('Android_helper'), findsWidgets);
    expect(find.text('Location sharing is off'), findsOneWidget);
    expect(find.text('Start Sharing'), findsOneWidget);
  });
}
