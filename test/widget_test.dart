import 'package:flutter_test/flutter_test.dart';

import 'package:sw_billing_employee_fe/main.dart' as app;

void main() {
  testWidgets('App shows login screen for unauthenticated user', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

  expect(find.text('Sign in'), findsOneWidget);
  expect(find.text('Enter your credentials'), findsOneWidget);
  });
}
