import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/game_saver.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a change the triggers cannot see is still written', () async {
    final dir = Directory.systemTemp.createTempSync('joppa_saver');
    final repository = SaveRepository(directory: () async => dir);
    final saver = GameSaver(
      repository: repository,
      snapshot: testSave,
      triggers: [ValueNotifier<int>(0)],
      delay: const Duration(milliseconds: 10),
    )..start();
    saver.markChanged();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await repository.load(), isNotNull);
    await saver.dispose();
  });

  test('a cancelled saver never writes again', () async {
    final dir = Directory.systemTemp.createTempSync('joppa_saver');
    final repository = SaveRepository(directory: () async => dir);
    final saver = GameSaver(
      repository: repository,
      snapshot: testSave,
      triggers: [ValueNotifier<int>(0)],
      delay: const Duration(milliseconds: 10),
    )..start();
    await saver.cancel();
    saver.markChanged();
    await saver.saveNow();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await repository.load(), isNull);
  });
}
