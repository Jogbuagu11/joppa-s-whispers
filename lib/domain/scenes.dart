// Story scenes (dialogue) — pure Dart, fully unit tested.

/// One speech bubble.
class SceneLine {
  final String speaker; // character id
  final String expression;
  final String text;

  const SceneLine({
    required this.speaker,
    required this.expression,
    required this.text,
  });
}

/// A dialogue scene, loaded from content/scenes.json.
class SceneModel {
  final String id;
  final String background;
  final List<SceneLine> lines;

  const SceneModel({
    required this.id,
    required this.background,
    required this.lines,
  });

  factory SceneModel.fromJson(Map<String, dynamic> json) => SceneModel(
    id: json['id'] as String,
    background: json['background'] as String,
    lines: [
      for (final l in json['lines'] as List<dynamic>)
        SceneLine(
          speaker: (l as Map<String, dynamic>)['speaker'] as String,
          expression: l['expression'] as String,
          text: l['text'] as String,
        ),
    ],
  );
}

/// Where the player is in a scene. Immutable: [next] returns a new position.
class ScenePosition {
  final SceneModel scene;
  final int index;

  const ScenePosition(this.scene, [this.index = 0]);

  /// The line on screen, or null for a scene with no lines.
  SceneLine? get line => index < scene.lines.length ? scene.lines[index] : null;

  bool get isLastLine => index >= scene.lines.length - 1;

  /// The next line, or null when the scene is over.
  ScenePosition? next() => isLastLine ? null : ScenePosition(scene, index + 1);
}

/// Which portrait file to show for [characterId] with [expression]: the exact
/// one if it exists in [availableAssets], otherwise the character's neutral
/// portrait, otherwise null (the screen then shows the name only).
String? portraitAssetFor(
  String characterId,
  String expression,
  Set<String> availableAssets,
) {
  for (final wanted in [expression, 'neutral']) {
    for (final ext in const ['png', 'jpg']) {
      final path = 'assets/characters/char_${characterId}_$wanted.$ext';
      if (availableAssets.contains(path)) return path;
    }
  }
  return null;
}
