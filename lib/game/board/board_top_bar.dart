// The row across the top of the board: level, Manna, the three currencies
// and two small buttons, all the same height.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

/// How tall everything in the top row is.
const double hudHeight = 36;

// Below this width the top row is split in two.
const double _oneRowWidth = 372;

class BoardTopBar extends StatelessWidget {
  const BoardTopBar({
    super.key,
    required this.wallet,
    required this.level,
    required this.manna,
    this.onAccount,
    this.onSettings,
    this.settingsTooltip,
  });

  final Widget wallet;
  final Widget level;
  final Widget manna;

  /// Opens the account screen; null hides the button.
  final VoidCallback? onAccount;

  /// Opens Settings; null hides the button.
  final VoidCallback? onSettings;
  final String? settingsTooltip;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final buttons = [
        if (onAccount != null) ...[
          const SizedBox(width: 4),
          _RoundButton(
            buttonKey: const Key('account_button'),
            icon: Icons.person,
            tooltip: 'Account',
            onTap: onAccount,
          ),
        ],
        if (onSettings != null) ...[
          const SizedBox(width: 4),
          _RoundButton(
            buttonKey: const Key('notifications_button'),
            icon: Icons.settings,
            tooltip: settingsTooltip,
            onTap: onSettings,
          ),
        ],
      ];
      // One row on most phones. On a narrow one the currencies drop to a
      // row of their own, so every number stays readable.
      if (box.maxWidth < _oneRowWidth) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: hudHeight,
              child: Row(
                children: [
                  level,
                  const SizedBox(width: 4),
                  Expanded(child: manna),
                  ...buttons,
                ],
              ),
            ),
            const SizedBox(height: 4),
            wallet,
          ],
        );
      }
      return SizedBox(
        height: hudHeight,
        child: Row(
          children: [
            level,
            const SizedBox(width: 4),
            // Manna and the three currencies share the width that is
            // left, so the row fits any phone.
            Expanded(flex: 5, child: manna),
            const SizedBox(width: 4),
            Expanded(flex: 9, child: wallet),
            ...buttons,
          ],
        ),
      );
    },
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Material(
      color: GamePalette.panel,
      shape: const CircleBorder(side: BorderSide(color: GamePalette.panelEdge)),
      child: InkWell(
        key: buttonKey,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: hudHeight,
          height: hudHeight,
          child: Icon(icon, color: GamePalette.level, size: 20),
        ),
      ),
    ),
  );
}
