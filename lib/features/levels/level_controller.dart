// The player's level: worked out from the story tasks done, with a record
// of the last level whose rewards were handed over.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';

class LevelController extends ChangeNotifier {
  final LevelsConfig config;
  final StoryController story;

  /// Gives the player Talents.
  final void Function(int amount) addTalents;

  /// Fills the Manna bar.
  final VoidCallback refillManna;

  int _rewarded;

  /// [rewardedLevel] comes from the save; 0 means "not recorded yet" (a new
  /// game, or a game saved before levels existed): such a game starts at
  /// its present level with nothing owed.
  /// A null [config] (content from before levels existed) keeps everyone
  /// at level 1.
  LevelController({
    required LevelsConfig? config,
    required this.story,
    required this.addTalents,
    required this.refillManna,
    int rewardedLevel = 0,
  }) : config = config ?? noLevels,
       _rewarded = rewardedLevel {
    // A record from the save is never lowered here, even if this content
    // has fewer levels: lowering it would pay those levels a second time
    // when fuller content returns.
    if (_rewarded < 1) _rewarded = level;
    story.addListener(notifyListeners);
  }

  int get xp => xpEarned(config, story.chapters, story.completedTasks.toSet());

  int get level => config.levelAt(xp);

  /// XP into the present level and the XP that level takes (0 and 0 at the
  /// highest level).
  ({int into, int needed}) get progress => config.progress(xp);

  /// The last level whose rewards were given (written to the save file).
  int get rewardedLevel => _rewarded;

  bool isUnlocked(String feature) => config.isUnlocked(feature, level);

  /// Hands over the rewards for any level gained since the last time: the
  /// Talents and a full Manna bar. Returns what was given, to show the
  /// player, or null if nothing was owed.
  LevelUp? collect() {
    final owed = levelUpOwed(config, rewarded: _rewarded, current: level);
    if (owed == null) return null;
    // Recorded before it is handed over, so it can never be paid twice.
    _rewarded = owed.to;
    if (owed.talents > 0) addTalents(owed.talents);
    refillManna();
    notifyListeners();
    return owed;
  }

  @override
  void dispose() {
    story.removeListener(notifyListeners);
    super.dispose();
  }
}
