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
    // The rim: dark wood between two gold lines, set with small studs.
    canvas.drawCircle(centre, radius, Paint()..color = GamePalette.gold);
    canvas.drawCircle(
      centre,
      radius - 3,
      Paint()..color = GamePalette.backgroundBottom,
    );
    canvas.drawCircle(
      centre,
      radius - 13,
      Paint()..color = GamePalette.talents,
    );
    const studs = 24;
    for (var i = 0; i < studs; i++) {
      final angle = 2 * pi * i / studs;
      canvas.drawCircle(
        centre + Offset(cos(angle), sin(angle)) * (radius - 8),
        2.2,
        Paint()..color = GamePalette.talents,
      );
    }
    final inner = radius - 15;
    final rect = Rect.fromCircle(center: centre, radius: inner);
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
      // Its number, on a small dark disc, which the list beneath explains.
      final middle = start + sweep / 2;
      if (sweep > 0.16) {
        final at = centre + Offset(cos(middle), sin(middle)) * inner * 0.68;
        canvas.drawCircle(
          at,
          11,
          Paint()..color = GamePalette.backgroundBottom,
        );
        final number = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
              color: GamePalette.talents,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        number.paint(canvas, at - number.size.center(Offset.zero));
      }
      start += sweep;
    }
    // The hub.
    canvas.drawCircle(centre, inner * 0.2, Paint()..color = GamePalette.gold);
    canvas.drawCircle(
      centre,
      inner * 0.15,
      Paint()..color = GamePalette.backgroundBottom,
    );
    canvas.drawCircle(
      centre,
      inner * 0.06,
      Paint()..color = GamePalette.talents,
    );
  }

  @override
  bool shouldRepaint(WheelPainter old) => old.odds != odds;
}

/// The marker at the top of the wheel that the prize comes to rest under.
class WheelPointer extends CustomPainter {
  const WheelPointer();

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(shape, const Color(0xFF000000), 3, false);
    canvas.drawPath(shape, Paint()..color = GamePalette.talents);
    canvas.drawPath(
      shape,
      Paint()
        ..color = GamePalette.backgroundBottom
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(WheelPointer old) => false;
}
