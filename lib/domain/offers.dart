// Offers (EXPANSION section 21): which one a player is shown, when, and how
// often. Pure Dart, unit tested. What an offer gives is decided by the server.
import 'package:whispers_of_joppa/domain/offer_memory.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';

export 'package:whispers_of_joppa/domain/offer_memory.dart';

/// The moments an offer may be shown at.
enum OfferTrigger {
  sessionStart('session_start'),
  outOfManna('out_of_manna'),
  levelUp('level_up'),
  chapterComplete('chapter_complete');

  const OfferTrigger(this.kind);

  /// The `kind` of the offers shown at this moment.
  final String kind;
}

// A flash sale or a themed bundle has no moment of its own: while its
// window is open it is shown when the game is opened.
const _atSessionStart = {'session_start', 'flash_sale', 'themed'};

/// One row of the server's `offers` table.
class Offer {
  final String id;
  final String kind;
  final String productId;
  final String title;
  final String subtitle;

  /// Exactly what it gives, as the server will grant it.
  final PurchaseGrant contents;

  /// 'any', 'non_payer' or 'payer'.
  final String audience;
  final int minLevel;

  /// Shown instead, once this one has been turned down.
  final String? nextOfferId;

  /// How long its countdown runs from when it is first shown.
  final Duration duration;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int priority;

  const Offer({
    required this.id,
    required this.kind,
    required this.productId,
    required this.title,
    required this.contents,
    this.subtitle = '',
    this.audience = 'any',
    this.minLevel = 1,
    this.nextOfferId,
    this.duration = const Duration(days: 1),
    this.startsAt,
    this.endsAt,
    this.priority = 0,
  });

  /// Null if [json] is not an offer, or gives nothing.
  static Offer? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'kind': final String kind,
      'product_id': final String productId,
      'title': final String title,
    }) {
      final contents = PurchaseGrant.fromJson(json['contents']);
      if (contents == null || _isEmpty(contents)) return null;
      DateTime? time(Object? value) =>
          value is String ? DateTime.tryParse(value) : null;
      return Offer(
        id: id,
        kind: kind,
        productId: productId,
        title: title,
        contents: contents,
        subtitle: switch (json['subtitle']) {
          final String words => words,
          _ => '',
        },
        audience: switch (json['audience']) {
          final String who => who,
          _ => 'any',
        },
        minLevel: switch (json['min_level']) {
          final int level => level,
          _ => 1,
        },
        nextOfferId: switch (json['next_offer_id']) {
          final String next => next,
          _ => null,
        },
        duration: switch (json['duration_seconds']) {
          final int seconds when seconds >= 60 => Duration(seconds: seconds),
          _ => const Duration(days: 1),
        },
        startsAt: time(json['starts_at']),
        endsAt: time(json['ends_at']),
        priority: switch (json['priority']) {
          final int priority => priority,
          _ => 0,
        },
      );
    }
    return null;
  }
}

bool _isEmpty(PurchaseGrant g) =>
    g.pearls == 0 && g.manna == 0 && g.talents == 0 && g.items.isEmpty;

/// How often offers may appear (content/offers.json, "rules").
class OfferRules {
  final int maxPerSession;
  final int maxAtSessionStart;
  final int sessionStartPerDay;

  /// A level-up offer comes at every level that divides by this.
  final int levelEvery;

  /// An offer that was shown (bought, turned down or left to run out) may
  /// come round again after this long, with a fresh countdown. Zero: never.
  final Duration repeatAfter;

  const OfferRules({
    this.maxPerSession = 3,
    this.maxAtSessionStart = 1,
    this.sessionStartPerDay = 1,
    this.levelEvery = 5,
    this.repeatAfter = const Duration(days: 7),
  });

  factory OfferRules.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    int read(String key, int fallback) => switch (map[key]) {
      final int n when n >= 0 => n,
      _ => fallback,
    };
    return OfferRules(
      maxPerSession: read('max_per_session', 3),
      maxAtSessionStart: read('max_at_session_start', 1),
      sessionStartPerDay: read('session_start_per_day', 1),
      levelEvery: read('level_every', 5),
      repeatAfter: Duration(days: read('repeat_after_days', 7)),
    );
  }
}

/// When [offer]'s countdown ends for a player first shown it at
/// [firstShown] (or now, if never): its own run, cut short by its window.
DateTime offerEndsAt(Offer offer, DateTime now, {DateTime? firstShown}) {
  final byTimer = (firstShown ?? now).add(offer.duration);
  final ends = offer.endsAt;
  return ends != null && ends.isBefore(byTimer) ? ends : byTimer;
}

/// Whether the rules allow one more offer now.
bool mayShowOffer({
  required OfferRules rules,
  required OfferTrigger trigger,
  required int shownThisSession,
  required int shownAtThisStart,
  required OfferMemory memory,
  required DateTime now,
}) {
  if (shownThisSession >= rules.maxPerSession) return false;
  if (trigger != OfferTrigger.sessionStart) return true;
  return shownAtThisStart < rules.maxAtSessionStart &&
      memory.startsOn(now) < rules.sessionStartPerDay;
}

/// Whether a level-up offer comes with a rise from level [from] to [to]:
/// when a level that divides by the rule's number was reached or passed.
bool levelBringsOffer(OfferRules rules, {required int from, required int to}) {
  final every = rules.levelEvery;
  return every > 0 && to > from && to ~/ every > from ~/ every;
}

/// The offer to show for [trigger], or null: the one with the highest
/// priority among those meant for this player and still running. An offer
/// that was turned down (or ran out) gives way to the one named as its
/// next, which is cheaper or bigger; with no next, or once any of them has
/// been bought, none of them is shown (until the memory of it lapses: see
/// [OfferMemory.lapsed]).
Offer? chooseOffer({
  required List<Offer> offers,
  required OfferTrigger trigger,
  required int level,
  required bool hasPaid,
  required OfferMemory memory,
  required DateTime now,
}) {
  final byId = {for (final offer in offers) offer.id: offer};
  bool running(Offer o) {
    final starts = o.startsAt;
    if (starts != null && now.isBefore(starts)) return false;
    final shown = memory.firstShown[o.id];
    final ends = shown == null
        ? o.endsAt
        : offerEndsAt(o, now, firstShown: shown);
    return ends == null || now.isBefore(ends);
  }

  bool spent(Offer o) => memory.declined.contains(o.id) || !running(o);
  bool forPlayer(Offer o) =>
      level >= o.minLevel &&
      (o.audience == 'any' || (o.audience == 'payer') == hasPaid);

  // Offers that are only ever reached as another's "next".
  final follow = {for (final o in offers) ?o.nextOfferId};
  Offer? best;
  var bestPriority = 0;
  for (final first in offers) {
    final atThisMoment = trigger == OfferTrigger.sessionStart
        ? _atSessionStart.contains(first.kind)
        : first.kind == trigger.kind;
    if (!atThisMoment || follow.contains(first.id) || !forPlayer(first)) {
      continue;
    }
    // Walk down the chain past everything already turned down.
    Offer? offer = first;
    final seen = <String>{};
    var bought = false;
    while (offer != null && seen.add(offer.id)) {
      if (memory.bought.contains(offer.id)) bought = true;
      if (!spent(offer)) break;
      offer = byId[offer.nextOfferId];
    }
    if (bought || offer == null || spent(offer) || !forPlayer(offer)) continue;
    if (best == null || first.priority > bestPriority) {
      best = offer;
      bestPriority = first.priority;
    }
  }
  return best;
}
