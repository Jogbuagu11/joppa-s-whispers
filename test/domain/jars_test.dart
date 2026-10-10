import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/chance_validator.dart';
import 'package:whispers_of_joppa/data/generator_type_validator.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/domain/jars.dart';
import 'package:whispers_of_joppa/domain/models.dart';

dynamic _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

const _clay = JarKind(
  id: 'clay',
  itemId: 'clayjar_01',
  pearlPrice: null,
  prizes: [
    Prize(id: 'pearl', name: '1 Pearl', weight: 1, pearls: 1, freeOnly: true),
    Prize(id: 'manna', name: '10 Manna', weight: 3, manna: 10),
  ],
);
const _treasure = JarKind(
  id: 'treasure',
  itemId: 'treasurejar_01',
  pearlPrice: 15,
  prizes: [
    Prize(id: 'pearl', name: '1 Pearl', weight: 1, pearls: 1, freeOnly: true),
    Prize(id: 'manna', name: '60 Manna', weight: 3, manna: 60),
  ],
);

void main() {
  test('a jar that is only given may hold Pearls; one that is sold never '
      'does, whatever its list says', () {
    expect(_clay.paid, isFalse);
    expect([for (final o in _clay.odds) o.prize.id], ['pearl', 'manna']);
    expect(_treasure.paid, isTrue);
    expect([for (final o in _treasure.odds) o.prize.id], ['manna']);
    final random = Random(2);
    for (var i = 0; i < 2000; i++) {
      expect(_treasure.open(random: random)?.pearls, 0);
    }
  });

  test('a jar is opened by the odds it shows', () {
    final random = Random(9);
    var pearls = 0;
    for (var i = 0; i < 8000; i++) {
      if (_clay.open(random: random)?.id == 'pearl') pearls++;
    }
    expect(pearls / 8000, closeTo(_clay.odds.first.chance, 0.02));
  });

  test('a jar comes with every fourth order, and never if switched off', () {
    const jars = JarsConfig(
      clayEveryOrders: 4,
      orderJar: 'clay',
      kinds: {'clay': _clay, 'treasure': _treasure},
    );
    expect(
      [for (var n = 0; n <= 9; n++) jars.jarForOrder(n)],
      [
        null,
        null,
        null,
        null,
        'clayjar_01',
        null,
        null,
        null,
        'clayjar_01',
        null,
      ],
    );
    const off = JarsConfig(
      clayEveryOrders: 0,
      orderJar: 'clay',
      kinds: {'clay': _clay},
    );
    expect(off.jarForOrder(4), isNull);
    expect([for (final j in jars.forSale) j.id], ['treasure']);
  });

  test('a jar item is read from content', () {
    final use = ItemUse.fromJson({'jar': 'clay'});
    expect(use?.jar, 'clay');
    expect(use?.isTool, isFalse);
    expect(use?.givesManna, isFalse);
    final problems = <String>[];
    checkItemUse('Item', {'jar': 'clay'}, problems);
    expect(problems, isEmpty);
    checkItemUse('Item', {'jar': 'clay', 'manna': 5}, problems);
    expect(problems, isNotEmpty);
  });

  group('the real game', () {
    final chance = _read('chance') as Map<String, dynamic>;
    final jars = JarsConfig.fromJson(chance['jars'] as Map<String, dynamic>);

    test('three kinds of jar; the two for sale hold no Pearls', () {
      expect(jars.kinds.keys, containsAll(['clay', 'treasure', 'golden']));
      expect([for (final j in jars.forSale) j.id], ['treasure', 'golden']);
      for (final jar in jars.forSale) {
        expect(jar.prizes.every((p) => p.pearls == 0), isTrue, reason: jar.id);
      }
      expect(jars.kinds[jars.orderJar]?.paid, isFalse);
      for (final jar in jars.kinds.values) {
        expect(
          jar.odds.fold<double>(0, (sum, o) => sum + o.chance),
          closeTo(1, 1e-9),
        );
      }
    });
  });

  group('the checker', () {
    Map<String, dynamic> copy() =>
        jsonDecode(jsonEncode(_read('chance'))) as Map<String, dynamic>;
    List<String> check(void Function(Map<String, dynamic> jars) change) {
      final chance = copy();
      change(chance['jars'] as Map<String, dynamic>);
      return chanceProblems(
        chance,
        chainsJson: _read('chains'),
        generatorsJson: _read('generators'),
      );
    }

    Map<String, dynamic> kind(Map<String, dynamic> jars, String id) =>
        (jars['kinds'] as Map<String, dynamic>)[id] as Map<String, dynamic>;
    List<dynamic> prizes(Map<String, dynamic> jars, String id) =>
        kind(jars, id)['prizes'] as List<dynamic>;

    test('reports what is wrong', () {
      expect(check((j) {}), isEmpty);
      expect(check((j) => j['clay_every_orders'] = -1), isNotEmpty);
      // The jar given with orders must not be one that is sold.
      expect(check((j) => j['order_jar'] = 'treasure'), isNotEmpty);
      expect(check((j) => j['order_jar'] = 'no_such_jar'), isNotEmpty);
      expect(check((j) => kind(j, 'clay')['item'] = 'bakery_01'), isNotEmpty);
      expect(check((j) => kind(j, 'treasure')['pearl_price'] = 0), isNotEmpty);
      expect(check((j) => prizes(j, 'golden').clear()), isNotEmpty);
      // An item on the board that says it is a kind of jar nobody defined.
      expect(
        check((j) => (j['kinds'] as Map<String, dynamic>).remove('golden')),
        isNotEmpty,
      );
    });

    test('a jar that is sold can never hold Pearls, and no jar holds a '
        'jar', () {
      expect(
        check(
          (j) => prizes(j, 'treasure').add({
            'id': 'pearls',
            'name': '5 Pearls',
            'weight': 1,
            'pearls': 5,
            'free_only': true,
          }),
        ),
        isNotEmpty,
      );
      expect(
        check(
          (j) => prizes(j, 'clay').add({
            'id': 'jar',
            'name': 'Golden Jar',
            'weight': 1,
            'items': ['goldenjar_01'],
          }),
        ),
        isNotEmpty,
      );
    });
  });
}
