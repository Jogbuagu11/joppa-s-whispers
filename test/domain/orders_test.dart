import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/orders.dart';

void main() {
  const config = EconomyConfig(
    maxManna: 100,
    mannaRegenSeconds: 120,
    generatorTapCost: 1,
    orderTalentsPerTier: 5,
    orderSlots: 3,
    mannaRefillBasePearls: 10,
    basketSlotBasePearls: 10,
    orderSkipCooldownSeconds: 1800,
    rewardedAdMannaBonus: 20,
    rewardedAdMannaDailyCap: 5,
    rewardedAdDoubleRewardDailyCap: 3,
  );
  final t0 = DateTime(2040, 1, 1, 12, 0, 0);

  group('OrderModel.fromJson', () {
    test('reads every field', () {
      final o = OrderModel.fromJson({
        'id': 'ch1_o_003',
        'chapter': 1,
        'character_id': 'silas',
        'kind': 'literal',
        'items': [
          {'item_id': 'bakery_04', 'count': 2},
        ],
        'rewards': {'talents': 40, 'blessings': 1},
        'text': 'Two flatbreads?',
        'scene_id': null,
      });
      expect(o.id, 'ch1_o_003');
      expect(o.chapter, 1);
      expect(o.characterId, 'silas');
      expect(o.kind, 'literal');
      expect(o.items.single.itemId, 'bakery_04');
      expect(o.items.single.count, 2);
      expect(o.talents, 40);
      expect(o.blessings, 1);
      expect(o.text, 'Two flatbreads?');
      expect(o.sceneId, isNull);
    });
  });

  group('canFillOrder', () {
    const order = OrderModel(
      id: 'o',
      chapter: 1,
      characterId: 'silas',
      kind: 'literal',
      items: [
        OrderItem(itemId: 'bakery_04', count: 2),
        OrderItem(itemId: 'fruit_01', count: 1),
      ],
      talents: 45,
      blessings: 1,
      text: '',
    );

    test('true when the board has everything', () {
      expect(canFillOrder(order, {'bakery_04': 2, 'fruit_01': 3}), isTrue);
    });
    test('false when one item is short', () {
      expect(canFillOrder(order, {'bakery_04': 1, 'fruit_01': 1}), isFalse);
    });
    test('false when an item is missing altogether', () {
      expect(canFillOrder(order, {'bakery_04': 2}), isFalse);
    });
  });

  test('an item listed twice is added up', () {
    const twice = OrderModel(
      id: 'o',
      chapter: 1,
      characterId: 'silas',
      kind: 'literal',
      items: [
        OrderItem(itemId: 'bakery_01', count: 1),
        OrderItem(itemId: 'bakery_01', count: 2),
      ],
      talents: 15,
      blessings: 1,
      text: '',
    );
    expect(orderItemTotals(twice), {'bakery_01': 3});
    expect(canFillOrder(twice, {'bakery_01': 2}), isFalse);
    expect(canFillOrder(twice, {'bakery_01': 3}), isTrue);
  });

  group('order book', () {
    final ids = ['a', 'b', 'c', 'd', 'e'];

    test('starts with the first orders showing and the rest waiting', () {
      final book = startOrders(ids, 3);
      expect(book.active, ['a', 'b', 'c']);
      expect(book.pending, ['d', 'e']);
    });

    test('fewer orders than slots shows them all', () {
      final book = startOrders(['a'], 3);
      expect(book.active, ['a']);
      expect(book.pending, isEmpty);
    });

    test('completing an order puts the next one on the same card', () {
      final book = completeOrder(startOrders(ids, 3), 'b');
      expect(book.active, ['a', 'd', 'c']);
      expect(book.pending, ['e']);
    });

    test('completing with nothing waiting removes the card', () {
      final book = completeOrder(startOrders(['a', 'b'], 3), 'a');
      expect(book.active, ['b']);
    });

    test('completing an order that is not showing changes nothing', () {
      final start = startOrders(ids, 3);
      expect(completeOrder(start, 'e').active, start.active);
    });

    test('skipping swaps in the next order and sends this one to the back', () {
      final book = skipOrder(config, startOrders(ids, 3), 'a', t0);
      expect(book.active, ['d', 'b', 'c']);
      expect(book.pending, ['e', 'a']);
      expect(book.lastSkip, t0);
    });

    test('skipping is blocked during the cooldown and allowed after it', () {
      final book = skipOrder(config, startOrders(ids, 3), 'a', t0);
      final soon = t0.add(const Duration(minutes: 10));
      expect(canSkipOrder(config, book, soon), isFalse);
      expect(skipCooldownRemaining(config, book, soon), 1200);
      expect(skipOrder(config, book, 'b', soon).active, book.active);

      final later = t0.add(const Duration(minutes: 30));
      expect(canSkipOrder(config, book, later), isTrue);
      expect(skipOrder(config, book, 'b', later).active, ['d', 'e', 'c']);
    });

    test('skipping is not allowed when nothing is waiting', () {
      final book = startOrders(['a', 'b'], 3);
      expect(canSkipOrder(config, book, t0), isFalse);
      expect(skipOrder(config, book, 'a', t0).active, ['a', 'b']);
    });

    test('a clock set backwards does not lock skipping', () {
      final book = skipOrder(config, startOrders(ids, 3), 'a', t0);
      final earlier = t0.subtract(const Duration(hours: 5));
      expect(skipCooldownRemaining(config, book, earlier), 0);
    });
  });
}
