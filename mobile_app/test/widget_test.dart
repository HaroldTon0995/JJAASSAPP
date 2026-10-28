import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/widgets/water_widgets.dart';

void main() {
  testWidgets('App splash to login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify splash screen content (droplet logo) is shown initially
    expect(find.byType(WaterDropletLogo), findsOneWidget);

    // Pump past the 2-second splash screen transition delay
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify we have transitioned to the Login screen
    expect(find.text('JJAASSApp'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
