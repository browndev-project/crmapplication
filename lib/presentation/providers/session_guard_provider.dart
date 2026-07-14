import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/http_client.dart' as http_client;
import '../../main.dart';
import '../screens/login_screen.dart';

/// Provider that monitors the user session in the background
final sessionGuardProvider = Provider((ref) {
  final guard = SessionGuard(ref);

  // Note: We don't call startMonitoring here directly to avoid side-effects during provider creation.
  // We'll trigger it from the UI or App initialization.

  ref.onDispose(() => guard.stopMonitoring());

  return guard;
});

class SessionGuard {
  final Ref ref;
  Timer? _timer;
  final _authService = AuthService();

  SessionGuard(this.ref);

  /// Starts the 5-minute periodic session check
  void startMonitoring() {
    if (_timer?.isActive ?? false) return;

    _timer?.cancel();
    http_client.onUnauthorized = () async {
      final authBox = await Hive.openBox('authBox');
      if (authBox.get('accessToken') == null) return;
      await _performLogout(authBox);
    };
    // Run every 5 minutes (300 seconds)
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _checkSession());

    // Also perform an immediate check on start
    _checkSession();

    debugPrint("SessionGuard: Background monitoring started (Every 5 mins)");
  }

  /// Call this when the app resumes from background to validate session immediately.
  void checkNow() {
    _checkSession();
  }

  /// Stops the periodic check
  void stopMonitoring() {
    _timer?.cancel();
    if (http_client.onUnauthorized != null) {
      http_client.onUnauthorized = null;
    }
    debugPrint("SessionGuard: Background monitoring stopped");
  }

  Future<void> _checkSession() async {
    try {
      final authBox = await Hive.openBox('authBox');
      final sessionId = authBox.get('sessionId');

      // If no session ID exists locally, the user is already technically "logged out"
      // or hasn't logged in yet. No need to check with server.
      if (sessionId == null) return;

      debugPrint("SessionGuard: Periodic validation for session: $sessionId");
      final isValid = await _authService.checkSession(sessionId);

      if (!isValid) {
        debugPrint(
          "SessionGuard: [ALERT] Session is invalid or expired. Redirecting to Login.",
        );
        await _performLogout(authBox);
      }
    } catch (e) {
      debugPrint("SessionGuard: Check failed due to network/server error: $e");
      // We don't logout on network errors to avoid kicking users out during poor connectivity
    }
  }

  Future<void> _performLogout(Box authBox) async {
    if (authBox.get('accessToken') == null && authBox.get('sessionId') == null) return;
    // 1. Clear sensitive auth data locally
    await authBox.delete('accessToken');
    await authBox.delete('sessionId');
    await authBox.delete('user_id');
    await authBox.delete('user_data');

    // 2. Stop the guard
    stopMonitoring();

    // 3. Navigate to Login using the Global Navigator Key
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
