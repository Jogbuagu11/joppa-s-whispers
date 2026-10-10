// Milestone 30 (first part): today's deals at the top of the Pearl shop. The
// free gift is taken once a day and is remembered. Uses a stand-in store.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/deals.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/store_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the free gift of the day is given once and remembered', (
    tester,
  ) async {
    final offers =
        jsonDecode(await rootBundle.loadString('content/offers.json'))
            as Map<String, dynamic>;
    final config = DealsConfig.fromJson(
      offers['daily_deals'] as Map<String, dynamic>,
    );
    await SaveRepository().save(
      SaveState(
        items: const [],
        generators: const [
          SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
        ],
        manna: 30,
        mannaLastRegen: DateTime.now(),
        talents: 5,
        blessings: 0,
        pearls: 3,
        activeOrders: const [],
        pendingOrders: const [],
        completedOrders: const [],
        completedTasks: const [],
        tutorialStep: tutorialFinished,
        lastOrderSkip: null,
      ),
    );
    final shop = PurchaseCoordinator(
      store: FakeStore(),
      backend: FakePurchaseBackend(),
    );
    final board = find.byType(GameWidget<BoardGame>);

    Future<BoardGame> open(Key key) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BoardScreen(
            key: key,
            playOpeningScene: false,
            playTutorial: false,
            shop: shop,
          ),
        ),
      );
      for (int i = 0; i < 200 && board.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 1));
      // Safe: the board widget was just found, and it always has its game.
      return tester.widget<GameWidget<BoardGame>>(board).game!;
    }

    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';
    FilledButton button(DailyDeal deal) =>
        tester.widget<FilledButton>(find.byKey(Key('deal_${deal.id}')));

    final game = await open(const Key('first'));
    expect(tester.takeException(), isNull);
    // Today's deals, by the phone's own day (the test may not cross
    // midnight, as none of the daily tests may).
    final today = dealsFor(config, DateTime.now());
    final gift = today.first;
    final dear = today.firstWhere((d) => d.pearlPrice > 3);

    await tester.tap(find.byKey(const Key('pearls_chip')));
    await settle();
    expect(find.byKey(const Key('daily_deals')), findsOneWidget);
    expect(find.text(gift.name), findsOneWidget);
    // With 3 Pearls a dearer deal is greyed out.
    expect(button(dear).onPressed, isNull);

    await tester.tap(find.byKey(Key('deal_${gift.id}')));
    await settle();
    expect(tester.takeException(), isNull);
    expect(button(gift).onPressed, isNull);
    await tester.pageBack();
    await settle();
    // What the gift said, no more and no less.
    expect(text('manna_count').split('/').first, '${30 + gift.manna}');
    expect(text('talents_count'), '${5 + gift.talents}');
    for (final id in gift.items) {
      expect(game.itemCounts()[id], 1);
    }
    expect(text('pearls_count'), '3');

    // Closed and opened again: still taken today.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await open(const Key('again'));
    await tester.tap(find.byKey(const Key('pearls_chip')));
    await settle();
    expect(button(gift).onPressed, isNull);
    await tester.pageBack();
    await settle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await SaveRepository().clear();
  });
}
