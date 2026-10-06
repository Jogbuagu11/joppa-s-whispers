import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/refunds.dart';

const _products = {
  'pearls_tier1': ProductModel(
    id: 'pearls_tier1',
    consumable: true,
    pearls: 25,
  ),
  'pearls_tier2': ProductModel(
    id: 'pearls_tier2',
    consumable: true,
    pearls: 140,
  ),
  'starter_pack': ProductModel(
    id: 'starter_pack',
    consumable: false,
    pearls: 100,
    manna: 100,
    generatorLevel: 2,
  ),
};

PurchaseRecord _granted(String id, String product) =>
    PurchaseRecord(transactionId: id, productId: product, granted: true);

PurchaseRecord _refunded(String id, String product) => PurchaseRecord(
  transactionId: id,
  productId: product,
  granted: false,
  refunded: true,
);

void main() {
  group('refundsToApply', () {
    test('a refunded purchase that is in the game is taken back', () {
      final refunds = refundsToApply(
        [_refunded('a', 'pearls_tier1'), _granted('b', 'pearls_tier2')],
        {'a', 'b'},
        _products,
      );
      expect(refunds.map((r) => r.transactionId), ['a']);
    });

    test('a refund for a purchase never applied here is ignored', () {
      expect(
        refundsToApply([_refunded('a', 'pearls_tier1')], {}, _products),
        isEmpty,
      );
    });

    test('the same refund listed twice counts once', () {
      final refunds = refundsToApply(
        [_refunded('a', 'pearls_tier1'), _refunded('a', 'pearls_tier1')],
        {'a'},
        _products,
      );
      expect(refunds, hasLength(1));
    });

    test('pending purchases and unknown products are not refunds', () {
      const pending = PurchaseRecord(
        transactionId: 'p',
        productId: 'pearls_tier1',
        granted: false,
      );
      expect(
        refundsToApply(
          [pending, _refunded('x', 'mystery_box')],
          {'p', 'x'},
          _products,
        ),
        isEmpty,
      );
    });
  });

  group('pearlsToRemove', () {
    test('takes the Pearls the refunded purchases gave', () {
      expect(
        pearlsToRemove(500, [
          _refunded('a', 'pearls_tier1'),
          _refunded('b', 'pearls_tier2'),
        ], _products),
        165,
      );
    });

    test('never takes more than the player has left', () {
      expect(
        pearlsToRemove(10, [_refunded('a', 'pearls_tier2')], _products),
        10,
      );
      expect(pearlsToRemove(0, [_refunded('a', 'pearls_tier2')], _products), 0);
    });

    test('takes nothing when there are no refunds', () {
      expect(pearlsToRemove(50, [], _products), 0);
    });
  });

  group('productsNoLongerOwned', () {
    test('a refunded starter pack is no longer owned', () {
      expect(
        productsNoLongerOwned([_refunded('a', 'starter_pack')], _products),
        {'starter_pack'},
      );
    });

    test('Pearl packs are never "owned"', () {
      expect(
        productsNoLongerOwned([_refunded('a', 'pearls_tier1')], _products),
        isEmpty,
      );
    });
  });

  group('standInPurchases', () {
    test('another standing purchase of a one-time product takes its place', () {
      final refund = _refunded('ios', 'starter_pack');
      expect(
        standInPurchases([refund], [refund, _granted('and', 'starter_pack')], {
          'ios',
        }, _products),
        {'ios': 'and'},
      );
    });

    test('nothing stands in when no other purchase of it stands', () {
      final refund = _refunded('ios', 'starter_pack');
      expect(
        standInPurchases([refund], [refund, _refunded('and', 'starter_pack')], {
          'ios',
        }, _products),
        isEmpty,
      );
    });

    test('Pearl packs never have a stand-in', () {
      final refund = _refunded('a', 'pearls_tier1');
      expect(
        standInPurchases([refund], [refund, _granted('b', 'pearls_tier1')], {
          'a',
        }, _products),
        isEmpty,
      );
    });

    test('one standing purchase covers only one refund', () {
      final r1 = _refunded('a', 'starter_pack');
      final r2 = _refunded('b', 'starter_pack');
      final stand = standInPurchases(
        [r1, r2],
        [r1, r2, _granted('c', 'starter_pack')],
        {'a', 'b'},
        _products,
      );
      expect(stand, {'a': 'c'});
    });
  });
}
