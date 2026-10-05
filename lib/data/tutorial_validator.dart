// Checks content/tutorial.json and content/endings.json. Pure Dart.
import 'package:whispers_of_joppa/domain/tutorial.dart';

final _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');
const _maxHint = 120;
const _maxEndingTitle = 30;
const _maxEndingBody = 200;
const _maxEndingButton = 16;

/// Adds a plain-English line to [problems] for every mistake found.
void checkTutorialAndEndings({
  required List<Map<String, dynamic>> tutorial,
  required List<Map<String, dynamic>> endings,
  required Set<String> characterIds,
  required Set<String> orderIds,
  required Set<String> taskIds,
  required Set<String> chapterIds,
  required List<String> problems,
}) {
  final stepIds = <String>{};
  for (final step in tutorial) {
    final id = step['id'];
    if (id is! String || !_idPattern.hasMatch(id)) {
      problems.add('Tutorial step id "$id" must be lowercase snake_case');
    } else if (!stepIds.add(id)) {
      problems.add('Tutorial step id "$id" is used more than once');
    }
    if (!characterIds.contains(step['speaker'])) {
      problems.add('Tutorial $id: unknown character "${step['speaker']}"');
    }
    final text = step['text'];
    if (text is! String || text.trim().isEmpty) {
      problems.add('Tutorial $id: missing text');
    } else if (text.length > _maxHint) {
      problems.add('Tutorial $id: text is over $_maxHint characters');
    }
    final free = step['free_manna'];
    if (free != null && free is! bool) {
      problems.add('Tutorial $id: free_manna must be true or false');
    }

    final doneWhen = step['done_when'] as Map<String, dynamic>;
    final target = doneWhen['id'];
    switch (tutorialTriggerFromName(doneWhen['type'] as String?)) {
      case null:
        problems.add(
          'Tutorial $id: unknown done_when type "${doneWhen['type']}"',
        );
      case TutorialTrigger.orderDelivered:
        if (!orderIds.contains(target)) {
          problems.add('Tutorial $id: unknown order "$target"');
        }
      case TutorialTrigger.taskDone:
        if (!taskIds.contains(target)) {
          problems.add('Tutorial $id: unknown task "$target"');
        }
      case TutorialTrigger.merge ||
          TutorialTrigger.generatorTap ||
          TutorialTrigger.tap:
        if (target != null) {
          problems.add('Tutorial $id: this done_when type takes no id');
        }
    }
  }

  final seenChapters = <String>{};
  for (final ending in endings) {
    final chapter = ending['chapter_id'];
    if (!chapterIds.contains(chapter)) {
      problems.add('Ending: unknown chapter "$chapter"');
    } else if (!seenChapters.add(chapter as String)) {
      problems.add('Ending: chapter "$chapter" has two endings');
    }
    void checkText(String key, int max) {
      final value = ending[key];
      if (value is! String || value.trim().isEmpty) {
        problems.add('Ending for $chapter: missing $key');
      } else if (value.length > max) {
        problems.add('Ending for $chapter: $key is over $max characters');
      }
    }

    checkText('title', _maxEndingTitle);
    checkText('body', _maxEndingBody);
    checkText('button', _maxEndingButton);
  }
}
