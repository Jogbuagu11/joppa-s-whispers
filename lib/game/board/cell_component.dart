// A single cell on the board grid.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/item_component.dart';

class CellComponent extends PositionComponent with TapCallbacks {
  final int col;
  final int row;
  double cellSize;

  ItemComponent? _item;

  /// Called when the cell is tapped while it holds an item.
  final void Function(int col, int row)? onItemTapped;

  static const _borderColor = Color(0xFF6B4A14);
  static const _fillColor = Color(0xB32A1F08);

  CellComponent({
    required this.col,
    required this.row,
    required this.cellSize,
    required Vector2 position,
    this.onItemTapped,
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

  @override
  void onTapUp(TapUpEvent event) {
    if (_item != null) onItemTapped?.call(col, row);
  }

  /// Moves and resizes this cell (and the item in it) when the board is
  /// given a different amount of room.
  void fit(double newSize, Vector2 newPosition) {
    cellSize = newSize;
    size = Vector2.all(newSize);
    position = newPosition;
    _item?.fit(Vector2.all(newSize - 8));
  }

  /// Places (or replaces) an item in this cell.
  void setItem(ItemModel item, Color color, ui.Image? art) {
    _item?.removeFromParent();
    final comp = ItemComponent(
      item: item,
      color: color,
      art: art,
      size: Vector2.all(cellSize - 8),
      position: Vector2(4, 4),
    );
    add(comp);
    _item = comp;
  }

  /// Empties this cell.
  void clearItem() {
    _item?.removeFromParent();
    _item = null;
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
