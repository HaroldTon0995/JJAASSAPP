import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjaassapp2/main.dart';
import 'package:jjaassapp2/widgets/water_widgets.dart';

void main() {
  testWidgets('App splash to login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify splash screen content (droplet logo) is shown initially
    expect(find.byType(WaterDropletLogo), findsOneWidget);

    // Pump past the 2-second splash screen transition delay
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify we have transitioned to the Login screen
    expect(find.text('JJAASS Water Market'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
