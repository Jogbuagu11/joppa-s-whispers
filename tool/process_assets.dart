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
