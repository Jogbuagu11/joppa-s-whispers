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

  test('Pearls won in play are added and saved like any others; nothing '
      'or less than nothing adds nothing', () {
    final purse = make(pearls: 5);
    var told = 0;
    purse.addListener(() => told++);
    purse.earnPearls(3);
    expect(purse.pearls, 8);
    expect(purse.pearlsListenable.value, 8);
    expect(told, 1);
    purse
      ..earnPearls(0)
      ..earnPearls(-4);
    expect(purse.pearls, 8);
    expect(told, 1);
    // Won Pearls are no purchase: nothing is recorded as bought.
    expect(purse.appliedTransactions, isEmpty);
    purse.dispose();
  });

  test('spendPearls takes Pearls only when there are enough', () {
    c.applyConfirmed([_p('t1', 'pearls_tier1')]);
    expect(c.spendPearls(60), isFalse);
    expect(c.spendPearls(-1), isFalse);
    expect(c.pearls, 50);
    expect(c.spendPearls(20), isTrue);
    expect(c.pearls, 30);
  });

  group('refunds', () {
    PurchaseRecord refunded(String tx, String product) => PurchaseRecord(
      transactionId: tx,
      productId: product,
      granted: false,
      refunded: true,
    );

    test('a refunded pack takes its Pearls back, once', () {
      c.applyConfirmed([_p('t1', 'pearls_tier1'), _p('t2', 'pearls_tier1')]);
      expect(c.pearls, 100);
      final server = [refunded('t1', 'pearls_tier1'), _p('t2', 'pearls_tier1')];
      expect(c.applyRefunds(server), 1);
      expect(c.pearls, 50);
      // Seeing the same refund again changes nothing.
      expect(c.applyRefunds(server), 0);
      expect(c.pearls, 50);
      expect(c.applyConfirmed(server).isEmpty, isTrue);
      expect(c.pearls, 50);
    });

    test('Pearls already spent are not taken below zero', () {
      c.applyConfirmed([_p('t1', 'pearls_tier1')]);
      expect(c.spendPearls(40), isTrue);
      expect(c.applyRefunds([refunded('t1', 'pearls_tier1')]), 1);
      expect(c.pearls, 0);
    });

    test('a refunded starter pack can be bought again', () {
      c.applyConfirmed([_p('t1', 'starter_pack')]);
      expect(c.canBuyProduct('starter_pack'), isFalse);
      expect(c.applyRefunds([refunded('t1', 'starter_pack')]), 1);
      expect(c.pearls, 0);
      expect(c.canBuyProduct('starter_pack'), isTrue);
      // Buying it again later delivers it again.
      final again = c.applyConfirmed([
        refunded('t1', 'starter_pack'),
        _p('t9', 'starter_pack'),
      ]);
      expect(again.pearls, 100);
    });

    test('a starter pack paid for twice survives one refund untouched', () {
      // Bought on an iPhone and again on an Android phone; only the first
      // was put in the game.
      final both = [_p('ios', 'starter_pack'), _p('and', 'starter_pack')];
      c.applyConfirmed(both);
      expect(c.pearls, 100);
      final server = [
        refunded('ios', 'starter_pack'),
        _p('and', 'starter_pack'),
      ];
      expect(c.applyRefunds(server), 1);
      expect(c.pearls, 100);
      expect(c.canBuyProduct('starter_pack'), isFalse);
      expect(c.appliedTransactions, ['and']);
      // The standing purchase is not delivered a second time.
      expect(c.applyConfirmed(server).isEmpty, isTrue);
      expect(c.pearls, 100);
      // If that one is refunded too, the pack goes.
      expect(
        c.applyRefunds([
          refunded('ios', 'starter_pack'),
          refunded('and', 'starter_pack'),
        ]),
        1,
      );
      expect(c.pearls, 0);
      expect(c.canBuyProduct('starter_pack'), isTrue);
    });

    test('a refund of something never delivered here does nothing', () {
      expect(c.applyRefunds([refunded('zz', 'pearls_tier1')]), 0);
      expect(c.pearls, 0);
    });
  });
}
