// The player's comfort choices (sound, vibration, tier numbers on items),
// and which small sound and vibration goes with each thing that happens.

/// Something in the game worth a small sound and a tap of vibration.
enum GameCue {
  /// A generator gave an item.
  spawn,

  /// Two items merged.
  merge,

  /// An order was delivered.
  deliver,

  /// A story task was done.
  task,

  /// A generator was tapped with no Manna left.
  empty,

  /// A bonus arrived (an ad's Manna, an event prize).
  reward,
}

enum HapticStrength { light, medium, heavy }

/// How firm the vibration for [cue] is: the bigger the moment, the firmer.
HapticStrength hapticFor(GameCue cue) => switch (cue) {
  GameCue.spawn || GameCue.empty => HapticStrength.light,
  GameCue.merge || GameCue.reward => HapticStrength.medium,
  GameCue.deliver || GameCue.task => HapticStrength.heavy,
};

/// The sound file for [cue], inside assets/audio/.
String soundFileFor(GameCue cue) => '${cue.name}.wav';

class ComfortPrefs {
  /// Sound effects.
  final bool sound;

  /// Vibration.
  final bool haptics;

  /// A small tier number on every item, for players who find the pictures
  /// or colours hard to tell apart.
  final bool tierNumbers;

  const ComfortPrefs({
    this.sound = true,
    this.haptics = true,
    this.tierNumbers = false,
  });

  /// Reads saved choices; anything missing or of the wrong kind keeps its
  /// usual setting.
  factory ComfortPrefs.fromJson(Map<String, dynamic> json) {
    const usual = ComfortPrefs();
    bool read(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    return ComfortPrefs(
      sound: read('sound', usual.sound),
      haptics: read('haptics', usual.haptics),
      tierNumbers: read('tierNumbers', usual.tierNumbers),
    );
  }

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'haptics': haptics,
    'tierNumbers': tierNumbers,
  };

  ComfortPrefs copyWith({bool? sound, bool? haptics, bool? tierNumbers}) =>
      ComfortPrefs(
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        tierNumbers: tierNumbers ?? this.tierNumbers,
      );
}

/// The most the phone's text-size setting may enlarge the game's words.
/// Beyond this the fixed bars around the board have no room left.
const double maxTextScale = 1.3;
