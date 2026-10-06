// Prepares raw item art for the game.
// Run from the project folder: dart run tool/process_assets.dart
//
// Reads assets_incoming/items/, fixes file names, shrinks each picture to
// 256 x 256 and writes it to assets/items/. Then reports which items still
// have no art and which files it could not use.
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:whispers_of_joppa/data/asset_names.dart';

const _size = 256;

void main() {
  final incoming = Directory('assets_incoming/items');
  final outDir = Directory('assets/items')..createSync(recursive: true);
  final skipped = <String>[];
  var written = 0;

  if (incoming.existsSync()) {
    final files = incoming.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (name.startsWith('.')) continue;
      final base = itemAssetBaseName(name);
      if (base == null) {
        skipped.add('$name (name is not item_<chain>_<two-digit tier>)');
        continue;
      }
      final image = img.decodeImage(file.readAsBytesSync());
      if (image == null) {
        skipped.add('$name (not a picture this tool can read)');
        continue;
      }
      if (image.width != image.height) {
        stdout.writeln('  note: $name is not square; it will be squashed');
      }
      final small = img.copyResize(
        image,
        width: _size,
        height: _size,
        interpolation: img.Interpolation.average,
      );
      // Pictures with a see-through background stay PNG; the rest become JPEG.
      if (image.hasAlpha) {
        File('${outDir.path}/$base.png').writeAsBytesSync(img.encodePng(small));
      } else {
        File(
          '${outDir.path}/$base.jpg',
        ).writeAsBytesSync(img.encodeJpg(small, quality: 88));
      }
      written++;
    }
  }

  _processCharacters(skipped);
  _processScenery(skipped);
  _processGenerators(skipped);

  final available = <String>{};
  for (final f in outDir.listSync().whereType<File>()) {
    final base = itemAssetBaseName(f.uri.pathSegments.last);
    if (base != null) available.add(base);
  }
  final chains =
      jsonDecode(File('content/chains.json').readAsStringSync())
          as List<dynamic>;
  final missing = itemsMissingArt(chains, available);

  stdout.writeln('Processed $written picture(s) into ${outDir.path}.');
  if (skipped.isNotEmpty) {
    stdout.writeln('Skipped ${skipped.length}:');
    for (final s in skipped) {
      stdout.writeln('  - $s');
    }
  }
  stdout.writeln(
    missing.isEmpty
        ? 'Every item has art.'
        : '${missing.length} item(s) still have no art: ${missing.join(', ')}',
  );
}

const _portraitWidth = 512;

/// Shrinks raw portraits from assets_incoming/characters/ into
/// assets/characters/, fixing misspelled names on the way.
void _processCharacters(List<String> skipped) {
  final incoming = Directory('assets_incoming/characters');
  if (!incoming.existsSync()) return;
  final outDir = Directory('assets/characters')..createSync(recursive: true);
  final files = incoming.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final done = <String>{};
  var written = 0;
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    if (name.startsWith('.')) continue;
    final base = characterAssetBaseName(name);
    if (base == null) {
      skipped.add('$name (name is not char_<id>_<expression>)');
      continue;
    }
    if (!done.add(base)) {
      skipped.add('$name (a second picture for $base; the first one was kept)');
      continue;
    }
    final image = img.decodeImage(file.readAsBytesSync());
    if (image == null) {
      skipped.add('$name (not a picture this tool can read)');
      continue;
    }
    final small = img.copyResize(
      image,
      width: _portraitWidth,
      interpolation: img.Interpolation.average,
    );
    if (image.hasAlpha) {
      File('${outDir.path}/$base.png').writeAsBytesSync(img.encodePng(small));
    } else {
      File(
        '${outDir.path}/$base.jpg',
      ).writeAsBytesSync(img.encodeJpg(small, quality: 88));
    }
    written++;
  }
  stdout.writeln('Processed $written portrait(s) into ${outDir.path}.');
}

const _sceneryWidth = 768;

/// Copies location pictures (assets_incoming/locations/) and scene
/// backgrounds (assets_incoming/backgrounds/) into assets/locations/, under
/// the names the game looks for. tool/art_names.json says which raw file is
/// which picture.
void _processScenery(List<String> skipped) {
  final names =
      jsonDecode(File('tool/art_names.json').readAsStringSync())
          as Map<String, dynamic>;
  final outDir = Directory('assets/locations')..createSync(recursive: true);
  var written = 0;
  final done = <String>{};
  void folder(String name, String prefix, {required bool mustBeListed}) {
    final incoming = Directory('assets_incoming/$name');
    if (!incoming.existsSync()) return;
    final known = (names[name] as Map<String, dynamic>).cast<String, String>();
    final files = incoming.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final raw = file.uri.pathSegments.last;
      if (raw.startsWith('.')) continue;
      final base = locationAssetBaseName(raw, known);
      final listed = known.keys.any(raw.startsWith);
      if (base == null || (mustBeListed && !listed)) {
        skipped.add('$raw (not listed in tool/art_names.json)');
        continue;
      }
      if (!done.add('$prefix$base')) {
        skipped.add('$raw (a second picture for $prefix$base; first kept)');
        continue;
      }
      final image = img.decodeImage(file.readAsBytesSync());
      if (image == null) {
        skipped.add('$raw (not a picture this tool can read)');
        continue;
      }
      final sized = image.width > _sceneryWidth
          ? img.copyResize(
              image,
              width: _sceneryWidth,
              interpolation: img.Interpolation.average,
            )
          : image;
      File(
        '${outDir.path}/$prefix$base.jpg',
      ).writeAsBytesSync(img.encodeJpg(sized, quality: 85));
      written++;
    }
  }

  folder('locations', '', mustBeListed: false);
  folder('backgrounds', 'bg_', mustBeListed: true);
  stdout.writeln('Processed $written location picture(s) into ${outDir.path}.');
}

/// Shrinks generator pictures (assets_incoming/generators/, one per level,
/// named `gen_<name>_l<level>`) into assets/generators/.
void _processGenerators(List<String> skipped) {
  final incoming = Directory('assets_incoming/generators');
  if (!incoming.existsSync()) return;
  final names =
      jsonDecode(File('tool/art_names.json').readAsStringSync())
          as Map<String, dynamic>;
  final other = (names['generators'] as Map<String, dynamic>? ?? const {})
      .cast<String, String>();
  final outDir = Directory('assets/generators')..createSync(recursive: true);
  final files = incoming.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final done = <String>{};
  for (final file in files) {
    final raw = file.uri.pathSegments.last;
    if (raw.startsWith('.')) continue;
    final base = generatorAssetBaseName(raw, other);
    if (base == null) {
      skipped.add('$raw (name is not gen_<name>_l<level>)');
      continue;
    }
    if (!done.add(base)) {
      skipped.add('$raw (a second picture for $base; the first one was kept)');
      continue;
    }
    final image = img.decodeImage(file.readAsBytesSync());
    if (image == null) {
      skipped.add('$raw (not a picture this tool can read)');
      continue;
    }
    final small = img.copyResize(
      image,
      width: _size,
      height: _size,
      interpolation: img.Interpolation.average,
    );
    File(
      '${outDir.path}/$base.jpg',
    ).writeAsBytesSync(img.encodeJpg(small, quality: 88));
  }
  stdout.writeln('Processed ${done.length} generator picture(s).');
}
