// Goal events (EXPANSION section 22): short events played on the ordinary
// board. Each counts one thing the player does and pays rewards at
// milestones. Several can run at once. Pure Dart, fully unit tested.
//
// The kinds: a milestone event counts Talents earned from orders; an energy
// event counts Manna spent; a collect event counts tokens that now and then
// drop from merges; an order event counts tokens that come with orders.
import 'package:whispers_of_joppa/domain/season_pass.dart';

enum GoalKind { milestone, energy, collect, order }

/// The name of each kind in an event's settings ("type"), and the feature
/// in content/levels.json that opens it to a player.
const goalKindNames = {
  'milestone': GoalKind.milestone,
  'energy': GoalKind.energy,
  'collect': GoalKind.collect,
  'order': GoalKind.order,
};
const goalKindFeatures = {
  GoalKind.milestone: 'milestone_event',
  GoalKind.energy: 'energy_event',
  GoalKind.collect: 'collect_event',
  GoalKind.order: 'order_event',
};

class GoalMilestone {
  final int points;
  final PassReward reward;

  const GoalMilestone({required this.points, required this.reward});
}

class GoalEvent {
  final String id;
  final String name;
  final GoalKind kind;
  final DateTime startsAt;
  final DateTime endsAt;

  /// A line telling the player what to do.
  final String blurb;

  /// What is counted, in the event's own words ("Olive branches").
  final String token;
  final List<GoalMilestone> milestones;

  /// Collect events: out of a hundred merges, how many drop a token.
  final int dropPercent;

  /// Order events: tokens that come with each order.
  final int perOrder;

  const GoalEvent({
    required this.id,
    required this.name,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.milestones,
    this.blurb = '',
    this.token = '',
    this.dropPercent = 0,
    this.perOrder = 1,
  });

  /// Reads a row of the `events` table whose settings name one of the goal
  /// kinds. (Check it with goalEventProblems first.)
  factory GoalEvent.fromJson(Map<String, dynamic> json) {
    final config = json['config'] as Map<String, dynamic>;
    return GoalEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      // Safe: goalEventProblems has checked the type is one of these.
      kind: goalKindNames[config['type']]!,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      blurb: config['blurb'] as String? ?? '',
      token: config['token'] as String? ?? '',
      dropPercent: config['drop_percent'] as int? ?? 0,
      perOrder: config['per_order'] as int? ?? 1,
      milestones: [
        for (final m in config['milestones'] as List<dynamic>)
          GoalMilestone(
            points: (m as Map<String, dynamic>)['points'] as int,
            reward: PassReward.fromJson(m),
          ),
      ],
    );
  }

  bool isLive(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);
}

/// Whether an `events` row is a goal event (its settings name a goal kind)
/// rather than an event with a board of its own.
bool isGoalEventRow(Object? row) => switch (row) {
  {'config': {'type': final String type}} => goalKindNames.containsKey(type),
  _ => false,
};

/// Something the player did that an event may count.
sealed class GoalAction {
  const GoalAction();
}

/// An order was delivered, paying [talents].
class OrderDelivered extends GoalAction {
  final int talents;
  const OrderDelivered(this.talents);
}

/// [amount] Manna was spent.
class MannaSpent extends GoalAction {
  final int amount;
  const MannaSpent(this.amount);
}

/// Two items were merged; [roll] is a number from 0 up to (not including)
/// 100, drawn by chance.
class ItemsMerged extends GoalAction {
  final int roll;
  const ItemsMerged(this.roll);
}

/// The points [action] earns in [event].
int goalPoints(GoalEvent event, GoalAction action) {
  final points = switch ((event.kind, action)) {
    (GoalKind.milestone, OrderDelivered(:final talents)) => talents,
    (GoalKind.order, OrderDelivered()) => event.perOrder,
    (GoalKind.energy, MannaSpent(:final amount)) => amount,
    (GoalKind.collect, ItemsMerged(:final roll)) =>
      roll < event.dropPercent ? 1 : 0,
    _ => 0,
  };
  return points < 0 ? 0 : points;
}

/// A player's run at one goal event, as kept in the save file.
class GoalProgress {
  final int points;

  /// How many milestones have been paid.
  final int paid;

  const GoalProgress({this.points = 0, this.paid = 0});

  factory GoalProgress.fromJson(Object? json) {
    int count(String key) =>
        switch (json is Map<String, dynamic> ? json[key] : null) {
          final int n when n > 0 => n,
          _ => 0,
        };
    return GoalProgress(points: count('points'), paid: count('paid'));
  }

  Map<String, dynamic> toJson() => {'points': points, 'paid': paid};
}

/// The milestones [progress] has reached and not been paid for.
List<GoalMilestone> goalsToPay(GoalEvent event, GoalProgress progress) {
  final reached = event.milestones
      .where((m) => progress.points >= m.points)
      .length;
  if (progress.paid >= reached) return const [];
  return event.milestones.sublist(progress.paid, reached);
}

/// The next milestone to reach, or null when every one is behind.
GoalMilestone? nextGoal(GoalEvent event, GoalProgress progress) {
  for (final m in event.milestones) {
    if (progress.points < m.points) return m;
  }
  return null;
}

/// How far [progress] is from the last milestone reached to the next, from
/// 0 to 1 (1 when every milestone is behind).
double goalFraction(GoalEvent event, GoalProgress progress) {
  final next = nextGoal(event, progress);
  if (next == null) return 1;
  var from = 0;
  for (final m in event.milestones) {
    if (m.points <= progress.points) from = m.points;
  }
  return (progress.points - from) / (next.points - from);
}
