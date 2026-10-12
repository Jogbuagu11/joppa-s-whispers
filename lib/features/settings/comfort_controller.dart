// The player's sound, vibration and tier-number choices, and the one place
// the game asks for a sound or a vibration.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/data/comfort_prefs_repository.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/services/feedback_player.dart';

class ComfortController extends ChangeNotifier {
  final FeedbackPlayer player;
  final ComfortPrefsRepository repository;

  ComfortPrefs _prefs = const ComfortPrefs();
  Future<void>? _loading;
  bool _hushed = false;

  ComfortController({required this.player, required this.repository});

  ComfortPrefs get prefs => _prefs;

  /// Reads the saved choices and gets the sounds ready. Safe to call more
  /// than once.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    _prefs = await repository.load();
    notifyListeners();
    await player.prepare();
    _tune();
  }

  /// Something else needs the speaker (an ad is showing): the tune waits
  /// until it is done.
  void hush(bool on) {
    _hushed = on;
    _tune();
  }

  void _tune() => player.music(_prefs.music && !_hushed);

  /// Something happened: play its sound and vibration, unless turned off.
  void cue(GameCue cue) {
    if (_prefs.sound) player.sound(cue);
    if (_prefs.haptics) player.haptic(hapticFor(cue));
  }

  Future<void> setSound(bool on) async {
    await _set(_prefs.copyWith(sound: on));
    // Lets the player hear (or not hear) what they just chose.
    if (on) player.sound(GameCue.merge);
  }

  Future<void> setMusic(bool on) async {
    await _set(_prefs.copyWith(music: on));
    _tune();
  }

  Future<void> setHaptics(bool on) async {
    await _set(_prefs.copyWith(haptics: on));
    if (on) player.haptic(HapticStrength.medium);
  }

  Future<void> setTierNumbers(bool on) =>
      _set(_prefs.copyWith(tierNumbers: on));

  Future<void> _set(ComfortPrefs prefs) async {
    _prefs = prefs;
    notifyListeners();
    await repository.save(prefs);
  }
}
