// Stand-ins for the phone's speaker and vibration, and the saved choices.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/comfort_prefs_repository.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/features/settings/comfort_controller.dart';
import 'package:whispers_of_joppa/services/feedback_player.dart';

class FakeFeedbackPlayer implements FeedbackPlayer {
  final List<GameCue> sounds = [];
  final List<HapticStrength> haptics = [];
  int prepared = 0;

  @override
  Future<void> prepare() async => prepared++;

  @override
  void sound(GameCue cue) => sounds.add(cue);

  @override
  void haptic(HapticStrength strength) => haptics.add(strength);
}

/// A controller that plays into [player] and keeps its choices in a
/// throwaway folder.
ComfortController fakeComfort(FakeFeedbackPlayer player, {Directory? folder}) {
  final dir = folder ?? Directory.systemTemp.createTempSync('comfort_test');
  return ComfortController(
    player: player,
    repository: ComfortPrefsRepository(directory: () async => dir),
  );
}

/// Makes this test's phone ask for the largest text the game allows.
void useLargestText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = maxTextScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
