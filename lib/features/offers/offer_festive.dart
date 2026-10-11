// The gold ornaments along the edges of an offer's pop-up, drawn in code.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

/// Gold ornaments just inside the panel's border: a curling corner piece
/// with leaves at each corner, a scalloped trim along the top and bottom,
/// studs down the sides, gems at the middle of each edge, rays of light
/// behind the title and a scatter of sparkles.
class OfferEdgePainter extends CustomPainter {
  const OfferEdgePainter({this.rays = true});

  /// The rays behind a title ribbon at the top (for a panel that has one).
  final bool rays;

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = GamePalette.talents
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = GamePalette.talents
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()..color = GamePalette.talents;
    final deep = Paint()..color = GamePalette.gold;
    final pale = Paint()..color = const Color(0xFFFFF3CF);

    // Rays of light fanning out behind the title ribbon.
    const from = Offset(0, 96);
    final centre = from.translate(size.width / 2, 0);
    final light = Paint()..color = const Color(0x22FFE9A8);
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width, rays ? 132 : 0));
    for (int i = 0; i < 14; i++) {
      final a = -pi + i * pi / 13;
      const half = 0.045;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy)
          ..lineTo(
            centre.dx + cos(a - half) * 400,
            centre.dy + sin(a - half) * 400,
          )
          ..lineTo(
            centre.dx + cos(a + half) * 400,
            centre.dy + sin(a + half) * 400,
          )
          ..close(),
        light,
      );
    }
    canvas.restore();

    // A leaf: a pointed oval lying along [angle].
    void leaf(Offset at, double angle, double length) {
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(angle);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(length / 2, -length / 3.2, length, 0)
          ..quadraticBezierTo(length / 2, length / 3.2, 0, 0),
        fill,
      );
      canvas.restore();
    }

    // One corner, drawn at the top left and turned for the other three.
    void corner() {
      const inset = 9.0;
      canvas
        ..drawPath(
          Path()
            ..moveTo(inset, 78)
            ..quadraticBezierTo(inset, inset, 78, inset),
          gold,
        )
        ..drawPath(
          Path()
            ..moveTo(inset + 8, 58)
            ..quadraticBezierTo(inset + 8, inset + 8, 58, inset + 8),
          thin,
        )
        // A curl at each end of the outer line.
        ..drawArc(
          Rect.fromCircle(center: const Offset(78, inset + 6), radius: 6),
          -pi / 2,
          pi * 1.4,
          false,
          gold,
        )
        ..drawArc(
          Rect.fromCircle(center: const Offset(inset + 6, 78), radius: 6),
          pi,
          -pi * 1.4,
          false,
          gold,
        );
      // A spray of leaves in the crook, around a pale bead.
      leaf(const Offset(24, 24), pi / 4, 20);
      leaf(const Offset(26, 22), pi / 10, 17);
      leaf(const Offset(22, 26), pi / 2 - pi / 10, 17);
      canvas
        ..drawCircle(const Offset(23, 23), 4.5, deep)
        ..drawCircle(const Offset(23, 23), 2.2, pale);
    }

    for (final (sx, sy) in const [
      (1.0, 1.0),
      (-1.0, 1.0),
      (1.0, -1.0),
      (-1.0, -1.0),
    ]) {
      canvas
        ..save()
        ..translate(sx < 0 ? size.width : 0, sy < 0 ? size.height : 0)
        ..scale(sx, sy);
      corner();
      canvas.restore();
    }

    // A scalloped trim along the top and bottom, between the corners.
    const scallop = 9.0;
    final count = ((size.width - 200) / (scallop * 2)).floor();
    final start = (size.width - count * scallop * 2) / 2 + scallop;
    for (int i = 0; i < count; i++) {
      final x = start + i * scallop * 2;
      canvas
        ..drawArc(
          Rect.fromCircle(center: Offset(x, 7), radius: scallop),
          0,
          pi,
          false,
          thin,
        )
        ..drawArc(
          Rect.fromCircle(center: Offset(x, size.height - 7), radius: scallop),
          pi,
          pi,
          false,
          thin,
        );
    }

    // Studs down the two sides, between the corners.
    for (double y = 104; y < size.height - 100; y += 22) {
      canvas
        ..drawCircle(Offset(9, y), 2.2, fill)
        ..drawCircle(Offset(size.width - 9, y), 2.2, fill);
    }

    // A gem at the middle of the bottom edge and of each side.
    void gem(Offset at, double r) {
      final shape = Path()
        ..moveTo(at.dx, at.dy - r)
        ..lineTo(at.dx + r, at.dy)
        ..lineTo(at.dx, at.dy + r)
        ..lineTo(at.dx - r, at.dy)
        ..close();
      canvas
        ..drawPath(shape, deep)
        ..drawPath(shape, thin)
        ..drawCircle(at.translate(-r * 0.25, -r * 0.25), r * 0.22, pale);
    }

    gem(Offset(size.width / 2, size.height - 10), 9);
    gem(Offset(10, size.height / 2), 6);
    gem(Offset(size.width - 10, size.height / 2), 6);

    // Sparkles: four-pointed stars scattered near the edges.
    void sparkle(Offset at, double r) {
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

    for (final (fx, fy, r) in const [
      (0.13, 0.075, 9.0),
      (0.80, 0.045, 7.0),
      (0.91, 0.20, 5.0),
      (0.07, 0.24, 5.0),
      (0.93, 0.60, 6.0),
      (0.065, 0.70, 6.0),
      (0.86, 0.90, 7.0),
      (0.16, 0.925, 5.0),
    ]) {
      sparkle(Offset(size.width * fx, size.height * fy), r);
    }
  }

  @override
  bool shouldRepaint(OfferEdgePainter old) => old.rays != rays;
}

/// The edge ornaments as a decoration, so they are drawn over a panel.
class OfferOrnaments extends Decoration {
  const OfferOrnaments({this.rays = true});

  final bool rays;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _OrnamentBox(OfferEdgePainter(rays: rays));
}

class _OrnamentBox extends BoxPainter {
  _OrnamentBox(this.painter);

  final OfferEdgePainter painter;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    painter.paint(canvas, size);
    canvas.restore();
  }
}
