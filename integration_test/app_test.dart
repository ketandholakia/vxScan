// End-to-end smoke test, run on a device/emulator:
//   flutter test integration_test
//
// Verifies the app boots, the scanner screen mounts (camera permission is
// granted by `flutter test` on Android via `flutter run`-style instrumentation),
// and history navigation works. Full scan flows need a real camera — those
// are covered manually with the device matrix in docs/RELEASE.md.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vxscan/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and history screen opens', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VxScanApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Scanner screen is the start destination.
    expect(find.text('vxScan'), findsWidgets);

    // Open history.
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('History'), findsOneWidget);

    // Open settings.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Settings'), findsOneWidget);
  });
}
