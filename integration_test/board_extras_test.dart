// Milestone 28: the splitting knife, the Golden Thread and a sealed jar,
// used by dragging on the real board.
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a knife splits, a Golden Thread raises, and a merge beside '
      'a sealed jar opens it', (tester) async {
    await SaveRepository().save(
      SaveState(
        items: const [
          SavedItem(itemId: 'knife_01', col: 1, row: 2),
          SavedItem(itemId: 'bakery_03', col: 2, row: 2),
          SavedItem(itemId: 'thread_01', col: 1, row: 4),
          SavedItem(itemId: 'bakery_01', col: 2, row: 4),
          SavedItem(itemId: 'breadjar_01', col: 3, row: 4),
        ],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
        ],
        manna: 60,
        mannaLastRegen: DateTime.now(),
        talents: 0,
        blessings: 0,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: const [],
        completedTasks: const [],
        tutorialStep: tutorialFinished,
        lastOrderSkip: null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: BoardScreen(playOpeningScene: false, playTutorial: false),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    // Safe: the board widget was just found, and it always has its game.
    final game = tester.widget<GameWidget<BoardGame>>(board).game!;
    expect(tester.takeException(), isNull);

    Offset centre(int col, int row) {
      final rect = tester.getRect(board);
      final byWidth = rect.width / BoardGame.cols;
      final byHeight = rect.height / BoardGame.rows;
      final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
      return Offset(
        rect.left +
            (rect.width - BoardGame.cols * cell) / 2 +
            (col + 0.5) * cell,
        rect.top +
            (rect.height - BoardGame.rows * cell) / 2 +
            (row + 0.5) * cell,
      );
    }

    Future<void> drag((int, int) from, (int, int) to) async {
      final start = centre(from.$1, from.$2);
      await tester.dragFrom(start, centre(to.$1, to.$2) - start);
      await tester.pump(const Duration(milliseconds: 600));
    }

    // The knife on the loaf: two of the tier below, and no knife.
    await drag((1, 2), (2, 2));
    expect(game.itemCounts()['knife_01'], isNull);
    expect(game.itemCounts()['bakery_03'], isNull);
    expect(game.itemCounts()['bakery_02'], 2);

    // The thread on the sheaf beside the sealed jar: the sheaf goes up a
    // tier, the thread is used, and the jar opens into its gift.
    await drag((1, 4), (2, 4));
    expect(tester.takeException(), isNull);
    final counts = game.itemCounts();
    expect(counts['thread_01'], isNull);
    expect(counts['bakery_01'], isNull);
    expect(counts['bakery_02'], 3);
    expect(counts['breadjar_01'], isNull);
    expect(counts['manna_jar_02'], 1);

    // What came out of the jar is a real Manna jar: tapping it asks.
    await tester.tapAt(centre(3, 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('use_item')), findsOneWidget);
    await tester.tap(find.byKey(const Key('use_item_keep')));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });
}
