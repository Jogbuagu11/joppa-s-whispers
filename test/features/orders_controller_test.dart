import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/board_inventory.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';

class _FakeBoard implements BoardInventory {
  final Map<String, int> counts;
  final _changed = ValueNotifier<int>(0);
  _FakeBoard(this.counts);

  @override
  Listenable get boardChanged => _changed;

  @override
  Map<String, int> itemCounts() => Map.of(counts);

  @override
  bool removeItems(Map<String, int> remove) {
    if (remove.entries.any((e) => (counts[e.key] ?? 0) < e.value)) return false;
    remove.forEach((id, n) => counts[id] = (counts[id] ?? 0) - n);
    _changed.value++;
    return true;
  }

  void add(String id) {
    counts[id] = (counts[id] ?? 0) + 1;
    _changed.value++;
  }
}

OrderModel _order(String id, String itemId, int count, int talents) =>
    OrderModel(
      id: id,
      chapter: 1,
      characterId: 'silas',
      kind: 'literal',
      items: [OrderItem(itemId: itemId, count: count)],
      talents: talents,
      blessings: 1,
      text: '',
    );

void main() {
  const config = EconomyConfig(
    maxManna: 100,
    mannaRegenSeconds: 120,
    generatorTapCost: 1,
    orderTalentsPerTier: 5,
    orderSlots: 2,
    mannaRefillBasePearls: 10,
    basketSlotBasePearls: 10,
    orderSkipCooldownSeconds: 1800,
    rewardedAdMannaBonus: 20,
    rewardedAdMannaDailyCap: 5,
    rewardedAdDoubleRewardDailyCap: 3,
  );
  final orders = [
    _order('a', 'bakery_01', 2, 10),
    _order('b', 'bakery_02', 1, 10),
    _order('c', 'fruit_01', 1, 5),
  ];
  late DateTime now;
  late _FakeBoard board;
  late OrdersController controller;

  setUp(() {
    now = DateTime(2040, 1, 1, 12);
    board = _FakeBoard({'bakery_01': 2});
    controller = OrdersController(
      config: config,
      board: board,
      orders: orders,
      clock: () => now,
    );
  });

  test('shows as many orders as there are slots', () {
    expect([for (final o in controller.activeOrders) o.id], ['a', 'b']);
    expect(controller.talents, 0);
    expect(controller.blessings, 0);
  });

  test('delivering takes the items, pays, and shows the next order', () {
    expect(controller.canDeliver(orders[0]), isTrue);
    expect(controller.deliver('a'), isTrue);
    expect(board.counts['bakery_01'], 0);
    expect(controller.talents, 10);
    expect(controller.blessings, 1);
    expect([for (final o in controller.activeOrders) o.id], ['c', 'b']);
  });

  test('cannot deliver without the items; nothing changes', () {
    expect(controller.canDeliver(orders[1]), isFalse);
    expect(controller.deliver('b'), isFalse);
    expect(controller.talents, 0);
    expect(board.counts, {'bakery_01': 2});
  });

  test('cannot deliver an order that is not showing, or twice', () {
    board.add('fruit_01');
    expect(controller.deliver('c'), isFalse);
    expect(controller.deliver('a'), isTrue);
    expect(controller.deliver('a'), isFalse);
    expect(controller.talents, 10);
  });

  test('listeners hear about board changes and deliveries', () {
    var notified = 0;
    controller.addListener(() => notified++);
    board.add('bakery_02');
    expect(notified, 1);
    controller.deliver('b');
    expect(notified, greaterThanOrEqualTo(2));
  });

  test('skip swaps the order and then waits for the cooldown', () {
    expect(controller.canSkip, isTrue);
    controller.skip('a');
    expect([for (final o in controller.activeOrders) o.id], ['c', 'b']);
    expect(controller.canSkip, isFalse);
    now = now.add(const Duration(minutes: 31));
    expect(controller.canSkip, isTrue);
  });

  test('stops listening to the board after dispose', () {
    var notified = 0;
    controller.addListener(() => notified++);
    controller.dispose();
    board.add('bakery_02');
    expect(notified, 0);
  });
}
