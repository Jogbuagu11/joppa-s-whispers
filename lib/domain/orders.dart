// Order rules — pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/economy.dart';

/// One kind of item an order asks for, and how many.
class OrderItem {
  final String itemId;
  final int count;

  const OrderItem({required this.itemId, required this.count});
}

/// A request from a character, loaded from content/orders.json.
class OrderModel {
  final String id;
  final int chapter;
  final String characterId;
  final String kind; // "literal" or "spiritual"
  final List<OrderItem> items;
  final int talents;
  final int blessings;
  final String text;
  final String? sceneId;

  const OrderModel({
    required this.id,
    required this.chapter,
    required this.characterId,
    required this.kind,
    required this.items,
    required this.talents,
    required this.blessings,
    required this.text,
    this.sceneId,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rewards = json['rewards'] as Map<String, dynamic>;
    return OrderModel(
      id: json['id'] as String,
      chapter: json['chapter'] as int,
      characterId: json['character_id'] as String,
      kind: json['kind'] as String,
      items: [
        for (final i in json['items'] as List<dynamic>)
          OrderItem(
            itemId: (i as Map<String, dynamic>)['item_id'] as String,
            count: i['count'] as int,
          ),
      ],
      talents: rewards['talents'] as int,
      blessings: rewards['blessings'] as int,
      text: json['text'] as String,
      sceneId: json['scene_id'] as String?,
    );
  }
}

/// Whether the board holds everything [order] asks for.
/// [itemCounts] maps item_id -> how many are on the board.
bool canFillOrder(OrderModel order, Map<String, int> itemCounts) =>
    orderItemTotals(
      order,
    ).entries.every((e) => (itemCounts[e.key] ?? 0) >= e.value);

/// item_id -> total wanted, adding up an item that is listed more than once.
Map<String, int> orderItemTotals(OrderModel order) {
  final totals = <String, int>{};
  for (final i in order.items) {
    totals[i.itemId] = (totals[i.itemId] ?? 0) + i.count;
  }
  return totals;
}

/// Which orders are showing, which are waiting, and when one was last skipped.
class OrderBook {
  /// Ids of the orders on screen, in card order.
  final List<String> active;

  /// Ids of the orders still to come, next first.
  final List<String> pending;

  final DateTime? lastSkip;

  const OrderBook({required this.active, required this.pending, this.lastSkip});
}

/// Says whether an order may be shown yet. Orders belong to chapters, and a
/// later chapter's orders wait until the story reaches it.
typedef OrderAvailable = bool Function(String orderId);

bool _all(String _) => true;

/// Takes the first order in [pending] that may be shown, or null.
String? _takeNext(List<String> pending, OrderAvailable available) {
  final index = pending.indexWhere(available);
  return index < 0 ? null : pending.removeAt(index);
}

/// Starts a fresh book: the first [slots] orders that may be shown take the
/// cards, the rest wait.
OrderBook startOrders(
  List<String> orderIds,
  int slots, {
  OrderAvailable available = _all,
}) => fillOrderCards(
  OrderBook(active: const [], pending: orderIds),
  slots,
  available: available,
);

/// Fills empty cards (up to [slots]) with waiting orders that may be shown.
/// Used when the story reaches a new chapter and its orders open up.
OrderBook fillOrderCards(
  OrderBook book,
  int slots, {
  OrderAvailable available = _all,
}) {
  final active = [...book.active];
  final pending = [...book.pending];
  while (active.length < slots) {
    final next = _takeNext(pending, available);
    if (next == null) break;
    active.add(next);
  }
  return OrderBook(active: active, pending: pending, lastSkip: book.lastSkip);
}

/// Removes a delivered order; the next waiting order that may be shown takes
/// its card.
OrderBook completeOrder(
  OrderBook book,
  String orderId, {
  OrderAvailable available = _all,
}) {
  final index = book.active.indexOf(orderId);
  if (index < 0) return book;
  final active = [...book.active];
  final pending = [...book.pending];
  final next = _takeNext(pending, available);
  if (next == null) {
    active.removeAt(index);
  } else {
    active[index] = next;
  }
  return OrderBook(active: active, pending: pending, lastSkip: book.lastSkip);
}

/// Seconds until an order may be skipped again; 0 means it may be skipped now.
int skipCooldownRemaining(EconomyConfig config, OrderBook book, DateTime now) {
  final last = book.lastSkip;
  if (last == null || now.isBefore(last)) return 0;
  final left = config.orderSkipCooldownSeconds - now.difference(last).inSeconds;
  return left < 0 ? 0 : left;
}

/// An order can be skipped when the cooldown is over and another that may be
/// shown is waiting.
bool canSkipOrder(
  EconomyConfig config,
  OrderBook book,
  DateTime now, {
  OrderAvailable available = _all,
}) =>
    book.pending.any(available) &&
    skipCooldownRemaining(config, book, now) == 0;

/// Swaps [orderId] for the next waiting order and sends it to the back of the
/// line. Returns the book unchanged if skipping is not allowed.
OrderBook skipOrder(
  EconomyConfig config,
  OrderBook book,
  String orderId,
  DateTime now, {
  OrderAvailable available = _all,
}) {
  final index = book.active.indexOf(orderId);
  if (index < 0 || !canSkipOrder(config, book, now, available: available)) {
    return book;
  }
  final active = [...book.active];
  final pending = [...book.pending];
  final next = _takeNext(pending, available);
  if (next == null) return book;
  active[index] = next;
  pending.add(orderId);
  return OrderBook(active: active, pending: pending, lastSkip: now);
}

/// Brings a saved order book in line with today's content: orders that no
/// longer exist are dropped, orders added since the save join the back of the
/// line, and empty cards are refilled with orders that may be shown, so cards
/// never run dry while such orders remain. [allOrderIds] is every order in content, in story order.
OrderBook reconcileOrderBook({
  required OrderBook saved,
  required Set<String> completed,
  required List<String> allOrderIds,
  required int slots,
  OrderAvailable available = _all,
}) {
  final known = allOrderIds.toSet();
  final seen = <String>{...completed};
  List<String> keep(List<String> ids) => [
    for (final id in ids)
      if (known.contains(id) && seen.add(id)) id,
  ];
  final active = keep(saved.active);
  final pending = keep(saved.pending);
  for (final id in allOrderIds) {
    if (seen.add(id)) pending.add(id);
  }
  return fillOrderCards(
    OrderBook(active: active, pending: pending, lastSkip: saved.lastSkip),
    slots,
    available: available,
  );
}
