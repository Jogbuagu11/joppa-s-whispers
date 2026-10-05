// Checks content/scenes.json. Pure Dart.

final _sceneId = RegExp(r'^[a-z][a-z0-9_]*$');
final _background = RegExp(r'^loc_[a-z0-9_]+$');
const _maxTextLength = 140;

/// Adds a plain-English line to [problems] for every mistake found.
void checkScenes({
  required List<Map<String, dynamic>> scenes,
  required List<Map<String, dynamic>> characters,
  required List<String> problems,
}) {
  // character id -> the expressions it may use
  final expressions = <String, Set<String>>{
    for (final c in characters)
      if (c['id'] is String)
        c['id'] as String: {
          for (final e in (c['expressions'] as List<dynamic>? ?? const []))
            if (e is String) e,
        },
  };

  final ids = <String>{};
  for (final scene in scenes) {
    final id = scene['id'];
    if (id is! String || !_sceneId.hasMatch(id)) {
      problems.add('Scene id "$id" must be lowercase snake_case');
    } else if (!ids.add(id)) {
      problems.add('Scene id "$id" is used more than once');
    }
    final background = scene['background'];
    if (background is! String || !_background.hasMatch(background)) {
      problems.add('Scene $id: background must look like loc_some_place');
    }
    final lines = (scene['lines'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (lines.isEmpty) problems.add('Scene $id: has no lines');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final where = 'Scene $id line ${i + 1}';
      final speaker = line['speaker'];
      final allowed = expressions[speaker];
      if (allowed == null) {
        problems.add('$where: unknown character "$speaker"');
      } else if (!allowed.contains(line['expression'])) {
        problems.add(
          '$where: $speaker has no "${line['expression']}" expression',
        );
      }
      final text = line['text'];
      if (text is! String || text.trim().isEmpty) {
        problems.add('$where: missing text');
      } else if (text.length > _maxTextLength) {
        problems.add('$where: text is over $_maxTextLength characters');
      }
    }
  }
}
