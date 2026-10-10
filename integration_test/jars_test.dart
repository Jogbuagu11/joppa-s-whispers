// Milestone 29: Jars of Clay. A jar on the board shows what it may hold and
// is opened only on "Open"; jars are sold under the wheel, except where the
// law forbids buying random rewards.
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

import 'helpers.dart';

/// Luck that always draws the first prize.
class _First implements Random {
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

  Future<BoardGame> open(WidgetTester tester, String country) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    await SaveRepository().save(
      SaveState(
        items: const [SavedItem(itemId: 'clayjar_01', col: 3, row: 4)],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
        ],
        manna: 40,
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
          key: Key(country),
          playOpeningScene: false,
          playTutorial: false,
          luck: _First(),
          country: country,
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    // Safe: the board widget was just found, and it always has its game.
    return tester.widget<GameWidget<BoardGame>>(board).game!;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Offset centre(WidgetTester tester, int col, int row) {
    final rect = tester.getRect(find.byType(GameWidget<BoardGame>));
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    return Offset(
      rect.left + (rect.width - BoardGame.cols * cell) / 2 + (col + 0.5) * cell,
      rect.top + (rect.height - BoardGame.rows * cell) / 2 + (row + 0.5) * cell,
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  }

  testWidgets('a jar on the board is opened only on Open; a jar is bought '
      'under the wheel and lands on the board', (tester) async {
    final chance = await _content('chance') as Map<String, dynamic>;
    final kinds =
        (chance['jars'] as Map<String, dynamic>)['kinds']
            as Map<String, dynamic>;
    final first =
        ((kinds['clay'] as Map<String, dynamic>)['prizes'] as List<dynamic>)
                .first
            as Map<String, dynamic>;
    final price =
        (kinds['treasure'] as Map<String, dynamic>)['pearl_price'] as int;
    final game = await open(tester, 'US');
    expect(tester.takeException(), isNull);
    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';

    // Tapping the jar shows what it may hold; "keep" leaves it be.
    await tester.tapAt(centre(tester, 3, 4));
    await settle(tester);
    expect(find.byKey(const Key('jar_dialog')), findsOneWidget);
    expect(find.byKey(Key('odds_${first['id']}')), findsOneWidget);
    await tester.tap(find.byKey(const Key('use_item_keep')));
    await settle(tester);
    expect(game.itemCounts()['clayjar_01'], 1);
    expect(text('talents_count'), '0');

    // Opened: the jar is gone and its prize is named and given.
    await tester.tapAt(centre(tester, 3, 4));
    await settle(tester);
    await tester.tap(find.byKey(const Key('jar_open')));
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('wheel_prize_name'))).data,
      first['name'],
    );
    await tester.tap(find.byKey(const Key('wheel_prize_ok')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(game.itemCounts()['clayjar_01'], isNull);
    expect(text('talents_count'), '${first['talents']}');

    // Under the wheel: the Treasure Jar, its odds, and buying one.
    await tapOnStrip(tester, 'wheel_button');
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('jar_buy_treasure')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('jar_odds_treasure')));
    await settle(tester);
    expect(find.byKey(const Key('jar_odds_panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('odds_close')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('jar_buy_treasure')));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(text('pearls_count'), '${20 - price}');
    expect(game.itemCounts()['treasurejar_01'], 1);
    await close(tester);
  });

  testWidgets('where buying random rewards is forbidden no jars are sold, '
      'but a jar already owned can still be opened', (tester) async {
    final game = await open(tester, 'BE');
    await tapOnStrip(tester, 'wheel_button');
    await settle(tester);
    expect(find.byKey(const Key('wheel_screen')), findsOneWidget);
    expect(find.byKey(const Key('jar_buy_treasure')), findsNothing);
    expect(find.byKey(const Key('jar_buy_golden')), findsNothing);
    await tester.pageBack();
    await settle(tester);
    await tester.tapAt(centre(tester, 3, 4));
    await settle(tester);
    await tester.tap(find.byKey(const Key('jar_open')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('wheel_prize_ok')));
    await settle(tester);
    expect(game.itemCounts()['clayjar_01'], isNull);
    await close(tester);
  });
}
