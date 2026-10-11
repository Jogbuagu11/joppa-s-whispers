// Milestone 21: while an event is on, a button on the board opens the
// event's own smaller board, which spends the player's Manna. The event here
// comes from a stand-in for the server.
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/event_fixtures.dart';
import '../test/support/store_fakes.dart';

import 'helpers.dart';

class _Server implements RemoteEvents {
  _Server({this.pass});

  final Map<String, dynamic>? pass;

  @override
  Future<List<Object?>> fetch() async => [eventRow(pass: pass)];
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
    // This event has no season pass: no way into one.
    expect(find.byKey(const Key('event_pass_button')), findsNothing);

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

  testWidgets('an event with a season pass: Premium is bought from its '
      'pop-up and is the player\'s once the server has recorded it', (
    tester,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/event_pass_test')
      ..createSync(recursive: true);
    for (final file in dir.listSync()) {
      file.deleteSync(recursive: true);
    }
    await SaveRepository().clear();
    final store = FakeStore();
    final backend = FakePurchaseBackend();
    // As the server does: the pass is recorded for the event it was shown in.
    backend.offerGrants['boat_festival'] = const PurchaseGrant(
      passEventId: 'boat_festival',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          key: const Key('with_pass'),
          startingMannaOverride: 10,
          playOpeningScene: false,
          playTutorial: false,
          shop: PurchaseCoordinator(store: store, backend: backend),
          events: EventsRepository(
            loadBundled: () async => const [],
            remote: _Server(pass: testPass),
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
    await tapOnStrip(tester, 'event_banner');
    final button = find.byKey(const Key('event_pass_button'));
    for (int i = 0; i < 100 && button.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.tap(button);
    await settle();
    expect(find.byKey(const Key('season_pass_popup')), findsOneWidget);
    expect(find.byKey(const Key('season_pass_premium_0')), findsOneWidget);
    expect(find.byKey(const Key('season_pass_endless')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final before = tester
        .widget<Text>(find.byKey(const Key('season_pass_tier')))
        .data;

    await tester.tap(find.byKey(const Key('season_pass_buy_premium')));
    await settle();
    await settle();
    expect(backend.offerIds, ['boat_festival']);
    expect(store.finished.length, 1);
    expect(
      tester.widget<Text>(find.byKey(const Key('season_pass_tier'))).data,
      isNot(before),
    );
    // Premium held: the way on is the upgrade.
    expect(find.byKey(const Key('season_pass_buy_premium')), findsNothing);
    expect(find.byKey(const Key('season_pass_upgrade')), findsOneWidget);
    await tester.tap(find.byKey(const Key('season_pass_close')));
    await settle();
    expect(find.byKey(const Key('season_pass_popup')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await settle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });
}
