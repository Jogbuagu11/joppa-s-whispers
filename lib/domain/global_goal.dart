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

  /// Tells the server this player has delivered [mine] orders in all (the
  /// whole count, so telling it twice adds nothing); gives the new total.
  Future<int> tell(String eventId, int mine);
}

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

  /// True once the goal has ended and its last total has been heard.
  final bool closed;

  const GlobalProgress({
    this.mine = 0,
    this.sent = 0,
    this.total = 0,
    this.paid = 0,
    this.endsAt,
    this.closed = false,
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
      closed: json is Map<String, dynamic> && json['closed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'mine': mine,
    'sent': sent,
    'total': total,
    'paid': paid,
    'ends_at': ?endsAt?.toUtc().toIso8601String(),
    if (closed) 'closed': true,
  };

  GlobalProgress copyWith({
    int? mine,
    int? sent,
    int? total,
    int? paid,
    DateTime? endsAt,
    bool? closed,
  }) => GlobalProgress(
    mine: mine ?? this.mine,
    sent: sent ?? this.sent,
    total: total ?? this.total,
    paid: paid ?? this.paid,
    endsAt: endsAt ?? this.endsAt,
    closed: closed ?? this.closed,
  );

  /// What everyone has done as far as this phone knows: the server's
  /// total, and this player's orders it has not yet been told of.
  int get known => total + (mine > sent ? mine - sent : 0);

  /// The same, in the shape the events list shows.
  GoalProgress get shown => GoalProgress(points: known, paid: paid);

  /// Whether the server has yet to hear of some of this player's orders.
  bool get hasUnsent => mine > sent;
}

/// The milestones the total has reached that this player has not been
/// paid for. Only those who took part (one order at least) are paid.
List<GoalMilestone> globalToPay(GoalEvent event, GlobalProgress progress) {
  if (progress.mine < 1) return const [];
  return goalsToPay(event, progress.shown);
}
