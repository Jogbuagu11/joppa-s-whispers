// Real and deliberately broken content bundles for tests.
import 'dart:convert';
import 'dart:io';

import 'package:whispers_of_joppa/data/content_bundle.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

/// The real content shipped in the app, at the given version.
ContentBundle realContent({int version = 1, int format = 1}) => ContentBundle(
  version: version,
  format: format,
  files: {for (final name in contentFileNames) name: _read(name)},
);

/// A bundle that parses but breaks a content rule.
ContentBundle brokenContent(int version) {
  final files = Map<String, Object?>.of(realContent().files);
  files['economy'] = {'max_manna': 0};
  return ContentBundle(version: version, format: 1, files: files);
}
