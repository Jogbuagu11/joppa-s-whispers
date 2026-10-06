// Packs content/ into one bundle file the server can hand out.
// Run from the project folder: dart run tool/build_content_bundle.dart
//
// It refuses to build if the content has any problem. The file is written to
// build/content/content_v<version>.json; uploading it to the `content` storage
// bucket and adding a row to `content_versions` releases it to players.
import 'dart:convert';
import 'dart:io';

import 'package:whispers_of_joppa/data/content_bundle.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

void main() {
  final manifest = _read('version') as Map<String, dynamic>;
  final bundle = ContentBundle(
    version: manifest['version'] as int,
    format: manifest['format'] as int,
    files: {for (final name in contentFileNames) name: _read(name)},
  );
  final problems = bundle.problems();
  if (problems.isNotEmpty) {
    stdout.writeln('Not built: ${problems.length} content problem(s):');
    for (final problem in problems) {
      stdout.writeln('  - $problem');
    }
    exitCode = 1;
    return;
  }
  final out = File('build/content/content_v${bundle.version}.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(bundle.toJson()));
  stdout.writeln(
    'Built ${out.path} (version ${bundle.version}, '
    '${(out.lengthSync() / 1024).toStringAsFixed(0)} KB)',
  );
}
