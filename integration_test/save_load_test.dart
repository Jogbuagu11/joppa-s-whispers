// Milestone 8: closing and reopening restores the exact board and progress.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final board = find.byType(GameWidget<BoardGame>);

  Future<BoardGame> open(WidgetTester tester, Key key) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          key: key,
          playOpeningScene: false,
          playTutorial: false,
        ),
      ),
    );
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    final game = tester.widget<GameWidget<BoardGame>>(board).game;
    expect(game, isNotNull);
    // The check above guarantees this is not null.
    return game!;
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data ?? '';

  testWidgets('progress survives closing and reopening', (tester) async {
    await SaveRepository().clear();
    final start =
        jsonDecode(await rootBundle.loadString('content/starting_board.json'))
            as Map<String, dynamic>;
    final generator =
        (start['generators'] as List<dynamic>).first as Map<String, dynamic>;

    // --- First session: change the board, Manna, wallet and orders. ---
    var game = await open(tester, const Key('first'));
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    Offset centre(int col, int row) => Offset(
      rect.left + (rect.width - BoardGame.cols * cell) / 2 + (col + 0.5) * cell,
      rect.top + (rect.height - BoardGame.rows * cell) / 2 + (row + 0.5) * cell,
    );

    // Spawn three items.
    for (int i = 0; i < 3; i++) {
      await tester.tapAt(
        centre(generator['col'] as int, generator['row'] as int),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    // Move the first starting item to the far corner (a pure move).
    final first =
        (start['items'] as List<dynamic>).first as Map<String, dynamic>;
    await tester.dragFrom(
      centre(first['col'] as int, first['row'] as int),
      centre(BoardGame.cols - 1, 0) -
          centre(first['col'] as int, first['row'] as int),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // Deliver whichever order is ready, if any.
    final ready = find.byWidgetPredicate(
      (w) => w is FilledButton && w.onPressed != null,
    );
    if (ready.evaluate().isNotEmpty) {
      await tapReady(tester, ready.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    final itemsBefore = [
      for (final i in game.snapshotItems()) '${i.itemId}@${i.col},${i.row}',
    ]..sort();
    final mannaBefore = text(tester, 'manna_count');
    final talentsBefore = text(tester, 'talents_count');
    final blessingsBefore = text(tester, 'blessings_count');
    final cardsBefore = [
      for (final e
          in find
              .byWidgetPredicate(
                (w) => w.key.toString().contains('order_card_'),
              )
              .evaluate())
        e.widget.key.toString(),
    ];
    expect(itemsBefore.length, greaterThan(3));
    // The move, the delivery and the new order card all really happened.
    expect(
      itemsBefore,
      contains('${first['item_id']}@${BoardGame.cols - 1},0'),
    );
    expect(talentsBefore, isNot('0'));
    expect(blessingsBefore, isNot('0'));
    final generatorsBefore = [
      for (final g in game.snapshotGenerators())
        '${g.generatorId}@${g.col},${g.row}:${g.level}',
    ];
    expect(mannaBefore, isNot(startsWith('${start['manna']}/')));

    // Wait past the 2-second save delay, then close the screen.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(await SaveRepository().load(), isNotNull);

    // --- Second session: everything is as it was left. ---
    game = await open(tester, const Key('second'));
    final itemsAfter = [
      for (final i in game.snapshotItems()) '${i.itemId}@${i.col},${i.row}',
    ]..sort();
    expect(itemsAfter, itemsBefore);
    expect([
      for (final g in game.snapshotGenerators())
        '${g.generatorId}@${g.col},${g.row}:${g.level}',
    ], generatorsBefore);
    expect(text(tester, 'manna_count'), mannaBefore);
    expect(text(tester, 'talents_count'), talentsBefore);
    expect(text(tester, 'blessings_count'), blessingsBefore);
    expect([
      for (final e
          in find
              .byWidgetPredicate(
                (w) => w.key.toString().contains('order_card_'),
              )
              .evaluate())
        e.widget.key.toString(),
    ], cardsBefore);

    await SaveRepository().clear();
  });
}
