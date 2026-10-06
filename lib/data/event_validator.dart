// Checks an event before the game will show it. Events come from the
// server, so a mistake in one must be caught here, never crash the game.
// Pure Dart.

/// Plain-English problems with one event ({id, name, starts_at, ends_at,
/// config}). An empty list means it can be played.
List<String> eventProblems(Object? raw) {
  final problems = <String>[];
  if (raw is! Map<String, dynamic>) return ['Event is not an object'];
  final id = raw['id'];
  final label = 'Event "$id"';
  if (id is! String || !RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(id)) {
    problems.add('$label: id must be lowercase letters, digits and _');
  }
  final name = raw['name'];
  if (name is! String || name.trim().isEmpty || name.length > 40) {
    problems.add('$label: name must be 1 to 40 characters');
  }
  final start = DateTime.tryParse('${raw['starts_at']}');
  final end = DateTime.tryParse('${raw['ends_at']}');
  if (start == null || end == null) {
    problems.add('$label: starts_at and ends_at must be dates');
  } else if (!end.isAfter(start)) {
    problems.add('$label: it must end after it starts');
  }
  final config = raw['config'];
  if (config is! Map<String, dynamic>) {
    return problems..add('$label: config is missing');
  }

  final board = config['board'];
  final cols = board is Map<String, dynamic> ? board['cols'] : null;
  final rows = board is Map<String, dynamic> ? board['rows'] : null;
  if (cols is! int ||
      rows is! int ||
      cols < 3 ||
      cols > 7 ||
      rows < 3 ||
      rows > 9) {
    problems.add('$label: board must be 3-7 columns by 3-9 rows');
  }

  final chain = config['chain'];
  final chainId = chain is Map<String, dynamic> ? chain['id'] : null;
  final tiers = chain is Map<String, dynamic> ? chain['tiers'] : null;
  var maxTier = 0;
  if (chainId is! String || tiers is! List<dynamic> || tiers.length < 2) {
    problems.add('$label: chain needs an id and at least 2 tiers');
  } else {
    final itemIds = <String>{};
    for (var i = 0; i < tiers.length; i++) {
      final t = tiers[i];
      final tier = t is Map<String, dynamic> ? t['tier'] : null;
      if (t is! Map<String, dynamic> ||
          tier is! int ||
          tier != i + 1 ||
          !_shortText(t['item_id']) ||
          !_shortText(t['name']) ||
          t['sell'] is! int ||
          !_assetOk(t['asset']) ||
          !itemIds.add('${t['item_id']}')) {
        problems.add('$label: chain tier ${i + 1} is wrong or repeated');
      }
    }
    maxTier = tiers.length;
    if (tiers.length > 12) problems.add('$label: chain has more than 12 tiers');
    final color = (chain as Map<String, dynamic>)['placeholder_color'];
    if (color != null && color is! String) {
      problems.add('$label: chain placeholder_color must be text');
    }
  }

  final generator = config['generator'];
  if (generator is! Map<String, dynamic>) {
    problems.add('$label: generator is missing');
  } else {
    if (!_shortText(generator['id']) || !_shortText(generator['name'])) {
      problems.add('$label: generator needs an id and a name');
    }
    if (generator['chain_id'] != chainId) {
      problems.add('$label: generator must make the event chain');
    }
    final cost = generator['energy_cost'];
    if (cost != null && (cost is! int || cost < 0 || cost > 20)) {
      problems.add('$label: generator energy_cost must be 0 to 20');
    }
    final col = generator['col'];
    final row = generator['row'];
    if (col is! int ||
        row is! int ||
        cols is! int ||
        rows is! int ||
        col < 0 ||
        row < 0 ||
        col >= cols ||
        row >= rows) {
      problems.add('$label: generator must sit on the event board');
    }
    _checkLevels(generator['levels'], maxTier, label, problems);
  }

  final milestones = config['milestones'];
  if (milestones is! List<dynamic> ||
      milestones.isEmpty ||
      milestones.length > 40) {
    problems.add('$label: needs at least one milestone (at most 40)');
  } else {
    var last = 0;
    for (final m in milestones) {
      final points = m is Map<String, dynamic> ? m['points'] : null;
      final manna = m is Map<String, dynamic> ? m['manna'] ?? 0 : null;
      final talents = m is Map<String, dynamic> ? m['talents'] ?? 0 : null;
      if (points is! int || points <= last) {
        problems.add('$label: milestone points must keep rising from 1');
        break;
      }
      last = points;
      if (manna is! int || talents is! int || manna < 0 || talents < 0) {
        problems.add('$label: milestone at $points has a bad reward');
      } else if (manna == 0 && talents == 0) {
        problems.add('$label: milestone at $points gives nothing');
      } else if (manna > 500 || talents > 5000) {
        problems.add('$label: milestone at $points gives too much');
      }
    }
  }
  return problems;
}

void _checkLevels(
  Object? levels,
  int maxTier,
  String label,
  List<String> problems,
) {
  if (levels is! List<dynamic> || levels.isEmpty) {
    problems.add('$label: generator needs at least one level');
    return;
  }
  for (var i = 0; i < levels.length; i++) {
    final level = levels[i];
    final odds = level is Map<String, dynamic> ? level['odds'] : null;
    final number = level is Map<String, dynamic> ? level['level'] : null;
    if (level is! Map<String, dynamic> ||
        number is! int ||
        number != i + 1 ||
        odds is! Map<String, dynamic> ||
        odds.isEmpty) {
      problems.add('$label: generator level ${i + 1} is wrong');
      continue;
    }
    var total = 0.0;
    for (final entry in odds.entries) {
      final tier = int.tryParse(entry.key);
      final chance = entry.value;
      if (tier == null ||
          tier < 1 ||
          tier > maxTier ||
          chance is! num ||
          chance <= 0) {
        problems.add('$label: generator level ${i + 1} has bad odds');
        total = 1;
        break;
      }
      total += chance;
    }
    if ((total - 1).abs() > 0.001) {
      problems.add('$label: generator level ${i + 1} odds must add up to 1');
    }
  }
}

bool _shortText(Object? value) =>
    value is String && value.trim().isNotEmpty && value.length <= 40;

/// Art is optional; if named, it must be a picture inside the app's item
/// art folder (a picture the installed app does not have simply shows the
/// coloured placeholder).
bool _assetOk(Object? value) =>
    value == null ||
    (value is String &&
        value.length <= 120 &&
        (value.isEmpty ||
            RegExp(r'^assets/items/[A-Za-z0-9_.]+$').hasMatch(value)));
