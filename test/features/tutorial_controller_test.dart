import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';
import 'package:whispers_of_joppa/features/story/tutorial_controller.dart';

const _steps = [
  TutorialStep(
    id: 'merge',
    speaker: 'silas',
    text: 'Join.',
    trigger: TutorialTrigger.merge,
    freeManna: true,
  ),
  TutorialStep(
    id: 'order',
    speaker: 'silas',
    text: 'Deliver.',
    trigger: TutorialTrigger.orderDelivered,
    targetId: 'o1',
  ),
  TutorialStep(
    id: 'end',
    speaker: 'silas',
    text: 'Go on.',
    trigger: TutorialTrigger.tap,
  ),
];

void main() {
  late Set<String> orders;

  TutorialController make({int start = 0}) => TutorialController(
    steps: _steps,
    completedOrders: () => orders,
    completedTasks: () => const {},
    startIndex: start,
  );

  setUp(() => orders = {});

  test('starts on the first hint with free Manna', () {
    final c = make();
    expect(c.index, 0);
    expect(c.current?.id, 'merge');
    expect(c.freeManna, isTrue);
    expect(c.isOver, isFalse);
  });

  test('the right action moves on and tells listeners; others do nothing', () {
    final c = make();
    var notified = 0;
    c.addListener(() => notified++);
    c.handle(const TutorialEvent(TutorialTrigger.generatorTap));
    expect(c.index, 0);
    expect(notified, 0);
    c.handle(const TutorialEvent(TutorialTrigger.merge));
    expect(c.current?.id, 'order');
    expect(c.freeManna, isFalse);
    expect(notified, 1);
  });

  test('finishing the last hint ends the tutorial for good', () {
    final c = make(start: 2);
    c.handle(const TutorialEvent(TutorialTrigger.tap));
    expect(c.isOver, isTrue);
    expect(c.current, isNull);
    expect(c.freeManna, isFalse);
    expect(c.index, _steps.length);
    c.handle(const TutorialEvent(TutorialTrigger.merge));
    expect(c.isOver, isTrue);
  });

  test('restoring skips a hint whose order was already delivered', () {
    orders = {'o1'};
    expect(make(start: 1).current?.id, 'end');
  });

  test('an order delivered early is skipped when its hint comes up', () {
    final c = make();
    orders = {'o1'};
    c.handle(const TutorialEvent(TutorialTrigger.merge));
    expect(c.current?.id, 'end');
  });

  test('a save from after the tutorial stays finished', () {
    expect(make(start: 99).isOver, isTrue);
  });
}
