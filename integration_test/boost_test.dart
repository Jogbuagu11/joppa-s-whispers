// Milestone 27: from level 15 the Manna pill carries a boost chip; with 2x
// on, a generator tap costs twice the Manna. Rare finds can be sold.
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

/// Luck that always draws the last outcome of any list.
class _Luckiest implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.999999;
  @override
  int nextInt(int max) => max - 1;
}

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<BoardGame> open(WidgetTester tester, Key key, {Random? luck}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          key: key,
          playOpeningScene: false,
          playTutorial: false,
          luck: luck,
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

  /// The middle of board cell ([col], [row]) on the screen.
  Offset cellCentre(WidgetTester tester, int col, int row) {
    final rect = tester.getRect(find.byType(GameWidget<BoardGame>));
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    return Offset(
      rect.left + (rect.width - BoardGame.cols * cell) / 2 + (col + 0.5) * cell,
      rect.top + (rect.height - BoardGame.rows * cell) / 2 + (row + 0.5) * cell,
    );
  }

  testWidgets('a rare find can be kept or sold for Talents', (tester) async {
    final chains = (await _content('chains') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final honey =
        (chains.firstWhere((c) => c['id'] == 'honey')['tiers'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .first;
    final id = honey['item_id'] as String;
    final price = honey['sell'] as int;
    await SaveRepository().save(
      SaveState(
        items: [SavedItem(itemId: id, col: 3, row: 4)],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
        ],
        manna: 60,
        mannaLastRegen: DateTime.now(),
        talents: 7,
        blessings: 0,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: const [],
        completedTasks: const [],
        tutorialStep: tutorialFinished,
        lastOrderSkip: null,
      ),
    );
    final game = await open(tester, const Key('sell'));
    String talents() =>
        tester.widget<Text>(find.byKey(const Key('talents_count'))).data ?? '';
    expect(talents(), '7');

    // Tapping it asks; "keep" changes nothing.
    await tester.tapAt(cellCentre(tester, 3, 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('use_item')), findsOneWidget);
    expect(find.byKey(const Key('use_item_use')), findsNothing);
    await tester.tap(find.byKey(const Key('use_item_keep')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.itemCounts()[id], 1);
    expect(talents(), '7');

    // Lifted by a finger and sold meanwhile: it goes, paid for once, and
    // letting go does not bring it back.
    final finger = await tester.startGesture(cellCentre(tester, 3, 4));
    await tester.pump(const Duration(milliseconds: 100));
    await finger.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.sellItemAt(3, 4), isTrue);
    await finger.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(game.itemCounts()[id], isNull);
    expect(talents(), '${7 + price}');
    expect(game.sellItemAt(3, 4), isFalse);
    game.placeItem(game.itemCatalog[id] ?? (throw StateError('no $id')));
    await tester.pump(const Duration(milliseconds: 300));
    final again = game.snapshotItems().single;

    // Selling takes it off the board and pays its price.
    await tester.tapAt(cellCentre(tester, again.col, again.row));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('use_item_sell')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(game.itemCounts()[id], isNull);
    expect(talents(), '${7 + price * 2}');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });

  testWidgets('a lucky boosted tap lifts the item further and says so', (
    tester,
  ) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    await SaveRepository().save(
      SaveState(
        items: const [],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
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
        tutorialStep: tutorialFinished,
        endingsSeen: [for (final c in chapters.take(2)) c['id'] as String],
        lastOrderSkip: null,
        boost: 1,
      ),
    );
    final game = await open(tester, const Key('lucky'), luck: _Luckiest());
    final pantry = game.generatorPlacements.firstWhere(
      (p) => p.gen.generatorId == 'gen_pantry',
    );
    await tester.tapAt(cellCentre(tester, pantry.col, pantry.row));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    // 2x lifts one tier; the luckiest draw multiplies that lift, so the
    // item is well above the second tier. The price is still 2 Manna.
    final made = game.snapshotItems().single.itemId;
    final tier = int.parse(made.substring(made.length - 2));
    expect(tier, greaterThan(2), reason: made);
    expect(find.byKey(const Key('lucky_toast')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });

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

    final pantry = game.generatorPlacements.firstWhere(
      (p) => p.gen.generatorId == 'gen_pantry',
    );
    final centre = cellCentre(tester, pantry.col, pantry.row);

    // The usual tap first.
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 400));
    expect(text('manna_count'), '${60 - cost}/$max');

    // Switch 2x on: the chip and the generator's price say so.
    await tester.tap(find.byKey(const Key('boost_chip')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(text('boost_label'), '×2');
    expect(game.generatorLabel(pantry.gen), '${cost * 2}M');
    final before = {for (final i in game.snapshotItems()) (i.col, i.row)};
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 400));
    expect(text('manna_count'), '${60 - cost - cost * 2}/$max');
    // Exactly one new item, and it is above the first tier (of the
    // pantry's chain or, one time in ten, of its rare chain).
    final added = [
      for (final i in game.snapshotItems())
        if (!before.contains((i.col, i.row))) i.itemId,
    ];
    expect(added, hasLength(1));
    expect(added.single.endsWith('_02'), isTrue, reason: added.single);

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
