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

  const OfferGift({
    required this.words,
    required this.icon,
    required this.color,
    this.asset,
  });
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
            const Icon(Icons.hourglass_bottom, size: 16, color: _cream),
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
                  SizedBox(
                    width: 40,
                    height: 40,
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
                    child: Text(
                      gift.words,
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
