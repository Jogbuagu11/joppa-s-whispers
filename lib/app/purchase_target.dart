// The game that purchases are delivered into, as the purchase coordinator
// sees it.
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/services/store_service.dart';

final _log = Logger('Purchases');

/// The game a purchase is delivered into.
class PurchaseTarget {
  /// Puts server-confirmed purchases into the game (each once) and returns
  /// what was added.
  final GrantTotals Function(List<PurchaseRecord> fromServer) applyConfirmed;

  /// Whether a transaction's contents are already in the game.
  final bool Function(String transactionId) hasApplied;

  /// Takes back what refunded purchases gave (each once) and returns how
  /// many refunds were handled.
  final int Function(List<PurchaseRecord> fromServer) applyRefunds;

  /// Writes the game to disk now, so a grant survives the app being closed.
  final Future<void> Function() saveNow;

  const PurchaseTarget({
    required this.applyConfirmed,
    required this.hasApplied,
    required this.applyRefunds,
    required this.saveNow,
  });
}

/// Tells the store the purchase is delivered. A store that fails or never
/// answers must not hold up the game: it will report the purchase again.
Future<void> finishWithStore(
  StoreService store,
  StorePurchase purchase,
  ProductModel product,
) async {
  try {
    await store
        .finish(purchase, consumable: product.consumable)
        .timeout(const Duration(seconds: 15));
  } on Object catch (e) {
    _log.warning(
      'The store did not confirm finishing ${purchase.productId}: $e',
    );
  }
}

/// What a purchase added, in words for the player.
String describeGrant(GrantTotals t) => [
  if (t.pearls > 0) '${t.pearls} Pearls',
  if (t.manna > 0) '${t.manna} Manna',
  if (t.talents > 0) '${t.talents} Talents',
  if (t.items.length == 1) '1 gift',
  if (t.items.length > 1) '${t.items.length} gifts',
  if (t.generatorLevel != null) 'a level-${t.generatorLevel} generator',
].join(', ');
