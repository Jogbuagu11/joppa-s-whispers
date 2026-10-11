// Milestone 31: the Treasure Jar. From its level on it has a button above
// the board; a full jar is opened with a purchase, gives what the server
// recorded, and is followed by an empty, bigger jar. Uses a stand-in store
// and server.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/store_fakes.dart';
import 'helpers.dart';

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final board = find.byType(GameWidget<BoardGame>);
  final popup = find.byKey(const Key('treasure_jar_popup'));

  late FakeStore store;
  late FakePurchaseBackend backend;
  late PurchaseCoordinator shop;

  setUp(() async {
    await SaveRepository().clear();
    store = FakeStore();
    backend = FakePurchaseBackend();
    shop = PurchaseCoordinator(store: store, backend: backend);
  });
  tearDown(SaveRepository().clear);

  Future<void> open(
    WidgetTester tester,
    Key key, {
    bool tutorial = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          key: key,
          playOpeningScene: false,
          playTutorial: tutorial,
          shop: shop,
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

  testWidgets('a new player has no Treasure Jar yet', (tester) async {
    await open(tester, const Key('new'), tutorial: true);
    expect(find.byKey(const Key('treasure_jar_button')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a full jar is opened with a purchase: the Pearls the server '
      'recorded arrive and an empty, bigger jar follows', (tester) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final sizes =
        (((await _content('offers')) as Map<String, dynamic>)['treasure_jar']
                as Map<String, dynamic>)['sizes']
            as List<dynamic>;
    final small = (sizes[0] as Map<String, dynamic>)['pearls'] as int;
    final next = (sizes[1] as Map<String, dynamic>)['pearls'] as int;
    // A game with Chapters 1 and 2 finished (past the jar's level) and a
    // jar that has just filled.
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
        extras: {
          'treasure': {'saved': small, 'opened': 0, 'told_full': true},
        },
      ),
    );
    // As the server does: opening a jar gives what that size holds.
    backend.offerGrants[null] = PurchaseGrant(pearls: small);
    await open(tester, const Key('full'));
    expect(tester.takeException(), isNull);
    expect(popup, findsNothing);

    await tapOnStrip(tester, 'treasure_jar_button');
    await settle(tester);
    expect(popup, findsOneWidget);
    expect(text(tester, 'treasure_jar_count'), contains('$small'));
    expect(tester.takeException(), isNull);
    // Nothing is given for looking.
    expect(text(tester, 'pearls_count'), '0');

    await tester.tap(find.byKey(const Key('treasure_jar_open')));
    await settle(tester);
    await settle(tester);
    expect(store.finished.length, 1);
    expect(backend.offerIds, [null]);
    expect(text(tester, 'treasure_jar_count'), contains('$next'));
    expect(text(tester, 'treasure_jar_count'), startsWith('0'));
    await tester.tap(find.byKey(const Key('treasure_jar_close')));
    await settle(tester);
    expect(popup, findsNothing);
    expect(text(tester, 'pearls_count'), '$small');
    expect(tester.takeException(), isNull);

    // Reopened: the Pearls and the new jar were saved; nothing comes twice.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await open(tester, const Key('again'));
    expect(text(tester, 'pearls_count'), '$small');
    await tapOnStrip(tester, 'treasure_jar_button');
    await settle(tester);
    expect(text(tester, 'treasure_jar_count'), startsWith('0'));
    await tester.tap(find.byKey(const Key('treasure_jar_close')));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
