// A race (EXPANSION section 22, "Race to the Harbor"): the player and four
// townsfolk of Joppa each deliver a number of orders; the first three home
// win prizes. The townsfolk are played by the game: each takes a set
// number of hours, counted from the player's first order. Pure Dart, fully
// unit tested.

class RaceRival {
  final String name;

  /// How long this rival takes to finish.
  final int hours;

  const RaceRival({required this.name, required this.hours});
}

/// How many of [goal] orders [rival] has delivered, [since] the race began
/// for this player (nothing before it began).
int rivalCount(RaceRival rival, int goal, Duration? since) {
  if (since == null || since.isNegative || rival.hours <= 0) return 0;
  final whole = Duration(hours: rival.hours).inSeconds;
  if (since.inSeconds >= whole) return goal;
  return goal * since.inSeconds ~/ whole;
}

/// The place (1 is first) of a player who finished after [taken]: behind
/// every rival who was home by then.
int racePlace(List<RaceRival> rivals, Duration taken) =>
    1 + rivals.where((r) => Duration(hours: r.hours) <= taken).length;
