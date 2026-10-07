// Makes one overview picture of a folder of art, so a whole batch can be
// judged at a glance.
// Run from the project folder: dart run tool/art_overview.dart <folder>
//
// Every picture in the folder is shown small, in name order, eight to a row
// (so a "before" sits beside its "after"). The result is written into the
// same folder as "_Overview.jpg".
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.isEmpty) {
    stdout.writeln('Usage: dart run tool/art_overview.dart <folder>');
    exitCode = 64;
    return;
  }
  final folder = Directory(args.first);
  final files = folder.listSync().whereType<File>().where((f) {
    final name = f.uri.pathSegments.last.toLowerCase();
    return !name.startsWith('_') &&
        !name.startsWith('.') &&
        (name.endsWith('.png') || name.endsWith('.jpg'));
  }).toList()..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stdout.writeln('No pictures in ${folder.path}.');
    return;
  }
  const width = 220;
  const perRow = 8;
  final first = img.decodeImage(files.first.readAsBytesSync());
  if (first == null) {
    stdout.writeln('Could not read ${files.first.path}.');
    exitCode = 1;
    return;
  }
  final height = (width * first.height / first.width).round();
  final rows = (files.length / perRow).ceil();
  final columns = files.length < perRow ? files.length : perRow;
  final sheet = img.Image(width: width * columns, height: height * rows);
  img.fill(sheet, color: img.ColorRgb8(26, 18, 5));
  for (var i = 0; i < files.length; i++) {
    final picture = img.decodeImage(files[i].readAsBytesSync());
    if (picture == null) continue;
    img.compositeImage(
      sheet,
      img.copyResize(picture, width: width, height: height),
      dstX: (i % perRow) * width,
      dstY: (i ~/ perRow) * height,
    );
  }
  File(
    '${folder.path}/_Overview.jpg',
  ).writeAsBytesSync(img.encodeJpg(sheet, quality: 85));
  stdout.writeln(
    'Wrote ${folder.path}/_Overview.jpg (${files.length} pictures).',
  );
}
