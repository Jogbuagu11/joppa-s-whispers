// Milestone 6: the Manna bar counts down and the out-of-Manna popup appears.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('running out of Manna shows the popup', (tester) async {
    // Start almost empty so the test does not depend on the starting amount.
    const manna = 3;
    await SaveRepository().clear();
    await tester.pumpWidget(
      const MaterialApp(home: BoardScreen(startingMannaOverride: manna)),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    final start =
        jsonDecode(await rootBundle.loadString('content/starting_board.json'))
            as Map<String, dynamic>;
    final economy =
        jsonDecode(await rootBundle.loadString('content/economy.json'))
            as Map<String, dynamic>;
    final max = economy['max_manna'] as int;
    final cost = economy['generator_tap_cost'] as int;
    final generator =
        (start['generators'] as List<dynamic>).first as Map<String, dynamic>;

    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    final generatorCentre = Offset(
      rect.left +
          (rect.width - BoardGame.cols * cell) / 2 +
          ((generator['col'] as int) + 0.5) * cell,
      rect.top +
          (rect.height - BoardGame.rows * cell) / 2 +
          ((generator['row'] as int) + 0.5) * cell,
    );
    String countText() =>
        tester.widget<Text>(find.byKey(const Key('manna_count'))).data ?? '';

    // The bar shows the starting Manna and a running countdown.
    expect(countText(), '$manna/$max');
    expect(
      tester.widget<Text>(find.byKey(const Key('manna_timer'))).data,
      startsWith('+1 in '),
    );

    // Spend all of it.
    final taps = manna ~/ cost;
    for (int i = 0; i < taps; i++) {
      await tester.tapAt(generatorCentre);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(countText(), '${manna - taps * cost}/$max');
    expect(find.byKey(const Key('out_of_manna_popup')), findsNothing);

    // One more tap cannot be paid for: the popup appears, nothing is spent.
    await tester.tapAt(generatorCentre);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('out_of_manna_popup')), findsOneWidget);
    expect(countText(), '${manna - taps * cost}/$max');

    await tester.tap(find.byKey(const Key('out_of_manna_ok')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('out_of_manna_popup')), findsNothing);
  });
}
