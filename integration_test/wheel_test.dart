// Milestone 29: the Blessing Wheel. A free spin a day and Pearl spins, every
// prize listed with its chance; no Pearl spins where the law forbids them.
import 'dart:convert';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import 'helpers.dart';

/// Luck that always lands on the first prize.
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

  /// A game with Chapters 1 and 2 finished (well past the wheel's level),
  /// or a brand-new one.
  Future<void> seed({required bool advanced}) async {
    final chapters = (await _content('chapters') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final orders = (await _content('orders') as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final done = advanced ? 2 : 0;
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
        pearls: 20,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: [
          for (final o in orders)
            if ((o['chapter'] as int) <= done) o['id'] as String,
        ],
        completedTasks: [
          for (final c in chapters.take(done))
            for (final t in c['tasks'] as List<dynamic>)
              (t as Map<String, dynamic>)['id'] as String,
        ],
        tutorialStep: tutorialFinished,
        endingsSeen: [for (final c in chapters.take(done)) c['id'] as String],
        lastOrderSkip: null,
      ),
    );
  }

  Future<void> open(WidgetTester tester, String country, Key key) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          key: key,
          playOpeningScene: false,
          playTutorial: false,
          luck: _First(),
          country: country,
        ),
      ),
    );
    final board = find.byType(GameWidget<BoardGame>);
    for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  }

  testWidgets('a new player has no wheel yet', (tester) async {
    await seed(advanced: false);
    await open(tester, 'US', const Key('new'));
    expect(find.byKey(const Key('wheel_button')), findsNothing);
    await close(tester);
  });

  testWidgets('a free spin, the odds, then a spin for Pearls', (tester) async {
    final chance = await _content('chance') as Map<String, dynamic>;
    final wheel = chance['wheel'] as Map<String, dynamic>;
    final first =
        (wheel['prizes'] as List<dynamic>).first as Map<String, dynamic>;
    final price = wheel['pearl_spin_base'] as int;
    final economy = await _content('economy') as Map<String, dynamic>;
    final max = economy['max_manna'] as int;
    await seed(advanced: true);
    await open(tester, 'US', const Key('wheel'));
    expect(tester.takeException(), isNull);

    await tapOnStrip(tester, 'wheel_button');
    await settle(tester);
    expect(find.byKey(const Key('wheel_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Every prize and its chance is on the screen before any spin.
    expect(find.byKey(Key('odds_${first['id']}')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wheel_see_odds')));
    await settle(tester);
    expect(find.byKey(const Key('odds_panel')), findsOneWidget);
    expect(find.byKey(const Key('odds_paid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('odds_close')));
    await settle(tester);

    // The free spin.
    await tester.tap(find.byKey(const Key('wheel_spin_free')));
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('wheel_prize_name'))).data,
      first['name'],
    );
    await tester.tap(find.byKey(const Key('wheel_prize_ok')));
    await settle(tester);
    expect(find.byKey(const Key('wheel_spin_free')), findsNothing);

    // A spin for Pearls.
    await tester.tap(find.byKey(const Key('wheel_spin_pearls')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('wheel_prize_ok')));
    await settle(tester);
    expect(tester.takeException(), isNull);

    // Back on the board: two prizes of Manna received, one price paid.
    await tester.pageBack();
    await settle(tester);
    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';
    expect(text('manna_count'), '${40 + 2 * (first['manna'] as int)}/$max');
    expect(text('pearls_count'), '${20 - price}');

    // Closed and opened again the same day: the free spin is still used.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await open(tester, 'US', const Key('again'));
    await tapOnStrip(tester, 'wheel_button');
    await settle(tester);
    expect(find.byKey(const Key('wheel_spin_free')), findsNothing);
    expect(find.byKey(const Key('wheel_spin_pearls')), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await close(tester);
  });

  testWidgets('in a country that forbids paid chance there are no Pearl '
      'spins', (tester) async {
    await seed(advanced: true);
    await open(tester, 'BE', const Key('belgium'));
    await tapOnStrip(tester, 'wheel_button');
    await settle(tester);
    expect(find.byKey(const Key('wheel_spin_free')), findsOneWidget);
    expect(find.byKey(const Key('wheel_spin_pearls')), findsNothing);
    await tester.tap(find.byKey(const Key('wheel_see_odds')));
    await settle(tester);
    expect(find.byKey(const Key('odds_paid')), findsNothing);
    await tester.tap(find.byKey(const Key('odds_close')));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    await close(tester);
  });
}
