// Today's deals at the top of the shop (EXPANSION 21.1): a free gift and a
// few things for Pearls, new each day. Each says exactly what it gives.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/deals.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// The name of the deals' record in the save file.
const dealsRecord = 'deals';

class DailyDeals extends StatelessWidget {
  const DailyDeals({
    super.key,
    required this.config,
    required this.extras,
    required this.text,
    required this.pearls,
    required this.spendPearls,
    required this.give,
    this.clock,
  });

  final DealsConfig config;
  final SaveExtras extras;
  final Map<String, String> text;

  /// The Pearls the player has (listened to, so the buttons keep up).
  final ValueNotifier<int> pearls;

  /// Takes Pearls; false (taking nothing) if there are not enough.
  final bool Function(int amount) spendPearls;

  /// Hands over what a deal holds.
  final void Function(DailyDeal deal) give;
  final DateTime Function()? clock;

  DateTime get _now => (clock ?? DateTime.now)();
  DealsTally get _tally => DealsTally.fromJson(extras.read(dealsRecord));

  /// Takes [deal]: once a day, and for its price if it has one. Returns
  /// whether it was taken.
  bool take(DailyDeal deal) {
    final now = _now;
    if (_tally.hasTaken(deal, now)) return false;
    if (!dealsFor(config, now).any((d) => d.id == deal.id)) return false;
    if (!deal.free && !spendPearls(deal.pearlPrice)) return false;
    extras.write(dealsRecord, _tally.after(deal, now).toJson());
    give(deal);
    return true;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([extras, pearls]),
    builder: (context, _) {
      final now = _now;
      return Container(
        key: const Key('daily_deals'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: GamePalette.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GamePalette.panelEdge, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text['deals_title'] ?? '',
              style: const TextStyle(
                color: GamePalette.talents,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            for (final deal in dealsFor(config, now)) _row(deal, now),
            Text(
              text['deals_note'] ?? '',
              style: const TextStyle(color: GamePalette.muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );

  Widget _row(DailyDeal deal, DateTime now) {
    final taken = _tally.hasTaken(deal, now);
    final label = taken
        ? text['deal_taken'] ?? ''
        : deal.free
        ? text['deal_free'] ?? ''
        : (text['deal_price'] ?? '').replaceAll(
            '{pearls}',
            '${deal.pearlPrice}',
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              deal.name,
              style: const TextStyle(color: Color(0xFFF3E5C8), fontSize: 15),
            ),
          ),
          FilledButton(
            key: Key('deal_${deal.id}'),
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: GamePalette.action,
              foregroundColor: GamePalette.onAction,
              disabledBackgroundColor: GamePalette.panelLight,
              disabledForegroundColor: GamePalette.muted,
            ),
            // Greyed out once taken, or without the Pearls for it.
            onPressed: taken || (!deal.free && pearls.value < deal.pearlPrice)
                ? null
                : () => take(deal),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
