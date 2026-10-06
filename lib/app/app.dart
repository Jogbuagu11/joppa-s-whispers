import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/app/cloud_sync.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';
import 'package:whispers_of_joppa/data/supabase_remote_content.dart';
import 'package:whispers_of_joppa/data/sync_base_repository.dart';
import 'package:whispers_of_joppa/game/board/board_cloud.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';
import 'package:whispers_of_joppa/services/ad_service.dart';
import 'package:whispers_of_joppa/services/google_rewarded_ads.dart';
import 'package:whispers_of_joppa/services/in_app_purchase_store.dart';
import 'package:whispers_of_joppa/services/purchase_backend.dart';
import 'package:whispers_of_joppa/services/supabase_auth_service.dart';

class WhispersApp extends ConsumerWidget {
  const WhispersApp({super.key});

  /// Device tests set this to false before starting the app, so a test run
  /// can never sign in, sync with, or change anything in the live backend,
  /// and never loads a real ad.
  static bool accountsEnabled = true;

  // Content: the app's own, replaced by newer server content when available.
  static final ContentRepository _content = ContentRepository(
    loadBundled: loadBundledContent,
    remote: SupabaseRemoteContent(Supabase.instance.client),
  );

  // Purchases: the store's payment sheet, checked by the server.
  static final PurchaseCoordinator _shop = PurchaseCoordinator(
    store: InAppPurchaseStore(),
    backend: SupabasePurchaseBackend(Supabase.instance.client),
  );

  // Optional rewarded ads (bonus Manna). Never shown unless asked for.
  static final AdService _ads = GoogleRewardedAds();

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
      home: accountsEnabled
          ? BoardScreen(
              cloud: _cloud,
              content: _content,
              shop: _shop,
              ads: _ads,
            )
          : const BoardScreen(),
    );
  }
}
