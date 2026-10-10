// One pack in the Joppa Special pop-up.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

const _cream = Color(0xFFF7ECD2);

/// One pack: its name, its Pearls drawn as a heap, how many, and its price
/// on a green button. The featured one stands taller, with a star.
class SpecialPackCard extends StatelessWidget {
  const SpecialPackCard({
    super.key,
    required this.name,
    required this.pearls,
    required this.pearlsWord,
    required this.price,
    required this.featured,
    required this.size,
    required this.onBuy,
  });

  final String name;
  final int pearls;
  final String pearlsWord;
  final String price;
  final bool featured;

  /// 0 for the smallest pack, 1 the next… (how big a heap is drawn).
  final int size;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: EdgeInsets.fromLTRB(6, featured ? 22 : 14, 6, 10),
          decoration: BoxDecoration(
            color: featured ? const Color(0xFFFFF4D6) : _cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: featured ? GamePalette.gold : GamePalette.panelEdge,
              width: featured ? 3 : 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5B3A12),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: featured ? 62 : 52,
                child: CustomPaint(
                  size: const Size(double.infinity, 62),
                  painter: _PearlHeapPainter(4 + size * 3),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$pearls',
                key: const Key('special_pack_pearls'),
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: const Color(0xFF3A2408),
                  fontSize: featured ? 26 : 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                pearlsWord,
                style: const TextStyle(
                  color: Color(0xFF7A5A22),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('special_pack_buy'),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    backgroundColor: GamePalette.action,
                    foregroundColor: GamePalette.onAction,
                    side: const BorderSide(
                      color: GamePalette.actionEdge,
                      width: 1.5,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: onBuy,
                  child: FittedBox(child: Text(price)),
                ),
              ),
            ],
          ),
        ),
        if (featured)
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: GamePalette.gold,
              shape: BoxShape.circle,
              border: Border.all(color: GamePalette.talents, width: 2),
            ),
            child: const Icon(
              Icons.star,
              size: 18,
              color: GamePalette.backgroundBottom,
            ),
          ),
      ],
    ),
  );
}

/// A little heap of Pearls: more of them for a bigger pack.
class _PearlHeapPainter extends CustomPainter {
  const _PearlHeapPainter(this.count);

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 8.5;
    final rows = <int>[];
    var left = count;
    for (var row = 4; left > 0; row--) {
      final inRow = left < row ? left : (row < 1 ? 1 : row);
      rows.add(inRow);
      left -= inRow;
    }
    var y = size.height - radius - 2;
    for (final inRow in rows) {
      final width = inRow * radius * 1.9;
      var x = (size.width - width) / 2 + radius;
      for (var i = 0; i < inRow; i++) {
        final at = Offset(x, y);
        canvas.drawCircle(
          at.translate(0, 2),
          radius,
          Paint()..color = const Color(0x33000000),
        );
        canvas.drawCircle(at, radius, Paint()..color = const Color(0xFFE9D3C4));
        canvas.drawCircle(
          at,
          radius,
          Paint()
            ..color = const Color(0xFFB79A88)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        // Its gleam.
        canvas.drawCircle(
          at.translate(-2.6, -2.8),
          2.4,
          Paint()..color = const Color(0xFFFFFFFF),
        );
        x += radius * 1.9;
      }
      y -= radius * 1.55;
    }
  }

  @override
  bool shouldRepaint(_PearlHeapPainter old) => old.count != count;
}
