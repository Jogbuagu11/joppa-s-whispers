// Milestone 4: tapping a generator spends Manna and spawns an item.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping a generator spends 1 Manna', (
    WidgetTester tester,
  ) async {
    app.main();
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    // The opening board is defined in content, so read it from there.
    final start =
        jsonDecode(await rootBundle.loadString('content/starting_board.json'))
            as Map<String, dynamic>;
    final manna = start['manna'] as int;
    final generator =
        (start['generators'] as List<dynamic>).first as Map<String, dynamic>;
    final genCol = generator['col'] as int;
    final genRow = generator['row'] as int;
    expect(find.text('Manna: $manna'), findsOneWidget);

    // Work out where that generator is drawn.
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    final left = rect.left + (rect.width - BoardGame.cols * cell) / 2;
    final top = rect.top + (rect.height - BoardGame.rows * cell) / 2;
    final generatorCentre = Offset(
      left + (genCol + 0.5) * cell,
      top + (genRow + 0.5) * cell,
    );

    await tester.tapAt(generatorCentre);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Manna: ${manna - 1}'), findsOneWidget);

    // An empty cell is not a generator: tapping it must not spend Manna.
    await tester.tapAt(Offset(left + 5.5 * cell, top + 4.5 * cell));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Manna: ${manna - 1}'), findsOneWidget);
  });
}
