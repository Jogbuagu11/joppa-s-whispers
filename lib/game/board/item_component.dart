// Renders a single game item: its art as a rounded card when the art exists,
// otherwise a coloured placeholder tile with the tier number.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';

class ItemComponent extends PositionComponent {
  final ItemModel item;

  /// Placeholder tile colour for this item's chain (from content).
  final Color color;

  /// The item's picture, or null to draw the placeholder.
  final ui.Image? art;

  ItemComponent({
    required this.item,
    required this.color,
    required this.art,
    required Vector2 size,
    required Vector2 position,
  }) : super(size: size, position: position);

  static final _artPaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final picture = art;

    if (picture != null) {
      canvas.save();
      canvas.clipRRect(rRect);
      canvas.drawImageRect(
        picture,
        Rect.fromLTWH(
          0,
          0,
          picture.width.toDouble(),
          picture.height.toDouble(),
        ),
        rect,
        _artPaint,
      );
      canvas.restore();
      return;
    }

    canvas.drawRRect(rRect, Paint()..color = color.withValues(alpha: 0.85));
    final tp = TextPainter(
      text: TextSpan(
        text: '${item.tier}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
  }
}
