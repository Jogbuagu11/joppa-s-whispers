// Milestone 25: story tasks give XP; reaching a level refills Manna, pays
// Talents and says so, exactly once, and the level survives a restart.
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

  testWidgets('the first task reaches level 2', (tester) async {
    await SaveRepository().clear();
    final levels = await _content('levels') as Map<String, dynamic>;
    final second =
        (levels['levels'] as List<dynamic>).first as Map<String, dynamic>;
    final reward = second['talents'] as int;
    final economy = await _content('economy') as Map<String, dynamic>;
    final max = economy['max_manna'] as int;

    // Start with little Manna, so the refill can be seen.
    await tester.pumpWidget(
      const MaterialApp(
        home: BoardScreen(
          playOpeningScene: false,
          playTutorial: false,
          startingMannaOverride: 7,
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
    }

    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle();
    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';

    // A new game: level 1, the badge fits in the top row.
    expect(tester.takeException(), isNull);
    expect(text('level_number'), '1');
    expect(text('manna_count'), '7/$max');
    expect(find.byKey(const Key('level_up')), findsNothing);

    // Earn a Blessing and do the first task.
    final ready = find.byWidgetPredicate(
      (w) =>
          w is FilledButton &&
          w.onPressed != null &&
          w.key.toString().contains('order_deliver_'),
    );
    await tester.tap(ready.first);
    await settle();
    final talentsBefore = int.parse(text('talents_count'));
    await tester.tap(find.byKey(const Key('task_button')));
    await settle();
    await tester.tap(find.byKey(const Key('scene_skip')));
    await settle();
    if (find.byKey(const Key('location_continue')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('location_continue')));
      await settle();
    }

    // The level-up message, with what it gave.
    expect(find.byKey(const Key('level_up')), findsOneWidget);
    expect(text('level_up_title'), contains('2'));
    expect(text('level_up_talents'), contains('$reward'));
    await tester.tap(find.byKey(const Key('level_up_continue')));
    await settle();
    expect(find.byKey(const Key('level_up')), findsNothing);
    expect(text('level_number'), '2');
    expect(text('talents_count'), '${talentsBefore + reward}');
    expect(text('manna_count'), '$max/$max');

    // Closing and reopening: still level 2, and not paid a second time.
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
    await settle();
    expect(text('level_number'), '2');
    expect(find.byKey(const Key('level_up')), findsNothing);
    expect(text('talents_count'), '${talentsBefore + reward}');
    await SaveRepository().clear();
  });
}
