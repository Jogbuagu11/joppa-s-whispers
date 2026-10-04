import 'package:flutter/material.dart';

/// The main game board screen. In Milestone 0 this is a blank placeholder.
/// The Flame game widget is added in Milestone 1.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('board_screen'),
      backgroundColor: Color(0xFF1A1205),
      body: SizedBox.expand(),
    );
  }
}
