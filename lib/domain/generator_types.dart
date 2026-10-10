// The kinds of generator and their clocks: charges and cooldowns, items made
// on their own, and generators that are used up. Pure Dart, unit tested.

enum GeneratorKind {
  /// Costs Manna each tap; never runs out.
  standard,

  /// Gives a set number of items, then rests and recharges. No Manna cost.
  charged,

  /// Makes an item by itself every so often. No Manna, no tapping.
  free,

  /// Gives a fixed number of items, then is gone. No Manna cost.
  temporary,
}

/// How one generator behaves (from content/generators.json).
class GeneratorRules {
  final GeneratorKind kind;

  /// Charged: items given before it rests.
  final int charges;

  /// Charged: how long it rests.
  final int cooldownSeconds;

  /// Free: seconds between items.
  final int intervalSeconds;

  /// Free: the most items made while the game was closed.
  final int maxWaiting;

  /// Temporary: items given before it disappears.
  final int taps;

  const GeneratorRules({
    this.kind = GeneratorKind.standard,
    this.charges = 0,
    this.cooldownSeconds = 0,
    this.intervalSeconds = 0,
    this.maxWaiting = 1,
    this.taps = 0,
  });

  static const standard = GeneratorRules();

  factory GeneratorRules.fromJson(Map<String, dynamic> json) {
    final kind = GeneratorKind.values.byName(
      json['type'] as String? ?? 'standard',
    );
    return GeneratorRules(
      kind: kind,
      charges: json['charges'] as int? ?? 0,
      cooldownSeconds: json['cooldown_seconds'] as int? ?? 0,
      intervalSeconds: json['interval_seconds'] as int? ?? 0,
      maxWaiting: json['max_waiting'] as int? ?? 1,
      taps: json['taps'] as int? ?? 0,
    );
  }

  /// Whether a tap on this generator costs Manna.
  bool get costsManna => kind == GeneratorKind.standard;
}

/// Where one generator's clock stands (written to the save file).
class GeneratorTimer {
  /// Charged: charges left before it rests. Temporary: taps left.
  final int left;

  /// Charged: when its rest ends (null while it has charges).
  /// Free: when its next item is due.
  final DateTime? at;

  const GeneratorTimer({required this.left, this.at});

  Map<String, dynamic> toJson() => {
    'left': left,
    'at': at?.toUtc().toIso8601String(),
  };

  /// Null if [json] is not a timer (the generator then starts fresh).
  static GeneratorTimer? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final left = json['left'];
    final at = json['at'];
    if (left is! int || left < 0) return null;
    return GeneratorTimer(
      left: left,
      at: at is String ? DateTime.tryParse(at) : null,
    );
  }
}

/// The clock of a generator that has just arrived on the board.
GeneratorTimer freshTimer(GeneratorRules rules, DateTime now) =>
    switch (rules.kind) {
      GeneratorKind.standard => const GeneratorTimer(left: 0),
      GeneratorKind.charged => GeneratorTimer(left: rules.charges),
      GeneratorKind.free => GeneratorTimer(
        left: 0,
        at: now.add(Duration(seconds: rules.intervalSeconds)),
      ),
      GeneratorKind.temporary => GeneratorTimer(left: rules.taps),
    };

/// A charged generator whose rest is over is full again. Anything else is
/// returned unchanged. A saved clock that makes no sense for [rules] (the
/// content changed) is replaced by a fresh one.
GeneratorTimer settled(
  GeneratorRules rules,
  GeneratorTimer timer,
  DateTime now,
) {
  switch (rules.kind) {
    case GeneratorKind.standard:
      return timer;
    case GeneratorKind.charged:
      final rest = timer.at;
      if (timer.left > rules.charges) return freshTimer(rules, now);
      if (timer.left > 0) return GeneratorTimer(left: timer.left);
      if (rest == null || !now.isBefore(rest)) return freshTimer(rules, now);
      // A rest can never be longer than a whole cooldown from now (a phone
      // clock set back must not lock the generator for days).
      final longest = now.add(Duration(seconds: rules.cooldownSeconds));
      return rest.isAfter(longest)
          ? GeneratorTimer(left: 0, at: longest)
          : timer;
    case GeneratorKind.free:
      final due = timer.at;
      final longest = now.add(Duration(seconds: rules.intervalSeconds));
      if (due == null || due.isAfter(longest)) return freshTimer(rules, now);
      return timer;
    case GeneratorKind.temporary:
      return timer.left > rules.taps ? freshTimer(rules, now) : timer;
  }
}

