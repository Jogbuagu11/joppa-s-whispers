// Story replay (EXPANSION section 24): every scene the player has seen can
// be played again from the keepsake book. Pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/progression.dart';

/// A scene that can be played again.
class ReplayScene {
  /// The chapter it belongs to ("Homecoming").
  final String chapter;

  /// The task that played it ("Clear the doorway").
  final String title;
  final String sceneId;

  const ReplayScene({
    required this.chapter,
    required this.title,
    required this.sceneId,
  });
}

/// The scenes of the tasks in [completed], in story order. A task with no
/// scene, or one whose scene is not among [sceneIds], is left out.
List<ReplayScene> replayScenes(
  List<ChapterModel> chapters,
  Set<String> completed,
  Set<String> sceneIds,
) => [
  for (final chapter in chapters)
    for (final task in chapter.tasks)
      if (task.sceneId case final String sceneId
          when completed.contains(task.id) && sceneIds.contains(sceneId))
        ReplayScene(
          chapter: chapter.title,
          title: task.title,
          sceneId: sceneId,
        ),
];
