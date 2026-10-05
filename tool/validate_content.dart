// Checks every file in content/ and lists any problems in plain English.
// Run from the project folder: dart run tool/validate_content.dart
import 'dart:convert';
import 'dart:io';

import 'package:whispers_of_joppa/data/content_validator.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

void main() {
  final problems = validateContent(
    chainsJson: _read('chains'),
    generatorsJson: _read('generators'),
    economyJson: _read('economy'),
    startingBoardJson: _read('starting_board'),
    ordersJson: _read('orders'),
    charactersJson: _read('characters'),
  );
  if (problems.isEmpty) {
    stdout.writeln('Content OK');
    return;
  }
  stdout.writeln('${problems.length} content problem(s):');
  for (final problem in problems) {
    stdout.writeln('  - $problem');
  }
  exitCode = 1;
}
