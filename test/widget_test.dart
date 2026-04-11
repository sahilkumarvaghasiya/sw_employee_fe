import 'package:flutter_test/flutter_test.dart';

import 'package:sw_billing_employee_fe/main.dart' as app;

void main() {
  testWidgets('App shows login screen for unauthenticated user', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Login to your account'), findsOneWidget);
  });
}
