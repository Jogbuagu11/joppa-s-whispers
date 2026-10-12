// Milestone 32: goal events. While one is on, an Events button on the board
// shows what to do and how far the player has come; what the player does on
// the ordinary board is counted and milestones pay their rewards. The
// events here come from a stand-in for the server.
import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/goal_fixtures.dart';
import 'helpers.dart';

class _Server implements RemoteEvents {
  @override
  Future<List<Object?>> fetch() async => [
    goalRow(
      id: 'lamps',
      type: 'energy',
      more: {
        'token': 'Manna spent',
        'milestones': [
          {'points': 1, 'talents': 25},
          {'points': 500, 'manna': 10},
        ],
      },
    ),
    goalRow(id: 'harvest'),
    goalRow(
      id: 'race',
      type: 'race',
      more: {
        'goal': 12,
        'rivals': [
          {'name': 'Miriam', 'hours': 5},
          {'name': 'Old Tobias', 'hours': 9},
          {'name': 'Lydia', 'hours': 16},
          {'name': 'Young Reuben', 'hours': 30},
        ],
        'prizes': [
          {'pearls': 5},
          {'manna': 30},
          {'talents': 60},
        ],
      },
    ),
  ];
}

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final board = find.byType(GameWidget<BoardGame>);

  Future<Directory> folder(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$name')..createSync(recursive: true);
    for (final file in dir.listSync()) {
      file.deleteSync(recursive: true);
    }
    return dir;
  }

  Future<void> open(WidgetTester tester, Key key, Directory dir) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          key: key,
          playOpeningScene: false,
          playTutorial: false,
          events: EventsRepository(
            loadBundled: () async => const [],
            remote: _Server(),
            directory: () async => dir,
          ),
          eventProgress: EventProgressRepository(directory: () async => dir),
        ),
      ),
    );
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data ?? '';

  testWidgets('a new player sees no events yet', (tester) async {
    await SaveRepository().clear();
    await open(tester, const Key('new'), await folder('goal_new'));
    expect(find.byKey(const Key('goal_events_button')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });

  testWidgets('events that are on are listed; Manna spent on the board is '
      'counted, a milestone pays, and progress is kept', (tester) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    // A game with Chapters 1 and 2 finished: past every event's level.
    await SaveRepository().save(
      SaveState(
        items: const [],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
        ],
        manna: 40,
        mannaLastRegen: DateTime.now(),
        talents: 0,
        blessings: 0,
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
    final dir = await folder('goal_events');
    await open(tester, const Key('first'), dir);
    expect(tester.takeException(), isNull);

    await tapOnStrip(tester, 'goal_events_button');
    await settle(tester);
    expect(find.byKey(const Key('goal_events_popup')), findsOneWidget);
    expect(find.byKey(const Key('goal_lamps')), findsOneWidget);
    expect(find.byKey(const Key('goal_harvest')), findsOneWidget);
    expect(text(tester, 'goal_count_lamps'), startsWith('0 '));
    await tester.ensureVisible(
      find.byKey(const Key('goal_race'), skipOffstage: false),
    );
    await settle(tester);
    expect(find.text('Old Tobias'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('goal_close')));
    await settle(tester);

    // Today's tasks: five of them, with a chest for the lot.
    await tapOnStrip(tester, 'daily_tasks_button');
    await settle(tester);
    expect(find.byKey(const Key('daily_tasks_popup')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('daily_count_'),
        skipOffstage: false,
      ),
      findsNWidgets(5),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('daily_close')));
    await settle(tester);

    // One tap on the generator spends Manna: the first milestone pays.
    expect(text(tester, 'talents_count'), '0');
    final rect = tester.getRect(board);
    final byWidth = rect.width / BoardGame.cols;
    final byHeight = rect.height / BoardGame.rows;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    await tester.tapAt(
      Offset(
        rect.left + (rect.width - BoardGame.cols * cell) / 2 + 2.5 * cell,
        rect.top + (rect.height - BoardGame.rows * cell) / 2 + 8.5 * cell,
      ),
    );
    await settle(tester);
    expect(text(tester, 'talents_count'), '25');
    expect(find.byKey(const Key('goal_toast')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Reopened: the count is still there and nothing is paid twice.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await open(tester, const Key('second'), dir);
    expect(text(tester, 'talents_count'), '25');
    await tapOnStrip(tester, 'goal_events_button');
    await settle(tester);
    expect(text(tester, 'goal_count_lamps'), isNot(startsWith('0 ')));
    await tester.tap(find.byKey(const Key('goal_close')));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });
}
