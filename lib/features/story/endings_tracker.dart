// Remembers which chapters' closing messages the player has seen.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/progression.dart';

class EndingsTracker extends ChangeNotifier {
  /// chapter_id -> the message shown when that chapter is finished.
  final Map<String, ChapterEnding> endings;
  final Set<String> _seen;

  EndingsTracker({required this.endings, Iterable<String> seen = const []})
    : _seen = {...seen};

  /// Chapters whose closing message has been shown (written to the save).
  List<String> get seen => _seen.toList();

  /// The closing message of a finished chapter the player has not seen yet,
  /// or null. Covers the case where the app closed before it was shown.
  ChapterEnding? pending(List<ChapterModel> chapters, Set<String> doneTasks) {
    for (final chapter in chapters) {
      final ending = endings[chapter.id];
      if (ending != null &&
          isChapterComplete(chapter, doneTasks) &&
          !_seen.contains(chapter.id)) {
        return ending;
      }
    }
    return null;
  }

  /// Records that a chapter's closing message has been shown.
  void markSeen(String chapterId) {
    if (_seen.add(chapterId)) notifyListeners();
  }
}
