import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whispers_of_joppa/app/config.dart';
import 'package:whispers_of_joppa/app/cloud_sync.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/data/comfort_prefs_repository.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/data/notification_prefs_repository.dart';
import 'package:whispers_of_joppa/data/supabase_remote_events.dart';
import 'package:whispers_of_joppa/data/supabase_remote_content.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/data/sync_base_repository.dart';
import 'package:whispers_of_joppa/game/board/board_cloud.dart';
import 'package:whispers_of_joppa/game/board/board_screen.dart';
import 'package:whispers_of_joppa/features/settings/comfort_controller.dart';
import 'package:whispers_of_joppa/features/settings/notifications_controller.dart';
import 'package:whispers_of_joppa/services/ad_service.dart';
import 'package:whispers_of_joppa/services/analytics_service.dart';
import 'package:whispers_of_joppa/services/google_rewarded_ads.dart';
import 'package:whispers_of_joppa/services/device_feedback_player.dart';
import 'package:whispers_of_joppa/services/device_notification_service.dart';
import 'package:whispers_of_joppa/services/in_app_purchase_store.dart';
import 'package:whispers_of_joppa/services/purchase_backend.dart';
import 'package:whispers_of_joppa/services/supabase_auth_service.dart';
import 'package:whispers_of_joppa/services/supabase_device_tokens.dart';

final _log = Logger('App');

class WhispersApp extends ConsumerWidget {
  const WhispersApp({super.key});

  /// Device tests set this to false before starting the app, so a test run
  /// can never sign in, sync with, or change anything in the live backend,
  /// and never loads a real ad.
  static bool accountsEnabled = true;

  /// Analytics and crash reports; set by main() once Firebase has started.
  /// Null (in tests, or if Firebase could not start) means nothing is sent.
  static Analytics? analytics;

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

  // Notifications: reminders on the phone, and push topics.
  static final NotificationsController _notifications = NotificationsController(
    service: DeviceNotificationService(pushAvailable: analytics != null),
    repository: NotificationPrefsRepository(),
    tokens: SupabaseDeviceTokens(Supabase.instance.client),
  );

  // Sound, vibration and tier numbers, each with its own switch.
  static final ComfortController _comfort = ComfortController(
    player: DeviceFeedbackPlayer(),
    repository: ComfortPrefsRepository(),
  );

  // Events: from the server, with the app's own file as the fallback.
  static final EventsRepository _events = EventsRepository(
    loadBundled: loadBundledEvents,
    remote: SupabaseRemoteEvents(Supabase.instance.client),
  );

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

  /// Opens one of the game's web pages in the phone's browser.
  static void _openPage(String page) {
    final url = switch (page) {
      'privacy' => AppConfig.privacyUrl,
      'terms' => AppConfig.termsUrl,
      'support' => AppConfig.supportUrl,
      _ => null,
    };
    if (url == null) {
      _log.warning('No web page called "$page"');
      return;
    }
    unawaited(
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).then((
        opened,
      ) {
        if (!opened) _log.warning('Could not open $url');
      }, onError: (Object e) => _log.warning('Could not open $url: $e')),
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
      // Words follow the phone's text-size setting, up to the largest size
      // the screens around the board have room for.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxTextScale,
        child: child ?? const SizedBox.shrink(),
      ),
      home: accountsEnabled
          ? BoardScreen(
              cloud: _cloud,
              content: _content,
              shop: _shop,
              ads: _ads,
              analytics: analytics,
              notifications: _notifications,
              events: _events,
              comfort: _comfort,
              onOpenPage: _openPage,
            )
          : const BoardScreen(),
    );
  }
}
