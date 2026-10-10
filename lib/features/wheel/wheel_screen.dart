// The Blessing Wheel (EXPANSION 20.4): a free spin a day, more for an ad or
// for Pearls. Every prize and its chance is listed under the wheel.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_app_bar.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/wheel.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_controller.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_odds.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_painter.dart';

class WheelScreen extends StatefulWidget {
  const WheelScreen({
    super.key,
    required this.controller,
    required this.text,
    this.below,
  });

  /// Shown under the wheel (the jars that can be bought).
  final Widget? below;

  final WheelController controller;

  /// The wording, from content/chance.json.
  final Map<String, String> text;

  @override
  State<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// Turns of the wheel (1 = once round) at the start and end of the spin
  /// being shown.
  double _from = 0;
  double _to = 0;
  bool _spinning = false;

  WheelController get _wheel => widget.controller;
  String _t(String key) => widget.text[key] ?? '';

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  Future<void> _spin(SpinKind kind) async {
    if (_spinning) return;
    setState(() => _spinning = true);
    try {
      final prize = await _wheel.spin(kind);
      if (prize == null || !mounted) return;
      // Turn so that the prize's slice comes to rest under the pointer.
      final odds = _wheel.freeOdds;
      final index = odds.indexWhere((o) => o.prize.id == prize.id);
      final rest = index < 0 ? 0.0 : 1 - sliceMiddle(odds, index);
      _from = _to;
      _to = _from.floorToDouble() + 4 + rest;
      await _turn.forward(from: 0);
      if (!mounted) return;
      await showPrize(context, text: widget.text, prize: prize);
    } finally {
      if (mounted) setState(() => _spinning = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('wheel_screen'),
    backgroundColor: GamePalette.background,
    appBar: gameAppBar(Text(_t('wheel_title'))),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _wheel,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Center(child: _wheelPicture()),
            const SizedBox(height: 12),
            ..._buttons(),
            const SizedBox(height: 8),
            OddsList(
              title: _t('odds_free'),
              odds: _wheel.freeOdds,
              numbered: true,
            ),
            Align(
              child: TextButton(
                key: const Key('wheel_see_odds'),
                onPressed: () => showWheelOdds(
                  context,
                  text: widget.text,
                  free: _wheel.freeOdds,
                  // No Pearl spins here: nothing to show for them.
                  paid: _wheel.paidAllowed ? _wheel.paidOdds : const [],
                ),
                child: Text(
                  _t('see_odds'),
                  style: const TextStyle(
                    color: GamePalette.talents,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            ?widget.below,
          ],
        ),
      ),
    ),
  );

  Widget _wheelPicture() => SizedBox(
    width: 240,
    height: 252,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 12,
          child: AnimatedBuilder(
            animation: _turn,
            builder: (context, child) => Transform.rotate(
              angle:
                  2 *
                  pi *
                  (_from +
                      (_to - _from) *
                          Curves.easeOutCubic.transform(_turn.value)),
              child: child,
            ),
            child: CustomPaint(
              key: const Key('wheel'),
              size: const Size.square(240),
              painter: WheelPainter(_wheel.freeOdds),
            ),
          ),
        ),
        // The pointer the prize comes to rest under.
        const Icon(Icons.arrow_drop_down, size: 40, color: Color(0xFFF7ECD2)),
      ],
    ),
  );

  List<Widget> _buttons() {
    final price = _wheel.pearlSpinPrice;
    final idle = !_spinning && !_wheel.busy;
    final buttons = [
      if (_wheel.freeSpins > 0)
        _button('wheel_spin_free', _t('spin_free'), idle, SpinKind.free),
      if (_wheel.adSpinOffered || (_wheel.busy && _wheel.adSpins > 0))
        _button('wheel_spin_ad', _t('spin_ad'), idle, SpinKind.ad),
      if (price != null)
        _button(
          'wheel_spin_pearls',
          _t('spin_pearls').replaceAll('{pearls}', '$price'),
          // Greyed out without the Pearls for it.
          idle && _wheel.pearls() >= price,
          SpinKind.pearls,
        ),
    ];
    // Nothing to spin with just now (all used, or no ad ready): say so
    // rather than show an empty space.
    return buttons.isNotEmpty
        ? buttons
        : [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _t('spins_done'),
                key: const Key('wheel_done'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: GamePalette.muted),
              ),
            ),
          ];
  }

  Widget _button(String key, String label, bool enabled, SpinKind kind) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: FilledButton(
          key: Key(key),
          style: FilledButton.styleFrom(
            backgroundColor: GamePalette.gold,
            foregroundColor: GamePalette.backgroundBottom,
            disabledBackgroundColor: GamePalette.panelLight,
            disabledForegroundColor: GamePalette.muted,
          ),
          onPressed: enabled ? () => _spin(kind) : null,
          child: Text(label),
        ),
      );
}
