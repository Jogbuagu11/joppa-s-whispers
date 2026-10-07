// Plays the game's small sounds and vibrations. The real one is
// DeviceFeedbackPlayer; tests use a stand-in.
import 'package:whispers_of_joppa/domain/comfort.dart';

abstract class FeedbackPlayer {
  /// Gets the sounds ready. Safe to call more than once.
  Future<void> prepare();

  void sound(GameCue cue);

  void haptic(HapticStrength strength);
}
