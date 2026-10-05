// The first-session tutorial — pure Dart, fully unit tested.

/// What the player has to do to finish a tutorial step.
enum TutorialTrigger { merge, generatorTap, orderDelivered, taskDone, tap }

const _triggerNames = {
  'merge': TutorialTrigger.merge,
  'generator_tap': TutorialTrigger.generatorTap,
  'order_delivered': TutorialTrigger.orderDelivered,
  'task_done': TutorialTrigger.taskDone,
  'tap': TutorialTrigger.tap,
};

/// The trigger for a name used in content/tutorial.json, or null if unknown.
TutorialTrigger? tutorialTriggerFromName(String? name) => _triggerNames[name];

/// One hint, loaded from content/tutorial.json.
class TutorialStep {
  final String id;
  final String speaker; // character id
  final String text;
  final TutorialTrigger trigger;

  /// The order or task this step waits for, when the trigger needs one.
  final String? targetId;

  /// Whether generator taps are free while this step is showing.
  final bool freeManna;

  const TutorialStep({
    required this.id,
    required this.speaker,
    required this.text,
    required this.trigger,
    this.targetId,
    this.freeManna = false,
  });

  /// Throws [FormatException] for a trigger type the game does not know.
  factory TutorialStep.fromJson(Map<String, dynamic> json) {
    final doneWhen = json['done_when'] as Map<String, dynamic>;
    final trigger = tutorialTriggerFromName(doneWhen['type'] as String?);
    if (trigger == null) {
      throw FormatException('Unknown tutorial trigger "${doneWhen['type']}"');
    }
    return TutorialStep(
      id: json['id'] as String,
      speaker: json['speaker'] as String,
      text: json['text'] as String,
      trigger: trigger,
      targetId: doneWhen['id'] as String?,
      freeManna: json['free_manna'] as bool? ?? false,
    );
  }
}

/// Something the player just did.
class TutorialEvent {
  final TutorialTrigger trigger;

  /// The order or task involved, if any.
  final String? id;

  const TutorialEvent(this.trigger, [this.id]);
}

/// Whether [event] is what [step] is waiting for.
bool tutorialStepSatisfiedBy(TutorialStep step, TutorialEvent event) =>
    step.trigger == event.trigger &&
    (step.targetId == null || step.targetId == event.id);

/// Whether [step] is already done according to saved progress, so it should
/// not be shown (the player delivered that order or did that task earlier).
bool tutorialStepAlreadyDone(
  TutorialStep step, {
  required Set<String> completedOrders,
  required Set<String> completedTasks,
}) => switch (step.trigger) {
  TutorialTrigger.orderDelivered => completedOrders.contains(step.targetId),
  TutorialTrigger.taskDone => completedTasks.contains(step.targetId),
  _ => false,
};

/// The step to show from [index] on, skipping any already done. Returns
/// steps.length when the tutorial is over.
int nextTutorialIndex(
  List<TutorialStep> steps,
  int index, {
  required Set<String> completedOrders,
  required Set<String> completedTasks,
}) {
  var i = index < 0 ? 0 : index;
  while (i < steps.length &&
      tutorialStepAlreadyDone(
        steps[i],
        completedOrders: completedOrders,
        completedTasks: completedTasks,
      )) {
    i++;
  }
  return i > steps.length ? steps.length : i;
}

/// The index after [event]: one further if it finishes the current step
/// (then past any steps already done), otherwise unchanged.
int advanceTutorial(
  List<TutorialStep> steps,
  int index,
  TutorialEvent event, {
  required Set<String> completedOrders,
  required Set<String> completedTasks,
}) {
  if (index < 0 || index >= steps.length) return steps.length;
  if (!tutorialStepSatisfiedBy(steps[index], event)) return index;
  return nextTutorialIndex(
    steps,
    index + 1,
    completedOrders: completedOrders,
    completedTasks: completedTasks,
  );
}

/// Whether generator taps are free right now: only on a step marked
/// free_manna, and only until [freeTapsAllowed] free taps have been used, so
/// lingering on an early step can never give unlimited free Manna.
bool tutorialTapIsFree(
  TutorialStep? step, {
  required int freeTapsUsed,
  required int freeTapsAllowed,
}) => step != null && step.freeManna && freeTapsUsed < freeTapsAllowed;
