// The row across the top of the board: wallet, level, buttons and Manna.
import 'package:flutter/material.dart';

const _gold = Color(0xFFD4802A);

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
    // On a wide phone the row spreads to both edges. On a narrow one (or at
    // a large text size) everything in it shrinks together to fit, so
    // nothing is ever pushed off the side.
    builder: (context, box) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.maxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            wallet,
            level,
            if (onAccount != null)
              IconButton(
                key: const Key('account_button'),
                onPressed: onAccount,
                tooltip: 'Account',
                icon: const Icon(Icons.person_outline, color: _gold),
              ),
            if (onSettings != null)
              IconButton(
                key: const Key('notifications_button'),
                onPressed: onSettings,
                tooltip: settingsTooltip,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.settings_outlined, color: _gold),
              ),
            manna,
          ],
        ),
      ),
    ),
  );
}
