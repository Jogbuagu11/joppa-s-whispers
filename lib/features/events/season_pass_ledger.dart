// Which season passes this player holds, as the server last said. Kept in
// the save file so an event can be played with its pass while offline; it
// is replaced whole each time the server's purchase list is read, so a
// refunded pass is gone the next time.
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

/// The name of the passes' record in the save file.
const seasonPassRecord = 'passes';

class SeasonPassLedger {
  final SaveExtras extras;

  SeasonPassLedger(this.extras);

  List<PassPurchase> get held => [
    if (extras.read(seasonPassRecord)?['held'] case final List<dynamic> list)
      for (final entry in list)
        if (entry case {'event_id': final String eventId})
          (eventId: eventId, plus: entry['plus'] == true),
  ];

  PassTier tierFor(String eventId) => passTier(held, eventId);

  /// The events whose pass the player has already been shown unasked.
  List<String> get _shown => [
    if (extras.read(seasonPassRecord)?['shown'] case final List<dynamic> list)
      for (final id in list)
        if (id is String) id,
  ];

  void _write(List<PassPurchase> held, List<String> shown) =>
      extras.write(seasonPassRecord, {
        'held': [
          for (final p in held) {'event_id': p.eventId, 'plus': p.plus},
        ],
        'shown': shown,
      });

  /// True once for each event, and only for a player without its pass:
  /// the moment to show them the pass unasked (they have just reached a
  /// reward that has a Premium one beside it).
  bool takeUpsell(String eventId) {
    final shown = _shown;
    if (tierFor(eventId) != PassTier.free || shown.contains(eventId)) {
      return false;
    }
    _write(held, [...shown, eventId]);
    return true;
  }

  /// The server's list of this player's purchases has been read.
  void serverRecords(List<PurchaseRecord> fromServer) {
    final now = standingPasses(fromServer);
    final before = held;
    if (now.length == before.length &&
        [
          for (var i = 0; i < now.length; i++) now[i] == before[i],
        ].every((same) => same)) {
      return;
    }
    _write(now, _shown);
  }
}
