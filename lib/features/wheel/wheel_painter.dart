// Draws the Blessing Wheel: one slice for each prize, as wide as its chance.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_font.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/chance.dart';

part 'wheel_rim.dart';

/// The colours of the slices, in turn (warm and flat, like the rest).
const wheelColors = [
  Color(0xFFD4802A),
  Color(0xFF7A5A22),
  Color(0xFFE9B44C),
  Color(0xFF8C4A2F),
  Color(0xFFA9C47F),
  Color(0xFFC9B58A),
  Color(0xFF5E6B3A),
  Color(0xFFF1DDD0),
  Color(0xFF9A6B3F),
];

/// The colour of slice [index].
Color wheelColor(int index) => wheelColors[index % wheelColors.length];

/// How far round the wheel (0 to 1, clockwise from the top) the middle of
/// slice [index] lies.
double sliceMiddle(List<PrizeOdds> odds, int index) {
  var before = 0.0;
  for (var i = 0; i < index; i++) {
    before += odds[i].chance;
  }
  return before + odds[index].chance / 2;
}

// The rim's golds, round the wheel: light where the lamp catches it.
const _rimGold = [
  Color(0xFFF6D98A),
  Color(0xFFB8741E),
  Color(0xFFEFC25A),
  Color(0xFF8A5412),
  Color(0xFFF6D98A),
  Color(0xFFB8741E),
  Color(0xFFEFC25A),
  Color(0xFF8A5412),
  Color(0xFFF6D98A),
];
const _lampLit = Color(0xFFFFF1C2);
const _lampDim = Color(0xFFE0A03C);
const _band = [Color(0xFF5A2A14), Color(0xFF2E1408)];

/// How wide the rim is, for a wheel of [radius].
double wheelRim(double radius) => radius * 0.15;

class WheelPainter extends CustomPainter {
  WheelPainter(this.odds);

  final List<PrizeOdds> odds;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rim = wheelRim(radius);
    final inner = radius - rim;
    _paintSlices(canvas, centre, inner);
    paintWheelRim(canvas, centre, radius, [
      for (var i = 0; i < odds.length; i++)
        sliceMiddle(odds, i) - odds[i].chance / 2,
    ]);
    paintWheelHub(canvas, centre, inner * 0.2);
  }

  void _paintSlices(Canvas canvas, Offset centre, double inner) {
    final rect = Rect.fromCircle(center: centre, radius: inner);
    var start = -pi / 2;
    for (var i = 0; i < odds.length; i++) {
      final sweep = odds[i].chance * 2 * pi;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = wheelColor(i));
      start += sweep;
    }
    // Depth: a little light at the middle, a little shade at the edge.
    canvas.drawCircle(
      centre,
      inner,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x30FFFFFF), Color(0x00000000), Color(0x55000000)],
          stops: [0, 0.62, 1],
        ).createShader(rect),
    );
    start = -pi / 2;
    for (var i = 0; i < odds.length; i++) {
      final sweep = odds[i].chance * 2 * pi;
      // A gold line between slices.
      canvas.drawLine(
        centre,
        centre + Offset(cos(start), sin(start)) * inner,
        Paint()
          ..color = _rimGold[0]
          ..strokeWidth = 1.6,
      );
      // Its number, on a small dark disc, which the list beneath explains.
      final middle = start + sweep / 2;
      if (sweep > 0.16) {
        final at = centre + Offset(cos(middle), sin(middle)) * inner * 0.66;
        canvas
          ..drawCircle(at, 12.5, Paint()..color = _rimGold[0])
          ..drawCircle(at, 11, Paint()..color = GamePalette.backgroundBottom);
        final number = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
              color: GamePalette.talents,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: wheelFontFamily,
              fontFamilyFallback: wheelFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        number.paint(canvas, at - number.size.center(Offset.zero));
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(WheelPainter old) => old.odds != odds;
}
