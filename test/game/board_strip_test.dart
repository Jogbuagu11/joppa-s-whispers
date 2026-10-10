import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/game/board/board_strip.dart';

import '../support/comfort_fakes.dart';

const _chapters = [
  ChapterModel(
    id: 'ch1',
    number: 1,
    title: 'Homecoming',
    locationId: 'bakehouse',
    tasks: [
      TaskModel(
        id: 't1',
        beat: 1,
        title: 'Clear the doorway',
        costBlessings: 2,
      ),
      TaskModel(
        id: 't2',
        beat: 2,
        title: 'Open the shutters',
        costBlessings: 9,
      ),
    ],
  ),
];

void main() {
  late ValueNotifier<int> blessings;
  late StoryController story;
  late List<String> tapped;
  late ValueNotifier<int> ready;

  Future<void> show(
    WidgetTester tester, {
    double width = 400,
    bool event = false,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tapped = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardStrip(
            story: story,
            height: 130,
            onDoTask: () {
              tapped.add('task');
              story.doNext();
            },
            onOpenLocation: () => tapped.add('place'),
            onOpenLetters: () => tapped.add('letters'),
            onOpenEvent: event ? () => tapped.add('event') : null,
            eventLabel: 'Boat Festival',
            ordersChanged: ready,
            readyOrders: () => ready.value,
            orders: const ColoredBox(
              key: Key('orders'),
              color: Colors.brown,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double left(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key))).left;

  setUp(() {
    ready = ValueNotifier<int>(0);
    blessings = ValueNotifier<int>(0);
    story = StoryController(
      chapters: _chapters,
      blessings: () => blessings.value,
      spendBlessings: (n) {
        if (n > blessings.value) return false;
        blessings.value -= n;
        return true;
      },
      wallet: blessings,
    );
  });

  testWidgets('at rest the three orders fill the row; the rest is off to '
      'the left', (tester) async {
    await show(tester);
    expect(tester.takeException(), isNull);
    final orders = tester.getRect(find.byKey(const Key('orders')));
    // (After the narrow gutter that holds the arrow.)
    expect(orders.left, moreOrLessEquals(16, epsilon: 0.5));
    expect(orders.width, 400 - 16);
    expect(left(tester, 'task_button'), lessThan(16));
    // An arrow at the edge says there is more that way; tapping it slides
    // back to the start.
    await tester.tap(find.byKey(const Key('strip_more')));
    await tester.pumpAndSettle();
    expect(left(tester, 'location_button'), greaterThanOrEqualTo(0));
    expect(find.byKey(const Key('strip_more')), findsNothing);
    await tester.tap(find.byKey(const Key('location_button')));
    await tester.tap(find.byKey(const Key('letters_button')));
    expect(tapped, ['place', 'letters']);
    expect(find.byKey(const Key('event_banner')), findsNothing);
  });

  testWidgets('the story card slides into view when its task can be done, '
      'and the orders return once it is', (tester) async {
    await show(tester);
    expect(left(tester, 'task_button'), lessThan(0));
    blessings.value = 2;
    await tester.pumpAndSettle();
    expect(left(tester, 'task_button'), greaterThan(0));
    expect(find.text('Clear the doorway'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task_button')));
    await tester.pumpAndSettle();
    expect(tapped, ['task']);
    // The next task costs more than is left: back to the orders.
    expect(left(tester, 'task_button'), lessThan(0));
    expect(
      tester.getRect(find.byKey(const Key('orders'))).left,
      moreOrLessEquals(16, epsilon: 0.5),
    );
  });

  testWidgets('a game opened with a task waiting starts on the story card', (
    tester,
  ) async {
    blessings.value = 5;
    await show(tester);
    expect(left(tester, 'location_button'), greaterThanOrEqualTo(0));
    expect(left(tester, 'task_button'), greaterThan(0));
  });

  testWidgets('while an event is on its button is in the row', (tester) async {
    blessings.value = 5;
    await show(tester, event: true);
    await tester.tap(find.byKey(const Key('event_banner')));
    expect(tapped, ['event']);
  });

  testWidgets('it fits a narrow phone at the largest text size, and can be '
      'swiped by hand', (tester) async {
    useLargestText(tester);
    await show(tester, width: 320, event: true);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('board_strip')),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(left(tester, 'location_button'), greaterThanOrEqualTo(0));
  });

  testWidgets('when another order becomes ready the row comes back to the '
      'orders, unless the story card is waiting', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const Key('strip_more')));
    await tester.pumpAndSettle();
    expect(left(tester, 'location_button'), greaterThanOrEqualTo(0));
    ready.value = 1;
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('orders'))).left,
      moreOrLessEquals(16, epsilon: 0.5),
    );
    // With the story task affordable, the story card keeps the view.
    blessings.value = 2;
    await tester.pumpAndSettle();
    ready.value = 2;
    await tester.pumpAndSettle();
    expect(left(tester, 'task_button'), greaterThan(0));
  });
}
