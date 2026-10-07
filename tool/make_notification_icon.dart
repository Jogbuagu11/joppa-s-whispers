// Makes the Android notification icon from a black-and-white picture.
// Run from the project folder:
//   dart run tool/make_notification_icon.dart <picture>
//
// Android draws a notification icon from its shape only, so it must be a
// white shape on a see-through background. The picture given is a white
// shape on black: its brightness becomes how solid each dot is. The shape is
// trimmed, centred with a small margin and written at every screen density
// to android/app/src/main/res/drawable-*/ic_notification.png.
import 'dart:io';

import 'package:image/image.dart' as img;

const _sizes = {
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

void main(List<String> args) {
  if (args.isEmpty) {
    stdout.writeln(
      'Usage: dart run tool/make_notification_icon.dart <picture>',
    );
    exitCode = 64;
    return;
  }
  final source = img.decodeImage(File(args.first).readAsBytesSync());
  if (source == null) {
    stdout.writeln('Could not read ${args.first}.');
    exitCode = 1;
    return;
  }
  // The box around everything bright.
  var left = source.width, top = source.height, right = -1, bottom = -1;
  for (final pixel in source) {
    if (pixel.luminanceNormalized > 0.5) {
      if (pixel.x < left) left = pixel.x;
      if (pixel.x > right) right = pixel.x;
      if (pixel.y < top) top = pixel.y;
      if (pixel.y > bottom) bottom = pixel.y;
    }
  }
  if (right < left || bottom < top) {
    stdout.writeln('The picture has no bright shape in it.');
    exitCode = 1;
    return;
  }
  final side = (right - left > bottom - top ? right - left : bottom - top) + 1;
  final padded = (side * 1.15).round();
  final square = img.Image(width: padded, height: padded, numChannels: 4);
  final offsetX = (padded - (right - left + 1)) ~/ 2;
  final offsetY = (padded - (bottom - top + 1)) ~/ 2;
  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      final alpha = (source.getPixel(x, y).luminanceNormalized * 255).round();
      square.setPixelRgba(
        x - left + offsetX,
        y - top + offsetY,
        255,
        255,
        255,
        alpha,
      );
    }
  }
  for (final entry in _sizes.entries) {
    final out = File(
      'android/app/src/main/res/drawable-${entry.key}/ic_notification.png',
    )..parent.createSync(recursive: true);
    out.writeAsBytesSync(
      img.encodePng(
        img.copyResize(
          square,
          width: entry.value,
          height: entry.value,
          interpolation: img.Interpolation.average,
        ),
      ),
    );
  }
  stdout.writeln('Wrote ic_notification.png at ${_sizes.length} sizes.');
}
