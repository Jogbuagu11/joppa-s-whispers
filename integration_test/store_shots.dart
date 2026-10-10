// Not a test of the game: this stages the screens for the store screenshots.
// Run by tool/take_store_screenshots.sh, which takes each picture from the
// simulator when this asks for it. It plays the game's real screens with the
// game's real content, from a made-up saved game late in the story.
import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import 'helpers.dart';

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

// A busy, tidy board: (item, column, row).
const _board = [
  ('bakery_05', 0, 0),
  ('bakery_03', 1, 0),
  ('fruit_06', 2, 0),
  ('loom_04', 3, 0),
  ('word_03', 5, 0),
  ('oil_04', 6, 0),
  ('bakery_02', 0, 1),
  ('fruit_03', 1, 1),
  ('fruit_03', 2, 1),
  ('armor_05', 4, 1),
  ('church_04', 5, 1),
  ('word_05', 6, 1),
  ('oil_02', 0, 2),
  ('loom_06', 2, 2),
  ('church_02', 3, 2),
  ('armor_03', 4, 2),
  ('bakery_07', 6, 2),
  ('fruit_08', 1, 3),
  ('word_02', 3, 3),
  ('oil_05', 5, 3),
  ('bakery_04', 0, 4),
  ('loom_02', 2, 4),
  ('armor_02', 4, 4),
  ('fruit_05', 6, 4),
  ('church_05', 1, 5),
  ('word_04', 3, 5),
  ('loom_03', 5, 5),
  ('bakery_01', 0, 6),
  ('bakery_01', 1, 6),
  ('oil_03', 4, 6),
  ('fruit_02', 6, 6),
];

const _eventBoard = [
  ('boat_05', 0, 0),
  ('boat_03', 1, 0),
  ('boat_02', 3, 0),
  ('boat_04', 4, 0),
  ('boat_02', 0, 1),
  ('boat_01', 2, 1),
  ('boat_03', 4, 1),
  ('boat_01', 1, 2),
  ('boat_06', 3, 2),
  ('boat_02', 0, 3),
  ('boat_01', 2, 3),
  ('boat_04', 4, 3),
  ('boat_03', 1, 4),
  ('boat_01', 3, 4),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    final docs = await getApplicationDocumentsDirectory();

    /// Asks the script on the Mac to photograph the screen, and waits for it.
    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      final request = File('${docs.path}/shot_request.txt');
      await tester.runAsync(() async {
        await request.writeAsString(name, flush: true);
        for (int i = 0; i < 300 && request.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
    }

    Future<void> wait([int tenths = 12]) async {
      for (int i = 0; i < tenths; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    List<String> tasksOf(int i) => [
      for (final t in chapters[i]['tasks'] as List<dynamic>)
        (t as Map<String, dynamic>)['id'] as String,
    ];

    // Chapters 1 to 5 finished; eight tasks into Chapter 6.
    await SaveRepository().save(
      SaveState(
        items: [
          for (final (id, col, row) in _board)
            SavedItem(itemId: id, col: col, row: row),
        ],
        generators: const [
          SavedGenerator(generatorId: 'gen_press', level: 2, col: 0, row: 8),
          SavedGenerator(generatorId: 'gen_loom', level: 2, col: 1, row: 8),
          SavedGenerator(generatorId: 'gen_pantry', level: 3, col: 2, row: 8),
          SavedGenerator(generatorId: 'gen_chest', level: 2, col: 3, row: 8),
          SavedGenerator(generatorId: 'gen_tree', level: 3, col: 4, row: 8),
          SavedGenerator(generatorId: 'gen_armor', level: 2, col: 5, row: 8),
          SavedGenerator(generatorId: 'gen_scribe', level: 1, col: 6, row: 8),
        ],
        manna: 86,
        mannaLastRegen: DateTime.now(),
        talents: 2480,
        blessings: 5,
        pearls: 120,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: [
          for (final o in orders)
            if ((o['chapter'] as int) < 6) o['id'] as String,
        ],
        completedTasks: [
          for (int i = 0; i < 5; i++) ...tasksOf(i),
          ...tasksOf(5).take(8),
        ],
        tutorialStep: 99,
        endingsSeen: [for (int i = 0; i < 5; i++) chapters[i]['id'] as String],
        lastOrderSkip: null,
      ),
    );
    final events = EventsRepository(loadBundled: loadBundledEvents);
    final event = currentEvent(await events.load(), DateTime.now());
    final eventProgress = EventProgressRepository();
    if (event != null) {
      await eventProgress.save(
        EventProgress(
          eventId: event.id,
          points: 214,
          paid: 4,
          items: [
            for (final (id, col, row) in _eventBoard)
              (itemId: id, col: col, row: row),
          ],
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BoardScreen(
          playOpeningScene: false,
          playTutorial: false,
          events: events,
          eventProgress: eventProgress,
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await wait(30);
    await shot('1_board');

    // The current place, being restored.
    await tapOnStrip(tester, 'location_button');
    await wait(20);
    await shot('2_restore');
    await tester.pageBack();
    await wait();

    // Esther's letters: the book, then one letter open.
    await tapOnStrip(tester, 'letters_button');
    await wait(15);
    await shot('4_letters');
    await tester.tap(find.byKey(const Key('letter_tile_letter_03')));
    await wait(15);
    await shot('6_letter');
    await tester.pageBack();
    await wait();
    if (find.byKey(const Key('letters_screen')).evaluate().isNotEmpty) {
      await tester.pageBack();
      await wait();
    }

    // The event board.
    if (find.byKey(const Key('event_banner')).evaluate().isNotEmpty) {
      await tapOnStrip(tester, 'event_banner');
      await wait(30);
      await shot('5_event');
      await tester.pageBack();
      await wait();
    }

    // The story: the next task's scene, a few lines in.
    await tapOnStrip(tester, 'task_button');
    await wait(20);
    await tester.tap(find.byKey(const Key('scene_text')));
    await wait(12);
    await shot('3_story');
  });
}
