// The jars that can be bought with Pearls, under the Blessing Wheel. What
// each may hold, and how likely, is one tap away before buying.
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/jars.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_odds.dart';

class JarShop extends StatelessWidget {
  const JarShop({
    super.key,
    required this.jars,
    required this.names,
    required this.text,
    required this.pearls,
    required this.onBuy,
  });

  /// The jars for sale, cheapest first.
  final List<JarKind> jars;

  /// jar kind -> the name of its item.
  final Map<String, String> names;
  final Map<String, String> text;

  /// The Pearls the player has (listened to, so the buttons keep up).
  final ValueNotifier<int> pearls;

  /// Buys one; false if it could not be bought.
  final bool Function(JarKind jar) onBuy;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: pearls,
    builder: (context, have, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text['jars_title'] ?? '',
          style: const TextStyle(
            color: GamePalette.talents,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        for (final jar in jars)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    names[jar.id] ?? '',
                    style: const TextStyle(color: Color(0xFFF3E5C8)),
                  ),
                ),
                TextButton(
                  key: Key('jar_odds_${jar.id}'),
                  onPressed: () => showJarOdds(
                    context,
                    text: text,
                    title: names[jar.id] ?? '',
                    jar: jar,
                  ),
                  child: Text(
                    text['see_odds'] ?? '',
                    style: const TextStyle(
                      color: GamePalette.talents,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                FilledButton(
                  key: Key('jar_buy_${jar.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: GamePalette.gold,
                    foregroundColor: GamePalette.backgroundBottom,
                    disabledBackgroundColor: GamePalette.panelLight,
                    disabledForegroundColor: GamePalette.muted,
                  ),
                  // Greyed out without the Pearls for it.
                  onPressed: have >= (jar.pearlPrice ?? 0)
                      ? () => onBuy(jar)
                      : null,
                  child: Text(
                    (text['jar_buy'] ?? '').replaceAll(
                      '{pearls}',
                      '${jar.pearlPrice}',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Shows what a kind of jar may hold, each with its chance.
Future<void> showJarOdds(
  BuildContext context, {
  required Map<String, String> text,
  required String title,
  required JarKind jar,
}) => showDialog<void>(
  context: context,
  builder: (context) => GameDialog(
    key: const Key('jar_odds_panel'),
    icon: Icons.percent,
    title: Text(title, style: const TextStyle(color: GamePalette.gold)),
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(
        shrinkWrap: true,
        children: [
          OddsList(title: text['jar_holds'] ?? '', odds: jar.odds),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              text['odds_note'] ?? '',
              style: const TextStyle(color: GamePalette.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        key: const Key('odds_close'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(text['close'] ?? ''),
      ),
    ],
  ),
);
