// Milestone 28: a merge can leave a bubble holding an item. It can be left
// alone, or its item kept for Pearls.
import 'dart:convert';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

/// Luck that always says yes: every merge leaves a bubble.
class _Always implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a bubble after a merge: left, then kept for Pearls', (
    tester,
  ) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final levels = await _content('levels') as Map<String, dynamic>;
    final rules =
        (levels['unlocks'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .firstWhere((u) => u['feature'] == 'bubbles')['bubble']
            as Map<String, dynamic>;
    final perTier = rules['pearls_per_tier'] as int;
    // Chapters 1 and 2 finished: well past the level bubbles begin at.
    await SaveRepository().save(
      SaveState(
        items: const [
          SavedItem(itemId: 'bakery_01', col: 2, row: 3),
          SavedItem(itemId: 'bakery_01', col: 3, row: 3),
        ],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
        ],
        manna: 60,
        mannaLastRegen: DateTime.now(),
        talents: 0,
        blessings: 0,
        pearls: 20,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: [
          for (final o in orders)
            if ((o['chapter'] as int) < 3) o['id'] as String,
        ],
        completedTasks: [
          for (final c in chapters.take(2))
            for (final t in c['tasks'] as List<dynamic>)
              (t as Map<String, dynamic>)['id'] as String,
        ],
        tutorialStep: tutorialFinished,
        endingsSeen: [for (final c in chapters.take(2)) c['id'] as String],
        lastOrderSkip: null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          playOpeningScene: false,
          playTutorial: false,
          luck: _Always(),
        ),
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

    final bubble = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('bubble_at_'),
    );
    expect(bubble, findsNothing);

    // Merge the two sheaves: a bubble appears.
    await tester.dragFrom(centre(2, 3), centre(3, 3) - centre(2, 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(game.itemCounts(), {'bakery_02': 1});
    expect(bubble, findsOneWidget);

    String pearls() =>
        tester.widget<Text>(find.byKey(const Key('pearls_count'))).data ?? '';
    expect(pearls(), '20');

    // Tapping it asks; "leave it" changes nothing.
    await tester.tap(bubble);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('bubble_dialog')), findsOneWidget);
    // No ads are set up in this test, so no ad is offered.
    expect(find.byKey(const Key('bubble_ad')), findsNothing);
    await tester.tap(find.byKey(const Key('bubble_leave')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(bubble, findsOneWidget);
    expect(pearls(), '20');

    // Kept for Pearls: the price is paid and the item lands on the board.
    await tester.tap(bubble);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('bubble_pearls')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(bubble, findsNothing);
    final counts = game.itemCounts();
    expect(counts.length, 2);
    expect(counts['bakery_02'], 1);
    // This luck always gives the next tier up.
    expect(counts['bakery_03'], 1);
    expect(pearls(), '${20 - perTier * 3}');

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });
}
