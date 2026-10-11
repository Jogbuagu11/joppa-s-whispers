// Things staged for the look pictures (look_shots.dart).

/// Two goal events like the first ones on the server, on for as long as
/// [event] (the feast event) is.
List<Map<String, dynamic>> lookGoalEvents(Map<String, dynamic> event) => [
  for (final (id, name, type, blurb, token) in const [
    (
      'harvest',
      'Harvest Gathering',
      'milestone',
      'Deliver orders: every Talent you earn counts.',
      'Talents earned',
    ),
    (
      'lamps',
      'Lamps of Joppa',
      'energy',
      'Keep the lamps burning: every Manna you spend counts.',
      'Manna spent',
    ),
  ])
    {
      'id': id,
      'name': name,
      'starts_at': event['starts_at'],
      'ends_at': event['ends_at'],
      'config': {
        'type': type,
        'blurb': blurb,
        'token': token,
        'milestones': [
          {'points': 30, 'talents': 20},
          {'points': 80, 'manna': 10},
          {
            'points': 150,
            'items': ['hourglass_01'],
          },
        ],
      },
    },
];
