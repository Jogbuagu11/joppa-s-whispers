import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/features/levels/level_controller.dart';
import 'package:whispers_of_joppa/features/levels/level_widgets.dart';
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_top_bar.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

import '../support/comfort_fakes.dart';

LevelController _levels() => LevelController(
  config: const LevelsConfig(
    xpPerTaskByChapter: {},
    xpPerTaskDefault: 10,
    steps: [LevelStep(level: 2, xp: 10)],
  ),
  story: StoryController(
    chapters: const [],
    blessings: () => 0,
    spendBlessings: (_) => true,
    wallet: ValueNotifier<int>(0),
  ),
  addTalents: (_) {},
  refillManna: () {},
);

void main() {
  // The whole top row as the real game shows it: wallet, level, both
  // buttons and the Manna bar.
  for (final width in [320.0, 375.0, 393.0, 430.0]) {
    for (final largeText in [false, true]) {
      testWidgets('the top row fits a ${width.toInt()}pt phone'
          '${largeText ? ' at the largest text size' : ''}', (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        if (largeText) useLargestText(tester);
        final levels = _levels();
        final game = BoardGame(
          itemCatalog: const {},
          chainData: const {},
          generatorLevels: const {},
          generatorPlacements: const [],
          startingItems: const [],
          chainPlaceholderColors: const {},
          manna: MannaController(config: _economy, startingManna: 86),
          onOutOfManna: () {},
        );
        final orders = OrdersController(
          config: _economy,
          board: game,
          orders: const [],
        )..addTalents(123456);
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: BoardTopBar(
                  wallet: WalletChips(
                    controller: orders,
                    pearls: ValueNotifier<int>(9999),
                  ),
                  level: LevelBadge(controller: levels),
                  onAccount: () => opened++,
                  onSettings: () => opened++,
                  // The Manna bar takes the width that is left over. (The real
                  // one cannot be used here: the test font's letters are far
                  // wider than the game's.)
                  manna: const SizedBox(key: Key('manna_count'), height: 56),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        // Nothing hangs off either side.
        final row = tester.getRect(find.byType(BoardTopBar));
        for (final key in ['talents_count', 'level_badge', 'manna_count']) {
          final part = tester.getRect(find.byKey(Key(key)));
          expect(part.left, greaterThanOrEqualTo(row.left - 0.01), reason: key);
          expect(part.right, lessThanOrEqualTo(row.right + 0.01), reason: key);
        }
        // And the buttons work.
        await tester.tap(find.byKey(const Key('account_button')));
        await tester.tap(find.byKey(const Key('notifications_button')));
        expect(opened, 2);
      });
    }
  }

  // The Manna bar by itself, as narrow as it ever gets (a 320pt phone with
  // both buttons) and at the width the event screen gives it.
  for (final width in [146.0, 170.0]) {
    testWidgets('the Manna bar fits ${width.toInt()}pt at the largest text '
        'size with a full count', (tester) async {
      useLargestText(tester);
      final manna = MannaController(config: _economy, startingManna: 100);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: MannaBar(controller: manna),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(MannaBar));
      final count = tester.getRect(find.byKey(const Key('manna_count')));
      expect(count.right, lessThanOrEqualTo(bar.right));
      expect(count.left, greaterThanOrEqualTo(bar.left));
      // Spending below the cap shows the countdown, which must fit too.
      manna.setAfterSpend(7);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

const _economy = EconomyConfig(
  maxManna: 100,
  mannaRegenSeconds: 120,
  generatorTapCost: 1,
  orderTalentsPerTier: 5,
  orderSlots: 3,
  tutorialFreeTaps: 12,
  mannaRefillBasePearls: 10,
  basketSlotBasePearls: 10,
  orderSkipCooldownSeconds: 1800,
  rewardedAdMannaBonus: 20,
  rewardedAdMannaDailyCap: 5,
  rewardedAdDoubleRewardDailyCap: 3,
);
