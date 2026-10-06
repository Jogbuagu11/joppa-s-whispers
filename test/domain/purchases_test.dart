import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';

final _products = {
  for (final json in [
    {'id': 'pearls_tier1', 'type': 'consumable', 'pearls': 50},
    {'id': 'pearls_tier2', 'type': 'consumable', 'pearls': 270},
    {
      'id': 'starter_pack',
      'type': 'non_consumable',
      'pearls': 100,
      'manna': 100,
      'generator_level': 2,
    },
  ])
    json['id'] as String: ProductModel.fromJson(json),
};

PurchaseRecord _p(String tx, String product, {bool granted = true}) =>
    PurchaseRecord(transactionId: tx, productId: product, granted: granted);

void main() {
  test('ProductModel.fromJson reads every field', () {
    final pack = _products['starter_pack'];
    expect(pack?.id, 'starter_pack');
    expect(pack?.consumable, isFalse);
    expect(pack?.pearls, 100);
    expect(pack?.manna, 100);
    expect(pack?.generatorLevel, 2);
    final pearls = _products['pearls_tier1'];
    expect(pearls?.consumable, isTrue);
    expect(pearls?.manna, 0);
    expect(pearls?.generatorLevel, isNull);
  });

  group('purchasesToApply', () {
    test('a new confirmed purchase is applied', () {
      final out = purchasesToApply([_p('t1', 'pearls_tier1')], {}, _products);
      expect([for (final r in out) r.transactionId], ['t1']);
    });

    test('a transaction already applied is never applied again', () {
      expect(
        purchasesToApply([_p('t1', 'pearls_tier1')], {'t1'}, _products),
        isEmpty,
      );
    });

    test('the same transaction listed twice is applied once', () {
      final out = purchasesToApply(
        [_p('t1', 'pearls_tier1'), _p('t1', 'pearls_tier1')],
        {},
        _products,
      );
      expect(out.length, 1);
    });

    test('refunded or pending purchases are not applied', () {
      expect(
        purchasesToApply(
          [_p('t1', 'pearls_tier1', granted: false)],
          {},
          _products,
        ),
        isEmpty,
      );
    });

    test('a product this build does not know is left for later', () {
      expect(
        purchasesToApply([_p('t1', 'season_pass_x')], {}, _products),
        isEmpty,
      );
    });

    test('only the missing ones are applied from a longer history', () {
      final out = purchasesToApply(
        [
          _p('t1', 'pearls_tier1'),
          _p('t2', 'pearls_tier2'),
          _p('t3', 'starter_pack'),
        ],
        {'t2'},
        _products,
      );
      expect([for (final r in out) r.transactionId], ['t1', 't3']);
    });
  });

  group('totalGrant', () {
    test('adds up Pearls and Manna and takes the highest generator level', () {
      final t = totalGrant([
        _p('t1', 'pearls_tier1'),
        _p('t2', 'pearls_tier2'),
        _p('t3', 'starter_pack'),
      ], _products);
      expect(t.pearls, 420);
      expect(t.manna, 100);
      expect(t.generatorLevel, 2);
      expect(t.isEmpty, isFalse);
    });

    test('nothing to apply gives nothing', () {
      expect(totalGrant([], _products).isEmpty, isTrue);
      expect(totalGrant([_p('t', 'unknown')], _products).isEmpty, isTrue);
    });
  });

  group('canBuy', () {
    test('Pearl packs can always be bought again', () {
      expect(canBuy('pearls_tier1', _products, {'pearls_tier1'}), isTrue);
    });
    test('the starter pack can be bought only once', () {
      expect(canBuy('starter_pack', _products, {}), isTrue);
      expect(canBuy('starter_pack', _products, {'starter_pack'}), isFalse);
    });
    test('an unknown product cannot be bought', () {
      expect(canBuy('nope', _products, {}), isFalse);
    });
  });
}
