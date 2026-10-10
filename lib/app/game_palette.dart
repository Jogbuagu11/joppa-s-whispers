// The game's colours in one place: warm wood, gold and parchment, with a few
// quiet earth tones so each thing on the board can be told apart.
import 'package:flutter/material.dart';

abstract final class GamePalette {
  /// Behind everything: dark lamplit wood.
  static const background = Color(0xFF1C1408);
  static const backgroundBottom = Color(0xFF140D05);

  /// Panels (bars and cards) and their edges.
  static const panel = Color(0xFF2A1F0C);
  static const panelLight = Color(0xFF3B2B12);
  static const panelEdge = Color(0xFF7A5A22);

  static const muted = Color(0xFFC9B58A);

  /// Talents: gold coins.
  static const talents = Color(0xFFE9B44C);

  /// Blessings: olive-leaf green.
  static const blessings = Color(0xFFA9C47F);

  /// Pearls: pearl white with a touch of rose.
  static const pearls = Color(0xFFF1DDD0);

  /// Manna: honey.
  static const manna = Color(0xFFF2CE7E);

  /// Levels and titles: the game's own gold.
  static const level = Color(0xFFE9993A);
  static const gold = Color(0xFFD4802A);

  /// The main button of a pop-up or a screen: leaf green, with its words in
  /// [onAction]. (Jennifer, 2026-10-10: coloured, not mustard.)
  static const action = Color(0xFF4E8A3A);
  static const actionEdge = Color(0xFF7FB85F);
  static const onAction = Color(0xFFFFF8E7);

  /// "Ready": something can be done right now (olive green).
  static const ready = Color(0xFF8DB255);

  /// A character's colour (their portrait ring and card tint) when the
  /// content does not give one.
  static const person = Color(0xFFD9B36C);
}
