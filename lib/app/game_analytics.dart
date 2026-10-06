// Watches a running game and reports what happens in it as analytics
// events. It only listens: nothing here changes the game.
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/analytics_events.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/features/shop/purchases_controller.dart';
import 'package:whispers_of_joppa/game/board/board_session.dart';
import 'package:whispers_of_joppa/services/analytics_service.dart';

final _log = Logger('GameAnalytics');

class GameAnalytics {
  final Analytics analytics;
  final DateTime Function() _now;

  int _merges = 0;
  int _taps = 0;
  DateTime? _sessionStart;
  void Function()? _detach;

  GameAnalytics(this.analytics, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  /// Starts reporting on [session]. Hooks already on the game (the tutorial
  /// uses the same ones) keep working: each is called first.
  void attach(BoardSession session) {
    _detach?.call();
    final game = session.game;
    final orders = session.orders;
    final story = session.story;
    final tutorial = session.tutorial;
    void context() => analytics.setContext(
      contentVersion: session.contentBundle.version,
      chapterId: story.chapter?.id,
    );
    context();

    final onMerge = game.onMerge;
    game.onMerge = () {
      onMerge?.call();
      if (isSampled(++_merges)) {
        analytics.log(AnalyticsEvent.merge, {'sampled_1_in': sampleEvery});
      }
    };
    final onSpawn = game.onGeneratorSpawn;
    game.onGeneratorSpawn = ({required bool wasFree}) {
      onSpawn?.call(wasFree: wasFree);
      if (isSampled(++_taps)) {
        analytics.log(AnalyticsEvent.generatorTap, {
          'sampled_1_in': sampleEvery,
        });
      }
    };
    final onDelivered = orders.onDelivered;
    orders.onDelivered = (id) {
      onDelivered?.call(id);
      analytics.log(AnalyticsEvent.orderComplete, {'order_id': id});
    };
    final onTaskDone = story.onTaskDone;
    story.onTaskDone = (id) {
      onTaskDone?.call(id);
      analytics.log(AnalyticsEvent.taskComplete, {'task_id': id});
      final done = story.completedTasks.toSet();
      for (final chapter in story.chapters) {
        final isLast = chapter.tasks.isNotEmpty && chapter.tasks.last.id == id;
        if (isLast && isChapterComplete(chapter, done)) {
          analytics.log(AnalyticsEvent.chapterComplete, {
            'chapter_id': chapter.id,
          });
        }
      }
      context();
    };

    var step = tutorial.index;
    var over = tutorial.isOver;
    void onTutorial() {
      if (tutorial.isOver && !over) {
        over = true;
        analytics.log(AnalyticsEvent.tutorialComplete);
      } else if (!tutorial.isOver && tutorial.index != step) {
        step = tutorial.index;
        analytics.log(AnalyticsEvent.tutorialStep, {'step': step});
      }
    }

    void onAd() => analytics.log(AnalyticsEvent.adWatched, {
      'reward': session.ads.mannaReward,
    });
    tutorial.addListener(onTutorial);
    session.ads.tallyChanged.addListener(onAd);
    _detach = () {
      tutorial.removeListener(onTutorial);
      session.ads.tallyChanged.removeListener(onAd);
    };
    sessionStarted();
  }

  /// Stops listening to a game that is being closed or replaced.
  void detach() {
    _detach?.call();
    _detach = null;
  }

  void sessionStarted() {
    if (_sessionStart != null) return;
    _sessionStart = _now();
    analytics.log(AnalyticsEvent.sessionStart);
  }

  void sessionEnded() {
    final start = _sessionStart;
    if (start == null) return;
    _sessionStart = null;
    final seconds = _now().difference(start).inSeconds;
    analytics.log(AnalyticsEvent.sessionEnd, {
      'seconds': seconds < 0 ? 0 : seconds,
    });
  }

  void outOfEnergy() => analytics.log(AnalyticsEvent.outOfEnergy);

  void purchaseStarted(String productId) =>
      analytics.log(AnalyticsEvent.purchaseStarted, {'product_id': productId});

  void letterOpened(String letterId) =>
      analytics.log(AnalyticsEvent.letterOpened, {'letter_id': letterId});

  /// Wraps the step that puts confirmed purchases into the game, reporting
  /// each one newly delivered.
  GrantTotals Function(List<PurchaseRecord>) reportingPurchases(
    PurchasesController purchases,
  ) => (fromServer) {
    final before = purchases.appliedTransactions.toSet();
    final totals = purchases.applyConfirmed(fromServer);
    // Reporting must never get in the way of a purchase being delivered.
    try {
      final delivered = newlyAppliedProducts(
        before,
        purchases.appliedTransactions.toSet(),
        {for (final r in fromServer) r.transactionId: r.productId},
      );
      for (final productId in delivered) {
        analytics.log(AnalyticsEvent.purchaseComplete, {
          'product_id': productId,
        });
      }
    } on Object catch (e) {
      _log.warning('Could not report a purchase: $e');
    }
    return totals;
  };
}
