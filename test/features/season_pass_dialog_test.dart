// The season pass's pop-up: both tracks, buying Premium, upgrading to Plus,
// and when nothing can be bought. Uses a stand-in store and server.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/event_controller.dart';
import 'package:whispers_of_joppa/features/events/event_pass.dart';
import 'package:whispers_of_joppa/features/events/season_pass_dialog.dart';
import 'package:whispers_of_joppa/features/events/season_pass_ledger.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';
import 'package:whispers_of_joppa/services/purchase_backend.dart';

import '../support/event_fixtures.dart';
import '../support/store_fakes.dart';

const _offers = <String, dynamic>{
  'season_pass': {
    'premium_product': 'pass_premium',
    'plus_product': 'pass_premium_plus',
  },
};
const _text = {
  'title': 'Season Pass',
  'have_free': 'Free track',
  'have_premium': 'You have Premium',
  'have_plus': 'You have Premium Plus',
  'buy_premium': 'Premium {price}',
  'buy_plus': 'Premium Plus {price}',
  'upgrade': 'Upgrade {price}',
  'at_points': '{points} points',
  'pearls': '{n} Pearls',
  'manna': '{n} Manna',
  'talents': '{n} Talents',
  'endless': 'Then {reward} every {points} points',
  'sign_in': 'Sign in to buy a pass.',
  'unavailable': 'The market is closed.',
  'close': 'Close',
};

