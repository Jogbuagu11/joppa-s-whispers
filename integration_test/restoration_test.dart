// Milestone 11: the location screen shows each area before and after its task.
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

  testWidgets('an area changes from before to after when its task is done', (
    tester,
  ) async {
    await SaveRepository().clear();
    await tester.pumpWidget(
      const MaterialApp(home: BoardScreen(playOpeningScene: false)),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    final chapter =
        (await _content('chapters') as List<dynamic>).first
            as Map<String, dynamic>;
    final location = (await _content('locations') as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((l) => l['id'] == chapter['location_id']);
    final areas = (location['areas'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final firstTask =
        (chapter['tasks'] as List<dynamic>).first as Map<String, dynamic>;
    final areaId = firstTask['restores_area'] as String?;
    expect(areaId, isNotNull, reason: 'the first task should restore an area');
    final area = areas.firstWhere((a) => a['id'] == areaId);

    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';
    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
    }

    // --- Before: open the location from the board. ---
    await tester.tap(find.byKey(const Key('location_button')));
    await settle();
    expect(find.byKey(const Key('location_screen')), findsOneWidget);
    expect(text('location_name'), location['name']);
    expect(text('location_progress'), '0 of ${areas.length} restored');
    for (final a in areas) {
      expect(find.byKey(Key('area_${a['id']}')), findsOneWidget);
    }
    expect(text('area_state_$areaId'), 'Not yet');
    expect(
      find.byKey(ValueKey<String>(area['before'] as String)),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey<String>(area['after'] as String)), findsNothing);
    await tester.tap(find.byKey(const Key('location_continue')));
    await settle();
    expect(find.byKey(const Key('location_screen')), findsNothing);

    // --- Earn a Blessing and do the first task. ---
    final ready = find.byWidgetPredicate(
      (w) =>
          w is FilledButton &&
          w.onPressed != null &&
          w.key.toString().contains('order_deliver_'),
    );
    expect(ready, findsWidgets);
    await tester.tap(ready.first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('task_button')));
    await settle();
    await tester.tap(find.byKey(const Key('scene_skip')));
    await settle();

    // --- After: the location opens by itself. The area starts in its old
    // state and changes in front of the player. ---
    expect(find.byKey(const Key('location_screen')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(text('location_progress'), '1 of ${areas.length} restored');
    expect(text('area_state_$areaId'), 'Restored');
    expect(
      find.byKey(ValueKey<String>(area['after'] as String)),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>(area['before'] as String)),
      findsNothing,
    );
    // Every other area is still waiting.
    for (final a in areas.where((a) => a['id'] != areaId)) {
      expect(text('area_state_${a['id']}'), 'Not yet');
    }

    await tester.tap(find.byKey(const Key('location_continue')));
    await settle();
    expect(find.byType(GameWidget<BoardGame>), findsOneWidget);
    await SaveRepository().clear();
  });
}
