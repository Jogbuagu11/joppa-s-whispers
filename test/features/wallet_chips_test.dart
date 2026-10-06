import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/board_inventory.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';

class _EmptyBoard implements BoardInventory {
  final _changed = ValueNotifier<int>(0);
  @override
  Listenable get boardChanged => _changed;
  @override
  Map<String, int> itemCounts() => {};
  @override
  bool removeItems(Map<String, int> counts) => false;
}

void main() {
  const config = EconomyConfig(
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

  Future<void> show(
    WidgetTester tester, {
    ValueNotifier<int>? pearls,
    VoidCallback? onOpenShop,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WalletChips(
          controller: OrdersController(
            config: config,
            board: _EmptyBoard(),
            orders: const [],
          ),
          pearls: pearls,
          onOpenShop: onOpenShop,
        ),
      ),
    ),
  );

  testWidgets('shows Pearls and opens the shop when tapped', (tester) async {
    var opened = 0;
    final pearls = ValueNotifier<int>(75);
    await show(tester, pearls: pearls, onOpenShop: () => opened++);
    expect(
      tester.widget<Text>(find.byKey(const Key('pearls_count'))).data,
      '75',
    );
    await tester.tap(find.byKey(const Key('pearls_chip')));
    expect(opened, 1);
    pearls.value = 125;
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('pearls_count'))).data,
      '125',
    );
  });

  testWidgets('during the tutorial the Pearls count does not open the shop', (
    tester,
  ) async {
    // The board passes no shop callback until the tutorial is over (GDD 11).
    await show(tester, pearls: ValueNotifier<int>(0));
    await tester.tap(find.byKey(const Key('pearls_chip')));
    await tester.pump();
    expect(find.byKey(const Key('shop_screen')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no Pearls source the Pearls count is hidden', (
    tester,
  ) async {
    await show(tester);
    expect(find.byKey(const Key('pearls_chip')), findsNothing);
    expect(find.byKey(const Key('talents_count')), findsOneWidget);
  });
}
