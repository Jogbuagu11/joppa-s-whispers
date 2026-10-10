// Draws the Blessing Wheel: one slice for each prize, as wide as its chance.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/chance.dart';

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

class WheelPainter extends CustomPainter {
  WheelPainter(this.odds);

  final List<PrizeOdds> odds;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius - 4);
    var start = -pi / 2;
    for (var i = 0; i < odds.length; i++) {
      final sweep = odds[i].chance * 2 * pi;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = wheelColor(i));
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = GamePalette.backgroundBottom
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Its number, which the list beneath explains.
      final middle = start + sweep / 2;
      final at = centre + Offset(cos(middle), sin(middle)) * radius * 0.72;
      final number = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: GamePalette.backgroundBottom,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (sweep > 0.12) {
        number.paint(canvas, at - number.size.center(Offset.zero));
      }
      start += sweep;
    }
    canvas.drawCircle(
      centre,
      radius - 4,
      Paint()
        ..color = GamePalette.panelEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      centre,
      radius * 0.12,
      Paint()..color = GamePalette.panel,
    );
  }

  @override
  bool shouldRepaint(WheelPainter old) => old.odds != odds;
}
