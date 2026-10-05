import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/scenes.dart';

void main() {
  final scene = SceneModel.fromJson({
    'id': 'ch1_s_01',
    'background': 'loc_harbor_dusk',
    'lines': [
      {'speaker': 'dockworker', 'expression': 'neutral', 'text': 'One.'},
      {'speaker': 'silas', 'expression': 'happy', 'text': 'Two.'},
      {'speaker': 'naomi', 'expression': 'sad', 'text': 'Three.'},
    ],
  });

  test('fromJson reads the scene', () {
    expect(scene.id, 'ch1_s_01');
    expect(scene.background, 'loc_harbor_dusk');
    expect(scene.lines.length, 3);
    expect(scene.lines[1].speaker, 'silas');
    expect(scene.lines[1].expression, 'happy');
    expect(scene.lines[1].text, 'Two.');
  });

  group('ScenePosition', () {
    test('starts on the first line', () {
      final p = ScenePosition(scene);
      expect(p.line?.text, 'One.');
      expect(p.isLastLine, isFalse);
    });

    test('next walks through every line, then ends', () {
      final second = ScenePosition(scene).next();
      expect(second?.line?.text, 'Two.');
      final third = second?.next();
      expect(third?.line?.text, 'Three.');
      expect(third?.isLastLine, isTrue);
      expect(third?.next(), isNull);
    });

    test('a scene with no lines is over at once', () {
      const empty = SceneModel(id: 'e', background: 'loc_x', lines: []);
      const p = ScenePosition(empty);
      expect(p.line, isNull);
      expect(p.isLastLine, isTrue);
      expect(p.next(), isNull);
    });
  });

  group('portraitAssetFor', () {
    const available = {
      'assets/characters/char_silas_happy.jpg',
      'assets/characters/char_silas_neutral.jpg',
      'assets/characters/char_naomi_neutral.png',
    };

    test('uses the exact expression when it exists', () {
      expect(
        portraitAssetFor('silas', 'happy', available),
        'assets/characters/char_silas_happy.jpg',
      );
    });

    test('falls back to neutral', () {
      expect(
        portraitAssetFor('silas', 'angry', available),
        'assets/characters/char_silas_neutral.jpg',
      );
      expect(
        portraitAssetFor('naomi', 'happy', available),
        'assets/characters/char_naomi_neutral.png',
      );
    });

    test('is null for a character with no portraits', () {
      expect(portraitAssetFor('dockworker', 'neutral', available), isNull);
    });
  });

  test('backgroundAssetFor finds bg_<id> in any allowed format', () {
    const available = {'assets/locations/bg_loc_market.webp'};
    expect(
      backgroundAssetFor('loc_market', available),
      'assets/locations/bg_loc_market.webp',
    );
    expect(backgroundAssetFor('loc_well', available), isNull);
  });
}