void main() {
  final start = DateTime.utc(2026, 10, 1);
  final event = EventModel.fromJson(
    eventRow(
      startsAt: start,
      endsAt: DateTime.utc(2026, 10, 22),
      pass: testPass,
    ),
  );
  final products = seasonPassProductsFrom(_offers);
  late SaveExtras extras;
  late SeasonPassLedger ledger;
  late EventProgressRepository repository;
  late int manna;
  late int talents;
  late int pearls;
  late List<String> items;

  EventController make([EventProgress? progress]) => EventController(
    event: event,
    progress: progress ?? EventProgress(eventId: event.id),
    repository: repository,
    addManna: (n) => manna += n,
    addTalents: (n) => talents += n,
    saveGame: () async {},
    tier: () => ledger.tierFor(event.id),
    addPearls: (n) => pearls += n,
    giveItems: items.addAll,
    clock: () => start.add(const Duration(days: 1)),
  );

  setUp(() {
    extras = SaveExtras();
    ledger = SeasonPassLedger(extras);
    final dir = Directory.systemTemp.createTempSync('joppa_pass');
    repository = EventProgressRepository(directory: () async => dir);
    manna = talents = pearls = 0;
    items = [];
  });
  tearDown(() => extras.dispose());

  late FakeStore store;
  late FakePurchaseBackend backend;
  late PurchasesController wallet;
  late PurchaseCoordinator shop;
  late EventController controller;

  setUp(() {
    store = FakeStore();
    backend = FakePurchaseBackend();
    wallet = PurchasesController(
      products: products,
      addManna: (_) {},
      raiseGenerators: (_) {},
    )..onServerRecords = ledger.serverRecords;
    shop =
        PurchaseCoordinator(store: store, backend: backend, products: products)
          ..target = PurchaseTarget(
            applyConfirmed: wallet.applyConfirmed,
            hasApplied: wallet.hasApplied,
            applyRefunds: wallet.applyRefunds,
            saveNow: () async {},
          )
          ..start();
    controller = make();
  });
  tearDown(() {
    shop.dispose();
    controller.dispose();
  });

  Future<void> open(
    WidgetTester tester, {
    Map<String, String> prices = const {
      'pass_premium': r'$4.99',
      'pass_premium_plus': r'$9.99',
    },
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pass = EventPass(
      extras: extras,
      shop: shop,
      prices: () async => prices,
      text: _text,
      premiumProduct: 'pass_premium',
      plusProduct: 'pass_premium_plus',
      earnPearls: (n) => pearls += n,
      giveItems: items.addAll,
      itemName: (id) => 'Golden Thread',
    );
    extras.addListener(controller.settle);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSeasonPass(
              context,
              controller: controller,
              pass: pass,
              prices: prices,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndWait(WidgetTester tester, String key) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key(key)));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();
  }

  testWidgets('both tracks are listed; Premium is bought at the store\'s '
      'price for this event, pays what was reached, and can be made Plus', (
    tester,
  ) async {
    controller.onMerged(2);
    backend.offerGrants['boat_festival'] = const PurchaseGrant(
      passEventId: 'boat_festival',
    );
    await open(tester);
    expect(find.text('Free track'), findsOneWidget);
    expect(find.text('2 points'), findsOneWidget);
    expect(find.text('10 Manna'), findsOneWidget);
    expect(find.text('4 Pearls'), findsOneWidget);
    expect(find.text('30 Talents + Golden Thread'), findsOneWidget);
    expect(find.text('Then 7 Talents every 50 points'), findsOneWidget);
    expect(find.text(r'Premium $4.99'), findsOneWidget);
    expect(find.text(r'Premium Plus $9.99'), findsOneWidget);
    expect(manna, 10);

    await tapAndWait(tester, 'season_pass_buy_premium');
    // The event went with the purchase.
    expect(backend.offerIds, ['boat_festival']);
    expect(store.finishedAsConsumable, [true]);
    expect(find.text('You have Premium'), findsOneWidget);
    expect(manna, 15);
    expect(controller.premiumPaid, 1);
    expect(find.byKey(const Key('season_pass_buy_plus')), findsNothing);
    expect(find.text(r'Upgrade $4.99'), findsOneWidget);

    await tapAndWait(tester, 'season_pass_upgrade');
    expect(find.text('You have Premium Plus'), findsOneWidget);
    expect(find.byKey(const Key('season_pass_upgrade')), findsNothing);
    // 2 earned now count as 3.
    expect(controller.points, 3);
    await tester.tap(find.byKey(const Key('season_pass_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('season_pass_popup')), findsNothing);
  });

  testWidgets('signed out, with no price, or with a payment on its way, '
      'nothing can be bought', (tester) async {
    await open(tester, prices: const {});
    expect(find.text('The market is closed.'), findsOneWidget);
    OutlinedButton premium() =>
        tester.widget(find.byKey(const Key('season_pass_buy_premium')));
    expect(premium().onPressed, isNull);
    await tester.tap(find.byKey(const Key('season_pass_close')));
    await tester.pumpAndSettle();

    backend.signedIn = false;
    await open(tester);
    expect(find.text('Sign in to buy a pass.'), findsOneWidget);
    expect(premium().onPressed, isNull);
    await tester.tap(find.byKey(const Key('season_pass_close')));
    await tester.pumpAndSettle();

    backend
      ..signedIn = true
      ..answer = VerifyResult.unavailable;
    await open(tester);
    await tapAndWait(tester, 'season_pass_buy_premium');
    expect(shop.isWaitingFor('pass_premium'), isTrue);
    expect(premium().onPressed, isNull);
    expect(store.accountIds.length, 1);
  });

  testWidgets('shown unasked: once an event, only when a pass can be bought '
      'and nothing else is going on', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var prices = const <String, String>{};
    var quiet = false;
    final pass = EventPass(
      extras: extras,
      shop: shop,
      prices: () async => prices,
      text: _text,
      premiumProduct: 'pass_premium',
      plusProduct: 'pass_premium_plus',
      earnPearls: (_) {},
      giveItems: (_) {},
      itemName: (id) => id,
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final popup = find.byKey(const Key('season_pass_popup'));
    Future<void> unasked() async {
      unawaited(
        pass.open(context, controller, unasked: true, quiet: () => quiet),
      );
      await tester.pumpAndSettle();
    }

    // No price from the store (or signed out): not shown, not used up.
    await unasked();
    expect(popup, findsNothing);
    prices = const {'pass_premium': r'$4.99', 'pass_premium_plus': r'$9.99'};
    // Something else going on (an item being moved): not now.
    await unasked();
    expect(popup, findsNothing);
    quiet = true;
    await unasked();
    expect(popup, findsOneWidget);
    await tester.tap(find.byKey(const Key('season_pass_close')));
    await tester.pumpAndSettle();
    // Once an event.
    await unasked();
    expect(popup, findsNothing);
    // Asked for, it always opens.
    unawaited(pass.open(context, controller));
    await tester.pumpAndSettle();
    expect(popup, findsOneWidget);
  });
}
