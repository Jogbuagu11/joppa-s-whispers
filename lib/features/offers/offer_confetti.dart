// A short shower of confetti when an offer's pop-up opens, drawn in code.
import 'dart:math';

import 'package:flutter/material.dart';

// Warm colours only: the game's own gold, clay, olive, cream and sea blue.
const _confetti = [
  Color(0xFFE9B44C),
  Color(0xFFD4802A),
  Color(0xFF9C3D2A),
  Color(0xFFA9C47F),
  Color(0xFFF3E5C8),
  Color(0xFF6FA8B8),
];

/// A short shower of confetti over its child's place, once, when it first
/// appears. Players who have asked their phone for less motion get none.
class OfferConfetti extends StatefulWidget {
  const OfferConfetti({super.key});

  @override
  State<OfferConfetti> createState() => _OfferConfettiState();
}

class _OfferConfettiState extends State<OfferConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fall = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) _fall.forward();
  }

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _fall,
      builder: (context, _) => _fall.isAnimating
          ? CustomPaint(
              key: const Key('offer_confetti'),
              painter: _ConfettiPainter(_fall.value),
              size: Size.infinite,
            )
          : const SizedBox.expand(),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.t);

  /// 0 at the start of the shower, 1 at its end.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // The same pieces every frame: the seed fixes where each one starts,
    // how fast it falls and how it turns.
    final random = Random(40);
    for (int i = 0; i < 110; i++) {
      final x = random.nextDouble();
      final delay = random.nextDouble() * 0.35;
      final speed = 0.7 + random.nextDouble() * 0.6;
      final sway = 10 + random.nextDouble() * 18;
      final spin = (random.nextDouble() - 0.5) * 14;
      final w = 7 + random.nextDouble() * 8;
      final round = random.nextInt(4) == 0;
      final color = _confetti[random.nextInt(_confetti.length)];
      final life = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (life <= 0) continue;
      final y = -20 + life * speed * (size.height + 60);
      final dx = x * size.width + sin(life * 9 + i) * sway;
      // Fades out over the last third of its fall.
      final alpha = life < 0.66 ? 1.0 : (1 - (life - 0.66) / 0.34);
      final paint = Paint()..color = color.withValues(alpha: alpha);
      canvas
        ..save()
        ..translate(dx, y)
        ..rotate(life * spin);
      if (round) {
        canvas.drawCircle(Offset.zero, w / 2.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.55),
            const Radius.circular(1.2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
