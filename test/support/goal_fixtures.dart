// A complete, valid goal event for tests.

/// A goal event row as the server gives it, on now unless dated otherwise.
Map<String, dynamic> goalRow({
  String id = 'harvest',
  String type = 'milestone',
  DateTime? startsAt,
  DateTime? endsAt,
  Map<String, dynamic> more = const {},
}) {
  final now = DateTime.now().toUtc();
  return {
    'id': id,
    'name': 'Harvest Gathering',
    'starts_at': (startsAt ?? now.subtract(const Duration(days: 1)))
        .toIso8601String(),
    'ends_at': (endsAt ?? now.add(const Duration(days: 2))).toIso8601String(),
    'config': {
      'type': type,
      'blurb': 'Deliver orders to gather the harvest.',
      'token': 'Talents',
      'milestones': [
        {'points': 10, 'manna': 5},
        {'points': 30, 'talents': 20, 'pearls': 2},
        {
          'points': 60,
          'items': ['thread_01'],
        },
      ],
      ...more,
    },
  };
}
