// The pieces of a timed offer's pop-up: its frame, the countdown, the list
// of what it gives, and the price button.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

const _cream = Color(0xFFF3E5C8);

const offerPanelDecoration = BoxDecoration(
  color: GamePalette.panel,
  borderRadius: BorderRadius.all(Radius.circular(26)),
  border: Border.fromBorderSide(
    BorderSide(color: GamePalette.talents, width: 3),
  ),
  boxShadow: [
    // A warm glow round the whole panel, over a deep shadow.
    BoxShadow(color: Color(0x88E9B44C), blurRadius: 26, spreadRadius: 2),
    BoxShadow(color: Color(0xCC000000), blurRadius: 28, offset: Offset(0, 12)),
  ],
);

/// One thing an offer gives: a picture or an icon, and its words
/// ("40 Pearls", "Manna jar").
class OfferGift {
  final String words;
  final IconData icon;
  final Color color;

  /// The item's picture, if it has one.
  final String? asset;

  /// The part of [words] to pick out in the gift's own colour (its
  /// amount); empty colours the whole line softly instead.
  final String amount;

  const OfferGift({
    required this.words,
    required this.icon,
    required this.color,
    this.asset,
    this.amount = '',
  });

  /// [words] as pieces of text: the amount large and in the gift's colour,
  /// the rest in cream. A gift with no amount (an item) is tinted whole.
  List<TextSpan> get spans {
    final at = amount.isEmpty ? -1 : words.indexOf(amount);
    if (at < 0) {
      return [
        TextSpan(
          text: words,
          style: TextStyle(color: Color.lerp(_cream, color, 0.45)),
        ),
      ];
    }
    return [
      if (at > 0) TextSpan(text: words.substring(0, at)),
      TextSpan(
        text: amount,
        style: TextStyle(
          color: color,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      TextSpan(text: words.substring(at + amount.length)),
    ];
  }
}

/// "2:05:09" for a time left; "0:00" once it is over.
String formatTimeLeft(Duration left) {
  if (left <= Duration.zero) return '0:00';
  final seconds = left.inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// The tag on a sale: a short, true comparison with the shop.
class OfferBadge extends StatelessWidget {
  const OfferBadge({super.key, required this.words});

  final String words;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: GamePalette.talents,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          words,
          key: const Key('offer_badge'),
          style: const TextStyle(
            color: Color(0xFF2A1F0C),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    ),
  );
}

class OfferCountdown extends StatelessWidget {
  const OfferCountdown({super.key, required this.left, required this.words});

  final Duration left;

  /// "Ends in {time}".
  final String words;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF6E2A1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GamePalette.talents),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_bottom,
              size: 16,
              color: GamePalette.manna,
            ),
            const SizedBox(width: 6),
            Text(
              words.replaceAll('{time}', formatTimeLeft(left)),
              key: const Key('offer_countdown'),
              style: const TextStyle(
                color: _cream,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Everything the offer gives, one line each.
class OfferGiftList extends StatelessWidget {
  const OfferGiftList({super.key, required this.gifts});

  final List<OfferGift> gifts;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GamePalette.panelLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GamePalette.panelEdge),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, gift) in gifts.indexed)
            Padding(
              key: Key('offer_gift_$index'),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    // A soft glow behind each gift.
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          gift.color.withValues(alpha: 0.35),
                          gift.color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: switch (gift.asset) {
                      final String asset => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              Icon(gift.icon, color: gift.color, size: 30),
                        ),
                      ),
                      null => Icon(gift.icon, color: gift.color, size: 30),
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: gift.spans),
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class OfferBuyButton extends StatelessWidget {
  const OfferBuyButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('offer_buy'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: GamePalette.action,
          foregroundColor: GamePalette.onAction,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: const StadiumBorder(
            side: BorderSide(color: GamePalette.actionEdge, width: 2),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    ),
  );
}
