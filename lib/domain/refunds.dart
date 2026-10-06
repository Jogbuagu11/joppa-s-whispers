// What a refund takes back out of the game. Pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/purchases.dart';

/// The refunded purchases whose contents are in this game and so must be
/// taken back: each transaction once, and only if it was applied here.
List<PurchaseRecord> refundsToApply(
  List<PurchaseRecord> fromServer,
  Set<String> appliedTransactionIds,
  Map<String, ProductModel> products,
) {
  final seen = <String>{};
  return [
    for (final record in fromServer)
      if (record.refunded &&
          !record.granted &&
          products.containsKey(record.productId) &&
          appliedTransactionIds.contains(record.transactionId) &&
          seen.add(record.transactionId))
        record,
  ];
}

/// For a refunded one-time product that the player has also paid for in
/// another purchase that still stands (the same pack bought on an iPhone and
/// an Android phone, say): refunded transaction id -> the standing one that
/// takes its place. Such a refund takes nothing out of the game.
Map<String, String> standInPurchases(
  List<PurchaseRecord> refunds,
  List<PurchaseRecord> fromServer,
  Set<String> appliedTransactionIds,
  Map<String, ProductModel> products,
) {
  final used = {...appliedTransactionIds};
  final out = <String, String>{};
  for (final refund in refunds) {
    if (products[refund.productId]?.consumable ?? true) continue;
    for (final other in fromServer) {
      if (other.granted &&
          other.productId == refund.productId &&
          other.transactionId.isNotEmpty &&
          used.add(other.transactionId)) {
        out[refund.transactionId] = other.transactionId;
        break;
      }
    }
  }
  return out;
}

/// How many Pearls [refunds] take back from a player holding [pearls]: the
/// Pearls those purchases gave, but never more than the player still has.
int pearlsToRemove(
  int pearls,
  List<PurchaseRecord> refunds,
  Map<String, ProductModel> products,
) {
  final given = totalGrant(refunds, products).pearls;
  if (pearls <= 0) return 0;
  return given > pearls ? pearls : given;
}

/// The one-time products the player no longer owns after [refunds] (those
/// not covered by a stand-in purchase).
Set<String> productsNoLongerOwned(
  List<PurchaseRecord> refunds,
  Map<String, ProductModel> products,
) => {
  for (final record in refunds)
    if (!(products[record.productId]?.consumable ?? true)) record.productId,
};
