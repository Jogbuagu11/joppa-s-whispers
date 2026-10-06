import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/cloud_sync.dart';
import 'package:whispers_of_joppa/data/sync_base_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

import '../support/fakes.dart';

void main() {
  late Directory dir;
  late FakeAuthService auth;
  late FakeCloudSaveStore store;
  late CloudSync sync;
  late List<bool> asked; // cloudIsFurtherOn for each time the player was asked
  bool? answer;

  Future<bool?> choose({
    required SaveState local,
    required SaveState cloud,
    required bool cloudIsFurtherOn,
  }) async {
    asked.add(cloudIsFurtherOn);
    return answer;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('joppa_sync_test');
    auth = FakeAuthService();
    store = FakeCloudSaveStore();
    sync = CloudSync(
      auth: auth,
      store: store,
      bases: SyncBaseRepository(directory: () async => dir),
    );
    asked = [];
    answer = null;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  final played = testSave(tasks: ['t1'], orders: ['o1'], blessings: 1);
  final further = testSave(tasks: ['t1', 't2'], orders: ['o1', 'o2']);

  test('signed out: nothing happens', () async {
    final out = await sync.sync(played, choose: choose);
    expect(out.result, SyncResult.signedOut);
    expect(store.uploads, 0);
  });

  test('first sign-in with no cloud save uploads this phone\'s game', () async {
    auth.signInAs('u1');
    final out = await sync.sync(played, choose: choose);
    expect(out.result, SyncResult.uploaded);
    expect(store.saves['u1']?.state.completedTasks, ['t1']);
    expect(asked, isEmpty);
  });

  test('a new phone with an unplayed game takes the cloud save', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    final out = await sync.sync(testSave(), choose: choose);
    expect(out.result, SyncResult.downloaded);
    expect(out.cloud?.state.completedTasks, ['t1', 't2']);
    expect(asked, isEmpty);
    expect(store.uploads, 0);
  });

  test(
    'a new phone with its own progress asks, suggesting the further one',
    () async {
      auth.signInAs('u1');
      store.seed('u1', further);
      answer = true;
      final out = await sync.sync(played, choose: choose);
      expect(asked, [true]);
      expect(out.result, SyncResult.downloaded);
      expect(out.cloud?.state.completedTasks, ['t1', 't2']);
    },
  );

  test('choosing this phone overwrites the cloud', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    answer = false;
    final out = await sync.sync(played, choose: choose);
    expect(out.result, SyncResult.keptLocalUploaded);
    expect(store.saves['u1']?.state.completedTasks, ['t1']);
  });

  test('backing out of the choice changes nothing', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    answer = null;
    final out = await sync.sync(played, choose: choose);
    expect(out.result, SyncResult.undecided);
    expect(store.uploads, 0);
    expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
  });

  test('after syncing, nothing changed means up to date', () async {
    auth.signInAs('u1');
    await sync.sync(played, choose: choose);
    final out = await sync.sync(played, choose: choose);
    expect(out.result, SyncResult.upToDate);
    expect(store.uploads, 1);
  });

  test(
    'after syncing, progress on this phone is uploaded without asking',
    () async {
      auth.signInAs('u1');
      await sync.sync(played, choose: choose);
      final out = await sync.sync(further, choose: choose);
      expect(out.result, SyncResult.uploaded);
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
      expect(asked, isEmpty);
    },
  );

  test('after syncing, progress from another phone is downloaded', () async {
    auth.signInAs('u1');
    await sync.sync(played, choose: choose);
    store.seed('u1', further);
    final out = await sync.sync(played, choose: choose);
    expect(out.result, SyncResult.downloaded);
    expect(out.cloud?.state.completedTasks, ['t1', 't2']);
    expect(asked, isEmpty);
  });

  test('progress on both since the last sync asks the player', () async {
    auth.signInAs('u1');
    await sync.sync(played, choose: choose);
    store.seed('u1', further);
    answer = false;
    final mine = testSave(tasks: ['t1'], orders: ['o1', 'o9']);
    final out = await sync.sync(mine, choose: choose);
    expect(asked, [true]);
    expect(out.result, SyncResult.keptLocalUploaded);
    expect(store.saves['u1']?.state.completedOrders, ['o1', 'o9']);
  });

  test(
    'a different account on the same phone is treated as a first sync',
    () async {
      auth.signInAs('u1');
      await sync.sync(played, choose: choose);
      auth.signInAs('u2');
      store.seed('u2', further);
      answer = true;
      final out = await sync.sync(played, choose: choose);
      expect(asked, [true]);
      expect(out.result, SyncResult.downloaded);
    },
  );

  test(
    'push is refused when another phone has saved since the last sync',
    () async {
      auth.signInAs('u1');
      await sync.sync(played, choose: choose);
      // Another phone moves the cloud game on.
      store.seed('u1', further);
      final mine = testSave(tasks: ['t1'], orders: ['o1', 'o9']);
      expect(await sync.push(mine), isFalse);
      // The other phone's progress is untouched.
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
    },
  );

  test('push does nothing on a phone that has never synced', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    expect(await sync.push(played), isFalse);
    expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
  });

  test(
    'a lost local save is rescued from the cloud, not uploaded over it',
    () async {
      auth.signInAs('u1');
      await sync.sync(further, choose: choose);
      // The phone's save is lost; it starts a new game but still has its sync record.
      final out = await sync.sync(testSave(), choose: choose);
      expect(out.result, SyncResult.downloaded);
      expect(out.cloud?.state.completedTasks, ['t1', 't2']);
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
      expect(asked, isEmpty);
    },
  );

  test('a downloaded game is only recorded as held once confirmed', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    final out = await sync.sync(testSave(), choose: choose);
    final cloud = out.cloud;
    expect(cloud, isNotNull);
    if (cloud == null) return;
    // Not confirmed (the write to the phone failed): the phone still holds an
    // unplayed game, and the next sync offers the cloud game again.
    final again = await sync.sync(testSave(), choose: choose);
    expect(again.result, SyncResult.downloaded);
    // Confirmed: the two are in step.
    await sync.confirmAdopted(cloud);
    final after = await sync.sync(cloud.state, choose: choose);
    expect(after.result, SyncResult.upToDate);
  });

  test('forget clears the sync record', () async {
    auth.signInAs('u1');
    await sync.sync(played, choose: choose);
    await sync.forget();
    expect(await sync.push(played), isFalse);
  });

  test('no connection: reported as failed, nothing lost', () async {
    auth.signInAs('u1');
    store.offline = true;
    final out = await sync.sync(played, choose: choose);
    expect(out.result, SyncResult.failed);
    expect(await sync.push(played), isFalse);
  });

  test(
    'push uploads when signed in and does nothing when signed out',
    () async {
      expect(await sync.push(played), isFalse);
      auth.signInAs('u1');
      await sync.sync(played, choose: choose);
      expect(await sync.push(further), isTrue);
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
      // A push keeps the sync record current, so the next sync is quiet.
      expect(
        (await sync.sync(further, choose: choose)).result,
        SyncResult.upToDate,
      );
    },
  );
}
