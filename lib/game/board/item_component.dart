// Renders a single game item as a colored tile with tier number.
// Real art is swapped in via Image asset when available.
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';

// Palette: one distinct color per chain.
const _chainColors = <String, Color>{
  'bakery': Color(0xFFD4802A),
  'fruit': Color(0xFF5DAD52),
  'church': Color(0xFF6B8FCF),
  'armor': Color(0xFFB44A4A),
  'loom': Color(0xFF9B68B0),
  'oil': Color(0xFFCFB83A),
  'word': Color(0xFF4AACAB),
};

class ItemComponent extends PositionComponent {
  final ItemModel item;

  ItemComponent({
    required this.item,
    required Vector2 size,
    required Vector2 position,
  }) : super(size: size, position: position);

  @override
  void render(Canvas canvas) {
    final color = _chainColors[item.chainId] ?? const Color(0xFF888888);
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
