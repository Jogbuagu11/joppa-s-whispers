// "You received…": tells the player what they have just been given, with
// some ceremony — a medallion showing the prize in a burst of light, gold
// ornaments on the panel's edges and a short shower of confetti.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/features/offers/offer_confetti.dart';
import 'package:whispers_of_joppa/features/offers/offer_festive.dart';
import 'package:whispers_of_joppa/features/offers/offer_parts.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_font.dart';

/// Shows [prize]. [picture] is its picture, if it is an item with one;
/// [onWheel] gives it the wheel's own lettering.
Future<void> showPrize(
  BuildContext context, {
  required Map<String, String> text,
  required Prize prize,
  String? picture,
  bool onWheel = false,
}) => showDialog<void>(
  context: context,
  builder: (context) => WheelFont(
    // The wheel's own lettering only for a prize from the wheel.
    enabled: onWheel,
    child: _PrizeDialog(text: text, prize: prize, picture: picture),
  ),
);

/// The icon and colour that stand for a prize.
({IconData icon, Color color}) _lookOf(Prize prize) {
  if (prize.pearls > 0) {
    return (icon: Icons.circle, color: GamePalette.offerPearls);
  }
  if (prize.manna > 0) return (icon: Icons.bolt, color: GamePalette.manna);
  if (prize.talents > 0) return (icon: Icons.paid, color: GamePalette.talents);
  return (icon: Icons.card_giftcard, color: GamePalette.offerItem);
}

class _PrizeDialog extends StatefulWidget {
  const _PrizeDialog({required this.text, required this.prize, this.picture});

  final Map<String, String> text;
  final Prize prize;
  final String? picture;

  @override
  State<_PrizeDialog> createState() => _PrizeDialogState();
}

class _PrizeDialogState extends State<_PrizeDialog>
    with SingleTickerProviderStateMixin {
  // The medallion springs into place once, as the pop-up opens.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();
  late final Animation<double> _grow = CurvedAnimation(
    parent: _pop,
    curve: Curves.elasticOut,
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prize = widget.prize;
    final look = _lookOf(prize);
    final picture = widget.picture;
    final title = widget.text['won_title'] ?? '';
    return Semantics(
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Dialog(
        key: const Key('wheel_prize'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SingleChildScrollView(
            child: Stack(
              children: [
                Container(
                  decoration: offerPanelDecoration,
                  foregroundDecoration: const OfferOrnaments(rays: false),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: GamePalette.talents,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          shadows: [
                            Shadow(blurRadius: 6, color: Color(0xAA000000)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ScaleTransition(
                        scale: _grow,
                        child: _Medallion(
                          icon: look.icon,
                          color: look.color,
                          picture: picture,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        prize.name,
                        key: const Key('wheel_prize_name'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.lerp(
                            const Color(0xFFF3E5C8),
                            look.color,
                            0.55,
                          ),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      OfferBuyButton(
                        buttonKey: const Key('wheel_prize_ok'),
                        label: widget.text['won_button'] ?? '',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Positioned.fill(child: OfferConfetti()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The prize in a gold ring, in a burst of light.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, required this.color, this.picture});

  final IconData icon;
  final Color color;
  final String? picture;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
    height: 150,
    child: CustomPaint(
      painter: _BurstPainter(color),
      child: Center(
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF5A421C), GamePalette.panel],
            ),
            border: Border.all(color: GamePalette.talents, width: 4),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: switch (picture) {
            final String asset => Image.asset(
              asset,
              key: const Key('wheel_prize_picture'),
              width: 104,
              height: 104,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Icon(icon, color: color, size: 58),
            ),
            null => Icon(icon, color: color, size: 58),
          },
        ),
      ),
    ),
  );
}

/// Rays of light and a few sparkles behind the medallion.
class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.width * 0.62;
    final ray = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: centre, radius: reach));
    const rays = 16;
    for (int i = 0; i < rays; i++) {
      final a = i * 2 * pi / rays;
      final half = i.isEven ? 0.10 : 0.055;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy)
          ..lineTo(
            centre.dx + cos(a - half) * reach,
            centre.dy + sin(a - half) * reach,
          )
          ..lineTo(
            centre.dx + cos(a + half) * reach,
            centre.dy + sin(a + half) * reach,
          )
          ..close(),
        ray,
      );
    }
    final pale = Paint()..color = const Color(0xFFFFF3CF);
    for (final (fx, fy, r) in const [
      (0.10, 0.22, 7.0),
      (0.90, 0.16, 6.0),
      (0.94, 0.78, 5.0),
      (0.07, 0.80, 5.0),
    ]) {
      final at = Offset(size.width * fx, size.height * fy);
      final star = Path();
      for (int i = 0; i < 8; i++) {
        final radius = i.isEven ? r : r * 0.28;
        final a = i * pi / 4 - pi / 2;
        final point = at.translate(cos(a) * radius, sin(a) * radius);
        i == 0
            ? star.moveTo(point.dx, point.dy)
            : star.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(star..close(), pale);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}
