// Chapters and story tasks — pure Dart, fully unit tested.

/// One story task: costs Blessings, plays a scene, may restore an area and
/// reveal a letter.
class TaskModel {
  final String id;
  final int beat;
  final String title;
  final int costBlessings;
  final String? sceneId;
  final String? restoresArea;
  final String? letterId;

  const TaskModel({
    required this.id,
    required this.beat,
    required this.title,
    required this.costBlessings,
    this.sceneId,
    this.restoresArea,
    this.letterId,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'] as String,
    beat: json['beat'] as int,
    title: json['title'] as String,
    costBlessings: json['cost_blessings'] as int,
    sceneId: json['scene_id'] as String?,
    restoresArea: json['restores_area'] as String?,
    letterId: json['letter_id'] as String?,
  );
}

/// A chapter and its tasks in story order, from content/chapters.json.
class ChapterModel {
  final String id;
  final int number;
  final String title;
  final String locationId;
  final List<TaskModel> tasks;

  const ChapterModel({
    required this.id,
    required this.number,
    required this.title,
    required this.locationId,
    required this.tasks,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) => ChapterModel(
    id: json['id'] as String,
    number: json['number'] as int,
    title: json['title'] as String,
    locationId: json['location_id'] as String,
    tasks: [
      for (final t in json['tasks'] as List<dynamic>)
        TaskModel.fromJson(t as Map<String, dynamic>),
    ],
  );
}

/// The next task to do in [chapter], or null when every task is done.
/// Tasks are done strictly in story order.
TaskModel? nextTask(ChapterModel chapter, Set<String> completedTaskIds) {
  for (final task in chapter.tasks) {
    if (!completedTaskIds.contains(task.id)) return task;
  }
  return null;
}

/// Whether [blessings] is enough to pay for [task].
bool canAffordTask(TaskModel task, int blessings) =>
    blessings >= task.costBlessings;

bool isChapterComplete(ChapterModel chapter, Set<String> completedTaskIds) =>
    nextTask(chapter, completedTaskIds) == null;

/// The number of the chapter the story has reached: the first one with a
/// task still to do, or the last chapter when everything is done. 1 if there
/// are no chapters.
int chapterReached(List<ChapterModel> chapters, Set<String> completedTaskIds) {
  for (final chapter in chapters) {
    if (!isChapterComplete(chapter, completedTaskIds)) return chapter.number;
  }
  return chapters.isEmpty ? 1 : chapters.last.number;
}

/// How many of [chapter]'s tasks are done.
int tasksDone(ChapterModel chapter, Set<String> completedTaskIds) =>
    chapter.tasks.where((t) => completedTaskIds.contains(t.id)).length;

/// Area ids restored so far in [chapter] (used by the location screen).
Set<String> restoredAreas(ChapterModel chapter, Set<String> completedTaskIds) =>
    {
      for (final task in chapter.tasks)
        if (completedTaskIds.contains(task.id)) ?task.restoresArea,
    };

/// Letter ids found so far in [chapter], in the order they were found.
List<String> lettersFound(ChapterModel chapter, Set<String> completedTaskIds) =>
    [
      for (final task in chapter.tasks)
        if (completedTaskIds.contains(task.id)) ?task.letterId,
    ];

/// The message shown when a chapter's last task is done, from
/// content/endings.json.
class ChapterEnding {
  final String chapterId;
  final String title;
  final String body;
  final String button;

  const ChapterEnding({
    required this.chapterId,
    required this.title,
    required this.body,
    required this.button,
  });

  factory ChapterEnding.fromJson(Map<String, dynamic> json) => ChapterEnding(
    chapterId: json['chapter_id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    button: json['button'] as String,
  );
}
