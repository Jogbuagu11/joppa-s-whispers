// The phone's speaker and vibration motor.
import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/services/feedback_player.dart';

final _log = Logger('DeviceFeedbackPlayer');

class DeviceFeedbackPlayer implements FeedbackPlayer {
  static const double _volume = 0.8;

  // The tune sits well under the chimes.
  static const double _musicVolume = 0.3;

  // Sound effects play over the player's own music instead of stopping it,
  // and on an iPhone they obey the silent switch.
  static final AudioContext _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  // A few ready players per sound, used again and again: nothing is
  // created (or left behind) each time a sound plays.
  final Map<GameCue, AudioPool> _pools = {};
  Future<void>? _preparing;
  bool _ready = false;

  /// True once the sounds are loaded and can be played.
  bool get ready => _ready;

  @override
  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    try {
      await AudioPlayer.global.setAudioContext(_context);
      for (final cue in GameCue.values) {
        _pools[cue] = await FlameAudio.createPool(
          soundFileFor(cue),
          maxPlayers: 3,
          audioContext: _context,
        );
      }
      _ready = true;
    } on Object catch (e) {
      // A game without sound is still a game.
      _log.warning('Sounds could not be loaded: $e');
    }
  }

  @override
  void sound(GameCue cue) {
    final pool = _pools[cue];
    if (!_ready || pool == null) return;
    unawaited(_play(cue, pool));
  }

  Future<void> _play(GameCue cue, AudioPool pool) async {
    try {
      await pool.start(volume: _volume);
    } on Object catch (e) {
      _log.warning('Sound ${cue.name} could not be played: $e');
    }
  }

  bool _musicOn = false;
  bool _musicLoaded = false;
  Future<void> _musicWork = Future.value();

  /// True once the tune has been loaded and started.
  bool get musicStarted => _musicLoaded;

  /// Done when every change asked of the tune has been made.
  Future<void> get musicSettled => _musicWork;

  // The tune loops, and stops by itself while the game is not on screen.
  @override
  void music(bool on) {
    if (on == _musicOn) return;
    _musicOn = on;
    // One change at a time, in the order they were asked for.
    _musicWork = _musicWork.then((_) => _setMusic(on));
  }

  Future<void> _setMusic(bool on) async {
    try {
      final bgm = FlameAudio.bgm;
      if (!on) {
        if (_musicLoaded) await bgm.pause();
      } else if (_musicLoaded) {
        await bgm.resume();
      } else {
        await bgm.initialize(audioContext: _context);
        await bgm.play(musicFile, volume: _musicVolume);
        _musicLoaded = true;
      }
    } on Object catch (e) {
      _log.warning('The tune could not be ${on ? 'played' : 'paused'}: $e');
    }
  }

  /// Stops every sound and lets the players go.
  Future<void> dispose() async {
    _ready = false;
    if (_musicLoaded) await FlameAudio.bgm.stop();
    _musicOn = false;
    final pools = _pools.values.toList();
    _pools.clear();
    for (final pool in pools) {
      await pool.dispose();
    }
  }

  @override
  void haptic(HapticStrength strength) {
    unawaited(switch (strength) {
      HapticStrength.light => HapticFeedback.lightImpact(),
      HapticStrength.medium => HapticFeedback.mediumImpact(),
      HapticStrength.heavy => HapticFeedback.heavyImpact(),
    });
  }
}
