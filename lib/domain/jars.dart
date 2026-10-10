// Jars of Clay (EXPANSION 20.4; 2 Cor. 4:7): a jar on the board holds one
// prize, drawn when it is opened from that kind of jar's published list.
// Pure Dart.
import 'dart:math';

import 'package:whispers_of_joppa/domain/chance.dart';

/// One kind of jar.
class JarKind {
  final String id;

  /// The board item that is this jar.
  final String itemId;

  /// What it costs to buy one, or null for a jar that is only ever given.
  final int? pearlPrice;
  final List<Prize> prizes;

  const JarKind({
    required this.id,
    required this.itemId,
    required this.pearlPrice,
    required this.prizes,
  });

  /// True for a jar that can be bought: its prizes never include Pearls.
  bool get paid => pearlPrice != null;

  /// What it may hold, each with its chance: exactly what [open] draws
  /// from.
  List<PrizeOdds> get odds => oddsFor(prizes, paid: paid);

  /// Draws what this jar holds.
  Prize? open({Random? random}) =>
      drawPrize(prizes, paid: paid, random: random);
}

class JarsConfig {
  /// A clay jar is given with every so many orders delivered (0 = never).
  final int clayEveryOrders;

  /// The kind of jar given with orders.
  final String orderJar;
  final Map<String, JarKind> kinds;

  const JarsConfig({
    required this.clayEveryOrders,
    required this.orderJar,
    required this.kinds,
  });

  factory JarsConfig.fromJson(Map<String, dynamic> json) => JarsConfig(
    clayEveryOrders: json['clay_every_orders'] as int,
    orderJar: json['order_jar'] as String,
    kinds: {
      for (final e in (json['kinds'] as Map<String, dynamic>).entries)
        e.key: JarKind(
          id: e.key,
          itemId: (e.value as Map<String, dynamic>)['item'] as String,
          pearlPrice: e.value['pearl_price'] as int?,
          prizes: [
            for (final p in e.value['prizes'] as List<dynamic>)
              Prize.fromJson(p as Map<String, dynamic>),
          ],
        ),
    },
  );

  /// The jar item to give now that [delivered] orders have been delivered
  /// in all, or null if this order brings none.
  String? jarForOrder(int delivered) =>
      clayEveryOrders > 0 && delivered > 0 && delivered % clayEveryOrders == 0
      ? kinds[orderJar]?.itemId
      : null;

  /// The kinds that can be bought, cheapest first.
  List<JarKind> get forSale => [
    for (final kind in kinds.values)
      if (kind.paid) kind,
  ]..sort((a, b) => (a.pearlPrice ?? 0).compareTo(b.pearlPrice ?? 0));
}
