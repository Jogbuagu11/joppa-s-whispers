import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';

ChapterModel _chapter(String id, int number, List<int> costs) => ChapterModel(
  id: id,
  number: number,
  title: 'Chapter $number',
  locationId: 'bakehouse',
  tasks: [
    for (int i = 0; i < costs.length; i++)
      TaskModel(
        id: '${id}_t${i + 1}',
        beat: i + 1,
        title: 'Task ${i + 1}',
        costBlessings: costs[i],
        sceneId: '${id}_s${i + 1}',
        restoresArea: i == 0 ? '${id}_area' : null,
      ),
  ],
);

void main() {
  late int blessings;
  late ValueNotifier<int> wallet;
  late StoryController story;

  bool spend(int amount) {
    if (amount > blessings) return false;
    blessings -= amount;
    wallet.value++;
    return true;
  }

  StoryController make({Iterable<String> done = const []}) => StoryController(
    chapters: [
      _chapter('ch1', 1, [1, 2]),
      _chapter('ch2', 2, [3]),
    ],
    blessings: () => blessings,
    spendBlessings: spend,
    wallet: wallet,
    completedTasks: done,
  );

  setUp(() {
    blessings = 0;
    wallet = ValueNotifier<int>(0);
    story = make();
  });

  test('starts on the first task of the first chapter', () {
    expect(story.chapter?.id, 'ch1');
    expect(story.next?.id, 'ch1_t1');
    expect(story.doneInChapter, 0);
    expect(story.completedTasks, isEmpty);
  });

  test('a task cannot be done without enough Blessings', () {
    expect(story.canDoNext, isFalse);
    expect(story.doNext(), isNull);
    expect(story.completedTasks, isEmpty);
    expect(blessings, 0);
  });

  test('doing a task spends its cost and moves to the next one', () {
    blessings = 1;
    expect(story.canDoNext, isTrue);
    final task = story.doNext();
    expect(task?.id, 'ch1_t1');
    expect(task?.sceneId, 'ch1_s1');
    expect(blessings, 0);
    expect(story.completedTasks, ['ch1_t1']);
    expect(story.next?.id, 'ch1_t2');
    expect(story.doneInChapter, 1);
    expect(story.canDoNext, isFalse);
  });

  test('finishing a chapter moves on to the next chapter', () {
    blessings = 3;
    story
      ..doNext()
      ..doNext();
    expect(story.chapter?.id, 'ch2');
    expect(story.next?.id, 'ch2_t1');
    expect(story.doneInChapter, 0);
  });

  test('when everything is done there is no next task', () {
    blessings = 6;
    story
      ..doNext()
      ..doNext()
      ..doNext();
    expect(story.next, isNull);
    expect(story.chapter?.id, 'ch2');
    expect(story.canDoNext, isFalse);
    expect(story.doNext(), isNull);
    expect(blessings, 0);
  });

  test('restores saved progress', () {
    final restored = make(done: ['ch1_t1']);
    expect(restored.next?.id, 'ch1_t2');
    expect(restored.completedTasks, ['ch1_t1']);
  });

  test('listeners hear when Blessings change and when a task is done', () {
    var notified = 0;
    story.addListener(() => notified++);
    wallet.value++;
    expect(notified, 1);
    blessings = 1;
    story.doNext();
    expect(notified, greaterThanOrEqualTo(3));
  });

  test('stops listening to the wallet after dispose', () {
    var notified = 0;
    story.addListener(() => notified++);
    story.dispose();
    wallet.value++;
    expect(notified, 0);
  });

  test('with no chapters there is nothing to do', () {
    final empty = StoryController(
      chapters: const [],
      blessings: () => 5,
      spendBlessings: spend,
      wallet: wallet,
    );
    expect(empty.chapter, isNull);
    expect(empty.next, isNull);
    expect(empty.doNext(), isNull);
  });

  test('restoredAreaIds grows as restoring tasks are done', () {
    expect(story.restoredAreaIds, isEmpty);
    blessings = 6;
    story.doNext();
    expect(story.restoredAreaIds, {'ch1_area'});
    story
      ..doNext()
      ..doNext();
    expect(story.restoredAreaIds, {'ch1_area', 'ch2_area'});
  });

  test('onTaskDone is called with the task id, only when a task is done', () {
    final done = <String>[];
    story.onTaskDone = done.add;
    story.doNext();
    expect(done, isEmpty);
    blessings = 1;
    story.doNext();
    expect(done, ['ch1_t1']);
  });
}
