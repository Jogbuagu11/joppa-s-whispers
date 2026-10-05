// Smoke test: app launches and the board screen appears.
// This test must NEVER be deleted, skipped, or weakened.
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('board screen appears on launch', (WidgetTester tester) async {
    app.main();
    // The Flame board redraws every frame, so pumpAndSettle would never finish.
    // Pump frames for up to 20 seconds until loading is done.
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final loaded =
          find.byType(GameWidget<BoardGame>).evaluate().isNotEmpty ||
          find.byKey(const Key('board_error')).evaluate().isNotEmpty;
      if (loaded) break;
    }
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const Key('board_screen')),
      findsOneWidget,
      reason: 'Board screen must appear on launch',
    );
    expect(
      find.byKey(const Key('board_error')),
      findsNothing,
      reason: 'Board must load without showing an error',
    );
    expect(
      find.byType(GameWidget<BoardGame>),
      findsOneWidget,
      reason: 'The merge board itself must be on screen',
    );
  });
}
