// Milestone 26: a charged generator arrives at its level, gives its charges
// for no Manna, then rests, and its rest survives closing the game.
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

  testWidgets('the Fig Tree: arrives at its level, charges, then rests', (
    tester,
  ) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final generators = (await _content('generators') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final fig = generators.firstWhere((g) => g['id'] == 'gen_fig');
    final charges = fig['charges'] as int;
    final economy = await _content('economy') as Map<String, dynamic>;
    final max = economy['max_manna'] as int;
    final firstTasks = [
      for (final t in (chapters.first['tasks'] as List<dynamic>).take(5))
        (t as Map<String, dynamic>)['id'] as String,
    ];

    // A game five tasks in (past the level the Fig Tree waits for), saved
    // by a build that had never heard of it.
    await SaveRepository().save(
      SaveState(
        items: const [],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
          SavedGenerator(generatorId: 'gen_tree', level: 1, col: 4, row: 8),
        ],
        manna: 40,
        mannaLastRegen: DateTime.now(),
        talents: 0,
        blessings: 0,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: const [],
        completedTasks: firstTasks,
        tutorialStep: 99,
        lastOrderSkip: null,
      ),
    );

    final board = find.byType(GameWidget<BoardGame>);
    Future<BoardGame> open(Key key) async {
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
      // Safe: the board widget was just found, and it always has its game.
      return game!;
    }

    var game = await open(const Key('first'));
    String manna() =>
        tester.widget<Text>(find.byKey(const Key('manna_count'))).data ?? '';
    final placed = game.generatorPlacements
        .where((p) => p.gen.generatorId == 'gen_fig')
        .toList();
    expect(placed, hasLength(1), reason: 'the Fig Tree has arrived');
    expect(game.generatorLabel(placed.single.gen), '×$charges');

    // Where it is drawn.
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    final centre = Offset(
      rect.left +
          (rect.width - BoardGame.cols * cell) / 2 +
          (placed.single.col + 0.5) * cell,
      rect.top +
          (rect.height - BoardGame.rows * cell) / 2 +
          (placed.single.row + 0.5) * cell,
    );

    final itemsBefore = game.snapshotItems().length;
    for (int i = 0; i < charges + 2; i++) {
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 300));
    }
    // Every charge gave an item; the extra taps gave nothing; no Manna used.
    expect(game.snapshotItems().length, itemsBefore + charges);
    expect(manna(), '40/$max');
    expect(game.generatorLabel(placed.single.gen), contains(':'));
    expect(tester.takeException(), isNull);

    // Close and reopen: it is still resting, and nothing is given twice.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    game = await open(const Key('reopened'));
    final again = game.generatorPlacements
        .where((p) => p.gen.generatorId == 'gen_fig')
        .single;
    expect(game.generatorLabel(again.gen), contains(':'));
    expect(game.snapshotItems().length, itemsBefore + charges);
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.snapshotItems().length, itemsBefore + charges);
    await SaveRepository().clear();
  });
}
