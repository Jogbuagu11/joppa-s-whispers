import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/domain/cloud_sync.dart';
import 'package:whispers_of_joppa/app/game_analytics.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/app/purchase_coordinator.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';
import 'package:whispers_of_joppa/data/save_repository.dart';
import 'package:whispers_of_joppa/features/letters/letters_screen.dart';
import 'package:whispers_of_joppa/features/levels/level_widgets.dart';
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/locations.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/features/bubbles/bubble_controller.dart';
import 'package:whispers_of_joppa/features/bubbles/bubble_layer.dart';
import 'package:whispers_of_joppa/features/events/event_screen.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';
import 'package:whispers_of_joppa/features/settings/account_screen.dart';
import 'package:whispers_of_joppa/features/settings/comfort_controller.dart';
import 'package:whispers_of_joppa/game/board/board_feedback.dart';
import 'package:whispers_of_joppa/features/settings/notification_settings_screen.dart';
import 'package:whispers_of_joppa/features/settings/notifications_controller.dart';
import 'package:whispers_of_joppa/features/restoration/location_screen.dart';
import 'package:whispers_of_joppa/features/story/scene_screen.dart';
import 'package:whispers_of_joppa/features/shop/shop_screen.dart';
import 'package:whispers_of_joppa/features/story/chapter_ending.dart';
import 'package:whispers_of_joppa/features/story/face_portrait.dart';
import 'package:whispers_of_joppa/features/story/tutorial_banner.dart';
import 'package:whispers_of_joppa/features/story/tutorial_spotlight.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/board_cloud.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_session.dart';
import 'package:whispers_of_joppa/game/board/board_share.dart';
import 'package:whispers_of_joppa/game/board/board_strip.dart';
import 'package:whispers_of_joppa/game/board/board_top_bar.dart';
import 'package:whispers_of_joppa/game/board/header_backdrop.dart';
import 'package:whispers_of_joppa/services/ad_service.dart';
import 'package:whispers_of_joppa/services/analytics_service.dart';

part 'board_screen_actions.dart';
part 'board_screen_bubbles.dart';
part 'board_screen_events.dart';
part 'board_screen_items.dart';
part 'board_screen_layout.dart';
part 'board_screen_notifications.dart';
part 'board_screen_routes.dart';

final _log = Logger('BoardScreen');

/// The main game board screen — hosts the Flame merge board.
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    this.startingMannaOverride,
    this.saveRepository,
    this.playOpeningScene = true,
    this.playTutorial = true,
    this.cloud,
    this.content,
    this.shop,
    this.ads,
    this.analytics,
    this.notifications,
    this.events,
    this.eventProgress,
    this.comfort,
    this.onOpenPage,
    this.bubbleLuck,
  });

  /// Decides which merges leave a bubble. Tests pass their own; the app
  /// leaves it to chance.
  final Random? bubbleLuck;

  /// Opens one of the game's web pages ("privacy", "terms", "support").
  /// Null (in tests) leaves those rows out of Settings.
  final void Function(String page)? onOpenPage;

  /// Sounds, vibration and tier numbers. Null (in tests) means a silent
  /// game with no such switches.
  final ComfortController? comfort;

  /// The player's account and cloud save. Null (in tests, or if the backend
  /// is not set up) hides the account button and keeps the game local.
  final BoardCloud? cloud;

  /// Where content comes from. Null (in tests) means the app's own content
  /// only, with no check for newer content on the server.
  final ContentRepository? content;

  /// The Pearl shop. Null (in tests, or where purchases are not set up)
  /// hides the shop; Pearls already owned are still shown.
  final PurchaseCoordinator? shop;

  /// Rewarded ads. Null (in tests, or where ads are not set up) means the
  /// "watch an ad" choice is never shown.
  final AdService? ads;

  /// Time-limited events. Null (in tests) means there are none.
  final EventsRepository? events;

  /// Where event progress is kept. Tests pass their own.
  final EventProgressRepository? eventProgress;

  /// Notifications. Null (in tests) hides the bell and never asks.
  final NotificationsController? notifications;

  /// Analytics and crash reports. Null (in tests) means nothing is sent.
  final Analytics? analytics;

  /// Whether a new game shows the tutorial hints (with free early taps).
  /// Tests that are about something else turn this off.
  final bool playTutorial;

  /// Whether a new game begins with the opening story scene. Tests that are
  /// about the board turn this off.
  final bool playOpeningScene;

  /// Where the game is saved. Tests pass their own; the app uses the default.
  final SaveRepository? saveRepository;

  /// Lets a test begin with a chosen amount of Manna instead of the amount
  /// in content/starting_board.json. Never set in the real app.
  final int? startingMannaOverride;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen>
    with
        _BoardState,
        _BoardRoutes,
        _BoardNotifications,
        _BoardEvents,
        _BoardItems,
        _BoardBubbles,
        _BoardLayout,
        _BoardScreenActions {
  @override
  Widget build(BuildContext context) {
    final session = _session;
    final error = _error;
    final Widget body;
    if (error != null) {
      body = Center(
        child: Text(
          error,
          key: const Key('board_error'),
          style: const TextStyle(color: Colors.red),
        ),
      );
    } else if (session == null) {
      body = const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4802A)),
      );
    } else {
      body = Stack(
        children: [
          Positioned.fill(
            child: HeaderBackdrop(
              asset: _boardText['header_background'] ?? '',
              boardKey: _boardKey,
              relayout: Listenable.merge([session.tutorial, session.orders]),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: BoardTopBar(
                    wallet: ListenableBuilder(
                      listenable: session.tutorial,
                      builder: (context, _) => WalletChips(
                        controller: session.orders,
                        pearls: session.purchases.pearlsListenable,
                        // No purchase offers during the tutorial (GDD 11).
                        onOpenShop:
                            widget.shop != null && session.tutorial.isOver
                            ? _openShop
                            : null,
                      ),
                    ),
                    level: LevelBadge(controller: session.levels),
                    onAccount: widget.cloud != null ? _openAccount : null,
                    onSettings: widget.notifications != null
                        ? _openNotificationSettings
                        : null,
                    settingsTooltip:
                        _notificationContent?.settingsText['title'],
                    manna: ListenableBuilder(
                      listenable: Listenable.merge([
                        session.game.boost,
                        session.levels,
                      ]),
                      builder: (context, _) => MannaBar(
                        controller: session.manna,
                        boostLabel: session.game.hasBoost
                            ? '×${session.game.activeBoost.mannaTimes}'
                            : null,
                        boostOn: session.game.boost.value > 0,
                        boostHint: _boardText['boost_hint'] ?? '',
                        onBoost: session.game.cycleBoost,
                      ),
                    ),
                  ),
                ),
                _playArea(session),
                // Hints (Silas and the others) sit under the board.
                TutorialBanner(
                  controller: session.tutorial,
                  characterNames: session.characterNames,
                  availableAssets: session.assetPaths,
                  looks: _characterLooks,
                ),
              ],
            ),
          ),
          // New players: the thing to tap next is lit up.
          Positioned.fill(child: _spotlight(session)),
        ],
      );
    }
    // The picture at the top is an evening sky: the phone's clock is drawn
    // light.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('board_screen'),
        backgroundColor: GamePalette.background,
        body: body,
      ),
    );
  }
}
