// Milestone 12: a first launch walks the player through the tutorial.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/main.dart' as app;

import 'helpers.dart';

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch: story, then guided merge and generator tap', (
    tester,
  ) async {
    await SaveRepository().clear();
    app.main();
    await skipOpeningScene(tester);
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    final steps = (await _content('tutorial') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final start = await _content('starting_board') as Map<String, dynamic>;
    final economy = await _content('economy') as Map<String, dynamic>;
    final max = economy['max_manna'] as int;
    final manna = start['manna'] as int;

    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    Offset centre(int col, int row) => Offset(
      rect.left + (rect.width - BoardGame.cols * cell) / 2 + (col + 0.5) * cell,
      rect.top + (rect.height - BoardGame.rows * cell) / 2 + (row + 0.5) * cell,
    );

    // While the tutorial runs, orders cannot be skipped away.
    expect(
      find.byWidgetPredicate((w) => w.key.toString().contains('order_skip_')),
      findsNothing,
    );

    // Step 1: the first hint asks for a merge.
    expect(steps[0]['done_when'], {'type': 'merge'});
    expect(find.byKey(const Key('tutorial_banner')), findsOneWidget);
    expect(text('tutorial_text'), steps[0]['text']);

    // Find two identical starting items and drag one onto the other.
    final items = (start['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final a = items.first;
    final b = items.skip(1).firstWhere((i) => i['item_id'] == a['item_id']);
    final from = centre(a['col'] as int, a['row'] as int);
    final to = centre(b['col'] as int, b['row'] as int);
    final game = tester.widget<GameWidget<BoardGame>>(board).game;
    final before = game?.itemCounts() ?? {};
    await tester.dragFrom(from, to - from);
    await tester.pump(const Duration(milliseconds: 500));
    final after = game?.itemCounts() ?? {};
    expect(
      after[a['item_id']] ?? 0,
      (before[a['item_id']] ?? 0) - 2,
      reason: 'the two items merged into one of the next tier',
    );

    // Step 2: now it asks for a generator tap.
    expect(steps[1]['done_when'], {'type': 'generator_tap'});
    expect(text('tutorial_text'), steps[1]['text']);
    final generator =
        (start['generators'] as List<dynamic>).first as Map<String, dynamic>;
    await tester.tapAt(
      centre(generator['col'] as int, generator['row'] as int),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // The tap was free (these early steps give free Manna)...
    expect(steps[1]['free_manna'], isTrue);
    expect(text('manna_count'), '$manna/$max');
    // ...it spawned an item, and the tutorial moved on to the first order.
    final afterTap = game?.itemCounts() ?? {};
    expect(
      afterTap.values.fold<int>(0, (n, c) => n + c),
      after.values.fold<int>(0, (n, c) => n + c) + 1,
    );
    expect(text('tutorial_text'), steps[2]['text']);

    await SaveRepository().clear();
  });
}
