// Walks the player through the first-session tutorial, one hint at a time.
import 'package:flutter/foundation.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';

class TutorialController extends ChangeNotifier {
  final List<TutorialStep> steps;

  /// Ids of delivered orders and finished tasks, read when a step ends so
  /// hints for things already done are skipped.
  final Set<String> Function() completedOrders;
  final Set<String> Function() completedTasks;

  int _index;

  TutorialController({
    required this.steps,
    required this.completedOrders,
    required this.completedTasks,
    int startIndex = 0,
  }) : _index = nextTutorialIndex(
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

  /// Generator taps cost nothing while an early tutorial step is showing.
  bool get freeManna => current?.freeManna ?? false;

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
