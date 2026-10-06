// Time-limited events: when one is on, how points are earned and which
// rewards they unlock. Pure Dart, fully unit tested.

/// One step on an event's reward track.
class EventMilestone {
  /// Event points needed to reach this step.
  final int points;
  final int manna;
  final int talents;

  const EventMilestone({
    required this.points,
    this.manna = 0,
    this.talents = 0,
  });

  factory EventMilestone.fromJson(Map<String, dynamic> json) => EventMilestone(
    points: json['points'] as int,
    manna: json['manna'] as int? ?? 0,
    talents: json['talents'] as int? ?? 0,
  );
}

/// An event as the server (or the app's own fallback file) describes it.
class EventModel {
  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;

  /// The event board's size.
  final int cols;
  final int rows;

  /// The event's own chain and generator, in the same form as entries in
  /// content/chains.json and content/generators.json.
  final Map<String, dynamic> chain;
  final Map<String, dynamic> generator;

  /// Where the generator sits on the event board.
  final int generatorCol;
  final int generatorRow;

  /// Reward steps, in rising order of points.
  final List<EventMilestone> milestones;

  const EventModel({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.cols,
    required this.rows,
    required this.chain,
    required this.generator,
    required this.generatorCol,
    required this.generatorRow,
    required this.milestones,
  });

  /// Reads one event: a row of the `events` table or an entry of
  /// content/events.json ({id, name, starts_at, ends_at, config}).
  factory EventModel.fromJson(Map<String, dynamic> json) {
    final config = json['config'] as Map<String, dynamic>;
    final board = config['board'] as Map<String, dynamic>;
    final generator = config['generator'] as Map<String, dynamic>;
    return EventModel(
      id: json['id'] as String,
      name: json['name'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      cols: board['cols'] as int,
      rows: board['rows'] as int,
      chain: config['chain'] as Map<String, dynamic>,
      generator: generator,
      generatorCol: generator['col'] as int,
      generatorRow: generator['row'] as int,
      milestones: [
        for (final m in config['milestones'] as List<dynamic>)
          EventMilestone.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}

/// Whether [event] is on at [now]: from its start up to, not including, its
/// end.
bool isEventLive(EventModel event, DateTime now) =>
    !now.isBefore(event.startsAt) && now.isBefore(event.endsAt);

/// The event to show at [now]: of those that are on, the one ending
/// soonest. Null when none is on.
EventModel? currentEvent(Iterable<EventModel> events, DateTime now) {
  EventModel? best;
  for (final event in events) {
    if (!isEventLive(event, now)) continue;
    if (best == null || event.endsAt.isBefore(best.endsAt)) best = event;
  }
  return best;
}

/// Time left before [event] ends (zero once it has).
Duration eventTimeLeft(EventModel event, DateTime now) {
  final left = event.endsAt.difference(now);
  return left.isNegative ? Duration.zero : left;
}

/// "2d 5h", "5h 12m" or "12m": how long is left, in a few characters.
String formatTimeLeft(Duration left) {
  if (left.inDays >= 1) return '${left.inDays}d ${left.inHours % 24}h';
  if (left.inHours >= 1) return '${left.inHours}h ${left.inMinutes % 60}m';
  return '${left.inMinutes}m';
}

/// Event points for a merge that made an item of [resultTier]: higher tiers
/// are worth more.
int eventPointsForMerge(int resultTier) => resultTier < 1 ? 0 : resultTier;

/// How many reward steps [points] has reached.
int milestonesReached(List<EventMilestone> milestones, int points) =>
    milestones.where((m) => points >= m.points).length;

/// The steps reached but not yet paid out, given how many were paid before.
List<EventMilestone> milestonesToPay(
  List<EventMilestone> milestones,
  int points,
  int alreadyPaid,
) {
  final reached = milestonesReached(milestones, points);
  if (alreadyPaid < 0 || alreadyPaid >= reached) return const [];
  return milestones.sublist(alreadyPaid, reached);
}

/// The next step not yet reached, or null when the track is finished.
EventMilestone? nextMilestone(List<EventMilestone> milestones, int points) {
  for (final m in milestones) {
    if (points < m.points) return m;
  }
  return null;
}

/// An item on the event board and its cell.
typedef EventItem = ({String itemId, int col, int row});

/// A player's progress in one event, kept on the phone.
class EventProgress {
  final String eventId;
  final int points;

  /// How many reward steps have been paid out.
  final int paid;
  final List<EventItem> items;

  const EventProgress({
    required this.eventId,
    this.points = 0,
    this.paid = 0,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'points': points,
    'paid': paid,
    'items': [
      for (final i in items) {'item_id': i.itemId, 'col': i.col, 'row': i.row},
    ],
  };

  factory EventProgress.fromJson(Map<String, dynamic> json) => EventProgress(
    eventId: json['event_id'] as String,
    points: json['points'] as int,
    paid: json['paid'] as int,
    items: [
      for (final i in json['items'] as List<dynamic>)
        (
          itemId: (i as Map<String, dynamic>)['item_id'] as String,
          col: i['col'] as int,
          row: i['row'] as int,
        ),
    ],
  );
}
