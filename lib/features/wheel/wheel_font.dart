// The lettering of the Blessing Wheel and its pop-ups: a bookish serif, as
// on the title screen, to set the wheel apart from the rest of the game.
// (Georgia on iPhone; Android's own serif. No font file is added.)
import 'package:flutter/material.dart';

const wheelFontFamily = 'Georgia';
const wheelFontFallback = ['serif'];

/// Gives everything under it the wheel's lettering.
class WheelFont extends StatelessWidget {
  const WheelFont({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
