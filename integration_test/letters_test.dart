// Milestone 13: letters found in the story appear in the keepsake book.
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

  final board = find.byType(GameWidget<BoardGame>);

  Future<void> open(WidgetTester tester, Key key) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          key: key,
          playOpeningScene: false,
          playTutorial: false,
        ),
      ),
    );
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data ?? '';

  testWidgets('a letter is locked until its task is done, then readable', (
    tester,
  ) async {
    final letters = (await _content('letters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final tasks =
        ((await _content('chapters') as List<dynamic>).first
                as Map<String, dynamic>)['tasks']
            as List<dynamic>;
    final taskList = tasks.cast<Map<String, dynamic>>();
    final letterTaskIndex = taskList.indexWhere((t) => t['letter_id'] != null);
    expect(letterTaskIndex, greaterThanOrEqualTo(0));
    final letterId = taskList[letterTaskIndex]['letter_id'] as String;
    final letter = letters.firstWhere((l) => l['id'] == letterId);

    // --- New game: the book is there but every letter is locked. ---
    await SaveRepository().clear();
    await open(tester, const Key('new'));
    await tester.tap(find.byKey(const Key('letters_button')));
    await settle(tester);
    expect(find.byKey(const Key('letters_screen')), findsOneWidget);
    expect(text(tester, 'letters_progress'), '0 of ${letters.length} found');
    expect(text(tester, 'letter_title_$letterId'), 'Not found yet');
    await tester.tap(find.byKey(Key('letter_tile_$letterId')));
    await settle(tester);
    expect(find.byKey(const Key('letter_reader')), findsNothing);
    await tester.pageBack();
    await settle(tester);

    // --- A game where the tasks up to the letter's task are done. ---
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await SaveRepository().save(
      SaveState(
        items: const [],
        generators: const [],
        manna: 50,
        mannaLastRegen: DateTime.now(),
        talents: 0,
        blessings: 0,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: const [],
        completedTasks: [
          for (final t in taskList.take(letterTaskIndex + 1)) t['id'] as String,
        ],
        tutorialStep: tutorialFinished,
        lastOrderSkip: null,
      ),
    );
    await open(tester, const Key('later'));
    await tester.tap(find.byKey(const Key('letters_button')));
    await settle(tester);
    expect(text(tester, 'letters_progress'), '1 of ${letters.length} found');
    expect(text(tester, 'letter_title_$letterId'), letter['title']);

    // The found letter opens in full, with its scripture reference.
    await tester.tap(find.byKey(Key('letter_tile_$letterId')));
    await settle(tester);
    expect(find.byKey(const Key('letter_reader')), findsOneWidget);
    expect(text(tester, 'letter_body'), letter['body']);
    expect(text(tester, 'letter_reference'), letter['reference']);

    await SaveRepository().clear();
  });
}
