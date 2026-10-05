import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/game_saver.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

SaveState _state(int manna) => SaveState(
  items: const [],
  generators: const [],
  manna: manna,
  mannaLastRegen: DateTime.utc(2040),
  talents: 0,
  blessings: 0,
  activeOrders: const [],
  pendingOrders: const [],
  completedOrders: const [],
  lastOrderSkip: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late SaveRepository repo;
  late ValueNotifier<int> trigger;
  late int manna;
  late int snapshots;
  late GameSaver saver;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('joppa_saver_test');
    repo = SaveRepository(directory: () async => dir);
    trigger = ValueNotifier<int>(0);
    manna = 10;
    snapshots = 0;
    saver = GameSaver(
      repository: repo,
      snapshot: () {
        snapshots++;
        return _state(manna);
      },
      triggers: [trigger],
      delay: const Duration(milliseconds: 60),
    )..start();
  });
  tearDown(() async {
    await saver.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  test('nothing is written until something changes', () async {
    await saver.flush();
    expect(await repo.load(), isNull);
    expect(snapshots, 0);
  });

  test('a change is written after the delay', () async {
    trigger.value++;
    expect(await repo.load(), isNull);
    await wait(250);
    expect((await repo.load())?.manna, 10);
  });

  test('a burst of changes becomes one write with the latest state', () async {
    for (int i = 0; i < 5; i++) {
      manna = 20 + i;
      trigger.value++;
      await wait(10);
    }
    await wait(250);
    expect(snapshots, 1);
    expect((await repo.load())?.manna, 24);
  });

  test('flush writes straight away', () async {
    manna = 55;
    trigger.value++;
    await saver.flush();
    expect((await repo.load())?.manna, 55);
  });

  test('going to the background writes straight away', () async {
    manna = 77;
    trigger.value++;
    saver.didChangeAppLifecycleState(AppLifecycleState.paused);
    await saver.flush();
    expect((await repo.load())?.manna, 77);
  });

  test('dispose writes unsaved changes and stops listening', () async {
    manna = 88;
    trigger.value++;
    await saver.dispose();
    expect((await repo.load())?.manna, 88);
    manna = 99;
    trigger.value++;
    await wait(200);
    expect((await repo.load())?.manna, 88);
  });

  test(
    'changes that never pause are still written by the maximum wait',
    () async {
      await saver.dispose();
      saver = GameSaver(
        repository: repo,
        snapshot: () => _state(manna),
        triggers: [trigger],
        delay: const Duration(milliseconds: 80),
        maxWait: const Duration(milliseconds: 200),
      )..start();
      // A change every 30 ms would postpone an 80 ms delay forever.
      for (int i = 0; i < 14; i++) {
        manna = 30 + i;
        trigger.value++;
        await wait(30);
      }
      expect(await repo.load(), isNotNull);
    },
  );
}
