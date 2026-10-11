// The Treasure Jar (EXPANSION section 13 and 21.1): a jar that fills with
// Pearls as the player plays and is opened with a purchase once it is full.
// Each time it is opened the next one is bigger. Pure Dart, fully tested.
//
// What opening a jar GIVES is decided by the server (verify-purchase), like
// every purchase: the amount for the jar's size. The count kept here only
// decides when the jar may be opened and what the player is shown.
import 'package:whispers_of_joppa/domain/purchases.dart';

/// One size of jar.
class JarSize {
  final String id;

  /// The store product that opens it (it carries the price).
  final String productId;

  /// How many Pearls it holds when full: what opening it gives.
  final int pearls;

  const JarSize({
    required this.id,
    required this.productId,
    required this.pearls,
  });
}

class TreasureJarRules {
  /// Smallest first; a jar that has been opened is followed by the next.
  final List<JarSize> sizes;

  /// Pearls saved for each order delivered, story task done and level won.
  final int perOrder;
  final int perTask;
  final int perLevel;

  const TreasureJarRules({
    required this.sizes,
    this.perOrder = 0,
    this.perTask = 0,
    this.perLevel = 0,
  });

  /// Reads content/offers.json's "treasure_jar"; null if there is none, or
  /// it names no usable size (the game then has no Treasure Jar).
  static TreasureJarRules? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    int amount(Object? value) => value is int && value > 0 ? value : 0;
    final sizes = [
      if (json['sizes'] case final List<dynamic> list)
        for (final s in list)
          if (s case {
            'id': final String id,
            'product_id': final String productId,
            'pearls': final int pearls,
          } when pearls > 0)
            JarSize(id: id, productId: productId, pearls: pearls),
    ];
    if (sizes.isEmpty) return null;
    final earn = json['earn'];
    return TreasureJarRules(
      sizes: sizes,
      perOrder: earn is Map<String, dynamic> ? amount(earn['order']) : 0,
      perTask: earn is Map<String, dynamic> ? amount(earn['task']) : 0,
      perLevel: earn is Map<String, dynamic> ? amount(earn['level']) : 0,
    );
  }

  /// The size of a player's jar after [opened] jars: the last size goes on
  /// for ever.
  JarSize sizeAfter(int opened) =>
      sizes[opened < 0
          ? 0
          : (opened >= sizes.length ? sizes.length - 1 : opened)];

  bool isJarProduct(String productId) =>
      sizes.any((s) => s.productId == productId);
}

/// The store products that open a jar, as products that can be bought again
/// and again and give what the server records.
Map<String, ProductModel> treasureJarProductsFrom(Object? offersJson) => {
  if (offersJson case {'treasure_jar': final Object jar})
    for (final size
        in TreasureJarRules.fromJson(jar)?.sizes ?? const <JarSize>[])
      size.productId: ProductModel(
        id: size.productId,
        consumable: true,
        reusable: true,
      ),
};

/// A player's jar, as kept in the save file.
class TreasureJarState {
  /// Pearls saved in the present jar.
  final int saved;

  /// How many jars this player has opened.
  final int opened;

  /// Whether the player has been told that this jar is full.
  final bool toldFull;

  const TreasureJarState({
    this.saved = 0,
    this.opened = 0,
    this.toldFull = false,
  });

  factory TreasureJarState.fromJson(Map<String, dynamic>? json) {
    int count(String key) => switch (json?[key]) {
      final int n when n > 0 => n,
      _ => 0,
    };
    return TreasureJarState(
      saved: count('saved'),
      opened: count('opened'),
      toldFull: json?['told_full'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'saved': saved,
    'opened': opened,
    'told_full': toldFull,
  };
}

/// Whether the jar holds all it can (only then can it be opened).
bool jarIsFull(TreasureJarRules rules, TreasureJarState state) =>
    state.saved >= rules.sizeAfter(state.opened).pearls;

/// The jar after [pearls] more are saved: never more than it holds.
TreasureJarState jarAfterSaving(
  TreasureJarRules rules,
  TreasureJarState state,
  int pearls,
) {
  if (pearls <= 0) return state;
  final most = rules.sizeAfter(state.opened).pearls;
  final saved = state.saved + pearls;
  return TreasureJarState(
    saved: saved > most ? most : saved,
    opened: state.opened,
    toldFull: state.toldFull,
  );
}

/// The jar after it is opened [times] (a purchase the server confirmed): an
/// empty one of the next size.
TreasureJarState jarAfterOpening(TreasureJarState state, {int times = 1}) =>
    times <= 0 ? state : TreasureJarState(opened: state.opened + times);

/// The jar once the player has been told it is full.
TreasureJarState jarToldFull(TreasureJarState state) =>
    TreasureJarState(saved: state.saved, opened: state.opened, toldFull: true);
