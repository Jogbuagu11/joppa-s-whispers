// The Blessing Wheel's frame, like a fairground wheel of fortune: a
// polished gold rim, a dark band set with lamps, a peg where each slice
// begins, a domed hub, and the flapper the prize comes to rest under.
part of 'wheel_painter.dart';

/// Draws the rim of a wheel of [radius] round [centre]. [pegs] are where
/// the slices begin, as fractions of a turn clockwise from the top.
void paintWheelRim(
  Canvas canvas,
  Offset centre,
  double radius,
  List<double> pegs,
) {
  final rim = wheelRim(radius);
  final inner = radius - rim;
  final outer = Rect.fromCircle(center: centre, radius: radius);
  Paint ring(double width, List<Color> colors, {double turn = 0}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..shader = SweepGradient(
      colors: colors,
      transform: GradientRotation(turn),
    ).createShader(outer);
  // A soft shadow under the whole wheel.
  canvas.drawCircle(
    centre + const Offset(0, 4),
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rim
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );
  // Outer gold, the dark band, inner gold.
  final gold = rim * 0.24;
  canvas
    ..drawCircle(centre, radius - gold / 2, ring(gold, _rimGold))
    ..drawCircle(
      centre,
      radius - rim / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim - 2 * gold
        ..shader = RadialGradient(
          colors: _band,
          stops: [1 - (rim - gold) / radius, 1 - gold / radius],
        ).createShader(outer),
    )
    ..drawCircle(centre, inner + gold / 2, ring(gold, _rimGold, turn: pi / 8))
    // Fine dark lines that set the gold off from the band and the slices.
    ..drawCircle(
      centre,
      radius - gold,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xAA1A0C04),
    )
    ..drawCircle(
      centre,
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xAA1A0C04),
    );
  // The lamps: every other one bright, so a turning wheel twinkles.
  const lamps = 24;
  final lampRadius = (rim - 2 * gold) * 0.3;
  for (var i = 0; i < lamps; i++) {
    final angle = 2 * pi * (i + 0.5) / lamps;
    final at = centre + Offset(cos(angle), sin(angle)) * (radius - rim / 2);
    final lit = i.isEven;
    if (lit) {
      canvas.drawCircle(
        at,
        lampRadius * 2.1,
        Paint()
          ..color = const Color(0x88FFD98A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas
      ..drawCircle(at, lampRadius + 1.2, Paint()..color = _rimGold[3])
      ..drawCircle(
        at,
        lampRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [const Color(0xFFFFFFFF), if (lit) _lampLit else _lampDim],
          ).createShader(Rect.fromCircle(center: at, radius: lampRadius)),
      );
  }
  // A gold peg where each slice begins.
  for (final turn in pegs) {
    final angle = 2 * pi * turn - pi / 2;
    final at = centre + Offset(cos(angle), sin(angle)) * (inner + gold / 2);
    canvas
      ..drawCircle(at, gold * 0.62, Paint()..color = const Color(0xFF5A3208))
      ..drawCircle(
        at,
        gold * 0.48,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: [Color(0xFFFFF1C2), Color(0xFFB8741E)],
          ).createShader(Rect.fromCircle(center: at, radius: gold * 0.48)),
      );
  }
}

/// Draws the domed gold hub, [radius] across its half.
void paintWheelHub(Canvas canvas, Offset centre, double radius) {
  final rect = Rect.fromCircle(center: centre, radius: radius);
  canvas
    ..drawCircle(
      centre + const Offset(0, 2),
      radius,
      Paint()
        ..color = const Color(0x77000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    )
    ..drawCircle(
      centre,
      radius,
      Paint()
        ..shader = const SweepGradient(colors: _rimGold).createShader(rect),
    )
    ..drawCircle(
      centre,
      radius * 0.74,
      Paint()..color = GamePalette.backgroundBottom,
    )
    ..drawCircle(
      centre,
      radius * 0.6,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFFFF1C2), Color(0xFFEFC25A), Color(0xFF8A5412)],
        ).createShader(Rect.fromCircle(center: centre, radius: radius * 0.6)),
    );
}

/// The flapper at the top of the wheel that the prize comes to rest under.
class WheelPointer extends CustomPainter {
  const WheelPointer();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shape = Path()
      ..moveTo(w * 0.08, h * 0.2)
      ..quadraticBezierTo(w * 0.5, -h * 0.12, w * 0.92, h * 0.2)
      ..lineTo(w / 2, h)
      ..close();
    canvas
      ..drawShadow(shape, const Color(0xFF000000), 4, false)
      ..drawPath(
        shape,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFF1C2), Color(0xFFEFC25A), Color(0xFF9A5E14)],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        shape,
        Paint()
          ..color = const Color(0xFF4A2A08)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.5,
      )
      // The pin it hangs from.
      ..drawCircle(
        Offset(w / 2, h * 0.28),
        w * 0.14,
        Paint()..color = const Color(0xFF4A2A08),
      )
      ..drawCircle(
        Offset(w / 2, h * 0.28),
        w * 0.09,
        Paint()..color = const Color(0xFFFFF1C2),
      );
  }

  @override
  bool shouldRepaint(WheelPointer old) => false;
}
