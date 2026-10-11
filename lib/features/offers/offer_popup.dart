// A timed offer: what it gives, listed exactly, a countdown, the store's
// own price on one button, and always a clear way to say no.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/features/offers/offer_confetti.dart';
import 'package:whispers_of_joppa/features/offers/offer_festive.dart';
import 'package:whispers_of_joppa/features/offers/offer_parts.dart';
import 'package:whispers_of_joppa/features/shop/special_parts.dart';

/// Shows [offer]. Returns true if the player bought it. Buying goes through
/// the shop exactly as in the Pearl shop: nothing is given until the server
/// has confirmed the payment.
Future<bool> showOfferPopup(
  BuildContext context, {
  required Offer offer,
  required String price,
  required DateTime endsAt,
  required PurchaseCoordinator shop,
  required Map<String, String> text,
  required String picture,
  required List<OfferGift> gifts,
  DateTime Function()? clock,
  void Function(String productId)? onBuy,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _OfferDialog(
        offer: offer,
        price: price,
        endsAt: endsAt,
        shop: shop,
        text: text,
        picture: picture,
        gifts: gifts,
        clock: clock ?? DateTime.now,
        onBuy: onBuy,
      ),
    ) ??
    false;

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({
    required this.offer,
    required this.price,
    required this.endsAt,
    required this.shop,
    required this.text,
    required this.picture,
    required this.gifts,
    required this.clock,
    this.onBuy,
  });

  final Offer offer;
  final String price;
  final DateTime endsAt;
  final PurchaseCoordinator shop;
  final Map<String, String> text;
  final String picture;
  final List<OfferGift> gifts;
  final DateTime Function() clock;
  final void Function(String productId)? onBuy;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  Timer? _tick;
  late Duration _left = widget.endsAt.difference(widget.clock());
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    widget.shop.message.value = null;
    widget.shop.busy.addListener(_afterPurchase);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = widget.endsAt.difference(widget.clock());
      if (!mounted) return;
      // Out of time while only being looked at: the offer is over.
      if (left <= Duration.zero && !_asked) return Navigator.of(context).pop();
      setState(() => _left = left);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.shop.busy.removeListener(_afterPurchase);
    super.dispose();
  }

  /// Once the shop has finished with a purchase asked for here, the pop-up
  /// stays to say what happened; its one button then closes it.
  void _afterPurchase() {
    if (mounted) setState(() {});
  }

  void _buy() {
    setState(() => _asked = true);
    widget.onBuy?.call(widget.offer.productId);
    widget.shop.buy(widget.offer.productId, offerId: widget.offer.id);
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final text = widget.text;
    return Semantics(
      namesRoute: true,
      explicitChildNodes: true,
      label: offer.title,
      child: Dialog(
        key: const Key('offer_popup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 14, right: 6),
                  decoration: offerPanelDecoration,
                  // Gold ornaments along the edges, over the picture too.
                  foregroundDecoration: const OfferOrnaments(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpecialHeader(
                        picture: widget.picture,
                        title: offer.title,
                        subtitle: offer.subtitle.isEmpty
                            ? text['offer_subtitle'] ?? ''
                            : offer.subtitle,
                      ),
                      if (offer.badge.isNotEmpty)
                        OfferBadge(words: offer.badge),
                      OfferCountdown(
                        left: _left,
                        words: text['offer_ends_in'] ?? '',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: OfferGiftList(gifts: widget.gifts),
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: widget.shop.message,
                        builder: (context, message, _) => message == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  message,
                                  key: const Key('offer_message'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFF3E5C8),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.shop.busy,
                        builder: (context, busy, _) => OfferBuyButton(
                          // The price is the store's own, never written in
                          // the app.
                          label: widget.price,
                          onPressed: busy || _left <= Duration.zero
                              ? null
                              : _buy,
                        ),
                      ),
                      TextButton(
                        key: const Key('offer_no_thanks'),
                        onPressed: () => Navigator.of(context).pop(_asked),
                        child: Text(
                          (_asked
                                  ? text['offer_close']
                                  : text['offer_no_thanks']) ??
                              '',
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
                // A short shower of confetti as it opens.
                const Positioned.fill(child: OfferConfetti()),
                Positioned(
                  top: 0,
                  right: 0,
                  child: SpecialClose(
                    onTap: () => Navigator.of(context).pop(_asked),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
