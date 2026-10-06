import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/features/story/endings_tracker.dart';

ChapterModel _chapter(String id, int number) => ChapterModel(
  id: id,
  number: number,
  title: id,
  locationId: 'bakehouse',
  tasks: [TaskModel(id: '${id}_t1', beat: 1, title: 'T', costBlessings: 1)],
);

ChapterEnding _ending(String id) =>
    ChapterEnding(chapterId: id, title: 'Done $id', body: 'B', button: 'OK');

void main() {
  final chapters = [_chapter('ch1', 1), _chapter('ch2', 2)];

  EndingsTracker make({List<String> seen = const []}) => EndingsTracker(
    endings: {'ch1': _ending('ch1'), 'ch2': _ending('ch2')},
    seen: seen,
  );

  test('nothing is pending while no chapter is finished', () {
    expect(make().pending(chapters, {}), isNull);
  });

  test('a finished chapter\'s ending is pending until seen', () {
    final t = make();
    expect(t.pending(chapters, {'ch1_t1'})?.chapterId, 'ch1');
    var notified = 0;
    t.addListener(() => notified++);
    t.markSeen('ch1');
    expect(t.pending(chapters, {'ch1_t1'}), isNull);
    expect(t.seen, ['ch1']);
    expect(notified, 1);
    // Marking it again changes nothing.
    t.markSeen('ch1');
    expect(notified, 1);
  });

  test('a seen ending restored from a save is not shown again', () {
    final t = make(seen: ['ch1']);
    expect(t.pending(chapters, {'ch1_t1'}), isNull);
    expect(t.pending(chapters, {'ch1_t1', 'ch2_t1'})?.chapterId, 'ch2');
  });

  test('a chapter with no ending in content has nothing to show', () {
    final t = EndingsTracker(endings: const {});
    expect(t.pending(chapters, {'ch1_t1'}), isNull);
  });
}
