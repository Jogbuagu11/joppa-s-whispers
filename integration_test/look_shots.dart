// Not a test of the game: this stages the pop-ups and the Blessing Wheel so
// that pictures of them can be taken from a simulator and looked at. A
// script outside the app takes each picture when asked (see
// tool/take_store_screenshots.sh for the same arrangement).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/offer_fakes.dart';
import '../test/support/store_fakes.dart';
import 'helpers.dart';

class _First implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

Future<dynamic> _content(String name) async =>
    jsonDecode(await rootBundle.loadString('content/$name.json'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pictures of the pop-ups and the wheel', (tester) async {
    final docs = await getApplicationDocumentsDirectory();
    Future<void> wait([int tenths = 8]) async {
      for (int i = 0; i < tenths; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String name) async {
      await wait(5);
      final request = File('${docs.path}/shot_request.txt');
      await tester.runAsync(() async {
        await request.writeAsString(name, flush: true);
        for (int i = 0; i < 300 && request.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
    }

    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    await SaveRepository().save(
      SaveState(
        items: const [
          SavedItem(itemId: 'manna_jar_02', col: 1, row: 2),
          SavedItem(itemId: 'bakery_01', col: 2, row: 3),
          SavedItem(itemId: 'bakery_01', col: 3, row: 3),
          SavedItem(itemId: 'clayjar_01', col: 3, row: 5),
          SavedItem(itemId: 'honey_01', col: 5, row: 5),
        ],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
        ],
        manna: 40,
        mannaLastRegen: DateTime.now(),
        talents: 120,
        blessings: 3,
        pearls: 60,
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
        // A Treasure Jar that has just filled.
        extras: const {
          'treasure': {'saved': 150, 'opened': 0, 'told_full': true},
        },
      ),
    );
    // The game's own event (and its season pass), on now.
    final event = Map<String, dynamic>.of(
      ((await _content('events')) as List<dynamic>).first
          as Map<String, dynamic>,
    );
    event['starts_at'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 1))
        .toIso8601String();
    event['ends_at'] = DateTime.now()
        .toUtc()
        .add(const Duration(days: 9))
        .toIso8601String();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BoardScreen(
          playOpeningScene: false,
          playTutorial: false,
          luck: _First(),
          country: 'US',
          events: EventsRepository(
            loadBundled: () async => [event],
            directory: () async =>
                Directory('${docs.path}/look_events')
                  ..createSync(recursive: true),
          ),
          eventProgress: EventProgressRepository(
            directory: () async =>
                Directory('${docs.path}/look_events')
                  ..createSync(recursive: true),
          ),
          shop: PurchaseCoordinator(
            store: FakeStore(),
            backend: FakePurchaseBackend(),
          ),
          offers: FakeOffersSource(const [
            Offer(
              id: 'market',
              kind: 'session_start',
              productId: 'offer_299',
              title: 'Market Day',
              subtitle: 'Fresh from the harbor market',
              contents: PurchaseGrant(
                pearls: 110,
                manna: 100,
                items: ['hourglass_02', 'manna_jar_02'],
              ),
            ),
          ]),
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The timed offer that greets the player, while its confetti falls.
    final offer = find.byKey(const Key('offer_popup'));
    for (int i = 0; i < 100 && offer.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await wait(4);
    await shot('00_timed_offer');
    await tester.tap(find.byKey(const Key('offer_no_thanks')));
    await wait(15);

    Offset centre(int col, int row) {
      final rect = tester.getRect(board);
      final byWidth = rect.width / BoardGame.cols;
      final byHeight = rect.height / BoardGame.rows;
      final cell = (byWidth < byHeight ? byWidth : byHeight) - 2;
      return Offset(
        rect.left +
            (rect.width - BoardGame.cols * cell) / 2 +
            (col + 0.5) * cell,
        rect.top +
            (rect.height - BoardGame.rows * cell) / 2 +
            (row + 0.5) * cell,
      );
    }

    Future<void> tapKey(String key) async {
      await tester.tap(find.byKey(Key(key)));
      await wait();
    }

    // The Joppa Special.
    await tapOnStrip(tester, 'special_button');
    await wait(12);
    await shot('0_joppa_special');
    await tapKey('special_no_thanks');

    // A Manna jar: use, keep or sell.
    await tester.tapAt(centre(1, 2));
    await wait();
    await shot('1_manna_jar');
    await tapKey('use_item_keep');

    // A rare find: keep or sell.
    await tester.tapAt(centre(5, 5));
    await wait();
    await shot('2_sell');
    await tapKey('use_item_keep');

    // A Jar of Clay and what it may hold; then its prize.
    await tester.tapAt(centre(3, 5));
    await wait();
    await shot('3_jar');
    await tapKey('jar_open');
    await shot('4_prize');
    await tapKey('wheel_prize_ok');

    // A (mystery) bubble after a merge.
    await tester.dragFrom(centre(2, 3), centre(3, 3) - centre(2, 3));
    await wait();
    await shot('5_board_with_bubble');
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('bubble_at_'),
      ),
    );
    await wait();
    await shot('6_bubble');
    await tapKey('bubble_leave');

    // The wheel.
    await tapOnStrip(tester, 'wheel_button');
    await wait(12);
    await shot('7_wheel');
    await tapKey('wheel_see_odds');
    await shot('8_odds');
    await tapKey('odds_close');
    await tapKey('wheel_spin_free');
    await wait(30);
    await shot('9_wheel_prize');
    await tapKey('wheel_prize_ok');
    await tester.ensureVisible(find.byKey(const Key('jar_buy_golden')));
    await wait();
    await shot('10_wheel_lower');
    await tapKey('jar_buy_treasure');
    await shot('11_buy_jar');
    await tapKey('jar_buy_no');
    await tester.pageBack();
    await wait(10);

    // The Treasure Jar (the piggy bank), full.
    await tapOnStrip(tester, 'treasure_jar_button');
    await wait(10);
    await shot('12_treasure_jar');
    await tapKey('treasure_jar_close');

    // The event, and its season pass.
    await tapOnStrip(tester, 'event_banner');
    final pass = find.byKey(const Key('event_pass_button'));
    for (int i = 0; i < 100 && pass.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await wait(10);
    await shot('13_event');
    await tapKey('event_pass_button');
    await wait(10);
    await shot('14_season_pass');
    await tapKey('season_pass_close');
    await tester.pageBack();
    await wait(10);

    await tester.pumpWidget(const SizedBox());
    await wait(30);
    await SaveRepository().clear();
  });
}
