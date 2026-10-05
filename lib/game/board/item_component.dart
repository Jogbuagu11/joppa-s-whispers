// Renders a single game item as a colored tile with tier number.
// Real art is swapped in via Image asset when available.
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';

class ItemComponent extends PositionComponent {
  final ItemModel item;

  /// Placeholder tile colour for this item's chain (from content).
  final Color color;

  ItemComponent({
    required this.item,
    required this.color,
    required Vector2 size,
    required Vector2 position,
  }) : super(size: size, position: position);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    // Background.
    canvas.drawRRect(rRect, Paint()..color = color.withValues(alpha: 0.85));

    // Tier number label.
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
