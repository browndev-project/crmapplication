import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'analytics_service.dart';
import '../../presentation/widgets/app_rating_dialog.dart';

/// Service managing the In-App Review prompt schedule:
/// 1. Initial 5-minute timer starting WHEN user reaches Dashboard (HomeScreen).
/// 2. Permanent suppression once user taps "Rate Now" (`has_reviewed_app = true`).
/// 3. 6-Day reminder interval if postponed or dismissed.
class AppReviewService {
  static final AppReviewService _instance = AppReviewService._internal();
  factory AppReviewService() => _instance;
  AppReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;
  Timer? _autoPromptTimer;

  static const String _boxName = 'reviewBox';
  static const String _keyHasReviewed = 'has_reviewed_app';
  static const String _keyFirstDashboardReach = 'first_dashboard_reach_timestamp';
  static const String _keyNextEligible = 'next_review_eligible_time';

  /// Helper to open the dedicated review Hive box (never cleared on logout)
  Future<Box> _getBox() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return await Hive.openBox(_boxName);
      }
      return Hive.box(_boxName);
    } catch (e, stack) {
      debugPrint('[AppReviewService ERROR] Opening Hive box $_boxName failed: $e\n$stack');
      return await Hive.openBox(_boxName);
    }
  }

  /// Resets review history in Hive for testing purposes
  Future<void> resetReviewStateForTesting() async {
    try {
      _autoPromptTimer?.cancel();
      final box = await _getBox();
      await box.delete(_keyHasReviewed);
      await box.delete(_keyFirstDashboardReach);
      await box.delete(_keyNextEligible);
      debugPrint('[AppReviewService DEBUG] 🔄 Reset review state in Hive for testing.');
    } catch (e) {
      debugPrint('[AppReviewService ERROR] Resetting test state failed: $e');
    }
  }

  /// Evaluates review eligibility and displays the rating dialog if eligible.
  Future<void> checkAndPromptReview(BuildContext context, {bool forceForTesting = false}) async {
    debugPrint('[AppReviewService DEBUG] 🔍 Initiating checkAndPromptReview(forceForTesting: $forceForTesting)...');
    try {
      final box = await _getBox();

      final bool hasReviewed = box.get(_keyHasReviewed, defaultValue: false) as bool;
      final String? firstReachStr = box.get(_keyFirstDashboardReach) as String?;
      final String? nextEligibleStr = box.get(_keyNextEligible) as String?;

      debugPrint('[AppReviewService DEBUG] State Check:');
      debugPrint('  - hasReviewed: $hasReviewed');
      debugPrint('  - firstDashboardReachTimestamp: $firstReachStr');
      debugPrint('  - nextEligibleTime: $nextEligibleStr');

      if (!forceForTesting) {
        // Rule 1: PERMANENT SUPPRESSION - If user already rated, NEVER show again.
        if (hasReviewed) {
          debugPrint('[AppReviewService DEBUG] 🛑 User already rated. Suppressing review popup permanently.');
          return;
        }

        // Record timestamp WHEN USER FIRST REACHES DASHBOARD HOME SCREEN
        final now = DateTime.now();
        String reachStr = firstReachStr ?? '';
        if (firstReachStr == null) {
          reachStr = now.toIso8601String();
          await box.put(_keyFirstDashboardReach, reachStr);
          debugPrint('[AppReviewService DEBUG] ⏱️ User reached Dashboard! 5-minute timer started at: $reachStr');
        }

        final firstReachTime = DateTime.tryParse(reachStr) ?? now;
        final dashboardAgeSeconds = now.difference(firstReachTime).inSeconds;
        final dashboardAgeMinutes = (dashboardAgeSeconds / 60).floor();

        debugPrint('[AppReviewService DEBUG] Time spent since reaching Dashboard: $dashboardAgeMinutes mins ($dashboardAgeSeconds secs).');

        // Rule 2: Initial 5-Minute Delay starting from Dashboard reach
        const int targetDelaySeconds = 300; // 5 minutes = 300 seconds
        if (dashboardAgeSeconds < targetDelaySeconds) {
          final remainingSeconds = targetDelaySeconds - dashboardAgeSeconds;
          debugPrint('[AppReviewService DEBUG] ⏳ Dashboard reach age is under 5 minutes ($dashboardAgeSeconds secs). Scheduling auto-prompt timer in $remainingSeconds seconds...');
          
          _autoPromptTimer?.cancel();
          _autoPromptTimer = Timer(Duration(seconds: remainingSeconds), () {
            debugPrint('[AppReviewService DEBUG] ⏰ 5 minutes completed since reaching Dashboard! Re-triggering checkAndPromptReview...');
            if (context.mounted) {
              checkAndPromptReview(context);
            }
          });
          return;
        }

        // Rule 3: 6-7 Day Deferral Interval if previously postponed
        if (nextEligibleStr != null) {
          final nextEligibleTime = DateTime.tryParse(nextEligibleStr);
          if (nextEligibleTime != null && now.isBefore(nextEligibleTime)) {
            debugPrint('[AppReviewService DEBUG] ⏳ Next eligible date is $nextEligibleStr. Postponing prompt.');
            return;
          }
        }
      } else {
        debugPrint('[AppReviewService DEBUG] ⚡ FORCE MODE ENABLED: Bypassing timers and age checks for instant UI verification!');
      }

      // Display rating modal
      if (!context.mounted) {
        debugPrint('[AppReviewService DEBUG] ⚠️ BuildContext is not mounted. Cannot show rating dialog.');
        return;
      }

      debugPrint('[AppReviewService DEBUG] 🎉 ALL CHECKS PASSED! Showing AppRatingDialog modal...');
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AppRatingDialog(
          onRateNow: () async {
            debugPrint('[AppReviewService DEBUG] User clicked "Rate Now"');
            Navigator.pop(dialogContext);
            await triggerReview();
          },
          onRemindLater: () async {
            debugPrint('[AppReviewService DEBUG] User clicked "Remind Me Later"');
            Navigator.pop(dialogContext);
            await deferReview(days: 6);
          },
          onNoThanks: () async {
            debugPrint('[AppReviewService DEBUG] User clicked "No Thanks"');
            Navigator.pop(dialogContext);
            await deferReview(days: 6);
          },
        ),
      );
    } catch (e, stack) {
      debugPrint('[AppReviewService ERROR] ❌ Exception in checkAndPromptReview: $e\n$stack');
    }
  }

  /// Triggers the Google Play / App Store native rating modal and sets permanently reviewed state.
  Future<void> triggerReview() async {
    debugPrint('[AppReviewService DEBUG] 🚀 Executing triggerReview()...');
    try {
      final box = await _getBox();

      // PERMANENT SUPPRESSION: Mark as reviewed so dialog NEVER shows again
      await box.put(_keyHasReviewed, true);
      debugPrint('[AppReviewService DEBUG] ✅ Marked has_reviewed_app = true permanently in reviewBox.');

      AnalyticsService().logCustomEvent(name: 'app_review_rated');

      final bool isAvailable = await _inAppReview.isAvailable();
      debugPrint('[AppReviewService DEBUG] InAppReview.isAvailable(): $isAvailable');

      if (isAvailable) {
        debugPrint('[AppReviewService DEBUG] Invoking InAppReview.requestReview()...');
        await _inAppReview.requestReview();
        debugPrint('[AppReviewService DEBUG] InAppReview.requestReview() completed.');
        // Also open store listing to guarantee Play Store review page on debug APKs / quota limits
        await _inAppReview.openStoreListing();
      } else {
        debugPrint('[AppReviewService DEBUG] Native review unavailable. Fallback to openStoreListing()...');
        await _inAppReview.openStoreListing();
      }
    } catch (e, stack) {
      debugPrint('[AppReviewService ERROR] ❌ Exception in triggerReview: $e\n$stack');
      try {
        await _inAppReview.openStoreListing();
      } catch (fallbackErr) {
        debugPrint('[AppReviewService ERROR] Store listing fallback failed: $fallbackErr');
      }
    }
  }

  /// Postpones the next review prompt by the specified number of days (default 6 days).
  Future<void> deferReview({int days = 6}) async {
    debugPrint('[AppReviewService DEBUG] 📅 Executing deferReview(days: $days)...');
    try {
      final box = await _getBox();
      final nextEligibleDate = DateTime.now().add(Duration(days: days));
      await box.put(_keyNextEligible, nextEligibleDate.toIso8601String());
      debugPrint('[AppReviewService DEBUG] ✅ Postponed review prompt until ${nextEligibleDate.toIso8601String()}');
      AnalyticsService().logCustomEvent(
        name: 'app_review_postponed',
        parameters: {'defer_days': days},
      );
    } catch (e, stack) {
      debugPrint('[AppReviewService ERROR] ❌ Exception in deferReview: $e\n$stack');
    }
  }
}
