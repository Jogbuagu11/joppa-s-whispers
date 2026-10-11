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

  /// True for a store product that carries only a price (an offer): what
  /// it gives is decided by the server and comes with each purchase.
  final bool reusable;

  const ProductModel({
    required this.id,
    required this.consumable,
    this.pearls = 0,
    this.manna = 0,
    this.generatorLevel,
    this.reusable = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'] as String,
    consumable: json['type'] == 'consumable',
    pearls: json['pearls'] as int? ?? 0,
    manna: json['manna'] as int? ?? 0,
    generatorLevel: json['generator_level'] as int?,
  );
}

/// The reusable offer products named in content/offers.json
/// ("offer_products"), as products that can be bought again and again.
Map<String, ProductModel> offerProductsFrom(Object? offersJson) => {
  if (offersJson case {'offer_products': final List<dynamic> ids})
    for (final id in ids)
      if (id is String)
        id: ProductModel(id: id, consumable: true, reusable: true),
};

/// Exactly what the server recorded one purchase as giving.
class PurchaseGrant {
  final int pearls;
  final int manna;
  final int talents;
  final List<String> items;
  final int? generatorLevel;

  /// For a season pass: the event it is for, and whether it is Premium
  /// Plus. Null for every other purchase.
  final String? passEventId;
  final bool passPlus;

  const PurchaseGrant({
    this.pearls = 0,
    this.manna = 0,
    this.talents = 0,
    this.items = const [],
    this.generatorLevel,
    this.passEventId,
    this.passPlus = false,
  });

  /// Reads the server's record; null if there is none (a purchase made
  /// before grants were recorded). Anything odd in it counts as nothing.
  static PurchaseGrant? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    int amount(String key) => switch (json[key]) {
      final int n when n > 0 => n,
      _ => 0,
    };
    return PurchaseGrant(
      pearls: amount('pearls'),
      manna: amount('manna'),
      talents: amount('talents'),
      items: [
        if (json['items'] case final List<dynamic> ids)
          for (final id in ids)
            if (id is String) id,
      ],
      generatorLevel: switch (json['generator_level']) {
        final int level when level > 0 => level,
        _ => null,
      },
      passEventId: switch (json['pass']) {
        {'event_id': final String id} when id.isNotEmpty => id,
        _ => null,
      },
      passPlus: switch (json['pass']) {
        {'tier': 'plus'} => true,
        _ => false,
      },
    );
  }
}

/// A purchase as the server recorded it for this player.
class PurchaseRecord {
  final String transactionId;
  final String productId;

  /// True while the purchase stands; false once refunded or still pending.
  final bool granted;

  /// True once the store has given the player their money back.
  final bool refunded;

  /// What the server recorded this purchase as giving (an offer's contents,
  /// a doubled first pack). Null for purchases recorded before that was
  /// kept: those give what the product gives.
  final PurchaseGrant? grant;

  const PurchaseRecord({
    required this.transactionId,
    required this.productId,
    required this.granted,
    this.refunded = false,
    this.grant,
  });
}

/// The sum of what a set of purchases gives.
class GrantTotals {
  final int pearls;
  final int manna;
  final int talents;
  final List<String> items;
  final int? generatorLevel;

  /// How many of the purchases were a season pass.
  final int passes;

  const GrantTotals({
    this.pearls = 0,
    this.manna = 0,
    this.talents = 0,
    this.items = const [],
    this.generatorLevel,
    this.passes = 0,
  });

  bool get isEmpty =>
      pearls == 0 &&
      manna == 0 &&
      talents == 0 &&
      items.isEmpty &&
      generatorLevel == null &&
      passes == 0;
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
    // A product that carries only a price gives what the server recorded:
    // with no record of that it is left for later, never given as nothing.
    if (product.reusable && record.grant == null) continue;
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

/// What [records] give in total: for each, what the server recorded it as
/// giving, or (for an older record without that) what its product gives.
GrantTotals totalGrant(
  List<PurchaseRecord> records,
  Map<String, ProductModel> products,
) {
  var pearls = 0;
  var manna = 0;
  var talents = 0;
  final items = <String>[];
  var passes = 0;
  int? level;
  for (final record in records) {
    final product = products[record.productId];
    if (product == null) continue;
    // What the server recorded wins; the product's own contents are for
    // purchases recorded before grants were kept.
    final grant =
        record.grant ??
        PurchaseGrant(
          pearls: product.pearls,
          manna: product.manna,
          generatorLevel: product.generatorLevel,
        );
    pearls += grant.pearls;
    manna += grant.manna;
    talents += grant.talents;
    items.addAll(grant.items);
    if (grant.passEventId != null) passes++;
    final wanted = grant.generatorLevel;
    if (wanted != null && (level == null || wanted > level)) level = wanted;
  }
  return GrantTotals(
    pearls: pearls,
    manna: manna,
    talents: talents,
    items: items,
    generatorLevel: level,
    passes: passes,
  );
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
