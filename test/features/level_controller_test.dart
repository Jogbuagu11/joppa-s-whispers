import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/features/levels/level_controller.dart';
import 'package:whispers_of_joppa/features/levels/level_widgets.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';

import '../support/comfort_fakes.dart';

const _config = LevelsConfig(
  xpPerTaskByChapter: {1: 10},
  xpPerTaskDefault: 10,
  steps: [
    LevelStep(level: 2, xp: 10, talents: 20),
    LevelStep(level: 3, xp: 30, talents: 30),
  ],
  unlocks: [
    FeatureUnlock(level: 3, feature: 'wheel', name: 'Wheel', available: true),
  ],
  text: {
    'title': 'Level {level}',
    'manna': 'Your Manna is full again.',
    'talents': '+{talents} Talents',
    'unlocked': 'New: {name}',
    'continue': 'Continue',
    'badge': 'Level {level}',
  },
);
const _chapters = [
  ChapterModel(
    id: 'ch1',
    number: 1,
    title: 'One',
    locationId: 'place',
    tasks: [
      TaskModel(id: 't1', beat: 1, title: 'One', costBlessings: 1),
      TaskModel(id: 't2', beat: 2, title: 'Two', costBlessings: 1),
      TaskModel(id: 't3', beat: 3, title: 'Three', costBlessings: 1),
    ],
  ),
];

void main() {
  late int talents;
  late int refills;
  late StoryController story;

  LevelController make({List<String> done = const [], int rewarded = 0}) {
    story = StoryController(
      chapters: _chapters,
      blessings: () => 99,
      spendBlessings: (_) => true,
      wallet: ValueNotifier<int>(0),
      completedTasks: done,
    );
    return LevelController(
      config: _config,
      story: story,
      addTalents: (n) => talents += n,
      refillManna: () => refills++,
      rewardedLevel: rewarded,
    );
  }

  setUp(() {
    talents = 0;
    refills = 0;
  });

  test('a new game is level 1 with nothing to collect', () {
    final c = make();
    expect(c.level, 1);
    expect(c.progress, (into: 0, needed: 10));
    expect(c.collect(), isNull);
    expect(talents, 0);
    expect(refills, 0);
  });

  test('finishing a task can reach a level: Talents and a full Manna bar, '
      'once', () {
    final c = make();
    var told = 0;
    c.addListener(() => told++);
    story.doNext();
    expect(c.level, 2);
    expect(told, greaterThan(0));
    final up = c.collect();
    expect(up?.to, 2);
    expect(talents, 20);
    expect(refills, 1);
    expect(c.rewardedLevel, 2);
    // Asking again gives nothing more.
    expect(c.collect(), isNull);
    expect(talents, 20);
    expect(refills, 1);
  });

  test('a level reached but not yet paid (the game was closed) is paid on '
      'return', () {
    final c = make(done: ['t1', 't2', 't3'], rewarded: 2);
    expect(c.level, 3);
    final up = c.collect();
    expect(up?.from, 2);
    expect(up?.talents, 30);
    expect(up?.unlocked.single.name, 'Wheel');
    expect(refills, 1);
  });

  test('a game from before levels starts at its level, owed nothing', () {
    final c = make(done: ['t1', 't2', 't3']);
    expect(c.level, 3);
    expect(c.rewardedLevel, 3);
    expect(c.collect(), isNull);
    expect(talents, 0);
  });

  test('features open at their level', () {
    final c = make();
    expect(c.isUnlocked('wheel'), isFalse);
    story
      ..doNext()
      ..doNext()
      ..doNext();
    expect(c.isUnlocked('wheel'), isTrue);
  });

  test('with no levels in the content everyone is level 1', () {
    story = StoryController(
      chapters: _chapters,
      blessings: () => 99,
      spendBlessings: (_) => true,
      wallet: ValueNotifier<int>(0),
      completedTasks: const ['t1', 't2'],
    );
    final c = LevelController(
      config: null,
      story: story,
      addTalents: (n) => talents += n,
      refillManna: () => refills++,
      rewardedLevel: 9,
    );
    expect(c.level, 1);
    // The record of levels already paid is kept, so nothing is paid twice
    // when the levels come back.
    expect(c.rewardedLevel, 9);
    expect(c.collect(), isNull);
    expect(talents, 0);
  });

  testWidgets('the badge shows the level and fills as XP is earned', (
    tester,
  ) async {
    useLargestText(tester);
    final c = make(done: ['t1']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LevelBadge(controller: c)),
      ),
    );
    expect(tester.takeException(), isNull);
    Text number() => tester.widget<Text>(find.byKey(const Key('level_number')));
    double? ring() => tester
        .widget<CircularProgressIndicator>(
          find.byKey(const Key('level_progress')),
        )
        .value;
    expect(number().data, '2');
    expect(ring(), 0);
    story.doNext();
    await tester.pump();
    expect(number().data, '2');
    expect(ring(), 0.5);
    story.doNext();
    await tester.pump();
    expect(number().data, '3');
    // The highest level shows a full ring.
    expect(ring(), 1);
  });

  testWidgets('the level-up message fits a small phone at the largest text '
      'size and closes on its button', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    useLargestText(tester);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    final up = levelUpOwed(_config, rewarded: 1, current: 3);
    // Safe: levels 2 and 3 are above level 1.
    showLevelUp(context, _config.text, up!);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('+50 Talents'), findsOneWidget);
    expect(find.text('New: Wheel'), findsOneWidget);
    expect(find.text('Your Manna is full again.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('level_up_continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level_up')), findsNothing);
  });
}
