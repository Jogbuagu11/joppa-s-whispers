// The new player's spotlight: a dim veil over the screen with the thing to
// touch next left bright, and a hand that shows the tap or the drag. It is
// only drawn; touches pass straight through to the game.
import 'package:flutter/material.dart';

/// What to light up: one or two places on the screen. With [drag], a hand
/// moves from the first to the second.
class SpotlightTargets {
  final List<Rect> rects;
  final bool drag;

  const SpotlightTargets(this.rects, {this.drag = false});
}

class TutorialSpotlight extends StatefulWidget {
  const TutorialSpotlight({
    super.key,
    required this.targets,
    required this.relayout,
    this.alwaysLit,
    this.enabled,
  });

  /// The places to light up right now, in screen coordinates.
  final SpotlightTargets Function() targets;

  /// Other places kept bright while the veil is up (the hint itself).
  final List<Rect> Function()? alwaysLit;

  /// False while the veil should stay away (something else is open).
  final bool Function()? enabled;

  /// Fires when the targets may have changed.
  final Listenable relayout;

  @override
  State<TutorialSpotlight> createState() => _TutorialSpotlightState();
}

class _TutorialSpotlightState extends State<TutorialSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hand = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  SpotlightTargets _targets = const SpotlightTargets([]);
  List<Rect> _lit = const [];

  @override
  void initState() {
    super.initState();
    widget.relayout.addListener(_refreshSoon);
    _refreshSoon();
  }

  @override
  void didUpdateWidget(TutorialSpotlight old) {
    super.didUpdateWidget(old);
    if (old.relayout != widget.relayout) {
      old.relayout.removeListener(_refreshSoon);
      widget.relayout.addListener(_refreshSoon);
    }
    _refreshSoon();
  }

  @override
  void dispose() {
    widget.relayout.removeListener(_refreshSoon);
    _hand.dispose();
    super.dispose();
  }

  /// Looks again once the screen has been laid out (and once more a little
  /// later, after anything that was sliding has come to rest).
  void _refreshSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    Future<void>.delayed(const Duration(milliseconds: 450), _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    final on = widget.enabled?.call() ?? true;
    final targets = on ? widget.targets() : const SpotlightTargets([]);
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero)
        : Offset.zero;
    List<Rect> local(List<Rect> rects) => [
      for (final r in rects) r.shift(-origin),
    ];
    setState(() {
      _targets = SpotlightTargets(local(targets.rects), drag: targets.drag);
      _lit = targets.rects.isEmpty
          ? const []
          : local(widget.alwaysLit?.call() ?? const []);
    });
    // The hand only moves while there is something to point at.
    if (_targets.rects.isEmpty) {
      _hand.stop();
    } else if (!_hand.isAnimating) {
      _hand.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targets.rects.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        key: const Key('tutorial_spotlight'),
        animation: _hand,
        builder: (context, _) => CustomPaint(
          painter: _SpotlightPainter(_targets, _lit, _hand.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.targets, this.lit, this.t);

  final SpotlightTargets targets;
  final List<Rect> lit;

  /// 0 to 1, over and over.
  final double t;

  static final _veil = Paint()..color = const Color(0x99000000);
  static final _ring = Paint()
    ..color = const Color(0xFFF2CE7E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _clear = Paint()..blendMode = BlendMode.clear;

  @override
  void paint(Canvas canvas, Size size) {
    RRect hole(Rect r) =>
        RRect.fromRectAndRadius(r.inflate(4), const Radius.circular(12));
    // The veil, with holes cut for everything that stays bright.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, _veil);
    for (final r in [...targets.rects, ...lit]) {
      canvas.drawRRect(hole(r), _clear);
    }
    canvas.restore();
    // A gold ring round each thing to touch, gently pulsing.
    final pulse = 1 + 2 * (t < 0.5 ? t : 1 - t);
    for (final r in targets.rects) {
      canvas.drawRRect(hole(r).inflate(pulse), _ring);
    }
    _paintHand(canvas, _handPoint());
  }

  /// Where the hand's fingertip is: tapping on the one target, or carrying
  /// the first onto the second.
  Offset _handPoint() {
    final first = targets.rects.first.center;
    if (!targets.drag || targets.rects.length < 2) {
      // A small press and release.
      final press = t < 0.5 ? t * 2 : (1 - t) * 2;
      return first + Offset(0, 10 * (1 - press));
    }
    final second = targets.rects[1].center;
    // Pause on the first, glide to the second, pause, start again.
    final glide = ((t - 0.15) / 0.6).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(glide);
    return Offset.lerp(first, second, eased) ?? first;
  }

  void _paintHand(Canvas canvas, Offset tip) {
    const icon = Icons.touch_app;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 44,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // The fingertip of the icon is near its top, a little left of centre.
    painter.paint(
      canvas,
      tip - Offset(painter.width * 0.42, painter.height * 0.1),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.t != t || old.targets != targets || old.lit != lit;
}
