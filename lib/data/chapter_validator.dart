// Checks content/chapters.json, locations.json and letters.json. Pure Dart.

final _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');
const _maxTaskTitle = 32;

/// Adds a plain-English line to [problems] for every mistake found.
void checkChapters({
  required List<Map<String, dynamic>> chapters,
  required List<Map<String, dynamic>> locations,
  required List<Map<String, dynamic>> letters,
  required Set<String> sceneIds,
  required Set<String> chainIds,
  required List<Map<String, dynamic>> orders,
  required List<String> problems,
}) {
  void checkId(String kind, Object? id, Set<String> seen) {
    if (id is! String || !_idPattern.hasMatch(id)) {
      problems.add('$kind id "$id" must be lowercase snake_case');
    } else if (!seen.add(id)) {
      problems.add('$kind id "$id" is used more than once');
    }
  }

  // location id -> its area ids
  final areasByLocation = <String, Set<String>>{};
  final locationIds = <String>{};
  final areaIds = <String>{};
  for (final location in locations) {
    checkId('Location', location['id'], locationIds);
    final areas = <String>{};
    for (final a in location['areas'] as List<dynamic>) {
      final area = a as Map<String, dynamic>;
      checkId('Area', area['id'], areaIds);
      if (area['id'] is String) areas.add(area['id'] as String);
      for (final key in ['name', 'before', 'after']) {
        final value = area[key];
        if (value is! String || value.trim().isEmpty) {
          problems.add('Area ${area['id']}: missing $key');
        }
      }
    }
    if (location['id'] is String) {
      areasByLocation[location['id'] as String] = areas;
    }
  }

  final letterIds = <String>{};
  for (final letter in letters) {
    checkId('Letter', letter['id'], letterIds);
    for (final key in ['title', 'body', 'reference']) {
      final value = letter[key];
      if (value is! String || value.trim().isEmpty) {
        problems.add('Letter ${letter['id']}: missing $key');
      }
    }
  }

  final chapterIds = <String>{};
  final taskIds = <String>{};
  final usedScenes = <String>{};
  final usedAreas = <String>{};
  for (final chapter in chapters) {
    final id = chapter['id'];
    checkId('Chapter', id, chapterIds);
    final number = chapter['number'];
    final areas = areasByLocation[chapter['location_id']];
    if (areas == null) {
      problems.add('Chapter $id: unknown location "${chapter['location_id']}"');
    }
    for (final chain in chapter['unlocks_chains'] as List<dynamic>) {
      if (!chainIds.contains(chain)) {
        problems.add('Chapter $id: unknown chain "$chain"');
      }
    }

    var cost = 0;
    for (final t in chapter['tasks'] as List<dynamic>) {
      final task = t as Map<String, dynamic>;
      final taskId = task['id'];
      checkId('Task', taskId, taskIds);
      final title = task['title'];
      if (title is! String || title.trim().isEmpty) {
        problems.add('Task $taskId: missing title');
      } else if (title.length > _maxTaskTitle) {
        problems.add('Task $taskId: title is over $_maxTaskTitle characters');
      }
      final taskCost = task['cost_blessings'];
      if (taskCost is! int || taskCost < 1) {
        problems.add('Task $taskId: cost_blessings must be 1 or more');
      } else {
        cost += taskCost;
      }
      final scene = task['scene_id'];
      if (scene != null) {
        if (!sceneIds.contains(scene)) {
          problems.add('Task $taskId: unknown scene "$scene"');
        } else if (!usedScenes.add(scene as String)) {
          problems.add('Task $taskId: scene "$scene" is used by another task');
        }
      }
      final area = task['restores_area'];
      if (area != null) {
        if (areas != null && !areas.contains(area)) {
          problems.add('Task $taskId: area "$area" is not in this location');
        } else if (!usedAreas.add(area as String)) {
          problems.add('Task $taskId: area "$area" is restored twice');
        }
      }
      final letter = task['letter_id'];
      if (letter != null && !letterIds.contains(letter)) {
        problems.add('Task $taskId: unknown letter "$letter"');
      }
    }

    // The chapter must be finishable with the Blessings its orders pay.
    var earnable = 0;
    for (final order in orders) {
      if (order['chapter'] != number) continue;
      final blessings = (order['rewards'] as Map<String, dynamic>)['blessings'];
      if (blessings is int) earnable += blessings;
    }
    if (cost > earnable) {
      problems.add(
        'Chapter $id: tasks cost $cost Blessings but its orders only pay '
        '$earnable',
      );
    }
  }
}
