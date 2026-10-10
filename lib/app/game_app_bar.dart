// The title bar every screen but the board shares: the game's evening
// harbor behind the title, as on the board.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

const _picture = 'assets/ui/board_header.jpg';

/// A title bar with the harbor picture behind it.
AppBar gameAppBar(Widget title) => AppBar(
  backgroundColor: GamePalette.backgroundBottom,
  foregroundColor: const Color(0xFFF7ECD2),
  systemOverlayStyle: SystemUiOverlayStyle.light,
  centerTitle: true,
  title: DefaultTextStyle.merge(
    style: const TextStyle(
      color: Color(0xFFF7ECD2),
      fontSize: 20,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(blurRadius: 8, color: Color(0xE6000000))],
    ),
    child: title,
  ),
  iconTheme: const IconThemeData(
    color: Color(0xFFF7ECD2),
    shadows: [Shadow(blurRadius: 8, color: Color(0xE6000000))],
  ),
  flexibleSpace: Image.asset(
    _picture,
    fit: BoxFit.cover,
    // The sky and the lit tower: the top-left of the picture.
    alignment: const Alignment(-0.4, -0.75),
    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
  ),
);
