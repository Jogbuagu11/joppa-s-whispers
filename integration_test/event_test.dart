// Milestone 21: while an event is on, a button on the board opens the
// event's own smaller board, which spends the player's Manna. The event here
// comes from a stand-in for the server.
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/event_fixtures.dart';

import 'helpers.dart';

class _Server implements RemoteEvents {
  @override
  Future<List<Object?>> fetch() async => [eventRow()];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an event that is on can be opened and played', (tester) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/event_test')
      ..createSync(recursive: true);
    for (final file in dir.listSync()) {
      file.deleteSync(recursive: true);
    }
    await SaveRepository().clear();
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          startingMannaOverride: 10,
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
    final banner = find.byKey(const Key('event_banner'));
    for (int i = 0; i < 200 && banner.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    // The event is a lit round button at the left of the swipeable row.
    await tapOnStrip(tester, 'event_banner');
    final eventBoard = find.descendant(
      of: find.byKey(const Key('event_screen')),
      matching: find.byType(GameWidget<BoardGame>),
    );
    for (int i = 0; i < 100 && eventBoard.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(eventBoard, findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('event_points'))).data,
      '0 points',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('event_next'))).data,
      'Next reward at 2: 10 Manna',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('event_time_left'))).data,
      endsWith('left'),
    );

    // The event board is 5 x 7 with its generator at column 2, row 6:
    // tapping it spends the player's own Manna.
    String manna() =>
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('event_screen')),
                matching: find.byKey(const Key('manna_count')),
              ),
            )
            .data ??
        '';
    expect(manna(), startsWith('10/'));
    final rect = tester.getRect(eventBoard);
    final byWidth = rect.width / 5;
    final byHeight = rect.height / 7;
    final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
    final generator = Offset(
      rect.left + (rect.width - 5 * cell) / 2 + 2.5 * cell,
      rect.top + (rect.height - 7 * cell) / 2 + 6.5 * cell,
    );
    await tester.tapAt(generator);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(generator);
    await tester.pump(const Duration(milliseconds: 300));
    expect(manna(), startsWith('8/'));

    // Leaving and coming back keeps the event board as it was.
    await tester.pageBack();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('event_screen')), findsNothing);
    final saved = await EventProgressRepository(
      directory: () async => dir,
    ).load('boat_festival');
    expect(saved.items, hasLength(2));
  });
}
