import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';
import 'package:whispers_of_joppa/features/story/chapter_ending.dart';
import 'package:whispers_of_joppa/features/story/tutorial_banner.dart';
import 'package:whispers_of_joppa/features/story/tutorial_controller.dart';

void main() {
  testWidgets('the tutorial banner shows each hint and its Got it button', (
    tester,
  ) async {
    final controller = TutorialController(
      steps: const [
        TutorialStep(
          id: 'a',
          speaker: 'silas',
          text: 'Join the sheaves.',
          trigger: TutorialTrigger.merge,
        ),
        TutorialStep(
          id: 'b',
          speaker: 'silas',
          text: 'On your own now.',
          trigger: TutorialTrigger.tap,
        ),
      ],
      completedOrders: () => const {},
      completedTasks: () => const {},
      freeTapsAllowed: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorialBanner(
            controller: controller,
            characterNames: const {'silas': 'Silas'},
            availableAssets: const {},
          ),
        ),
      ),
    );
    String hint() =>
        tester.widget<Text>(find.byKey(const Key('tutorial_text'))).data ?? '';

    expect(hint(), 'Join the sheaves.');
    expect(find.text('Silas'), findsOneWidget);
    // A step that waits for a merge has no button.
    expect(find.byKey(const Key('tutorial_ok')), findsNothing);

    controller.handle(const TutorialEvent(TutorialTrigger.merge));
    await tester.pump();
    expect(hint(), 'On your own now.');

    // The last hint is dismissed with its button, and the banner goes away.
    await tester.tap(find.byKey(const Key('tutorial_ok')));
    await tester.pump();
    expect(find.byKey(const Key('tutorial_banner')), findsNothing);
    expect(controller.isOver, isTrue);
  });

  testWidgets('the chapter ending shows its content and closes on its button', (
    tester,
  ) async {
    const ending = ChapterEnding(
      chapterId: 'ch1',
      title: 'Chapter 1 Complete',
      body: 'The oven stays lit.',
      button: 'Keep baking',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChapterEnding(context, ending),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter_ending')), findsOneWidget);
    expect(find.text('Chapter 1 Complete'), findsOneWidget);
    expect(find.text('The oven stays lit.'), findsOneWidget);

    // Tapping outside does not close it.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter_ending')), findsOneWidget);

    await tester.tap(find.text('Keep baking'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter_ending')), findsNothing);
  });
}
