// What each product gives, and which verified purchases still need applying.
// Pure Dart, fully unit tested.

/// A product from content/products.json.
class ProductModel {
  final String id;

  /// True for packs that can be bought again and again.
  final bool consumable;
  final int pearls;
  final int manna;

  /// If set, the player's generators are raised to at least this level.
  final int? generatorLevel;

  const ProductModel({
    required this.id,
    required this.consumable,
    this.pearls = 0,
    this.manna = 0,
    this.generatorLevel,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'] as String,
    consumable: json['type'] == 'consumable',
    pearls: json['pearls'] as int? ?? 0,
    manna: json['manna'] as int? ?? 0,
    generatorLevel: json['generator_level'] as int?,
  );
}

/// A purchase as the server recorded it for this player.
class PurchaseRecord {
  final String transactionId;
  final String productId;

  /// True while the purchase stands; false once refunded or still pending.
  final bool granted;

  const PurchaseRecord({
    required this.transactionId,
    required this.productId,
    required this.granted,
  });
}

/// The sum of what a set of purchases gives.
class GrantTotals {
  final int pearls;
  final int manna;
  final int? generatorLevel;

  const GrantTotals({this.pearls = 0, this.manna = 0, this.generatorLevel});

  bool get isEmpty => pearls == 0 && manna == 0 && generatorLevel == null;
}

/// The server-confirmed purchases that have not been applied to this game
/// yet. Each transaction is applied at most once: anything already in
/// [appliedTransactionIds], repeated in the list, refunded, pending, or for a
/// product this build does not know is left out.
///
/// A one-time product is applied at most once in total, however many
/// transactions exist for it (the same pack bought on an iPhone and an
/// Android phone, say): [ownedProductIds] are the ones this game already has.
List<PurchaseRecord> purchasesToApply(
  List<PurchaseRecord> fromServer,
  Set<String> appliedTransactionIds,
  Map<String, ProductModel> products, {
  Set<String> ownedProductIds = const {},
}) {
  final seen = {...appliedTransactionIds};
  final owned = {...ownedProductIds};
  final out = <PurchaseRecord>[];
  for (final record in fromServer) {
    final product = products[record.productId];
    if (!record.granted || product == null) continue;
    if (record.transactionId.isEmpty) continue;
    if (!seen.add(record.transactionId)) continue;
    if (!product.consumable && !owned.add(product.id)) continue;
    out.add(record);
  }
  return out;
}

/// The level each generator ends up at when a purchase raises generators to
/// at least [level]: lower ones are raised, higher ones are left alone.
List<int> raisedGeneratorLevels(List<int> currentLevels, int level) => [
  for (final current in currentLevels) current < level ? level : current,
];

/// What [records] give in total.
GrantTotals totalGrant(
  List<PurchaseRecord> records,
  Map<String, ProductModel> products,
) {
  var pearls = 0;
  var manna = 0;
  int? level;
  for (final record in records) {
    final product = products[record.productId];
    if (product == null) continue;
    pearls += product.pearls;
    manna += product.manna;
    final wanted = product.generatorLevel;
    if (wanted != null && (level == null || wanted > level)) level = wanted;
  }
  return GrantTotals(pearls: pearls, manna: manna, generatorLevel: level);
}

/// Whether [productId] may be bought now: a one-time product can only be
/// bought if the player does not already own it.
bool canBuy(
  String productId,
  Map<String, ProductModel> products,
  Set<String> ownedProductIds,
) {
  final product = products[productId];
  if (product == null) return false;
  return product.consumable || !ownedProductIds.contains(productId);
}
