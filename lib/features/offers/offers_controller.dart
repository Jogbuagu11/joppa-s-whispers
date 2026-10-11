// Decides which offer, if any, is shown at a given moment, and remembers
// what was shown and turned down. The rules are in domain/offers.dart.
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';
import 'package:whispers_of_joppa/services/offers_source.dart';

/// The name of the offers' record in the save file.
const offersRecord = 'offers';

class OffersController {
  final OffersSource source;
  final OfferRules rules;
  final SaveExtras extras;
  final DateTime Function() _clock;

  /// Tells the server an offer was shown or turned down (signed-in players).
  final void Function(Offer offer, String outcome)? note;

  List<Offer> _offers = const [];
  int _shownThisSession = 0;
  int _shownAtThisStart = 0;

  OffersController({
    required this.source,
    required this.rules,
    required this.extras,
    this.note,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  OfferMemory get _memory => OfferMemory.fromJson(extras.read(offersRecord));

  /// Reads the offers from the server (again). Until this has finished
  /// there are none to show.
  Future<void> load() async => _offers = await source.fetch();

  /// The offer to show for [trigger] to this player, or null: none fits,
  /// or the rules say there have been enough for now.
  Offer? next(
    OfferTrigger trigger, {
    required int level,
    required bool hasPaid,
  }) {
    final now = _clock();
    final memory = _memory;
    final allowed = mayShowOffer(
      rules: rules,
      trigger: trigger,
      shownThisSession: _shownThisSession,
      shownAtThisStart: _shownAtThisStart,
      memory: memory,
      now: now,
    );
    if (!allowed) return null;
    if (trigger == OfferTrigger.levelUp && !levelBringsOffer(rules, level)) {
      return null;
    }
    return chooseOffer(
      offers: _offers,
      trigger: trigger,
      level: level,
      hasPaid: hasPaid,
      memory: memory,
      now: now,
    );
  }

  /// Records that [offer] is on the screen now. Returns when its countdown
  /// ends (counted from the first time this player saw it).
  DateTime shown(Offer offer, OfferTrigger trigger) {
    final now = _clock();
    final memory = _memory.afterShown(offer, trigger, now);
    extras.write(offersRecord, memory.toJson());
    _shownThisSession++;
    if (trigger == OfferTrigger.sessionStart) _shownAtThisStart++;
    note?.call(offer, 'shown');
    return offerEndsAt(offer, now, firstShown: memory.firstShown[offer.id]);
  }

  /// Records that [offer] was turned down: next time its "next" is offered.
  void declined(Offer offer) {
    extras.write(offersRecord, _memory.afterDeclined(offer).toJson());
    note?.call(offer, 'dismissed');
  }
}
