// Milestone 10: a story task spends Blessings, plays its scene and moves the
// chapter on.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('doing a task spends Blessings and plays its scene', (
    tester,
  ) async {
    await SaveRepository().clear();
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

    final chapter =
        (await _content('chapters') as List<dynamic>).first
            as Map<String, dynamic>;
    final tasks = (chapter['tasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final scenes = (await _content('scenes') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final first = tasks[0];
    final second = tasks[1];
    final cost = first['cost_blessings'] as int;

    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';
    FilledButton taskButton() =>
        tester.widget<FilledButton>(find.byKey(const Key('task_button')));

    // The first task is shown, but with no Blessings it cannot be started.
    expect(text('task_title'), first['title']);
    expect(text('task_progress'), contains('0/${tasks.length}'));
    expect(text('task_progress'), contains(chapter['title'] as String));
    expect(text('blessings_count'), '0');
    expect(taskButton().onPressed, isNull);

    // Earn Blessings by delivering whichever order is ready.
    final ready = find.byWidgetPredicate(
      (w) =>
          w is FilledButton &&
          w.onPressed != null &&
          w.key.toString().contains('order_deliver_'),
    );
    expect(ready, findsWidgets, reason: 'the starting board fills one order');
    await tester.tap(ready.first);
    await tester.pump(const Duration(milliseconds: 500));
    final earned = int.parse(text('blessings_count'));
    expect(earned, greaterThanOrEqualTo(cost));
    expect(taskButton().onPressed, isNotNull);

    // Do the task: Blessings are spent and its scene opens.
    await tester.tap(find.byKey(const Key('task_button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    final scene = scenes.firstWhere((s) => s['id'] == first['scene_id']);
    final firstLine =
        (scene['lines'] as List<dynamic>).first as Map<String, dynamic>;
    expect(find.byKey(const Key('scene_screen')), findsOneWidget);
    expect(text('scene_text'), firstLine['text']);

    await tester.tap(find.byKey(const Key('scene_skip')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // A task that restores part of the bakehouse then shows the bakehouse.
    if (first['restores_area'] != null) {
      expect(find.byKey(const Key('location_screen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('location_continue')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
    }

    // Back on the board: paid for, counted, and the next task is up.
    expect(find.byKey(const Key('scene_screen')), findsNothing);
    expect(text('blessings_count'), '${earned - cost}');
    expect(text('task_progress'), contains('1/${tasks.length}'));
    expect(text('task_title'), second['title']);
    if (earned - cost < (second['cost_blessings'] as int)) {
      expect(taskButton().onPressed, isNull);
    }

    // Close and reopen: the task stays done and the Blessings stay spent.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(
      const MaterialApp(
        home: BoardScreen(
          key: Key('reopened'),
          playOpeningScene: false,
          playTutorial: false,
        ),
      ),
    );
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(text('task_progress'), contains('1/${tasks.length}'));
    expect(text('task_title'), second['title']);
    expect(text('blessings_count'), '${earned - cost}');

    await SaveRepository().clear();
  });
}
