import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/cloud_sync.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

SaveState _save({
  List<String> tasks = const [],
  List<String> orders = const [],
  int talents = 0,
  int blessings = 0,
  int manna = 100,
  DateTime? regen,
}) => SaveState(
  items: const [SavedItem(itemId: 'bakery_01', col: 0, row: 0)],
  generators: const [],
  manna: manna,
  mannaLastRegen: regen ?? DateTime.utc(2040),
  talents: talents,
  blessings: blessings,
  activeOrders: const [],
  pendingOrders: const [],
  completedOrders: orders,
  completedTasks: tasks,
  tutorialStep: 0,
  lastOrderSkip: null,
);

void main() {
  test('saveProgressScore ranks tasks above orders', () {
    expect(saveProgressScore(_save()), 0);
    expect(saveProgressScore(_save(orders: ['a', 'b'])), 2);
    expect(saveProgressScore(_save(tasks: ['t1'])), 1000);
    expect(
      saveProgressScore(_save(tasks: ['t1'])),
      greaterThan(saveProgressScore(_save(orders: List.filled(50, 'o')))),
    );
  });

  test('isFreshGame is true only for an unplayed game', () {
    expect(isFreshGame(_save()), isTrue);
    expect(isFreshGame(_save(orders: ['a'])), isFalse);
    expect(isFreshGame(_save(tasks: ['t'])), isFalse);
    expect(isFreshGame(_save(talents: 5)), isFalse);
    expect(isFreshGame(_save(blessings: 1)), isFalse);
  });

  test('saveFingerprint ignores Manna ticking but sees real progress', () {
    final base = saveFingerprint(_save());
    expect(saveFingerprint(_save(manna: 42, regen: DateTime.utc(2041))), base);
    expect(saveFingerprint(_save(talents: 5)), isNot(base));
    expect(saveFingerprint(_save(orders: ['a'])), isNot(base));
  });

  group('decideSync', () {
    SyncAction decide({
      bool hasCloud = true,
      bool localFresh = false,
      bool hasBase = true,
      bool localChanged = false,
      bool cloudChanged = false,
      bool cloudFresh = false,
    }) => decideSync(
      hasCloud: hasCloud,
      localFresh: localFresh,
      hasBase: hasBase,
      localChanged: localChanged,
      cloudChanged: cloudChanged,
      cloudFresh: cloudFresh,
    );

    test('no cloud save yet: upload', () {
      expect(decide(hasCloud: false, hasBase: false), SyncAction.upload);
      expect(
        decide(hasCloud: false, hasBase: false, localFresh: true),
        SyncAction.upload,
      );
    });

    test('new phone with an unplayed game takes the cloud save', () {
      expect(decide(hasBase: false, localFresh: true), SyncAction.download);
    });

    test('new phone with its own progress asks the player', () {
      expect(decide(hasBase: false), SyncAction.ask);
    });

    test(
      'a lost or reset local game takes the cloud save, even after earlier syncs',
      () {
        // With a sync record this looks like "only this phone changed", which
        // must not upload an empty game over real progress.
        expect(
          decide(localFresh: true, hasBase: true, localChanged: true),
          SyncAction.download,
        );
      },
    );

    test('two unplayed games: nothing to rescue, normal rules apply', () {
      expect(
        decide(localFresh: true, cloudFresh: true, hasBase: false),
        SyncAction.download,
      );
      expect(decide(localFresh: true, cloudFresh: true), SyncAction.nothing);
    });

    test('nothing changed: nothing to do', () {
      expect(decide(), SyncAction.nothing);
    });

    test('only this phone changed: upload', () {
      expect(decide(localChanged: true), SyncAction.upload);
    });

    test('only the cloud changed: download', () {
      expect(decide(cloudChanged: true), SyncAction.download);
    });

    test('both changed: ask the player', () {
      expect(decide(localChanged: true, cloudChanged: true), SyncAction.ask);
    });
  });

  test('cloudIsFurtherOn only when strictly ahead', () {
    expect(cloudIsFurtherOn(_save(), _save(tasks: ['t'])), isTrue);
    expect(cloudIsFurtherOn(_save(tasks: ['t']), _save(tasks: ['t'])), isFalse);
    expect(cloudIsFurtherOn(_save(tasks: ['t']), _save()), isFalse);
  });

  group('SyncBase', () {
    test('survives being written and read back', () {
      final base = SyncBase(
        userId: 'u1',
        cloudUpdatedAt: DateTime.utc(2040, 3, 4, 5, 6),
        localFingerprint: 'abc',
      );
      final back = SyncBase.fromJson(base.toJson());
      expect(back.userId, 'u1');
      expect(back.cloudUpdatedAt, DateTime.utc(2040, 3, 4, 5, 6));
      expect(back.localFingerprint, 'abc');
    });

    test('rejects a record with a missing field', () {
      expect(() => SyncBase.fromJson({'user_id': 'u1'}), throwsFormatException);
    });
  });
}
