// Milestone 27: from level 15 the Manna pill carries a boost chip; with 2x
// on, a generator tap costs twice the Manna.
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
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    final game = tester.widget<GameWidget<BoardGame>>(board).game;
    // Safe: the board widget was just found, and it always has its game.
    return game!;
  }

  testWidgets('before level 15 there is no boost chip', (tester) async {
    await SaveRepository().clear();
    await open(tester, const Key('new'));
    expect(find.byKey(const Key('boost_chip')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('from level 15: 2x costs twice the Manna, and is remembered', (
    tester,
  ) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final economy = await _content('economy') as Map<String, dynamic>;
    final max = economy['max_manna'] as int;
    final cost = economy['generator_tap_cost'] as int;
    // Chapters 1 and 2 finished: well past level 15.
    await SaveRepository().save(
      SaveState(
        items: const [],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
          SavedGenerator(generatorId: 'gen_tree', level: 1, col: 4, row: 8),
          SavedGenerator(generatorId: 'gen_chest', level: 1, col: 3, row: 8),
        ],
        manna: 60,
        mannaLastRegen: DateTime.now(),
        talents: 0,
        blessings: 0,
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
        tutorialStep: 99,
        endingsSeen: [for (final c in chapters.take(2)) c['id'] as String],
        lastOrderSkip: null,
      ),
    );
    var game = await open(tester, const Key('first'));
    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';
    expect(tester.takeException(), isNull);
    expect(text('boost_label'), '×1');

    // Where the pantry is drawn.
    final board = find.byType(GameWidget<BoardGame>);
    final pantry = game.generatorPlacements.firstWhere(
      (p) => p.gen.generatorId == 'gen_pantry',
    );
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    final centre = Offset(
      rect.left +
          (rect.width - BoardGame.cols * cell) / 2 +
          (pantry.col + 0.5) * cell,
      rect.top +
          (rect.height - BoardGame.rows * cell) / 2 +
          (pantry.row + 0.5) * cell,
    );

    // The usual tap first.
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 400));
    expect(text('manna_count'), '${60 - cost}/$max');

    // Switch 2x on: the chip and the generator's price say so.
    await tester.tap(find.byKey(const Key('boost_chip')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(text('boost_label'), '×2');
    expect(game.generatorLabel(pantry.gen), '${cost * 2}M');
    final before = game.snapshotItems().length;
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 400));
    expect(text('manna_count'), '${60 - cost - cost * 2}/$max');
    expect(game.snapshotItems().length, before + 1);
    // The item is above the first tier (or, one time in ten, the rare
    // chain's first).
    final newest = game.snapshotItems().map((i) => i.itemId).toList();
    expect(
      newest.any((id) => id.startsWith('honey_') || !id.endsWith('_01')),
      isTrue,
    );

    // 4x is not open yet: the next tap of the chip turns boost off.
    await tester.tap(find.byKey(const Key('boost_chip')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(text('boost_label'), '×1');
    await tester.tap(find.byKey(const Key('boost_chip')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(text('boost_label'), '×2');

    // Closed and reopened, 2x is still on.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    game = await open(tester, const Key('reopened'));
    expect(text('boost_label'), '×2');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });
}
