// Generator tile — fixed board cell that spawns items when tapped.
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';

class GeneratorComponent extends PositionComponent with TapCallbacks {
  final GeneratorModel generator;
  final void Function(String generatorId) onTapped;

  static final _bgPaint = Paint()..color = const Color(0xFF2D5A27);
  static final _borderPaint = Paint()
    ..color = const Color(0xFF7CB342)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _costPaint = TextPaint(
    style: TextStyle(color: Color(0xFFFFD700), fontSize: 9),
  );

  // Name wrapped to the tile width so long names stay inside the tile.
  late final TextPainter _namePainter;

  GeneratorComponent({
    required this.generator,
    required this.onTapped,
    required Vector2 position,
    required double cellSize,
  }) : super(position: position, size: Vector2.all(cellSize));

  @override
  Future<void> onLoad() async {
    _namePainter = TextPainter(
      text: TextSpan(
        text: generator.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: size.x - 8);
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.handled = true;
    onTapped(generator.generatorId);
  }

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, _bgPaint);
    canvas.drawRRect(rect, _borderPaint);

    _namePainter.paint(
      canvas,
      Offset(
        (size.x - _namePainter.width) / 2,
        (size.y - _namePainter.height) / 2 - 4,
      ),
    );
    _costPaint.render(
      canvas,
      '${generator.energyCost}M',
      Vector2(size.x - 4, size.y - 4),
      anchor: Anchor.bottomRight,
    );
  }
}
