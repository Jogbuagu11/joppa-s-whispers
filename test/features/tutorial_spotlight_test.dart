import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/features/story/tutorial_spotlight.dart';

void main() {
  late ValueNotifier<int> changed;
  late SpotlightTargets targets;
  late bool enabled;
  var taps = 0;

  Future<void> show(WidgetTester tester) async {
    taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // The game underneath: a button where the spotlight points.
              Positioned(
                left: 100,
                top: 200,
                width: 60,
                height: 60,
                child: GestureDetector(
                  key: const Key('under'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                ),
              ),
              Positioned.fill(
                child: TutorialSpotlight(
                  relayout: changed,
                  targets: () => targets,
                  enabled: () => enabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // One frame to measure, and the short wait for things to come to rest.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  setUp(() {
    changed = ValueNotifier<int>(0);
    targets = const SpotlightTargets([]);
    enabled = true;
  });

  testWidgets('with nothing to point at there is no veil', (tester) async {
    await show(tester);
    expect(find.byKey(const Key('tutorial_spotlight')), findsNothing);
    // Nothing is left animating.
    await tester.pumpAndSettle();
  });

  testWidgets('a target is lit, and touches go through to the game', (
    tester,
  ) async {
    targets = const SpotlightTargets([Rect.fromLTWH(100, 200, 60, 60)]);
    await show(tester);
    expect(find.byKey(const Key('tutorial_spotlight')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('under')));
    expect(taps, 1);
    // A touch on the dim part goes through too: the veil blocks nothing.
    await tester.tapAt(const Offset(20, 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('it follows the game: a new step, then the tutorial ending', (
    tester,
  ) async {
    targets = const SpotlightTargets([Rect.fromLTWH(100, 200, 60, 60)]);
    await show(tester);
    // A drag between two places.
    targets = const SpotlightTargets([
      Rect.fromLTWH(10, 300, 50, 50),
      Rect.fromLTWH(70, 300, 50, 50),
    ], drag: true);
    changed.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('tutorial_spotlight')), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The tutorial ends: the veil goes and nothing keeps moving.
    targets = const SpotlightTargets([]);
    changed.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('tutorial_spotlight')), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('it stays away while something else is open', (tester) async {
    targets = const SpotlightTargets([Rect.fromLTWH(100, 200, 60, 60)]);
    enabled = false;
    await show(tester);
    expect(find.byKey(const Key('tutorial_spotlight')), findsNothing);
    enabled = true;
    changed.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('tutorial_spotlight')), findsOneWidget);
  });
}
