// Walks the player through the first-session tutorial, one hint at a time.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';

class TutorialController extends ChangeNotifier {
  final List<TutorialStep> steps;

  /// Ids of delivered orders and finished tasks, read when a step ends so
  /// hints for things already done are skipped.
  final Set<String> Function() completedOrders;
  final Set<String> Function() completedTasks;

  /// How many free generator taps the tutorial gives in total.
  final int freeTapsAllowed;

  int _index;
  int _freeTapsUsed;

  TutorialController({
    required this.steps,
    required this.completedOrders,
    required this.completedTasks,
    required this.freeTapsAllowed,
    int startIndex = 0,
    int freeTapsAlreadyUsed = 0,
  }) : _freeTapsUsed = freeTapsAlreadyUsed,
       _index = nextTutorialIndex(
         steps,
         startIndex,
         completedOrders: completedOrders(),
         completedTasks: completedTasks(),
       );

  /// Which step is showing (written to the save file); steps.length when over.
  int get index => _index;

  /// The hint on screen, or null once the tutorial is finished.
  TutorialStep? get current => _index < steps.length ? steps[_index] : null;

  bool get isOver => current == null;

  /// Free taps used so far (written to the save file).
  int get freeTapsUsed => _freeTapsUsed;

  /// Generator taps cost nothing on the early tutorial steps, up to a fixed
  /// number of taps in total.
  bool get freeManna => tutorialTapIsFree(
    current,
    freeTapsUsed: _freeTapsUsed,
    freeTapsAllowed: freeTapsAllowed,
  );

  /// Call after a generator tap that cost nothing.
  void noteFreeTap() {
    _freeTapsUsed++;
    notifyListeners();
  }

  /// Tell the tutorial what the player just did.
  void handle(TutorialEvent event) {
    final next = advanceTutorial(
      steps,
      _index,
      event,
      completedOrders: completedOrders(),
      completedTasks: completedTasks(),
    );
    if (next == _index) return;
    _index = next;
    notifyListeners();
  }
}
