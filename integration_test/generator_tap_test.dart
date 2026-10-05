// Milestone 4: tapping a generator spends Manna and spawns an item.
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping a generator spends 1 Manna', (
    WidgetTester tester,
  ) async {
    app.main();
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Manna: 10'), findsOneWidget);

    // Work out where the generator in column 2, bottom row is drawn.
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    final left = rect.left + (rect.width - BoardGame.cols * cell) / 2;
    final top = rect.top + (rect.height - BoardGame.rows * cell) / 2;
    final generatorCentre = Offset(
      left + 2.5 * cell,
      top + (BoardGame.rows - 0.5) * cell,
    );

    await tester.tapAt(generatorCentre);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Manna: 9'), findsOneWidget);

    // An empty cell is not a generator: tapping it must not spend Manna.
    await tester.tapAt(Offset(left + 5.5 * cell, top + 4.5 * cell));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Manna: 9'), findsOneWidget);
  });
}
