// Milestone 23 (Chapter 2): a player who has finished Chapter 1 finds the
// story at the well, Chapter 2's orders on the cards, and the House Church
// generator on the board.
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

  testWidgets('finishing Chapter 1 opens Chapter 2', (tester) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    List<Map<String, dynamic>> tasksOf(int i) =>
        (chapters[i]['tasks'] as List<dynamic>).cast<Map<String, dynamic>>();

    // A game saved the moment Chapter 1 was finished, by a build that knew
    // nothing of Chapter 2: two generators, and an item sitting exactly
    // where the new generator would like to go.
    await SaveRepository().save(
      SaveState(
        items: const [SavedItem(itemId: 'bakery_01', col: 3, row: 8)],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
          SavedGenerator(generatorId: 'gen_tree', level: 1, col: 4, row: 8),
        ],
        manna: 50,
        mannaLastRegen: DateTime.now(),
        talents: 0,
        blessings: 6,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: [
          for (final o in orders)
            if (o['chapter'] == 1) o['id'] as String,
        ],
        completedTasks: [for (final t in tasksOf(0)) t['id'] as String],
        tutorialStep: tutorialFinished,
        endingsSeen: const ['ch1'],
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
    expect(tester.takeException(), isNull);

    // The story has moved on to Chapter 2's first task.
    expect(
      tester.widget<Text>(find.byKey(const Key('task_title'))).data,
      tasksOf(1).first['title'],
    );

    // Chapter 2's orders are on the cards (the first three, in order).
    final chapterTwo = [
      for (final o in orders)
        if (o['chapter'] == 2) o['id'] as String,
    ];
    for (final id in chapterTwo.take(3)) {
      expect(find.byKey(Key('order_card_$id')), findsOneWidget);
    }

    // The Elder's Chest has arrived: next to its home cell, because an item
    // was in the way. The item is untouched.
    final game = tester.widget<GameWidget<BoardGame>>(board).game;
    expect(game, isNotNull);
    if (game == null) return;
    final chest = game.generatorPlacements
        .where((p) => p.gen.generatorId == 'gen_chest')
        .toList();
    expect(chest, hasLength(1));
    expect((chest.single.col, chest.single.row), (3, 7));
    expect(game.generatorPlacements, hasLength(3));
    expect(game.snapshotItems().single.itemId, 'bakery_01');

    // Tapping it makes a House Church item (and spends Manna).
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    await tester.tapAt(
      Offset(
        rect.left + (rect.width - BoardGame.cols * cell) / 2 + 3.5 * cell,
        rect.top + (rect.height - BoardGame.rows * cell) / 2 + 7.5 * cell,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      game.snapshotItems().where((i) => i.itemId.startsWith('church_')),
      hasLength(1),
    );
  });
}