/// Whether a tap can give an item right now (charged and temporary only;
/// a standard generator's limit is Manna, and a free one is not tapped).
bool canGive(GeneratorRules rules, GeneratorTimer timer, DateTime now) =>
    switch (rules.kind) {
      GeneratorKind.standard => true,
      GeneratorKind.charged => settled(rules, timer, now).left > 0,
      GeneratorKind.free => false,
      GeneratorKind.temporary => timer.left > 0,
    };

/// The clock after a tap gave an item. A charged generator that gives its
/// last charge starts its rest.
GeneratorTimer afterGiving(
  GeneratorRules rules,
  GeneratorTimer timer,
  DateTime now,
) {
  switch (rules.kind) {
    case GeneratorKind.standard:
    case GeneratorKind.free:
      return timer;
    case GeneratorKind.charged:
      final left = settled(rules, timer, now).left - 1;
      return left > 0
          ? GeneratorTimer(left: left)
          : GeneratorTimer(
              left: 0,
              at: now.add(Duration(seconds: rules.cooldownSeconds)),
            );
    case GeneratorKind.temporary:
      return GeneratorTimer(left: timer.left > 0 ? timer.left - 1 : 0);
  }
}

/// A temporary generator that has given everything is taken off the board.
bool isUsedUp(GeneratorRules rules, GeneratorTimer timer) =>
    rules.kind == GeneratorKind.temporary && timer.left <= 0;

/// Seconds until a resting charged generator is full, or until a free one
/// makes its next item. Null when nothing is being waited for.
int? secondsToWait(GeneratorRules rules, GeneratorTimer timer, DateTime now) {
  if (rules.kind != GeneratorKind.charged && rules.kind != GeneratorKind.free) {
    return null;
  }
  final at = settled(rules, timer, now).at;
  if (at == null) return null;
  final seconds = at.difference(now).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

/// How many items a free generator owes by [now] (never more than its
/// `max_waiting`), and its clock once they are made. [room] is how many it
/// has space for; what does not fit is not saved up.
({int items, GeneratorTimer timer}) freeItemsDue(
  GeneratorRules rules,
  GeneratorTimer timer,
  DateTime now, {
  required int room,
}) {
  if (rules.kind != GeneratorKind.free || rules.intervalSeconds <= 0) {
    return (items: 0, timer: timer);
  }
  final clock = settled(rules, timer, now);
  final due = clock.at;
  if (due == null || now.isBefore(due)) return (items: 0, timer: clock);
  final owed = 1 + now.difference(due).inSeconds ~/ rules.intervalSeconds;
  var items = owed > rules.maxWaiting ? rules.maxWaiting : owed;
  if (items > room) items = room;
  if (items <= 0) return (items: 0, timer: clock);
  // The next one is a full interval away, however long the wait was.
  return (items: items, timer: freshTimer(rules, now));
}

/// A time-skip (an hourglass): takes [seconds] off a wait, or ends it when
/// [seconds] is null. Returns null if there is nothing to shorten, so the
/// hourglass is not wasted.
GeneratorTimer? skipped(
  GeneratorRules rules,
  GeneratorTimer timer,
  DateTime now, {
  int? seconds,
}) {
  final clock = settled(rules, timer, now);
  final at = clock.at;
  if (at == null || !now.isBefore(at)) return null;
  if (rules.kind == GeneratorKind.charged) {
    final sooner = seconds == null
        ? now
        : at.subtract(Duration(seconds: seconds));
    return sooner.isAfter(now)
        ? GeneratorTimer(left: 0, at: sooner)
        : freshTimer(rules, now);
  }
  if (rules.kind == GeneratorKind.free) {
    final sooner = seconds == null
        ? now
        : at.subtract(Duration(seconds: seconds));
    return GeneratorTimer(left: 0, at: sooner.isAfter(now) ? sooner : now);
  }
  return null;
}

/// "1:05:09", "4:30" or "0:07": a wait as the player reads it.
String formatWait(int seconds) {
  final h = seconds ~/ 3600;
  final m = seconds % 3600 ~/ 60;
  final s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}
