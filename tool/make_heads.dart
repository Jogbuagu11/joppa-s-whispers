// Cuts each character's head and shoulders out of their full-length
// portrait, with a see-through background, for the order cards.
//
//     dart run tool/make_heads.dart
//
// Reads assets/characters/char_<id>_neutral.jpg and the framing in
// content/characters.json (`face_zoom`), and writes
// assets/characters/head_<id>.png (256 x 256). The plain backdrop behind the
// figure is found by spreading in from the top and side edges; the bottom
// fades out so the shoulders do not end in a hard line.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const _size = 256;
const _defaultZoom = 2.3;

// How different a pixel may be from the backdrop and still count as it.
const _tolerance = 26.0;

// The backdrop is never more than this share of a head-and-shoulders picture.
const _mostBackdrop = 0.62;

void main() {
  final characters =
      jsonDecode(File('content/characters.json').readAsStringSync())
          as List<dynamic>;
  var made = 0;
  for (final entry in characters.cast<Map<String, dynamic>>()) {
    final id = entry['id'] as String;
    final file = File('assets/characters/char_${id}_neutral.jpg');
    if (!file.existsSync()) {
      stdout.writeln('$id: no portrait yet, skipped');
      continue;
    }
    final portrait = img.decodeJpg(file.readAsBytesSync());
    if (portrait == null) {
      stdout.writeln('$id: could not be read, skipped');
      continue;
    }
    final zoom = (entry['face_zoom'] as num?)?.toDouble() ?? _defaultZoom;
    // The same window the game used to show in its ring: the top of the
    // picture, centred, 1/zoom of its width.
    final window = (portrait.width / zoom).round();
    final top = (portrait.width * 0.04 * (1 - 1 / zoom)).round();
    final head = img
        .copyResize(
          img.copyCrop(
            portrait,
            x: (portrait.width - window) ~/ 2,
            y: top,
            width: window,
            height: window,
          ),
          width: _size,
          height: _size,
          interpolation: img.Interpolation.cubic,
        )
        .convert(numChannels: 4);
    // A pale figure on a pale backdrop (white hair on white) can be eaten
    // along with it: if too much went, try again more strictly.
    var cut = head.clone();
    for (var tolerance = _tolerance; tolerance >= 3; tolerance /= 2) {
      cut = head.clone();
      final cleared = _clearBackdrop(cut, tolerance);
      if (cleared <= _mostBackdrop) break;
    }
    _fadeBottom(cut);
    File('assets/characters/head_$id.png').writeAsBytesSync(img.encodePng(cut));
    made++;
  }
  stdout.writeln('Made $made heads.');
}

double _distance(img.Pixel a, List<num> b) =>
    sqrt(pow(a.r - b[0], 2) + pow(a.g - b[1], 2) + pow(a.b - b[2], 2));

/// Makes the backdrop see-through, spreading in from the top and the sides.
/// Returns the share of the picture that was cleared.
double _clearBackdrop(img.Image head, double tolerance) {
  final w = head.width;
  final h = head.height;
  final seen = List.generate(h, (_) => List.filled(w, false));
  final queue = <(int, int, List<num>)>[];
  void seed(int x, int y) {
    final p = head.getPixel(x, y);
    queue.add((x, y, [p.r, p.g, p.b]));
  }

  for (int x = 0; x < w; x++) {
    seed(x, 0);
  }
  // The sides, but not the bottom third, where the shoulders reach the edge.
  for (int y = 0; y < h * 2 ~/ 3; y++) {
    seed(0, y);
    seed(w - 1, y);
  }
  while (queue.isNotEmpty) {
    final (x, y, backdrop) = queue.removeLast();
    if (x < 0 || y < 0 || x >= w || y >= h || seen[y][x]) continue;
    final pixel = head.getPixel(x, y);
    if (_distance(pixel, backdrop) > tolerance) continue;
    seen[y][x] = true;
    // Each step compares with the colour it came from, so a backdrop that
    // changes slowly (a soft grey wall) is followed, but an outline stops it.
    final here = [pixel.r, pixel.g, pixel.b];
    final next = [for (var i = 0; i < 3; i++) (backdrop[i] * 3 + here[i]) / 4];
    queue
      ..add((x + 1, y, next))
      ..add((x - 1, y, next))
      ..add((x, y + 1, next))
      ..add((x, y - 1, next));
  }
  var cleared = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (!seen[y][x]) continue;
      head.setPixelRgba(x, y, 0, 0, 0, 0);
      cleared++;
    }
  }
  // Soften the cut edge by one pixel.
  final alpha = [
    for (int y = 0; y < h; y++)
      [for (int x = 0; x < w; x++) head.getPixel(x, y).a],
  ];
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      if (alpha[y][x] == 0) continue;
      var clear = 0;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        if (alpha[y + dy][x + dx] == 0) clear++;
      }
      if (clear > 0) {
        final p = head.getPixel(x, y);
        head.setPixelRgba(x, y, p.r, p.g, p.b, 255 - clear * 45);
      }
    }
  }
  return cleared / (w * h);
}

/// Fades the last part of the picture out, so the shoulders end softly.
void _fadeBottom(img.Image head) {
  final start = (head.height * 0.82).round();
  for (int y = start; y < head.height; y++) {
    final keep = 1 - (y - start) / (head.height - start);
    for (int x = 0; x < head.width; x++) {
      final p = head.getPixel(x, y);
      head.setPixelRgba(x, y, p.r, p.g, p.b, (p.a * keep).round());
    }
  }
}
