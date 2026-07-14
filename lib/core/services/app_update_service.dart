import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'http_client.dart' as http;
import 'auth_service.dart';
import '../../presentation/widgets/app_update_dialog.dart';
import '../../main.dart';

class AppUpdateService {
  // Constant string matching version defined in pubspec.yaml
  static const String currentVersion = "1.2.1"; 

  static Future<void> checkUpdate(BuildContext context) async {
    if (kIsWeb) return;

    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/app-controls');
      debugPrint('AppUpdateService: Fetching app controls from $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      debugPrint('AppUpdateService: Response status code ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];
          
          Map<String, dynamic>? platformConfig;
          if (Platform.isAndroid) {
            platformConfig = data['android'] != null ? Map<String, dynamic>.from(data['android']) : null;
          } else if (Platform.isIOS) {
            platformConfig = data['ios'] != null ? Map<String, dynamic>.from(data['ios']) : null;
          } else {
            // Fallback for development/testing on other platforms (e.g. Windows desktop)
            platformConfig = data['android'] != null ? Map<String, dynamic>.from(data['android']) : null;
          }

          if (platformConfig == null) {
            debugPrint('AppUpdateService: No config block found for this platform.');
            return;
          }

          final bool enabled = platformConfig['enabled'] ?? false;
          if (!enabled) {
            debugPrint('AppUpdateService: App update checking bypassed because enabled is false.');
            return;
          }

          final String versionCode = platformConfig['versionCode'] ?? '';
          final bool forceUpdate = platformConfig['forceUpdate'] ?? false;
          final String storeUrl = platformConfig['storeUrl'] ?? '';
          final String title = platformConfig['title'] ?? '';
          final String message = platformConfig['message'] ?? '';

          debugPrint('AppUpdateService: Platform Config - VersionCode: $versionCode, Force: $forceUpdate, Local: $currentVersion');

          if (versionCode.isNotEmpty) {
            final isNewer = isVersionLessThan(currentVersion, versionCode);
            if (isNewer) {
              debugPrint('AppUpdateService: Local version ($currentVersion) is less than remote ($versionCode). Showing popup...');
              final dialogContext = navigatorKey.currentContext ?? context;
              if (dialogContext.mounted) {
                showDialog(
                  context: dialogContext,
                  barrierDismissible: !forceUpdate,
                  builder: (ctx) => AppUpdateDialog(
                    title: title,
                    message: message,
                    storeUrl: storeUrl,
                    forceUpdate: forceUpdate,
                  ),
                );
              }
            } else {
              debugPrint('AppUpdateService: Local version is up-to-date.');
            }
          }
        }
      }
    } catch (e) {
      // Bypassed gracefully to ensure user can use current app if backend check fails
      debugPrint('AppUpdateService: Gracefully caught exception during update check: $e');
    }
  }

  /// Compares semantic version strings (e.g. "1.10.0" is greater than "1.2.0")
  static bool isVersionLessThan(String local, String remote) {
    String cleanLocal = local.split('+').first.trim();
    String cleanRemote = remote.split('+').first.trim();

    List<String> localParts = cleanLocal.split('.');
    List<String> remoteParts = cleanRemote.split('.');

    int maxLength = localParts.length > remoteParts.length ? localParts.length : remoteParts.length;

    for (int i = 0; i < maxLength; i++) {
      int localVal = i < localParts.length ? int.tryParse(localParts[i]) ?? 0 : 0;
      int remoteVal = i < remoteParts.length ? int.tryParse(remoteParts[i]) ?? 0 : 0;

      if (localVal < remoteVal) return true;
      if (localVal > remoteVal) return false;
    }
    return false;
  }
}
