// The Joppa Special: a showpiece pop-up offering three packs side by side,
// the middle one raised. Each pack says exactly what it gives, at the
// store's own price, and there is always a clear way to say no.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/features/shop/special_pack_card.dart';
import 'package:whispers_of_joppa/features/shop/special_parts.dart';
import 'package:whispers_of_joppa/services/store_service.dart';

/// One pack in the special: a store product under a name of its own.
class SpecialPack {
  final String productId;
  final String name;

  /// True for the pack that is raised and starred.
  final bool featured;

  const SpecialPack({
    required this.productId,
    required this.name,
    this.featured = false,
  });
}

/// The special as content describes it (content/offers.json, "special").
class SpecialOffer {
  final String title;
  final String subtitle;
  final String picture;
  final String noThanks;
  final String unavailable;
  final String pearlsWord;
  final List<SpecialPack> packs;

  const SpecialOffer({
    required this.title,
    required this.subtitle,
    required this.picture,
    required this.noThanks,
    required this.unavailable,
    required this.pearlsWord,
    required this.packs,
  });

  /// Null if [json] is not a special.
  static SpecialOffer? fromJson(Object? json) => switch (json) {
    {
      'title': final String title,
      'subtitle': final String subtitle,
      'picture': final String picture,
      'no_thanks': final String noThanks,
      'unavailable': final String unavailable,
      'pearls_word': final String pearlsWord,
      'packs': final List<dynamic> packs,
    } =>
      SpecialOffer(
        title: title,
        subtitle: subtitle,
        picture: picture,
        noThanks: noThanks,
        unavailable: unavailable,
        pearlsWord: pearlsWord,
        packs: [
          for (final pack in packs)
            if (pack case {
              'product_id': final String id,
              'name': final String name,
            })
              SpecialPack(
                productId: id,
                name: name,
                featured: pack['featured'] == true,
              ),
        ],
      ),
    _ => null,
  };
}

/// Shows the special. Buying goes through the shop, exactly as in the
/// Pearl shop; the pop-up stays until the player closes it.
Future<void> showSpecialOffer(
  BuildContext context, {
  required SpecialOffer offer,
  required PurchaseCoordinator shop,
  void Function(String productId)? onBuy,
}) => showDialog<void>(
  context: context,
  builder: (context) => _SpecialDialog(offer: offer, shop: shop, onBuy: onBuy),
);

class _SpecialDialog extends StatefulWidget {
  const _SpecialDialog({required this.offer, required this.shop, this.onBuy});

  final SpecialOffer offer;
  final PurchaseCoordinator shop;
  final void Function(String productId)? onBuy;

  @override
  State<_SpecialDialog> createState() => _SpecialDialogState();
}

class _SpecialDialogState extends State<_SpecialDialog> {
  late final Future<List<StoreProduct>> _products = widget.shop.loadProducts();

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return Semantics(
      namesRoute: true,
      explicitChildNodes: true,
      label: offer.title,
      child: Dialog(
        key: const Key('special_offer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 14, right: 6),
                  decoration: BoxDecoration(
                    color: GamePalette.panel,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: GamePalette.talents, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xCC000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpecialHeader(
                        picture: offer.picture,
                        title: offer.title,
                        subtitle: offer.subtitle,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
                        child: _packs(),
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: widget.shop.message,
                        builder: (context, message, _) => message == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  0,
                                ),
                                child: Text(
                                  message,
                                  key: const Key('special_message'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFF3E5C8),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                      ),
                      TextButton(
                        key: const Key('special_no_thanks'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          offer.noThanks,
                          style: const TextStyle(
                            color: GamePalette.muted,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: SpecialClose(onTap: () => Navigator.of(context).pop()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _packs() => FutureBuilder<List<StoreProduct>>(
    future: _products,
    builder: (context, snapshot) {
      final loaded = snapshot.data;
      if (loaded == null) {
        return const Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(color: GamePalette.gold),
        );
      }
      final prices = {for (final p in loaded) p.id: p.price};
      final packs = [
        for (final pack in widget.offer.packs)
          // Only what the store really sells, with contents the game knows.
          if (prices.containsKey(pack.productId) &&
              (widget.shop.products[pack.productId]?.pearls ?? 0) > 0)
            pack,
      ];
      if (packs.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            widget.offer.unavailable,
            key: const Key('special_unavailable'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFF3E5C8)),
          ),
        );
      }
      return ValueListenableBuilder<bool>(
        valueListenable: widget.shop.busy,
        builder: (context, busy, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (index, pack) in packs.indexed)
              Expanded(
                child: SpecialPackCard(
                  key: Key('special_pack_${pack.productId}'),
                  name: pack.name,
                  pearls: widget.shop.products[pack.productId]?.pearls ?? 0,
                  pearlsWord: widget.offer.pearlsWord,
                  // The price is the store's own, never written in the app.
                  price: prices[pack.productId] ?? '',
                  featured: pack.featured,
                  size: index,
                  onBuy: busy
                      ? null
                      : () {
                          widget.onBuy?.call(pack.productId);
                          widget.shop.buy(pack.productId);
                        },
                ),
              ),
          ],
        ),
      );
    },
  );
}
