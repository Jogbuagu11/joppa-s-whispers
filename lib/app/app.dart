import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/app/cloud_sync.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/data/sync_base_repository.dart';
import 'package:whispers_of_joppa/game/board/board_cloud.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';
import 'package:whispers_of_joppa/services/supabase_auth_service.dart';

class WhispersApp extends ConsumerWidget {
  const WhispersApp({super.key});

  // One account link for the life of the app.
  static final BoardCloud _cloud = _buildCloud();

  static BoardCloud _buildCloud() {
    final client = Supabase.instance.client;
    final auth = SupabaseAuthService(client);
    return BoardCloud(
      auth: auth,
      sync: CloudSync(
        auth: auth,
        store: SupabaseCloudSaveStore(client),
        bases: SyncBaseRepository(),
      ),
    );
  }

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
      home: BoardScreen(cloud: _cloud),
    );
  }
}
