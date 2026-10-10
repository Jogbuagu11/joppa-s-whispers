// The player's Pearls and the record of which purchases are already in the
// game. Bought Pearls only ever arrive here from purchases the server has
// confirmed; small amounts are also won in play (earnPearls).
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/refunds.dart';

class PurchasesController extends ChangeNotifier {
  /// product_id -> what it gives (from content/products.json).
  final Map<String, ProductModel> products;

  /// Adds bought Manna to the player's Manna.
  final void Function(int amount) addManna;

  /// Raises the player's generators to at least this level.
  final void Function(int level) raiseGenerators;

  int _pearls;
  final Set<String> _applied;
  final Set<String> _owned;

  PurchasesController({
    required this.products,
    required this.addManna,
    required this.raiseGenerators,
    int startingPearls = 0,
    Iterable<String> appliedTransactions = const [],
    Iterable<String> ownedProducts = const [],
  }) : _pearls = startingPearls,
       _applied = {...appliedTransactions},
       _owned = {...ownedProducts};

  int get pearls => _pearls;

  /// The Pearls count as something a widget can listen to.
  late final ValueNotifier<int> pearlsListenable = ValueNotifier<int>(_pearls);

  @override
  void notifyListeners() {
    pearlsListenable.value = _pearls;
    super.notifyListeners();
  }

  @override
  void dispose() {
    pearlsListenable.dispose();
    super.dispose();
  }

  /// Written to the save file.
  List<String> get appliedTransactions => _applied.toList();
  List<String> get ownedProducts => _owned.toList();

  bool canBuyProduct(String productId) => canBuy(productId, products, _owned);

  /// Whether this transaction's contents are already in the game.
  bool hasApplied(String transactionId) => _applied.contains(transactionId);

  /// Puts every server-confirmed purchase that is not in the game yet into
  /// it, each exactly once. Returns what was added (empty if nothing was).
  GrantTotals applyConfirmed(List<PurchaseRecord> fromServer) {
    final fresh = purchasesToApply(
      fromServer,
      _applied,
      products,
      ownedProductIds: _owned,
    );
    if (fresh.isEmpty) return const GrantTotals();
    final totals = totalGrant(fresh, products);
    for (final record in fresh) {
      _applied.add(record.transactionId);
      if (!(products[record.productId]?.consumable ?? true)) {
        _owned.add(record.productId);
      }
    }
    _pearls += totals.pearls;
    if (totals.manna > 0) addManna(totals.manna);
    final level = totals.generatorLevel;
    if (level != null) raiseGenerators(level);
    notifyListeners();
    return totals;
  }

  /// Takes back what refunded purchases gave: their Pearls (never below
  /// zero) and ownership of a refunded one-time product. Each refund is
  /// taken once. Returns the number of refunds handled.
  ///
  /// Manna and generator levels from a refunded starter pack stay: once the
  /// player has played on, there is no telling which Manna was the pack's.
  int applyRefunds(List<PurchaseRecord> fromServer) {
    final refunds = refundsToApply(fromServer, _applied, products);
    if (refunds.isEmpty) return 0;
    // A one-time product also paid for in a purchase that still stands is
    // kept: that purchase takes the refunded one's place.
    final standIns = standInPurchases(refunds, fromServer, _applied, products);
    final lost = [
      for (final r in refunds)
        if (!standIns.containsKey(r.transactionId)) r,
    ];
    _pearls -= pearlsToRemove(_pearls, lost, products);
    _owned.removeAll(productsNoLongerOwned(lost, products));
    // Forgetting the transaction is what stops it being taken back twice.
    _applied
      ..removeAll(refunds.map((r) => r.transactionId))
      ..addAll(standIns.values);
    notifyListeners();
    return refunds.length;
  }

  /// Adds Pearls won or earned in play (never bought ones: those come only
  /// through a verified purchase).
  void earnPearls(int amount) {
    if (amount <= 0) return;
    _pearls += amount;
    notifyListeners();
  }

  /// Takes Pearls for something bought with them. Returns false, taking
  /// nothing, if there are not enough.
  bool spendPearls(int amount) {
    if (amount < 0 || amount > _pearls) return false;
    _pearls -= amount;
    notifyListeners();
    return true;
  }
}
