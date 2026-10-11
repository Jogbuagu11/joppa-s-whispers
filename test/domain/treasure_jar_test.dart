// The Treasure Jar: filling, being full, and growing after it is opened.
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/treasure_jar.dart';

const _json = <String, dynamic>{
  'sizes': [
    {'id': 'small', 'product_id': 'treasure_jar_small', 'pearls': 10},
    {'id': 'large', 'product_id': 'treasure_jar_large', 'pearls': 30},
    {'id': 'broken', 'product_id': 'x', 'pearls': 0},
    'nonsense',
  ],
  'earn': {'order': 4, 'task': 6, 'level': -3},
};

void main() {
  final rules = TreasureJarRules.fromJson(_json);

  test('the rules are read from content; nonsense is left out', () {
    expect(rules?.sizes.map((s) => s.id), ['small', 'large']);
    expect(rules?.perOrder, 4);
    expect(rules?.perTask, 6);
    expect(rules?.perLevel, 0);
    expect(TreasureJarRules.fromJson(null), isNull);
    expect(TreasureJarRules.fromJson({'sizes': <dynamic>[]}), isNull);
    expect(TreasureJarRules.fromJson({'sizes': 'x'}), isNull);
  });

  test('the jar fills as Pearls are saved, and never past full', () {
    final r = rules ?? fail('no rules');
    var jar = const TreasureJarState();
    expect(jarIsFull(r, jar), isFalse);
    jar = jarAfterSaving(r, jar, 4);
    expect(jar.saved, 4);
    jar = jarAfterSaving(r, jar, 0);
    jar = jarAfterSaving(r, jar, -9);
    expect(jar.saved, 4);
    jar = jarAfterSaving(r, jar, 4);
    expect(jarIsFull(r, jar), isFalse);
    jar = jarAfterSaving(r, jar, 4);
    expect(jar.saved, 10);
    expect(jarIsFull(r, jar), isTrue);
    expect(jarAfterSaving(r, jar, 50).saved, 10);
  });

  test('an opened jar is followed by an empty, bigger one; the biggest '
      'goes on for ever', () {
    final r = rules ?? fail('no rules');
    final full = jarToldFull(const TreasureJarState(saved: 10));
    expect(full.toldFull, isTrue);
    final next = jarAfterOpening(full);
    expect(next.saved, 0);
    expect(next.opened, 1);
    expect(next.toldFull, isFalse);
    expect(r.sizeAfter(next.opened).id, 'large');
    expect(r.sizeAfter(7).id, 'large');
    expect(r.sizeAfter(-1).id, 'small');
    expect(jarAfterOpening(full, times: 0), same(full));
    expect(jarAfterOpening(full, times: 2).opened, 2);
  });

  test('the jar is kept in the save file', () {
    const jar = TreasureJarState(saved: 7, opened: 2, toldFull: true);
    final back = TreasureJarState.fromJson(jar.toJson());
    expect(back.saved, 7);
    expect(back.opened, 2);
    expect(back.toldFull, isTrue);
    final odd = TreasureJarState.fromJson({'saved': -4, 'opened': 'x'});
    expect(odd.saved, 0);
    expect(odd.opened, 0);
    expect(TreasureJarState.fromJson(null).saved, 0);
  });

  test('the products that open a jar are bought again and again and give '
      'what the server records', () {
    final products = treasureJarProductsFrom({'treasure_jar': _json});
    expect(products.keys, ['treasure_jar_small', 'treasure_jar_large']);
    expect(products['treasure_jar_small']?.reusable, isTrue);
    expect(products['treasure_jar_small']?.consumable, isTrue);
    expect(treasureJarProductsFrom(null), isEmpty);
    expect(treasureJarProductsFrom({'treasure_jar': 3}), isEmpty);
    expect(rules?.isJarProduct('treasure_jar_large'), isTrue);
    expect(rules?.isJarProduct('offer_099'), isFalse);
  });
}
