// Holds the visible orders and the player's Talents and Blessings.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/app/board_inventory.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/orders.dart';

class OrdersController extends ChangeNotifier {
  final EconomyConfig config;
  final BoardInventory board;
  final Map<String, OrderModel> _orders;
  final DateTime Function() _now;
  OrderBook _book;
  final Set<String> _completed;

  /// Called with the order id each time an order is delivered.
  void Function(String orderId)? onDelivered;
  int _talents;
  int _blessings;

  OrdersController({
    required this.config,
    required this.board,
    required List<OrderModel> orders,
    OrderBook? savedBook,
    Iterable<String> completedOrders = const [],
    int startingTalents = 0,
    int startingBlessings = 0,
    DateTime Function()? clock,
  }) : _orders = {for (final o in orders) o.id: o},
       _now = clock ?? DateTime.now,
       _completed = {...completedOrders},
       _talents = startingTalents,
       _blessings = startingBlessings,
       _book =
           savedBook ??
           startOrders([for (final o in orders) o.id], config.orderSlots) {
    board.boardChanged.addListener(notifyListeners);
  }

  /// Which orders are showing and waiting (written to the save file).
  OrderBook get book => _book;

  /// Ids of delivered orders (written to the save file).
  List<String> get completedOrders => _completed.toList();

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
    // The board refuses, changing nothing, if it does not hold the items.
    if (!board.removeItems(orderItemTotals(order))) return false;
    _talents += order.talents;
    _blessings += order.blessings;
    _completed.add(orderId);
    _book = completeOrder(_book, orderId);
    notifyListeners();
    onDelivered?.call(orderId);
    return true;
  }

  /// Takes Blessings for a story task. Returns false, taking nothing, if the
  /// player does not have enough.
  bool spendBlessings(int amount) {
    if (amount < 0 || amount > _blessings) return false;
    _blessings -= amount;
    notifyListeners();
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
