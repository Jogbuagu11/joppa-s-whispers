import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/cloud_sync.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/data/sync_base_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_cloud.dart';

import '../support/fakes.dart';

void main() {
  late Directory dir;
  late FakeAuthService auth;
  late FakeCloudSaveStore store;
  late DateTime now;
  late BoardCloud cloud;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('joppa_board_cloud_test');
    auth = FakeAuthService();
    store = FakeCloudSaveStore();
    now = DateTime(2040, 1, 1, 12);
    cloud = BoardCloud(
      auth: auth,
      sync: CloudSync(
        auth: auth,
        store: store,
        bases: SyncBaseRepository(directory: () async => dir),
      ),
      uploadEvery: const Duration(seconds: 20),
      clock: () => now,
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  final played = testSave(tasks: ['t1'], orders: ['o1']);
  final more = testSave(tasks: ['t1', 't2'], orders: ['o1', 'o2']);

  /// Runs syncNow with a real BuildContext.
  Future<({String message, CloudSave? adopt})> sync(
    WidgetTester tester,
    SaveState local,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    late ({String message, CloudSave? adopt}) result;
    await tester.runAsync(
      () async => result = await cloud.syncNow(context, local),
    );
    return result;
  }

  testWidgets('signed out: says so and uploads nothing', (tester) async {
    final r = await sync(tester, played);
    expect(r.message, contains('Sign in'));
    expect(r.adopt, isNull);
    await tester.runAsync(() => cloud.afterLocalSave(more));
    expect(store.uploads, 0);
  });

  testWidgets(
    'first sync uploads; later saves upload no more than every 20 s',
    (tester) async {
      auth.signInAs('u1');
      final r = await sync(tester, played);
      expect(r.message, contains('saved to your account'));
      expect(store.uploads, 1);

      // Too soon: skipped.
      now = now.add(const Duration(seconds: 5));
      await tester.runAsync(() => cloud.afterLocalSave(more));
      expect(store.uploads, 1);

      // Long enough: uploaded.
      now = now.add(const Duration(seconds: 20));
      await tester.runAsync(() => cloud.afterLocalSave(more));
      expect(store.uploads, 2);
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
    },
  );

  testWidgets('a cloud game for an unplayed phone is handed back to adopt', (
    tester,
  ) async {
    auth.signInAs('u1');
    store.seed('u1', more);
    final r = await sync(tester, testSave());
    expect(r.adopt?.state.completedTasks, ['t1', 't2']);
    expect(r.message, contains('brought to this phone'));
  });

  testWidgets('saves are not uploaded before a sync has compared the two', (
    tester,
  ) async {
    auth.signInAs('u1');
    store.seed('u1', more);
    await tester.runAsync(() => cloud.afterLocalSave(played));
    expect(store.uploads, 0);
    expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
  });

  testWidgets('a failed sync reports it and stops automatic uploads', (
    tester,
  ) async {
    auth.signInAs('u1');
    store.offline = true;
    final r = await sync(tester, played);
    expect(r.message, contains('Could not reach your account'));
    store.offline = false;
    now = now.add(const Duration(minutes: 5));
    await tester.runAsync(() => cloud.afterLocalSave(more));
    expect(store.uploads, 0);
  });

  testWidgets('reset stops uploads until the next sync', (tester) async {
    auth.signInAs('u1');
    await sync(tester, played);
    cloud.reset();
    expect(cloud.inStep, isFalse);
    now = now.add(const Duration(minutes: 5));
    await tester.runAsync(() => cloud.afterLocalSave(more));
    expect(store.uploads, 1);
  });

  testWidgets('another phone saving in between stops this one overwriting it', (
    tester,
  ) async {
    auth.signInAs('u1');
    await sync(tester, played);
    expect(cloud.inStep, isTrue);
    // Another phone uploads newer progress.
    store.seed('u1', more);
    now = now.add(const Duration(minutes: 5));
    final mine = testSave(tasks: ['t1'], orders: ['o1', 'o9']);
    await tester.runAsync(() => cloud.afterLocalSave(mine));
    expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
    // And it stops sending until a full sync has compared them again.
    expect(cloud.inStep, isFalse);
  });

  testWidgets('leaving the app sends the save at once, ignoring the wait', (
    tester,
  ) async {
    auth.signInAs('u1');
    await sync(tester, played);
    now = now.add(const Duration(seconds: 1));
    await tester.runAsync(() => cloud.afterLocalSave(more, force: true));
    expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
  });

  testWidgets('a downloaded game counts as in step only once confirmed', (
    tester,
  ) async {
    auth.signInAs('u1');
    store.seed('u1', more);
    final r = await sync(tester, testSave());
    expect(cloud.inStep, isFalse);
    final adopt = r.adopt;
    expect(adopt, isNotNull);
    if (adopt == null) return;
    await tester.runAsync(() => cloud.confirmAdopted(adopt));
    expect(cloud.inStep, isTrue);
  });

  testWidgets('switching account stops uploads until the next sync', (
    tester,
  ) async {
    auth.signInAs('u1');
    await sync(tester, played);
    expect(cloud.inStep, isTrue);
    auth.signInAs('u2');
    expect(cloud.inStep, isFalse);
    now = now.add(const Duration(minutes: 5));
    await tester.runAsync(() => cloud.afterLocalSave(more));
    expect(store.saves['u2'], isNull);
  });

  testWidgets('forgetAccount clears the sync record', (tester) async {
    auth.signInAs('u1');
    await sync(tester, played);
    await tester.runAsync(cloud.forgetAccount);
    expect(cloud.inStep, isFalse);
    expect(await tester.runAsync(() => cloud.sync.push(more)), isFalse);
  });
}
