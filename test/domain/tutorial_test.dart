import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';

void main() {
  final steps = [
    for (final json in [
      {
        'id': 'tut_merge',
        'speaker': 'silas',
        'text': 'Join them.',
        'done_when': {'type': 'merge'},
        'free_manna': true,
      },
      {
        'id': 'tut_generator',
        'speaker': 'silas',
        'text': 'Tap it.',
        'done_when': {'type': 'generator_tap'},
        'free_manna': true,
      },
      {
        'id': 'tut_first_order',
        'speaker': 'silas',
        'text': 'Deliver.',
        'done_when': {'type': 'order_delivered', 'id': 'o1'},
        'free_manna': true,
      },
      {
        'id': 'tut_first_task',
        'speaker': 'naomi',
        'text': 'Go.',
        'done_when': {'type': 'task_done', 'id': 't1'},
      },
      {
        'id': 'tut_love',
        'speaker': 'naomi',
        'text': 'Love.',
        'done_when': {'type': 'order_delivered', 'id': 'o3'},
      },
      {
        'id': 'tut_handoff',
        'speaker': 'silas',
        'text': 'Off you go.',
        'done_when': {'type': 'tap'},
      },
    ])
      TutorialStep.fromJson(json),
  ];

  int advance(
    int index,
    TutorialEvent event, {
    Set<String> orders = const {},
    Set<String> tasks = const {},
  }) => advanceTutorial(
    steps,
    index,
    event,
    completedOrders: orders,
    completedTasks: tasks,
  );

  test('fromJson reads every field', () {
    final s = steps[2];
    expect(s.id, 'tut_first_order');
    expect(s.speaker, 'silas');
    expect(s.text, 'Deliver.');
    expect(s.trigger, TutorialTrigger.orderDelivered);
    expect(s.targetId, 'o1');
    expect(s.freeManna, isTrue);
    expect(steps[3].freeManna, isFalse);
    expect(steps[0].targetId, isNull);
  });

  test('fromJson rejects an unknown trigger', () {
    expect(
      () => TutorialStep.fromJson({
        'id': 'x',
        'speaker': 'silas',
        'text': 't',
        'done_when': {'type': 'dance'},
      }),
      throwsFormatException,
    );
    expect(tutorialTriggerFromName('dance'), isNull);
    expect(tutorialTriggerFromName('merge'), TutorialTrigger.merge);
  });

  group('advanceTutorial', () {
    test('the matching action moves to the next step', () {
      expect(advance(0, const TutorialEvent(TutorialTrigger.merge)), 1);
      expect(advance(1, const TutorialEvent(TutorialTrigger.generatorTap)), 2);
    });

    test('any other action leaves the step showing', () {
      expect(advance(0, const TutorialEvent(TutorialTrigger.generatorTap)), 0);
      expect(advance(0, const TutorialEvent(TutorialTrigger.tap)), 0);
    });

    test('a step waiting for one order ignores other orders', () {
      const wrong = TutorialEvent(TutorialTrigger.orderDelivered, 'o2');
      const right = TutorialEvent(TutorialTrigger.orderDelivered, 'o1');
      expect(advance(2, wrong), 2);
      expect(advance(2, right, orders: {'o1'}), 3);
    });

    test('steps already done earlier are skipped over', () {
      // The Love order (o3) was delivered before the first task was done.
      const taskDone = TutorialEvent(TutorialTrigger.taskDone, 't1');
      expect(advance(3, taskDone, orders: {'o1', 'o3'}, tasks: {'t1'}), 5);
    });

    test('the last step ends the tutorial', () {
      expect(advance(5, const TutorialEvent(TutorialTrigger.tap)), 6);
    });

    test('once over, nothing brings it back', () {
      expect(advance(6, const TutorialEvent(TutorialTrigger.merge)), 6);
      expect(advance(99, const TutorialEvent(TutorialTrigger.merge)), 6);
      expect(advance(-1, const TutorialEvent(TutorialTrigger.merge)), 6);
    });
  });

  group('nextTutorialIndex', () {
    int next(
      int i, {
      Set<String> orders = const {},
      Set<String> tasks = const {},
    }) => nextTutorialIndex(
      steps,
      i,
      completedOrders: orders,
      completedTasks: tasks,
    );

    test('keeps a step that still needs doing', () {
      expect(next(0), 0);
      expect(next(2), 2);
    });

    test('skips order and task steps that are already done', () {
      expect(next(2, orders: {'o1'}), 3);
      expect(next(2, orders: {'o1', 'o3'}, tasks: {'t1'}), 5);
    });

    test('never skips steps that cannot be known from the save', () {
      expect(next(0, orders: {'o1', 'o3'}, tasks: {'t1'}), 0);
    });

    test('clamps to the end', () {
      expect(next(50), 6);
      expect(next(-3), 0);
    });
  });

  group('tutorialTapIsFree', () {
    bool free(int index, int used) => tutorialTapIsFree(
      index < steps.length ? steps[index] : null,
      freeTapsUsed: used,
      freeTapsAllowed: 3,
    );

    test('free on a free_manna step while taps remain', () {
      expect(free(0, 0), isTrue);
      expect(free(2, 2), isTrue);
    });
    test('no longer free once the allowance is used up', () {
      expect(free(0, 3), isFalse);
      expect(free(2, 99), isFalse);
    });
    test('never free on other steps or after the tutorial', () {
      expect(free(3, 0), isFalse);
      expect(free(6, 0), isFalse);
    });
  });
}
