import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../presentation/widgets/force_update_dialog.dart';
import 'promo_campaign_service.dart';

class ForceUpdateService {
  static bool _isDialogShowing = false;

  /// Check for app update and trigger force update dialog/flow if required.
  /// Returns `true` if a force update is blocking the app flow.
  static Future<bool> checkAndTriggerUpdate(BuildContext context) async {
    try {
      // 1. First, check Native Google Play Store In-App Update API on Android
      if (!kIsWeb && Platform.isAndroid) {
        final nativeUpdateHandled = await _checkGooglePlayInAppUpdate();
        if (nativeUpdateHandled) {
          debugPrint('🚀 [ForceUpdateService] Native Play Store In-App Update triggered.');
          return true;
        }
      }

      // 2. Second, check App Controls API / Version comparison as fallback & for iOS
      final appControls = await PromoCampaignService.fetchAppControls();
      if (appControls != null) {
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersionStr = packageInfo.version; // e.g. "1.3.5"

        final updateConfig = appControls['appUpdate'] ?? appControls['versionControl'];
        if (updateConfig != null && updateConfig is Map) {
          final minVersion = (updateConfig['minimumVersion'] ?? updateConfig['minVersion'] ?? '').toString();
          final latestVersion = (updateConfig['latestVersion'] ?? '').toString();
          final bool forceUpdateFlag = updateConfig['forceUpdate'] == true || updateConfig['force'] == true;
          final String playStoreUrl = (updateConfig['playStoreUrl'] ?? updateConfig['storeUrl'] ?? '').toString();
          final String appStoreUrl = (updateConfig['appStoreUrl'] ?? '').toString();
          final String updateNotes = (updateConfig['notes'] ?? updateConfig['releaseNotes'] ?? '').toString();

          final bool isVersionOutdated = _isVersionLower(currentVersionStr, minVersion);

          if (isVersionOutdated || forceUpdateFlag) {
            if (context.mounted && !_isDialogShowing) {
              _isDialogShowing = true;
              final targetStoreUrl = Platform.isIOS && appStoreUrl.isNotEmpty
                  ? appStoreUrl
                  : (playStoreUrl.isNotEmpty
                      ? playStoreUrl
                      : 'https://play.google.com/store/apps/details?id=${packageInfo.packageName}');

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => ForceUpdateDialog(
                  currentVersion: currentVersionStr,
                  newVersion: latestVersion.isNotEmpty ? latestVersion : minVersion,
                  storeUrl: targetStoreUrl,
                  releaseNotes: updateNotes,
                ),
              );
            }
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ForceUpdateService] Error checking update: $e');
    }
    return false;
  }

  /// Triggers Native Play Store In-App Immediate Update API
  static Future<bool> _checkGooglePlayInAppUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          final result = await InAppUpdate.performImmediateUpdate();
          return result == AppUpdateResult.success || result == AppUpdateResult.userDeniedUpdate;
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [ForceUpdateService] Native Play Store In-App Update check skipped/not supported: $e');
    }
    return false;
  }

  /// Compares two semver strings e.g. "1.3.4" < "1.3.5"
  static bool _isVersionLower(String current, String required) {
    if (current.isEmpty || required.isEmpty) return false;

    try {
      final currentParts = current.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
      final requiredParts = required.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();

      final maxLength = currentParts.length > requiredParts.length ? currentParts.length : requiredParts.length;

      for (int i = 0; i < maxLength; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final r = i < requiredParts.length ? requiredParts[i] : 0;

        if (c < r) return true;
        if (c > r) return false;
      }
    } catch (e) {
      debugPrint('_isVersionLower error: $e');
    }
    return false;
  }

  /// Helper to launch Play Store or App Store URL
  static Future<void> launchStore(String storeUrl) async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.parse(storeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching store URL: $e');
    }
  }
}
