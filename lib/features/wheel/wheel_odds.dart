// The list of prizes with their chances, and the "See odds" panel.
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_painter.dart';

/// Every prize of one kind of try, each with its chance.
class OddsList extends StatelessWidget {
  const OddsList({
    super.key,
    required this.title,
    required this.odds,
    this.numbered = false,
  });

  final String title;
  final List<PrizeOdds> odds;

  /// Whether each prize carries the number and colour of its slice.
  final bool numbered;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          title,
          textAlign: TextAlign.left,
          style: const TextStyle(
            color: GamePalette.talents,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      for (var i = 0; i < odds.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              if (numbered) ...[
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: wheelColor(i),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: GamePalette.backgroundBottom,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  odds[i].prize.name,
                  textAlign: TextAlign.left,
                  style: const TextStyle(color: Color(0xFFF3E5C8)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: GamePalette.panelLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formatChance(odds[i].chance),
                  key: Key('odds_${odds[i].prize.id}'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: GamePalette.talents,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// A further list for the odds panel: its heading and its chances.
typedef OddsSection = ({String title, List<PrizeOdds> odds});

/// Shows every prize and its chance: for free and ad spins, (if there are
/// any) for Pearl spins, and then the game's other chances.
Future<void> showWheelOdds(
  BuildContext context, {
  required Map<String, String> text,
  required List<PrizeOdds> free,
  required List<PrizeOdds> paid,
  List<OddsSection> more = const [],
}) => showDialog<void>(
  context: context,
  builder: (context) => GameDialog(
    key: const Key('odds_panel'),
    icon: Icons.percent,
    title: Text(
      text['odds_title'] ?? '',
      style: const TextStyle(color: GamePalette.gold),
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(
        shrinkWrap: true,
        children: [
          OddsList(title: text['odds_free'] ?? '', odds: free),
          if (paid.isNotEmpty)
            OddsList(
              key: const Key('odds_paid'),
              title: text['odds_paid'] ?? '',
              odds: paid,
            ),
          for (final section in more)
            OddsList(title: section.title, odds: section.odds),
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

/// Tells the player what they have just been given.
Future<void> showPrize(
  BuildContext context, {
  required Map<String, String> text,
  required Prize prize,
}) => showDialog<void>(
  context: context,
  builder: (context) => GameDialog(
    key: const Key('wheel_prize'),
    icon: Icons.card_giftcard,
    title: Text(
      text['won_title'] ?? '',
      style: const TextStyle(color: GamePalette.gold),
    ),
    content: Text(
      prize.name,
      key: const Key('wheel_prize_name'),
      style: const TextStyle(color: Color(0xFFF3E5C8), fontSize: 18),
    ),
    actions: [
      FilledButton(
        key: const Key('wheel_prize_ok'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(text['won_button'] ?? ''),
      ),
    ],
  ),
);
