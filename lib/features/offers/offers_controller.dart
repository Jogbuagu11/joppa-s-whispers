// Decides which offer, if any, is shown at a given moment, and remembers
// what was shown and turned down. The rules are in domain/offers.dart.
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';
import 'package:whispers_of_joppa/services/offers_source.dart';

/// The name of the offers' record in the save file.
const offersRecord = 'offers';

const _freshFor = Duration(minutes: 10);

class OffersController {
  final OffersSource source;
  final OfferRules rules;
  final SaveExtras extras;
  final DateTime Function() _clock;

  /// Tells the server an offer was shown or turned down (signed-in players).
  final void Function(Offer offer, String outcome)? note;

  List<Offer> _offers = const [];
  DateTime? _readAt;
  int _shownThisSession;
  int _shownAtThisStart;

  /// [carryOn] is the controller this one takes over from in the same run
  /// of the app (the game was reloaded): the session's count goes on.
  OffersController({
    required this.source,
    required this.rules,
    required this.extras,
    this.note,
    OffersController? carryOn,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _shownThisSession = carryOn?._shownThisSession ?? 0,
       _shownAtThisStart = carryOn?._shownAtThisStart ?? 0;

  OfferMemory get _memory => OfferMemory.fromJson(
    extras.read(offersRecord),
  ).lapsed(_clock(), rules.repeatAfter);

  /// Reads the offers from the server. Until this has finished there are
  /// none to show.
  Future<void> load() async {
    _offers = await source.fetch();
    _readAt = _clock();
  }

  /// Reads them again if that was a while ago, so an offer changed or
  /// switched off on the server is not shown from memory.
  Future<void> refreshIfStale() async {
    final read = _readAt;
    if (read == null || _clock().difference(read) > _freshFor) await load();
  }

  /// The offer to show for [trigger] to this player, or null: none fits,
  /// or the rules say there have been enough for now. For a level-up,
  /// [fromLevel] is the level before it.
  Offer? next(
    OfferTrigger trigger, {
    required int level,
    required bool hasPaid,
    int? fromLevel,
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
    if (trigger == OfferTrigger.levelUp &&
        !levelBringsOffer(rules, from: fromLevel ?? level - 1, to: level)) {
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

  /// The player has come back after a good while away: a new session, with
  /// its own greeting and its own count.
  void newSession() {
    _shownThisSession = 0;
    _shownAtThisStart = 0;
  }

  /// Records that [offer] was bought: it is not offered again for now.
  void bought(Offer offer) =>
      extras.write(offersRecord, _memory.afterBought(offer).toJson());

  /// Records that [offer] was turned down: next time its "next" is offered.
  void declined(Offer offer) {
    extras.write(offersRecord, _memory.afterDeclined(offer).toJson());
    note?.call(offer, 'dismissed');
  }
}
