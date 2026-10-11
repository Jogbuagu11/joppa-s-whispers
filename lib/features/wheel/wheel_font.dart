// The lettering of the Blessing Wheel: Lilita One, a round, friendly display
// face (SIL Open Font License; the file and its licence are in
// assets/fonts/). Used on the wheel's own screen and the pop-ups of a spin.
import 'package:flutter/material.dart';

const wheelFontFamily = 'LilitaOne';
const wheelFontFallback = <String>[];

/// Gives everything under it the wheel's lettering.
class WheelFont extends StatelessWidget {
  const WheelFont({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// False leaves the lettering as it is (a pop-up shared with other parts
  /// of the game, opened from somewhere other than the wheel).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final theme = Theme.of(context);
    TextTheme serif(TextTheme base) => base.apply(
      fontFamily: wheelFontFamily,
      fontFamilyFallback: wheelFontFallback,
    );
    return Theme(
      data: theme.copyWith(
        textTheme: serif(theme.textTheme),
        primaryTextTheme: serif(theme.primaryTextTheme),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: wheelFontFamily,
          fontFamilyFallback: wheelFontFallback,
        ),
        child: child,
      ),
    );
  }
}
