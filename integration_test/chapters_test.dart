// Milestone 23: a player who has finished a chapter finds the story at the
// next one, its orders on the cards, and its generator on the board.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The generators a player has before each chapter begins, and the one the
  // chapter brings (with the first few letters of the items it makes).
  const before = [
    SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
    SavedGenerator(generatorId: 'gen_tree', level: 1, col: 4, row: 8),
    SavedGenerator(generatorId: 'gen_chest', level: 1, col: 3, row: 8),
    SavedGenerator(generatorId: 'gen_armor', level: 1, col: 5, row: 8),
    SavedGenerator(generatorId: 'gen_loom', level: 1, col: 1, row: 8),
    SavedGenerator(generatorId: 'gen_press', level: 1, col: 0, row: 8),
  ];
  const cases = [
    (finished: 1, has: 2, brings: 'gen_chest', makes: 'church_', blocked: true),
    (finished: 2, has: 3, brings: 'gen_armor', makes: 'armor_', blocked: false),
    (finished: 3, has: 4, brings: 'gen_loom', makes: 'loom_', blocked: false),
    (finished: 4, has: 5, brings: 'gen_press', makes: 'oil_', blocked: false),
    (finished: 5, has: 6, brings: 'gen_scribe', makes: 'word_', blocked: false),
  ];

  for (final c in cases) {
    testWidgets('finishing Chapter ${c.finished} opens Chapter '
        '${c.finished + 1}', (tester) async {
      final chapters = (await _content('chapters') as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final orders = (await _content('orders') as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final board = await _content('starting_board') as Map<String, dynamic>;
      final home = (board['generators'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((g) => g['generator_id'] == c.brings);
      final homeCol = home['col'] as int;
      final homeRow = home['row'] as int;
      List<Map<String, dynamic>> tasksOf(int i) =>
          (chapters[i]['tasks'] as List<dynamic>).cast<Map<String, dynamic>>();

      // A game saved the moment the chapter was finished, by a build that
      // knew nothing of the next one. In the first case an item sits exactly
      // where the new generator would like to go.
      await SaveRepository().save(
        SaveState(
          items: [
            if (c.blocked)
              SavedItem(itemId: 'bakery_01', col: homeCol, row: homeRow),
          ],
          generators: before.take(c.has).toList(),
          manna: 50,
          mannaLastRegen: DateTime.now(),
          talents: 0,
          blessings: 6,
          activeOrders: const [],
          pendingOrders: const [],
          completedOrders: [
            for (final o in orders)
              if ((o['chapter'] as int) <= c.finished) o['id'] as String,
          ],
          completedTasks: [
            for (int i = 0; i < c.finished; i++)
              for (final t in tasksOf(i)) t['id'] as String,
          ],
          tutorialStep: tutorialFinished,
          endingsSeen: [for (int i = 1; i <= c.finished; i++) 'ch$i'],
          lastOrderSkip: null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          // A fresh screen for each case.
          key: ValueKey(c.finished),
          home: const BoardScreen(playOpeningScene: false, playTutorial: false),
        ),
      );
      final boardFinder = find.byType(GameWidget<BoardGame>);
      for (int i = 0; i < 200 && boardFinder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      // The story has moved on to the next chapter's first task.
      expect(
        tester.widget<Text>(find.byKey(const Key('task_title'))).data,
        tasksOf(c.finished).first['title'],
      );

      // Its orders are on the cards (the first three, in order).
      final next = [
        for (final o in orders)
          if (o['chapter'] == c.finished + 1) o['id'] as String,
      ];
      for (final id in next.take(3)) {
        expect(find.byKey(Key('order_card_$id')), findsOneWidget);
      }

      // Its generator has arrived: at its home cell, or right beside it
      // when an item was in the way (the item is untouched).
      final game = tester.widget<GameWidget<BoardGame>>(boardFinder).game;
      expect(game, isNotNull);
      if (game == null) return;
      final arrived = game.generatorPlacements
          .where((p) => p.gen.generatorId == c.brings)
          .toList();
      expect(arrived, hasLength(1));
      final col = arrived.single.col;
      final row = arrived.single.row;
      expect((col - homeCol).abs() + (row - homeRow).abs(), c.blocked ? 1 : 0);
      expect(game.generatorPlacements, hasLength(c.has + 1));
      expect(game.snapshotItems(), hasLength(c.blocked ? 1 : 0));

      // Tapping it makes one of the new chain's items.
      final rect = tester.getRect(boardFinder);
      final byWidth = rect.width / BoardGame.cols;
      final byHeight = rect.height / BoardGame.rows;
      final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
      await tester.tapAt(
        Offset(
          rect.left +
              (rect.width - BoardGame.cols * cell) / 2 +
              (col + 0.5) * cell,
          rect.top +
              (rect.height - BoardGame.rows * cell) / 2 +
              (row + 0.5) * cell,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        game.snapshotItems().where((i) => i.itemId.startsWith(c.makes)),
        hasLength(1),
      );
      // Leave nothing behind for the next case.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
    });
  }
}
