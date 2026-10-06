import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';

const _products = {
  'pearls_tier1': ProductModel(
    id: 'pearls_tier1',
    consumable: true,
    pearls: 50,
  ),
  'starter_pack': ProductModel(
    id: 'starter_pack',
    consumable: false,
    pearls: 100,
    manna: 100,
    generatorLevel: 2,
  ),
};

PurchaseRecord _p(String tx, String product, {bool granted = true}) =>
    PurchaseRecord(transactionId: tx, productId: product, granted: granted);

void main() {
  late int manna;
  late int? level;
  late PurchasesController c;

  PurchasesController make({
    int pearls = 0,
    List<String> applied = const [],
    List<String> owned = const [],
  }) => PurchasesController(
    products: _products,
    addManna: (n) => manna += n,
    raiseGenerators: (l) => level = l,
    startingPearls: pearls,
    appliedTransactions: applied,
    ownedProducts: owned,
  );

  setUp(() {
    manna = 0;
    level = null;
    c = make();
  });

  test('a confirmed Pearl pack adds its Pearls once', () {
    final added = c.applyConfirmed([_p('t1', 'pearls_tier1')]);
    expect(added.pearls, 50);
    expect(c.pearls, 50);
    expect(c.appliedTransactions, ['t1']);
  });

  test('the same transaction is never granted twice', () {
    c.applyConfirmed([_p('t1', 'pearls_tier1')]);
    final again = c.applyConfirmed([_p('t1', 'pearls_tier1')]);
    expect(again.isEmpty, isTrue);
    expect(c.pearls, 50);
  });

  test('two different purchases of the same pack are both granted', () {
    c.applyConfirmed([_p('t1', 'pearls_tier1'), _p('t2', 'pearls_tier1')]);
    expect(c.pearls, 100);
  });

  test(
    'the starter pack gives Pearls, Manna and a generator level, and is owned',
    () {
      var notified = 0;
      c.addListener(() => notified++);
      c.applyConfirmed([_p('t1', 'starter_pack')]);
      expect(c.pearls, 100);
      expect(manna, 100);
      expect(level, 2);
      expect(c.ownedProducts, ['starter_pack']);
      expect(c.canBuyProduct('starter_pack'), isFalse);
      expect(c.canBuyProduct('pearls_tier1'), isTrue);
      expect(notified, 1);
    },
  );

  test('refunded or pending purchases add nothing', () {
    final added = c.applyConfirmed([_p('t1', 'pearls_tier1', granted: false)]);
    expect(added.isEmpty, isTrue);
    expect(c.pearls, 0);
    expect(c.appliedTransactions, isEmpty);
  });

  test(
    'restores Pearls, applied transactions and owned products from a save',
    () {
      final restored = make(
        pearls: 75,
        applied: ['t1'],
        owned: ['starter_pack'],
      );
      expect(restored.pearls, 75);
      expect(
        restored.applyConfirmed([_p('t1', 'pearls_tier1')]).isEmpty,
        isTrue,
      );
      expect(restored.pearls, 75);
      expect(restored.canBuyProduct('starter_pack'), isFalse);
    },
  );

  test('spendPearls takes Pearls only when there are enough', () {
    c.applyConfirmed([_p('t1', 'pearls_tier1')]);
    expect(c.spendPearls(60), isFalse);
    expect(c.spendPearls(-1), isFalse);
    expect(c.pearls, 50);
    expect(c.spendPearls(20), isTrue);
    expect(c.pearls, 30);
  });
}
