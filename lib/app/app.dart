import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';

class WhispersApp extends ConsumerWidget {
  const WhispersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lock portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
      title: 'Whispers of Joppa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B6914)),
        useMaterial3: true,
      ),
      home: const BoardScreen(),
    );
  }
}
