// Shared steps for the device tests.
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';

/// A new game opens with a story scene. Waits for it (or for the board, if
/// there is no scene) and skips it, so the test can get to the board.
Future<void> skipOpeningScene(WidgetTester tester) async {
  final skip = find.byKey(const Key('scene_skip'));
  final board = find.byType(GameWidget<BoardGame>);
  for (int i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (skip.evaluate().isNotEmpty) break;
    if (board.evaluate().isNotEmpty) {
      // The board is built a moment before the scene slides over it, so give
      // the scene a chance to appear before deciding there is none.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      break;
    }
  }
  if (skip.evaluate().isNotEmpty) {
    await tester.tap(skip);
    // Let the scene slide away.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Finishing a task can reach a new level, which shows a message. Closes it
/// if it is there, so the test can get back to the board.
Future<void> dismissLevelUp(WidgetTester tester) async {
  final button = find.byKey(const Key('level_up_continue'));
  for (int i = 0; i < 10 && button.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (button.evaluate().isEmpty) return;
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}
