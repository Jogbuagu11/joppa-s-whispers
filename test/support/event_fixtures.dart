// A complete, valid event for tests.

/// An event row as the server gives it. [startsAt]/[endsAt] default to
/// "on now".
Map<String, dynamic> eventRow({
  String id = 'boat_festival',
  String name = 'Joppa Boat Festival',
  DateTime? startsAt,
  DateTime? endsAt,
}) {
  final now = DateTime.now().toUtc();
  return {
    'id': id,
    'name': name,
    'starts_at': (startsAt ?? now.subtract(const Duration(days: 1)))
        .toIso8601String(),
    'ends_at': (endsAt ?? now.add(const Duration(days: 2, hours: 5)))
        .toIso8601String(),
    'config': {
      'board': {'cols': 5, 'rows': 7},
      'chain': {
        'id': 'boat',
        'placeholder_color': '#3A7CA5',
        'name': 'Boatbuilding',
        'tiers': [
          for (var t = 1; t <= 6; t++)
            {
              'tier': t,
              'item_id': 'boat_0$t',
              'name': 'Boat part $t',
              'sell': t,
            },
        ],
      },
      'generator': {
        'id': 'gen_boatyard',
        'name': 'Boatyard',
        'chain_id': 'boat',
        'col': 2,
        'row': 6,
        'levels': [
          {
            'level': 1,
            'odds': {'1': 1.0},
          },
        ],
      },
      'milestones': [
        {'points': 2, 'manna': 10},
        {'points': 5, 'talents': 50},
        {'points': 9, 'manna': 20, 'talents': 100},
      ],
    },
  };
}
