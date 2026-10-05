// Holds the visible orders and the player's Talents and Blessings.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/orders.dart';

/// What the orders need from the board, so this file does not depend on Flame.
abstract class BoardInventory {
  /// item_id -> how many are on the board right now.
  Map<String, int> itemCounts();

  /// Takes the given number of each item off the board.
  void removeItems(Map<String, int> counts);

  /// Fires whenever the items on the board change.
  Listenable get boardChanged;
}

class OrdersController extends ChangeNotifier {
  final EconomyConfig config;
  final BoardInventory board;
  final Map<String, OrderModel> _orders;
  final DateTime Function() _now;
  OrderBook _book;
  int _talents = 0;
  int _blessings = 0;

  OrdersController({
    required this.config,
    required this.board,
    required List<OrderModel> orders,
    DateTime Function()? clock,
  }) : _orders = {for (final o in orders) o.id: o},
       _now = clock ?? DateTime.now,
       _book = startOrders([for (final o in orders) o.id], config.orderSlots) {
    board.boardChanged.addListener(notifyListeners);
  }

  int get talents => _talents;
  int get blessings => _blessings;

  /// The orders on screen, in card order.
  List<OrderModel> get activeOrders => [
    for (final id in _book.active) ?_orders[id],
  ];

  bool canDeliver(OrderModel order) => canFillOrder(order, board.itemCounts());

  bool get canSkip => canSkipOrder(config, _book, _now());

  /// Takes the items off the board, pays the rewards and shows the next order.
  /// Returns false, changing nothing, if the board does not have the items.
  bool deliver(String orderId) {
    final order = _orders[orderId];
    if (order == null || !_book.active.contains(orderId)) return false;
    if (!canDeliver(order)) return false;
    _talents += order.talents;
    _blessings += order.blessings;
    _book = completeOrder(_book, orderId);
    // Removing items fires boardChanged, which refreshes listeners.
    board.removeItems({for (final i in order.items) i.itemId: i.count});
    return true;
  }

  /// Swaps an order for the next one, if skipping is allowed right now.
  void skip(String orderId) {
    _book = skipOrder(config, _book, orderId, _now());
    notifyListeners();
  }

  @override
  void dispose() {
    board.boardChanged.removeListener(notifyListeners);
    super.dispose();
  }
}
