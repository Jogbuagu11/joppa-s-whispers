import 'dart:async';

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
import 'package:whispers_of_joppa/domain/models.dart';
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
import 'package:whispers_of_joppa/features/story/task_bar.dart';
import 'package:whispers_of_joppa/features/story/tutorial_banner.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/board_cloud.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/board_session.dart';
import 'package:whispers_of_joppa/game/board/board_top_bar.dart';
import 'package:whispers_of_joppa/services/ad_service.dart';
import 'package:whispers_of_joppa/services/analytics_service.dart';

part 'board_screen_actions.dart';
part 'board_screen_events.dart';
part 'board_screen_items.dart';
part 'board_screen_notifications.dart';
part 'board_screen_routes.dart';

final _log = Logger('BoardScreen');

/// How the space under the bars is shared: the board is a 7 by 9 grid as
/// wide as the screen if the height allows; the order cards get the rest,
/// never less than their smallest size nor more than their largest.
({double cards, double board}) shareHeight({
  required double width,
  required double height,
}) {
  const gap = 6.0;
  final fullWidth = width * BoardGame.rows / BoardGame.cols;
  final most = height - orderCardsMinHeight - gap;
  final board = fullWidth < most ? fullWidth : (most < 0 ? 0.0 : most);
  final left = height - board - gap;
  final cards = left > orderCardsMaxHeight
      ? orderCardsMaxHeight
      : (left < orderCardsMinHeight ? orderCardsMinHeight : left);
  return (cards: cards, board: board);
}

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
  });

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
      body = SafeArea(
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
                    onOpenShop: widget.shop != null && session.tutorial.isOver
                        ? _openShop
                        : null,
                  ),
                ),
                level: LevelBadge(controller: session.levels),
                onAccount: widget.cloud != null ? _openAccount : null,
                onSettings: widget.notifications != null
                    ? _openNotificationSettings
                    : null,
                settingsTooltip: _notificationContent?.settingsText['title'],
                manna: MannaBar(controller: session.manna),
              ),
            ),
            TaskBar(
              controller: session.story,
              onDo: _doNextTask,
              onOpenLocation: _openLocation,
              onOpenLetters: _openLetters,
            ),
            // No event offers during the tutorial.
            if (_event case final event?)
              ListenableBuilder(
                listenable: session.tutorial,
                // Nor for a game played from memory only (older content):
                // rewards could not be kept.
                builder: (context, _) =>
                    session.tutorial.isOver && !session.downgraded
                    ? _eventBanner(event)
                    : const SizedBox.shrink(),
              ),
            // The board comes first: it is as wide as the screen whenever
            // the height allows, and the order cards take what is left
            // (within their limits).
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final (:cards, :board) = shareHeight(
                    width: box.maxWidth,
                    height: box.maxHeight,
                  );
                  // On a very short screen the cards keep their least size
                  // and anything that does not fit is cut off, not an error.
                  return ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 0,
                      maxHeight: box.maxHeight > cards + 6
                          ? box.maxHeight
                          : cards + 6,
                      child: Column(
                        children: [
                          _ordersBackdrop(
                            child: OrdersBar(
                              controller: session.orders,
                              items: session.game.itemCatalog,
                              characterNames: session.characterNames,
                              placeholderColors:
                                  session.game.chainPlaceholderColors,
                              looks: _characterLooks,
                              // The backdrop's own edging is part of the share.
                              height: cards - 10,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: board,
                            child: GameWidget(game: session.game),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Hints (Silas and the others) sit under the board.
            TutorialBanner(
              controller: session.tutorial,
              characterNames: session.characterNames,
              availableAssets: session.assetPaths,
              looks: _characterLooks,
            ),
          ],
        ),
      );
    }
    // The board is dark: the phone's clock and battery are drawn light.
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
