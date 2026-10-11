// The Treasure Jar, drawn in code: a clay jar that shows how full it is.
// (A placeholder until Jennifer approves a painted one.)
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

class TreasureJarPicture extends StatelessWidget {
  const TreasureJarPicture({super.key, required this.fill, this.size = 120});

  /// How full the jar is, from 0 (empty) to 1 (full).
  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _JarPainter(fill.clamp(0, 1).toDouble())),
  );
}

class _JarPainter extends CustomPainter {
  _JarPainter(this.fill);

  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // The jar's outline: a narrow neck over a round belly.
    final body = Path()
      ..moveTo(w * 0.36, h * 0.16)
      ..lineTo(w * 0.64, h * 0.16)
      ..quadraticBezierTo(w * 0.62, h * 0.30, w * 0.80, h * 0.44)
      ..quadraticBezierTo(w * 0.96, h * 0.70, w * 0.70, h * 0.94)
      ..lineTo(w * 0.30, h * 0.94)
      ..quadraticBezierTo(w * 0.04, h * 0.70, w * 0.20, h * 0.44)
      ..quadraticBezierTo(w * 0.38, h * 0.30, w * 0.36, h * 0.16)
      ..close();
    if (fill >= 1) {
      // A full jar glows.
      canvas.drawCircle(
        Offset(w / 2, h * 0.55),
        w * 0.52,
        Paint()
          ..color = GamePalette.manna.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawPath(body, Paint()..color = GamePalette.panelLight);
    // The Pearls inside, up to the level saved.
    final top = h * (0.94 - 0.74 * fill);
    canvas
      ..save()
      ..clipPath(body)
      ..drawRect(
        Rect.fromLTRB(0, top, w, h),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GamePalette.pearls, GamePalette.offerPearls],
          ).createShader(Rect.fromLTRB(0, top, w, h)),
      )
      ..restore();
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeJoin = StrokeJoin.round
        ..color = GamePalette.gold,
    );
    // The rim.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.30, h * 0.08, w * 0.70, h * 0.18),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = GamePalette.gold,
    );
  }

  @override
  bool shouldRepaint(_JarPainter old) => old.fill != fill;
}
