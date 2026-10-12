// The global feast goal (EXPANSION section 22): every player's orders add
// to one total kept on the server; when it reaches a milestone, everyone
// who took part gets the reward. Pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/goal_events.dart';

/// The server's count for global goals.
abstract class GlobalGoalServer {
  /// Whether this player can add to a total (they are signed in).
  bool get signedIn;

  /// The total so far. Throws if the server cannot be reached.
  Future<int> total(String eventId);

  /// Adds [amount] of this player's orders; gives the new total.
  Future<int> add(String eventId, int amount);
}

/// The most orders sent to the server in one go.
const globalGoalMostAtOnce = 100;

/// A player's part in one global goal, as kept in the save file.
class GlobalProgress {
  /// Orders this player has delivered during the goal.
  final int mine;

  /// How many of those the server has been told of.
  final int sent;

  /// The total of all players, as last heard.
  final int total;

  /// How many milestones have been paid.
  final int paid;
  final DateTime? endsAt;

  const GlobalProgress({
    this.mine = 0,
    this.sent = 0,
    this.total = 0,
    this.paid = 0,
    this.endsAt,
  });

  factory GlobalProgress.fromJson(Object? json) {
    int count(String key) =>
        switch (json is Map<String, dynamic> ? json[key] : null) {
          final int n when n > 0 => n,
          _ => 0,
        };
    return GlobalProgress(
      mine: count('mine'),
      sent: count('sent'),
      total: count('total'),
      paid: count('paid'),
      endsAt: json is Map<String, dynamic>
          ? DateTime.tryParse('${json['ends_at']}')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'mine': mine,
    'sent': sent,
    'total': total,
    'paid': paid,
    'ends_at': ?endsAt?.toUtc().toIso8601String(),
  };

  GlobalProgress copyWith({int? mine, int? sent, int? total, int? paid}) =>
      GlobalProgress(
        mine: mine ?? this.mine,
        sent: sent ?? this.sent,
        total: total ?? this.total,
        paid: paid ?? this.paid,
        endsAt: endsAt,
      );

  /// What everyone has done as far as this phone knows: the server's
  /// total, and this player's orders it has not yet been told of.
  int get known => total + (mine > sent ? mine - sent : 0);

  /// The same, in the shape the events list shows.
  GoalProgress get shown => GoalProgress(points: known, paid: paid);

  /// How many orders to send to the server now.
  int get toSend {
    final waiting = mine - sent;
    if (waiting <= 0) return 0;
    return waiting > globalGoalMostAtOnce ? globalGoalMostAtOnce : waiting;
  }
}

/// The milestones the total has reached that this player has not been
/// paid for. Only those who took part (one order at least) are paid.
List<GoalMilestone> globalToPay(GoalEvent event, GlobalProgress progress) {
  if (progress.mine < 1) return const [];
  return goalsToPay(event, progress.shown);
}
