// The player's Pearls and the record of which purchases are already in the
// game. Pearls only ever arrive here from purchases the server has confirmed.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';

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

  /// Puts every server-confirmed purchase that is not in the game yet into
  /// it, each exactly once. Returns what was added (empty if nothing was).
  GrantTotals applyConfirmed(List<PurchaseRecord> fromServer) {
    final fresh = purchasesToApply(fromServer, _applied, products);
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

  /// Takes Pearls for something bought with them. Returns false, taking
  /// nothing, if there are not enough.
  bool spendPearls(int amount) {
    if (amount < 0 || amount > _pearls) return false;
    _pearls -= amount;
    notifyListeners();
    return true;
  }
}
