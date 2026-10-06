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
    final out = await sync.sync(played, choose: choose, contentVersion: 9);
    expect(out.result, SyncResult.signedOut);
    expect(store.uploads, 0);
  });

  test('first sign-in with no cloud save uploads this phone\'s game', () async {
    auth.signInAs('u1');
    final out = await sync.sync(played, choose: choose, contentVersion: 9);
    expect(out.result, SyncResult.uploaded);
    expect(store.saves['u1']?.state.completedTasks, ['t1']);
    expect(asked, isEmpty);
  });

  test('a new phone with an unplayed game takes the cloud save', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    final out = await sync.sync(testSave(), choose: choose, contentVersion: 9);
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
      final out = await sync.sync(played, choose: choose, contentVersion: 9);
      expect(asked, [true]);
      expect(out.result, SyncResult.downloaded);
      expect(out.cloud?.state.completedTasks, ['t1', 't2']);
    },
  );

  test('choosing this phone overwrites the cloud', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    answer = false;
    final out = await sync.sync(played, choose: choose, contentVersion: 9);
    expect(out.result, SyncResult.keptLocalUploaded);
    expect(store.saves['u1']?.state.completedTasks, ['t1']);
  });

  test('backing out of the choice changes nothing', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    answer = null;
    final out = await sync.sync(played, choose: choose, contentVersion: 9);
    expect(out.result, SyncResult.undecided);
    expect(store.uploads, 0);
    expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
  });

  test('after syncing, nothing changed means up to date', () async {
    auth.signInAs('u1');
    await sync.sync(played, choose: choose, contentVersion: 9);
    final out = await sync.sync(played, choose: choose, contentVersion: 9);
    expect(out.result, SyncResult.upToDate);
    expect(store.uploads, 1);
  });

  test(
    'after syncing, progress on this phone is uploaded without asking',
    () async {
      auth.signInAs('u1');
      await sync.sync(played, choose: choose, contentVersion: 9);
      final out = await sync.sync(further, choose: choose, contentVersion: 9);
      expect(out.result, SyncResult.uploaded);
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
      expect(asked, isEmpty);
    },
  );

  test('after syncing, progress from another phone is downloaded', () async {
    auth.signInAs('u1');
    await sync.sync(played, choose: choose, contentVersion: 9);
    store.seed('u1', further);
    final out = await sync.sync(played, choose: choose, contentVersion: 9);
    expect(out.result, SyncResult.downloaded);
    expect(out.cloud?.state.completedTasks, ['t1', 't2']);
    expect(asked, isEmpty);
  });

  test('progress on both since the last sync asks the player', () async {
    auth.signInAs('u1');
    await sync.sync(played, choose: choose, contentVersion: 9);
    store.seed('u1', further);
    answer = false;
    final mine = testSave(tasks: ['t1'], orders: ['o1', 'o9']);
    final out = await sync.sync(mine, choose: choose, contentVersion: 9);
    expect(asked, [true]);
    expect(out.result, SyncResult.keptLocalUploaded);
    expect(store.saves['u1']?.state.completedOrders, ['o1', 'o9']);
  });

  test(
    'a different account on the same phone is treated as a first sync',
    () async {
      auth.signInAs('u1');
      await sync.sync(played, choose: choose, contentVersion: 9);
      auth.signInAs('u2');
      store.seed('u2', further);
      answer = true;
      final out = await sync.sync(played, choose: choose, contentVersion: 9);
      expect(asked, [true]);
      expect(out.result, SyncResult.downloaded);
    },
  );

  test(
    'push is refused when another phone has saved since the last sync',
    () async {
      auth.signInAs('u1');
      await sync.sync(played, choose: choose, contentVersion: 9);
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
      await sync.sync(further, choose: choose, contentVersion: 9);
      // The phone's save is lost; it starts a new game but still has its sync record.
      final out = await sync.sync(
        testSave(),
        choose: choose,
        contentVersion: 9,
      );
      expect(out.result, SyncResult.downloaded);
      expect(out.cloud?.state.completedTasks, ['t1', 't2']);
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
      expect(asked, isEmpty);
    },
  );

  test('a downloaded game is only recorded as held once confirmed', () async {
    auth.signInAs('u1');
    store.seed('u1', further);
    final out = await sync.sync(testSave(), choose: choose, contentVersion: 9);
    final cloud = out.cloud;
    expect(cloud, isNotNull);
    if (cloud == null) return;
    // Not confirmed (the write to the phone failed): the phone still holds an
    // unplayed game, and the next sync offers the cloud game again.
    final again = await sync.sync(
      testSave(),
      choose: choose,
      contentVersion: 9,
    );
    expect(again.result, SyncResult.downloaded);
    // Confirmed: the two are in step.
    await sync.confirmAdopted(cloud);
    final after = await sync.sync(
      cloud.state,
      choose: choose,
      contentVersion: 9,
    );
    expect(after.result, SyncResult.upToDate);
  });

  test('a cloud game made with newer content is not taken over', () async {
    auth.signInAs('u1');
    store.seed('u1', testSave(tasks: ['t1', 't9'], contentVersion: 2));
    final out = await sync.sync(testSave(), choose: choose, contentVersion: 1);
    expect(out.result, SyncResult.needsNewerContent);
    expect(out.cloud, isNull);
    expect(store.uploads, 0);
    // Once this phone runs the newer content, it is taken over normally.
    final later = await sync.sync(
      testSave(),
      choose: choose,
      contentVersion: 2,
    );
    expect(later.result, SyncResult.downloaded);
  });

  test(
    'a local game that lost parts to older content is never uploaded',
    () async {
      auth.signInAs('u1');
      await sync.sync(played, choose: choose, contentVersion: 2);
      // The same game, now running on older content than it was saved with.
      final stripped = testSave(tasks: ['t1'], contentVersion: 2);
      final out = await sync.sync(stripped, choose: choose, contentVersion: 1);
      expect(out.result, SyncResult.needsNewerContent);
      expect(store.uploads, 1);
    },
  );

  test(
    'keeping this phone is refused if another phone saved while choosing',
    () async {
      auth.signInAs('u1');
      store.seed('u1', further);
      final newest = testSave(tasks: ['t1', 't2', 't3']);
      // While the player reads the question, another phone uploads.
      Future<bool?> slowChoice({
        required SaveState local,
        required SaveState cloud,
        required bool cloudIsFurtherOn,
      }) async {
        store.seed('u1', newest);
        return false;
      }

      final out = await sync.sync(
        played,
        choose: slowChoice,
        contentVersion: 9,
      );
      expect(out.result, SyncResult.changedMeanwhile);
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2', 't3']);
    },
  );

  test('forget clears the sync record', () async {
    auth.signInAs('u1');
    await sync.sync(played, choose: choose, contentVersion: 9);
    await sync.forget();
    expect(await sync.push(played), isFalse);
  });

  test('no connection: reported as failed, nothing lost', () async {
    auth.signInAs('u1');
    store.offline = true;
    final out = await sync.sync(played, choose: choose, contentVersion: 9);
    expect(out.result, SyncResult.failed);
    expect(await sync.push(played), isFalse);
  });

  test(
    'push uploads when signed in and does nothing when signed out',
    () async {
      expect(await sync.push(played), isFalse);
      auth.signInAs('u1');
      await sync.sync(played, choose: choose, contentVersion: 9);
      expect(await sync.push(further), isTrue);
      expect(store.saves['u1']?.state.completedTasks, ['t1', 't2']);
      // A push keeps the sync record current, so the next sync is quiet.
      expect(
        (await sync.sync(further, choose: choose, contentVersion: 9)).result,
        SyncResult.upToDate,
      );
    },
  );
}
