import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

SaveState _save({Map<String, dynamic> extras = const {}}) => SaveState(
  items: const [],
  generators: const [],
  manna: 10,
  mannaLastRegen: DateTime.utc(2026, 10, 10),
  talents: 0,
  blessings: 0,
  activeOrders: const [],
  pendingOrders: const [],
  completedOrders: const [],
  completedTasks: const [],
  tutorialStep: 0,
  lastOrderSkip: null,
  extras: extras,
);

void main() {
  test('a feature reads back the record it wrote, and a write asks for a '
      'save', () {
    final extras = SaveExtras();
    var saves = 0;
    extras.addListener(() => saves++);
    expect(extras.read('wheel'), isNull);
    extras.write('wheel', {'day': '2026-10-10', 'free': 1});
    expect(extras.read('wheel'), {'day': '2026-10-10', 'free': 1});
    expect(saves, 1);
    expect(extras.all, {
      'wheel': {'day': '2026-10-10', 'free': 1},
    });
    extras.dispose();
  });

  test('records of features this build does not know are kept as they '
      'are; something that is not a record reads as nothing', () {
    final extras = SaveExtras({
      'later_feature': {'a': 1},
      'odd': 7,
    })..write('wheel', {'free': 1});
    expect(extras.read('odd'), isNull);
    expect(extras.all['later_feature'], {'a': 1});
    expect(extras.all['odd'], 7);
    extras.dispose();
  });

  test('extras survive the save file; an older save has none', () {
    final written = _save(
      extras: {
        'wheel': {'free': 1},
      },
    ).toJson();
    expect(SaveState.fromJson(written).extras, {
      'wheel': {'free': 1},
    });
    final old = _save().toJson();
    expect(old.containsKey('extras'), isFalse);
    expect(SaveState.fromJson(old).extras, isEmpty);
  });
}
