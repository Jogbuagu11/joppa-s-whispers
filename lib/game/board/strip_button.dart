// A round button for the left end of the swipeable row above the board.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

class StripButton extends StatelessWidget {
  const StripButton({
    super.key,
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.lit = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// A gold button rather than a dark one (something is on now).
  final bool lit;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Material(
      color: lit ? GamePalette.gold : GamePalette.panel.withValues(alpha: 0.92),
      shape: const CircleBorder(side: BorderSide(color: GamePalette.panelEdge)),
      child: InkWell(
        key: buttonKey,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: 20,
            color: lit ? GamePalette.backgroundBottom : GamePalette.level,
          ),
        ),
      ),
    ),
  );
}

/// The round buttons at the far left of the row, three to a column.
class StripMenu extends StatelessWidget {
  const StripMenu({
    super.key,
    required this.buttons,
    required this.columnWidth,
  });

  final List<Widget> buttons;
  final double columnWidth;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < buttons.length; i += 3)
        SizedBox(
          width: columnWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: buttons.skip(i).take(3).toList(),
          ),
        ),
    ],
  );
}
