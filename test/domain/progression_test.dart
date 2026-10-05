import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/progression.dart';

void main() {
  final chapter = ChapterModel.fromJson({
    'id': 'ch1',
    'number': 1,
    'title': 'Homecoming',
    'location_id': 'bakehouse',
    'tasks': [
      {
        'id': 't1',
        'beat': 2,
        'title': 'Clear the doorway',
        'cost_blessings': 1,
        'scene_id': 's2',
        'restores_area': 'door',
        'letter_id': null,
      },
      {
        'id': 't2',
        'beat': 3,
        'title': 'Search the oven niche',
        'cost_blessings': 2,
        'scene_id': 's3',
        'restores_area': null,
        'letter_id': 'letter_01',
      },
      {
        'id': 't3',
        'beat': 4,
        'title': 'Relight the oven',
        'cost_blessings': 2,
        'scene_id': null,
        'restores_area': 'oven',
        'letter_id': null,
      },
    ],
  });

  test('fromJson reads the chapter and its tasks', () {
    expect(chapter.id, 'ch1');
    expect(chapter.number, 1);
    expect(chapter.title, 'Homecoming');
    expect(chapter.locationId, 'bakehouse');
    expect(chapter.tasks.length, 3);
    final t = chapter.tasks[1];
    expect(t.id, 't2');
    expect(t.beat, 3);
    expect(t.title, 'Search the oven niche');
    expect(t.costBlessings, 2);
    expect(t.sceneId, 's3');
    expect(t.restoresArea, isNull);
    expect(t.letterId, 'letter_01');
  });

  group('nextTask', () {
    test('is the first task on a new game', () {
      expect(nextTask(chapter, {})?.id, 't1');
    });
    test('moves on as tasks are completed', () {
      expect(nextTask(chapter, {'t1'})?.id, 't2');
      expect(nextTask(chapter, {'t1', 't2'})?.id, 't3');
    });
    test('never skips an earlier task', () {
      expect(nextTask(chapter, {'t2', 't3'})?.id, 't1');
    });
    test('is null when the chapter is finished', () {
      expect(nextTask(chapter, {'t1', 't2', 't3'}), isNull);
    });
  });

  test('canAffordTask compares Blessings with the cost', () {
    final t2 = chapter.tasks[1];
    expect(canAffordTask(t2, 1), isFalse);
    expect(canAffordTask(t2, 2), isTrue);
    expect(canAffordTask(t2, 5), isTrue);
  });

  test('isChapterComplete and tasksDone', () {
    expect(isChapterComplete(chapter, {'t1'}), isFalse);
    expect(isChapterComplete(chapter, {'t1', 't2', 't3'}), isTrue);
    expect(tasksDone(chapter, {}), 0);
    expect(tasksDone(chapter, {'t1', 't3', 'unknown'}), 2);
  });

  test('restoredAreas lists areas of completed tasks only', () {
    expect(restoredAreas(chapter, {}), isEmpty);
    expect(restoredAreas(chapter, {'t1', 't2'}), {'door'});
    expect(restoredAreas(chapter, {'t1', 't2', 't3'}), {'door', 'oven'});
  });

  test('lettersFound lists letters of completed tasks in order', () {
    expect(lettersFound(chapter, {'t1'}), isEmpty);
    expect(lettersFound(chapter, {'t1', 't2'}), ['letter_01']);
  });

  test('ChapterEnding.fromJson reads every field', () {
    final e = ChapterEnding.fromJson({
      'chapter_id': 'ch1',
      'title': 'Chapter 1 Complete',
      'body': 'More soon.',
      'button': 'Keep baking',
    });
    expect(e.chapterId, 'ch1');
    expect(e.title, 'Chapter 1 Complete');
    expect(e.body, 'More soon.');
    expect(e.button, 'Keep baking');
  });
}
