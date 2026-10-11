// What the game remembers about offers between sessions. Pure Dart.
import 'package:whispers_of_joppa/domain/ads.dart' show dayStamp;
import 'package:whispers_of_joppa/domain/offers.dart';

/// What the game remembers about offers between sessions (saved).
class OfferMemory {
  /// The day the session-start count is for.
  final String day;
  final int sessionStartsToday;

  /// offer id -> when its countdown began.
  final Map<String, DateTime> firstShown;

  /// Offers turned down or let run out.
  final Set<String> declined;

  /// Offers bought.
  final Set<String> bought;

  const OfferMemory({
    this.day = '',
    this.sessionStartsToday = 0,
    this.firstShown = const {},
    this.declined = const {},
    this.bought = const {},
  });

  /// Reads what was saved; anything missing or odd counts as nothing.
  factory OfferMemory.fromJson(Map<String, dynamic>? json) => OfferMemory(
    day: switch (json?['day']) {
      final String day => day,
      _ => '',
    },
    sessionStartsToday: switch (json?['starts']) {
      final int n when n > 0 => n,
      _ => 0,
    },
    firstShown: {
      if (json?['shown'] case final Map<String, dynamic> shown)
        for (final e in shown.entries)
          if (e.value case final String at)
            if (DateTime.tryParse(at) case final DateTime time) e.key: time,
    },
    declined: _ids(json?['declined']),
    bought: _ids(json?['bought']),
  );

  static Set<String> _ids(Object? json) => {
    if (json case final List<dynamic> ids)
      for (final id in ids)
        if (id is String) id,
  };

  Map<String, dynamic> toJson() => {
    'day': day,
    'starts': sessionStartsToday,
    'shown': {
      for (final e in firstShown.entries)
        e.key: e.value.toUtc().toIso8601String(),
    },
    'declined': declined.toList(),
    'bought': bought.toList(),
  };

  /// Session-start offers already shown on the day of [now].
  int startsOn(DateTime now) => day == dayStamp(now) ? sessionStartsToday : 0;

  /// The memory after [offer] is shown at [now] for [trigger].
  OfferMemory afterShown(Offer offer, OfferTrigger trigger, DateTime now) =>
      OfferMemory(
        day: dayStamp(now),
        sessionStartsToday:
            startsOn(now) + (trigger == OfferTrigger.sessionStart ? 1 : 0),
        firstShown: {offer.id: now, ...firstShown},
        declined: declined,
        bought: bought,
      );

  /// The memory after [offer] is turned down.
  OfferMemory afterDeclined(Offer offer) => OfferMemory(
    day: day,
    sessionStartsToday: sessionStartsToday,
    firstShown: firstShown,
    declined: {...declined, offer.id},
    bought: bought,
  );

  /// The memory after [offer] is bought.
  OfferMemory afterBought(Offer offer) => OfferMemory(
    day: day,
    sessionStartsToday: sessionStartsToday,
    firstShown: firstShown,
    declined: declined,
    bought: {...bought, offer.id},
  );

  /// This memory with everything about offers first shown longer ago than
  /// [repeatAfter] forgotten, so they may come round again (with a fresh
  /// countdown, a good while after the last). Zero forgets nothing.
  OfferMemory lapsed(DateTime now, Duration repeatAfter) {
    if (repeatAfter <= Duration.zero) return this;
    final kept = {
      for (final e in firstShown.entries)
        if (now.difference(e.value) < repeatAfter) e.key: e.value,
    };
    if (kept.length == firstShown.length) return this;
    return OfferMemory(
      day: day,
      sessionStartsToday: sessionStartsToday,
      firstShown: kept,
      declined: declined.where(kept.containsKey).toSet(),
      bought: bought.where(kept.containsKey).toSet(),
    );
  }
}
