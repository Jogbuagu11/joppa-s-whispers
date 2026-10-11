// A purchase gives exactly what the server recorded for it: an offer's
// contents, or a doubled first pack. Uses a stand-in store and server.
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/refunds.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';

import '../support/store_fakes.dart';

final _products = {
  'pearls_tier1': const ProductModel(
    id: 'pearls_tier1',
    consumable: true,
    pearls: 25,
  ),
  ...offerProductsFrom({
    'offer_products': ['offer_099', 'offer_499', 7],
  }),
};

void main() {
  late FakeStore store;
  late FakePurchaseBackend backend;
  late PurchasesController wallet;
  late PurchaseCoordinator shop;
  var manna = 0;
  var talents = 0;
  final items = <String>[];

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    manna = 0;
    talents = 0;
    items.clear();
    store = FakeStore();
    backend = FakePurchaseBackend();
    wallet =
        PurchasesController(
            products: _products,
            addManna: (n) => manna += n,
            raiseGenerators: (_) {},
          )
          ..addTalents = ((n) => talents += n)
          ..giveItems = items.addAll;
    shop =
        PurchaseCoordinator(store: store, backend: backend, products: _products)
          ..target = PurchaseTarget(
            applyConfirmed: wallet.applyConfirmed,
            hasApplied: wallet.hasApplied,
            applyRefunds: wallet.applyRefunds,
            saveNow: () async {},
          )
          ..start();
  });
  tearDown(() => shop.dispose());

  test('the offer products are read from content as reusable packs', () {
    expect(_products.keys, ['pearls_tier1', 'offer_099', 'offer_499']);
    expect(_products['offer_099']?.reusable, isTrue);
    expect(_products['offer_099']?.consumable, isTrue);
    expect(offerProductsFrom(null), isEmpty);
    expect(offerProductsFrom({'offer_products': 'x'}), isEmpty);
  });

  test('the shop lists its own products; offers are asked for apart', () async {
    expect([for (final p in await shop.loadProducts()) p.id], ['pearls_tier1']);
    expect(
      [for (final p in await shop.loadProducts(offers: true)) p.id],
      ['offer_099', 'offer_499'],
    );
  });

  test('an offer gives what the server recorded for it, once, and the '
      'server is told which offer was on the screen', () async {
    backend.offerGrants['welcome'] = const PurchaseGrant(
      pearls: 40,
      manna: 50,
      talents: 30,
      items: ['manna_jar_02', 'hourglass_01'],
    );
    await shop.buy('offer_099', offerId: 'welcome');
    await settle();
    expect(backend.offerIds, ['welcome']);
    expect(wallet.pearls, 40);
    expect(manna, 50);
    expect(talents, 30);
    expect(items, ['manna_jar_02', 'hourglass_01']);
    expect(shop.message.value, contains('40 Pearls'));
    expect(shop.message.value, contains('2 gifts'));
    // Finished with the store as a pack that can be bought again.
    expect(store.finishedAsConsumable, [true]);

    // Reading the server again adds nothing.
    await shop.deliverConfirmed();
    expect(wallet.pearls, 40);
    expect(items.length, 2);

    // The same price again, another offer.
    backend.offerGrants['bigger'] = const PurchaseGrant(pearls: 60);
    await shop.buy('offer_099', offerId: 'bigger');
    await settle();
    expect(backend.offerIds, ['welcome', 'bigger']);
    expect(wallet.pearls, 100);
  });

  test('an offer payment the server recorded nothing for gives nothing '
      '(never the app\'s own guess)', () async {
    await shop.buy('offer_499', offerId: 'unknown_to_server');
    await settle();
    expect(wallet.pearls, 0);
    expect(items, isEmpty);
  });

  test('a shop pack gives what the server recorded (a doubled first pack), '
      'and an older record without a grant gives what the product gives', () {
    const doubled = PurchaseRecord(
      transactionId: 'a',
      productId: 'pearls_tier1',
      granted: true,
      grant: PurchaseGrant(pearls: 50),
    );
    const old = PurchaseRecord(
      transactionId: 'b',
      productId: 'pearls_tier1',
      granted: true,
    );
    expect(totalGrant([doubled], _products).pearls, 50);
    expect(totalGrant([old], _products).pearls, 25);
    expect(totalGrant([doubled, old], _products).pearls, 75);
  });

  test('a refund takes back what that purchase really gave', () async {
    backend.offerGrants['welcome'] = const PurchaseGrant(pearls: 40);
    await shop.buy('offer_099', offerId: 'welcome');
    await settle();
    expect(wallet.pearls, 40);
    backend.refund('tx1');
    await shop.deliverConfirmed();
    expect(wallet.pearls, 0);
    expect(pearlsToRemove(100, backend.recorded, _products), 40);
  });

  test('the server\'s record is read carefully', () {
    expect(PurchaseGrant.fromJson(null), isNull);
    expect(PurchaseGrant.fromJson('x'), isNull);
    final grant = PurchaseGrant.fromJson(<String, dynamic>{
      'pearls': 40,
      'manna': -5,
      'talents': '9',
      'items': ['jar', 3],
      'generator_level': 2,
    });
    expect(grant?.pearls, 40);
    expect(grant?.manna, 0);
    expect(grant?.talents, 0);
    expect(grant?.items, ['jar']);
    expect(grant?.generatorLevel, 2);
  });
}
