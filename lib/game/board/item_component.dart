// Renders a single game item: its art as a rounded card when the art exists,
// otherwise a coloured placeholder tile with the tier number. When the player
// has asked for tier numbers, a small numbered badge is drawn on the art too.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';

class ItemComponent extends PositionComponent with HasGameReference<BoardGame> {
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

  /// Resizes the tile when the board is given a different amount of room.
  void fit(Vector2 newSize) {
    size = newSize;
    // The badge was laid out for the old size.
    _badgeText = null;
  }

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
      if (game.showTierNumbers) _renderBadge(canvas);
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

  static final _badgePaint = Paint()..color = const Color(0xE61A1205);
  static final _badgeRim = Paint()
    ..color = const Color(0xFFF3E5C8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  /// The tier number in a dark disc at the bottom-right corner: readable
  /// on any picture, and without telling colours apart.
  void _renderBadge(Canvas canvas) {
    final radius = size.x * 0.19;
    final centre = Offset(size.x - radius - 1, size.y - radius - 1);
    canvas.drawCircle(centre, radius, _badgePaint);
    canvas.drawCircle(centre, radius, _badgeRim);
    final tp = _badgeText ??= _layoutBadge(radius);
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  // Laid out once: the tile's size and tier never change.
  TextPainter? _badgeText;

  TextPainter _layoutBadge(double radius) => TextPainter(
    text: TextSpan(
      text: '${item.tier}',
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 1.3,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}
