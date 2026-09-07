import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:havapaw/screens/splash_screen.dart';

void main() {
  testWidgets('HavaPaw splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const Scaffold(body: SizedBox()),
        },
      ),
    );
    await tester.pump();

    expect(find.text('HavaPaw'), findsOneWidget);
    expect(find.text("Your Pet's Best Friend"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // SplashScreen schedules navigation after 2.5s; elapse it so no timer
    // is left pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
  });
}
