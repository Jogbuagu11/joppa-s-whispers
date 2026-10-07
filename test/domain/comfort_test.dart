import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';

void main() {
  test('sound and vibration start on; tier numbers start off', () {
    const prefs = ComfortPrefs();
    expect(prefs.sound, isTrue);
    expect(prefs.haptics, isTrue);
    expect(prefs.tierNumbers, isFalse);
  });

  test('choices survive being saved and read back', () {
    const prefs = ComfortPrefs(sound: false, tierNumbers: true);
    final back = ComfortPrefs.fromJson(prefs.toJson());
    expect(back.sound, isFalse);
    expect(back.haptics, isTrue);
    expect(back.tierNumbers, isTrue);
  });

  test('missing or damaged choices fall back to the usual ones', () {
    final back = ComfortPrefs.fromJson({'sound': 'loud', 'haptics': false});
    expect(back.sound, isTrue);
    expect(back.haptics, isFalse);
    expect(back.tierNumbers, isFalse);
  });

  test('each switch changes only itself', () {
    final prefs = const ComfortPrefs().copyWith(haptics: false);
    expect(prefs.sound, isTrue);
    expect(prefs.haptics, isFalse);
    expect(prefs.tierNumbers, isFalse);
  });

  test('bigger moments vibrate more firmly', () {
    expect(hapticFor(GameCue.spawn), HapticStrength.light);
    expect(hapticFor(GameCue.empty), HapticStrength.light);
    expect(hapticFor(GameCue.merge), HapticStrength.medium);
    expect(hapticFor(GameCue.reward), HapticStrength.medium);
    expect(hapticFor(GameCue.deliver), HapticStrength.heavy);
    expect(hapticFor(GameCue.task), HapticStrength.heavy);
  });

  test('every cue has its sound file in assets/audio', () {
    for (final cue in GameCue.values) {
      final file = File('assets/audio/${soundFileFor(cue)}');
      expect(file.existsSync(), isTrue, reason: file.path);
      // A real .wav, not an empty stand-in.
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(bytes.length, greaterThan(1000));
    }
  });

  test('text may grow, but not past what the screens have room for', () {
    expect(maxTextScale, greaterThan(1.0));
    expect(maxTextScale, lessThanOrEqualTo(1.5));
  });
}
