import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/replay.dart';

TaskModel _task(String id, String? scene) => TaskModel(
  id: id,
  beat: 1,
  title: 'Task $id',
  costBlessings: 1,
  sceneId: scene,
  restoresArea: null,
  letterId: null,
);

void main() {
  final chapters = [
    ChapterModel(
      id: 'ch1',
      number: 1,
      title: 'One',
      locationId: 'l',
      tasks: [_task('a', 's1'), _task('b', null), _task('c', 's3')],
    ),
    ChapterModel(
      id: 'ch2',
      number: 2,
      title: 'Two',
      locationId: 'l',
      tasks: [_task('d', 's4'), _task('e', 'gone')],
    ),
  ];
  const all = {'s1', 's3', 's4'};

  test('nothing done, nothing to replay', () {
    expect(replayScenes(chapters, const {}, all), isEmpty);
  });

  test('only the scenes of finished tasks, in story order', () {
    final scenes = replayScenes(chapters, const {'d', 'a', 'b'}, all);
    expect(scenes.map((s) => s.sceneId), ['s1', 's4']);
    expect(scenes.first.chapter, 'One');
    expect(scenes.first.title, 'Task a');
    expect(scenes.last.chapter, 'Two');
  });

  test('a task whose scene is missing is left out', () {
    expect(replayScenes(chapters, const {'e', 'c'}, all).single.sceneId, 's3');
  });
}
