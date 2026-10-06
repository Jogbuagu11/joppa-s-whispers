// Tracks which story tasks are done and spends Blessings on the next one.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/progression.dart';

class StoryController extends ChangeNotifier {
  final List<ChapterModel> chapters;

  /// How many Blessings the player has right now.
  final int Function() blessings;

  /// Takes Blessings from the player; false (taking nothing) if they are short.
  final bool Function(int amount) spendBlessings;

  /// Fires when the Blessings count changes, so the task button can refresh.
  final Listenable wallet;

  final Set<String> _completed;

  /// Called with the task id each time a task is done.
  void Function(String taskId)? onTaskDone;

  StoryController({
    required this.chapters,
    required this.blessings,
    required this.spendBlessings,
    required this.wallet,
    Iterable<String> completedTasks = const [],
  }) : _completed = {...completedTasks} {
    wallet.addListener(notifyListeners);
  }

  /// Ids of finished tasks (written to the save file).
  List<String> get completedTasks => _completed.toList();

  /// The chapter being played: the first one with a task left, or the last
  /// chapter when everything is finished. Null only if there are no chapters.
  ChapterModel? get chapter {
    for (final c in chapters) {
      if (!isChapterComplete(c, _completed)) return c;
    }
    return chapters.isEmpty ? null : chapters.last;
  }

  /// Ids of every area restored so far, across all chapters.
  Set<String> get restoredAreaIds => {
    for (final c in chapters) ...restoredAreas(c, _completed),
  };

  /// Ids of every letter found so far, across all chapters.
  Set<String> get foundLetterIds => {
    for (final c in chapters) ...lettersFound(c, _completed),
  };

  TaskModel? get next {
    final current = chapter;
    return current == null ? null : nextTask(current, _completed);
  }

  int get doneInChapter {
    final current = chapter;
    return current == null ? 0 : tasksDone(current, _completed);
  }

  bool get canDoNext {
    final task = next;
    return task != null && canAffordTask(task, blessings());
  }

  /// Pays for the next task and marks it done. Returns the task so its scene
  /// can be played, or null (changing nothing) if it cannot be afforded.
  TaskModel? doNext() {
    final task = next;
    if (task == null || !spendBlessings(task.costBlessings)) return null;
    _completed.add(task.id);
    notifyListeners();
    onTaskDone?.call(task.id);
    return task;
  }

  @override
  void dispose() {
    wallet.removeListener(notifyListeners);
    super.dispose();
  }
}
