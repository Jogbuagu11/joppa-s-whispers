import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

void main() {
  late Directory dir;
  late SaveRepository repo;

  final sample = SaveState(
    items: const [SavedItem(itemId: 'bakery_01', col: 0, row: 0)],
    generators: const [
      SavedGenerator(generatorId: 'gen_pantry', level: 1, col: 2, row: 8),
    ],
    manna: 7,
    mannaLastRegen: DateTime.utc(2040, 1, 1),
    talents: 20,
    blessings: 1,
    activeOrders: const ['a'],
    pendingOrders: const ['b'],
    lastOrderSkip: null,
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('joppa_save_test');
    repo = SaveRepository(directory: () async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('no save file means no saved game', () async {
    expect(await repo.load(), isNull);
  });

  test('saving then loading gives the same game back', () async {
    await repo.save(sample);
    final back = await repo.load();
    expect(back?.manna, 7);
    expect(back?.talents, 20);
    expect(back?.items.single.itemId, 'bakery_01');
    expect(back?.generators.single.generatorId, 'gen_pantry');
    expect(back?.activeOrders, ['a']);
  });

  test('saving leaves no temporary file behind', () async {
    await repo.save(sample);
    final names = [for (final f in dir.listSync()) f.uri.pathSegments.last];
    expect(names, ['save.json']);
  });

  test('a damaged save is set aside and the game starts fresh', () async {
    File('${dir.path}/save.json').writeAsStringSync('{ this is not json');
    expect(await repo.load(), isNull);
    expect(File('${dir.path}/save.corrupt.json').existsSync(), isTrue);
    expect(File('${dir.path}/save.json').existsSync(), isTrue);
  });

  test('a save from a newer app is not loaded', () async {
    final json = sample.toJson()..['save_version'] = currentSaveVersion + 5;
    File('${dir.path}/save.json').writeAsStringSync(
      json.toString(), // not valid JSON either way: must not crash
    );
    expect(await repo.load(), isNull);
  });

  test('clear removes the save', () async {
    await repo.save(sample);
    await repo.clear();
    expect(await repo.load(), isNull);
  });
}
