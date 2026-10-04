// Smoke test: app launches and the board screen appears.
// This test must NEVER be deleted, skipped, or weakened.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('board screen appears on launch', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      find.byKey(const Key('board_screen')),
      findsOneWidget,
      reason: 'Board screen must appear on launch',
    );
  });
}
