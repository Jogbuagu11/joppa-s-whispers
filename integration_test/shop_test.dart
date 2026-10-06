// Milestone 16: buying in the Pearl shop delivers to the game once, and the
// Pearls are still there after closing and reopening. Uses a stand-in store
// and purchase server: no real money and no network.
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

import '../test/support/store_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final board = find.byType(GameWidget<BoardGame>);

  testWidgets('buy Pearls and the starter pack; both survive a restart', (
    tester,
  ) async {
    await SaveRepository().clear();
    addTearDown(SaveRepository().clear);
    final store = FakeStore();
    final backend = FakePurchaseBackend();
    final shop = PurchaseCoordinator(store: store, backend: backend);

    final products = {
      for (final p
          in jsonDecode(await rootBundle.loadString('content/products.json'))
              as List<dynamic>)
        (p as Map<String, dynamic>)['id'] as String: p,
    };
    final economy =
        jsonDecode(await rootBundle.loadString('content/economy.json'))
            as Map<String, dynamic>;
    final start =
        jsonDecode(await rootBundle.loadString('content/starting_board.json'))
            as Map<String, dynamic>;
    final max = economy['max_manna'] as int;
    final startManna = start['manna'] as int;
    final pack = products['pearls_tier1'] ?? const <String, dynamic>{};
    final starter = products['starter_pack'] ?? const <String, dynamic>{};
    final packPearls = pack['pearls'] as int;
    final starterPearls = starter['pearls'] as int;
    final starterManna = starter['manna'] as int;

    Future<void> open(Key key) async {
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
    }

    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
    }

    String text(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';

    await open(const Key('first'));
    expect(text('pearls_count'), '0');

    // --- Open the shop from the Pearls count. ---
    await tester.tap(find.byKey(const Key('pearls_chip')));
    await settle();
    expect(find.byKey(const Key('shop_screen')), findsOneWidget);
    for (final id in products.keys) {
      expect(find.byKey(Key('shop_product_$id')), findsOneWidget);
    }

    // --- Buy a Pearl pack: delivered once, store told it is finished. ---
    await tester.tap(find.byKey(const Key('shop_buy_pearls_tier1')));
    await settle();
    expect(text('shop_pearls'), 'You have $packPearls Pearls');
    expect(text('shop_message'), contains('$packPearls Pearls'));
    expect(store.finished.length, 1);
    expect(backend.verified.length, 1);

    // --- Buy the starter pack: Pearls + Manna, then owned. ---
    await tester.ensureVisible(find.byKey(const Key('shop_buy_starter_pack')));
    await tester.tap(find.byKey(const Key('shop_buy_starter_pack')));
    await settle();
    expect(
      text('shop_pearls'),
      'You have ${packPearls + starterPearls} Pearls',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('shop_buy_starter_pack')))
          .onPressed,
      isNull,
    );

    // --- Back on the board the wallet and Manna show it. ---
    await tester.pageBack();
    await settle();
    expect(text('pearls_count'), '${packPearls + starterPearls}');
    expect(text('manna_count'), '${startManna + starterManna}/$max');

    // --- Close and reopen: nothing lost, nothing granted twice. ---
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await open(const Key('second'));
    await tester.pump(const Duration(seconds: 2));
    expect(text('pearls_count'), '${packPearls + starterPearls}');
    expect(text('manna_count'), '${startManna + starterManna}/$max');
  });
}
