// A single cell on the board grid.
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/item_component.dart';

class CellComponent extends PositionComponent {
  final int col;
  final int row;
  final double cellSize;

  ItemComponent? _item;

  static const _borderColor = Color(0xFF5C3D0D);
  static const _fillColor = Color(0xFF2A1F08);

  CellComponent({
    required this.col,
    required this.row,
    required this.cellSize,
    required Vector2 position,
  }) : super(position: position, size: Vector2.all(cellSize));

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(1, 1, cellSize - 2, cellSize - 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = _fillColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = _borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Places (or replaces) an item in this cell.
  void setItem(ItemModel item, Color color) {
    _item?.removeFromParent();
    final comp = ItemComponent(
      item: item,
      color: color,
      size: Vector2.all(cellSize - 8),
      position: Vector2(4, 4),
    );
    add(comp);
    _item = comp;
  }

  /// Removes the item from this cell for dragging, returning the component.
  ItemComponent? liftItem() {
    final comp = _item;
    if (comp == null) return null;
    _item = null;
    remove(comp);
    // Convert position to game-level coordinates.
    comp.position = absolutePosition + Vector2(4, 4);
    return comp;
  }

  @override
  bool containsPoint(Vector2 point) {
    return absolutePosition.x <= point.x &&
        point.x <= absolutePosition.x + cellSize &&
        absolutePosition.y <= point.y &&
        point.y <= absolutePosition.y + cellSize;
  }
}
