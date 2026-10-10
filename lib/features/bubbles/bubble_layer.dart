// The bubbles drawn over the board: each floats at a corner of the cell its
// item was made in, with a ring showing the time it has left.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/features/bubbles/bubble_controller.dart';

class BubbleLayer extends StatelessWidget {
  const BubbleLayer({
    super.key,
    required this.controller,
    required this.cellRect,
    required this.placeholderColors,
    required this.onTap,
    this.label = '',
  });

  final BubbleController controller;

  /// Where a cell is drawn, inside the board.
  final Rect Function(int col, int row) cellRect;
  final Map<String, int> placeholderColors;
  final void Function(Bubble bubble) onTap;

  /// What a bubble is, for screen readers (with `{name}` for its item).
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Stack(
        children: [for (final bubble in controller.bubbles) _bubble(bubble)],
      ),
    );
  }

  Widget _bubble(Bubble bubble) {
    final cell = cellRect(bubble.col, bubble.row);
    // Smaller than the cell and up in its corner, so the item beneath can
    // still be seen and dragged.
    final size = cell.width * 0.62;
    return Positioned(
      key: ValueKey('bubble_at_${bubble.id}'),
      left: cell.right - size * 0.8,
      top: cell.top - size * 0.2,
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label: label.replaceAll('{name}', bubble.item.name),
        child: GestureDetector(
          key: Key('bubble_${bubble.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(bubble),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xCCF3E5C8),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(size * 0.2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.12),
                  child: _picture(bubble.item),
                ),
              ),
              CircularProgressIndicator(
                value: controller.shareLeft(bubble.id),
                strokeWidth: 3,
                color: GamePalette.gold,
                backgroundColor: GamePalette.panelEdge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picture(ItemModel item) => item.asset.isEmpty
      ? ColoredBox(
          color: Color(placeholderColors[item.chainId] ?? 0xFF888888),
          child: Center(
            child: Text(
              '${item.tier}',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        )
      : Image.asset(item.asset, fit: BoxFit.cover);
}
