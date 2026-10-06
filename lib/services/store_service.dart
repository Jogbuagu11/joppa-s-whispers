// The app stores (App Store / Google Play), behind an interface so the
// purchase flow can be tested without them.
import 'package:whispers_of_joppa/domain/purchases.dart';

/// A product as the store describes it, with the store's own localized price.
class StoreProduct {
  final String id;
  final String title;
  final String price;

  const StoreProduct({
    required this.id,
    required this.title,
    required this.price,
  });
}

enum StorePurchaseStatus { pending, purchased, restored, canceled, failed }

/// Something the store reports about a purchase.
class StorePurchase {
  final String productId;

  /// The store's id for this transaction (null until the store assigns one).
  final String? transactionId;

  /// What the server needs to check the purchase with the store.
  final String receipt;
  final StorePurchaseStatus status;

  /// The store's own object, handed back to [StoreService.finish].
  final Object? raw;

  const StorePurchase({
    required this.productId,
    required this.transactionId,
    required this.receipt,
    required this.status,
    this.raw,
  });
}

abstract class StoreService {
  /// 'ios' or 'android'.
  String get platform;

  /// Purchases as the store reports them, including ones left unfinished by
  /// an earlier run of the app.
  Stream<StorePurchase> get purchases;

  /// Whether purchases can be made on this device at all.
  Future<bool> isAvailable();

  /// The store's listing for each of [productIds] that it knows.
  Future<List<StoreProduct>> loadProducts(Set<String> productIds);

  /// Opens the store's payment sheet. The result arrives on [purchases].
  /// [accountId] is the signed-in player's id; the store attaches it to the
  /// purchase so the server can check the purchase belongs to that player.
  Future<void> buy(ProductModel product, {required String accountId});

  /// Tells the store the purchase has been delivered. Only call this after
  /// the server has confirmed and the contents have been granted.
  Future<void> finish(StorePurchase purchase, {required bool consumable});

  /// Asks the store to report purchases again (restores one-time products and
  /// surfaces anything left unfinished). On iPhone this can ask the player
  /// for their Apple ID, so only call it when they tap "Restore purchases".
  Future<void> restore();

  /// Quietly asks the store for purchases left unfinished by an earlier run,
  /// without ever prompting the player. Safe to call at every launch.
  Future<void> redeliverUnfinished();
}
