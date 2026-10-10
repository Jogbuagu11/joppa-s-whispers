// The pieces of the Joppa Special pop-up: its pictured header with a ribbon,
// a pack card, and the round close button.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

const _cream = Color(0xFFF7ECD2);
const _ribbon = Color(0xFF9C3D2A);
const _ribbonDark = Color(0xFF6E2A1C);

/// The harbor at evening with the title on a ribbon across it.
class SpecialHeader extends StatelessWidget {
  const SpecialHeader({
    super.key,
    required this.picture,
    required this.title,
    required this.subtitle,
  });

  final String picture;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 132,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              picture,
              fit: BoxFit.cover,
              alignment: const Alignment(-0.3, -0.6),
              errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: GamePalette.panelLight),
            ),
            // A dark foot to the picture, so the ribbon stands out.
            const Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 46,
                width: double.infinity,
                child: ColoredBox(color: Color(0x991C1408)),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.72),
              child: CustomPaint(
                painter: const _RibbonPainter(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(34, 7, 34, 9),
                  child: Text(
                    title,
                    key: const Key('special_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _cream,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      shadows: [
                        Shadow(blurRadius: 4, color: Color(0xAA000000)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Container(
        width: double.infinity,
        color: GamePalette.panelLight,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: GamePalette.talents,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

/// A ribbon with notched ends and a gold edge.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const notch = 14.0;
    final shape = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - notch, size.height / 2)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(notch, size.height / 2)
      ..close();
    canvas.drawShadow(shape, const Color(0xFF000000), 5, false);
    canvas.drawPath(shape, Paint()..color = _ribbon);
    // A darker band along the foot, and a gold line round it.
    canvas.drawRect(
      Rect.fromLTWH(notch, size.height - 5, size.width - 2 * notch, 5),
      Paint()..color = _ribbonDark,
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = GamePalette.talents
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => false;
}

/// The round cross at the pop-up's corner.
class SpecialClose extends StatelessWidget {
  const SpecialClose({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: MaterialLocalizations.of(context).closeButtonLabel,
    child: Material(
      color: _ribbon,
      shape: const CircleBorder(
        side: BorderSide(color: GamePalette.talents, width: 2),
      ),
      elevation: 4,
      child: InkWell(
        key: const Key('special_close'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.close, size: 20, color: _cream),
        ),
      ),
    ),
  );
}
