import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/user_model.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/location_service.dart';
import 'session_guard_provider.dart';
import 'lead_provider.dart';
import 'task_provider.dart';
import 'meeting_provider.dart';
import 'visit_provider.dart';
import 'dashboard_provider.dart';
import 'service_provider.dart';
import 'staff_provider.dart';
import 'team_provider.dart';
import 'group_provider.dart';
import 'property_provider.dart';
import 'company_provider.dart';
import 'lead_document_provider.dart';
import 'lead_card_config_provider.dart';
import 'whatsapp_provider.dart';

// Simple state class for Login
class LoginState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final User? user;

  const LoginState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.user,
  });

  LoginState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    User? user,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      error: error, 
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
    );
  }
}

class LoginNotifier extends StateNotifier<LoginState> {
  final AuthService _authService;
  final Ref _ref;
  final LocationService _locationService = LocationService();

  LoginNotifier(this._authService, this._ref) : super(const LoginState());

  Future<void> login(String uniqueId, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.login(uniqueId, password);

      if (response.success && response.user != null) {
        // Store tokens in Hive
        final box = await Hive.openBox('authBox');
        await box.put('accessToken', response.accessToken);
        await box.put('sessionId', response.sessionId);
        await box.put('user_id', response.user!.id);
        
        // Save full user object
        await box.put('user_data', jsonEncode(response.user!.toJson()));
        
        state = state.copyWith(
          isLoading: false, 
          isAuthenticated: true,
          user: response.user,
        );
        
        // Enable Notifications after login
        FCMService.enableNotifications();
        _locationService.startTracking();
      } else {
         state = state.copyWith(
          isLoading: false, 
          error: response.message.isNotEmpty ? response.message : 'Login failed',
          isAuthenticated: false
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false, 
        error: e.toString(),
        isAuthenticated: false
      );
    }
  }
  
  Future<void> logout() async {
    try {
      final box = await Hive.openBox('authBox');
      final sessionId = box.get('sessionId');

      // Step 1: Notify backend of logout while session + deviceId are still in Hive.
      if (sessionId != null) {
        final success = await _authService.logoutUser(sessionId);
        if (!success) {
          debugPrint('Logout API did not return 200 status code. Aborting logout.');
          return;
        }
      }

      // Step 2: Remove this device's FCM subscription from the backend.
      // MUST happen before _clearAllHiveBoxes() because removeSubscription()
      // reads 'crm_device_id' from Hive. Clearing Hive first makes deviceId null
      // and the unsubscribe call silently returns without doing anything (Bug 4).
      await _authService.removeSubscription();
    } catch (e) {
      debugPrint('Logout API/subscription error: $e');
      return;
    }

    // Step 3: Cancel the FCM foreground message listener and delete the FCM token
    // from Firebase so this device stops receiving push notifications.
    await FCMService.disableNotifications();

    // Step 4: Stop background location tracking.
    _locationService.stopTracking();

    // Step 5: Clear all local Hive storage (done AFTER removeSubscription so
    // crm_device_id is still available for the unsubscribe API call above).
    await _clearAllHiveBoxes();

    // Step 6: Reset login state so UI listeners (PermissionsNotifier etc.) react.
    state = const LoginState(isAuthenticated: false);

    // Step 7: Invalidate all providers — this also triggers sessionGuardProvider's
    // onDispose which calls stopMonitoring(), tearing down the 5-min timer
    // and the global onUnauthorized hook.
    _invalidateAllProviders();
  }

  Future<void> _clearAllHiveBoxes() async {
    final boxesToClear = ['authBox', 'taskBox', 'serviceBox', 'dashboardBox'];
    for (var boxName in boxesToClear) {
      try {
        final box = await Hive.openBox(boxName);
        await box.clear();
        debugPrint('✅ Cleared Hive Box: $boxName');
      } catch (e) {
        debugPrint('❌ Error clearing box $boxName: $e');
      }
    }
  }

  void _invalidateAllProviders() {
    // Invalidate sessionGuardProvider first — its onDispose handler calls
    // stopMonitoring() which cancels the 5-min timer and the global
    // onUnauthorized hook registered in http_client.
    _ref.invalidate(sessionGuardProvider);
    _ref.invalidate(leadsProvider);
    _ref.invalidate(tasksProvider);
    _ref.invalidate(meetingsProvider);
    _ref.invalidate(visitsProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(servicesProvider);
    // Removed permissionsProvider invalidation to avoid circular dependency
    // as it already listens to loginProvider and resets itself.
    _ref.invalidate(companyProvider);
    _ref.invalidate(leadStatusProvider);
    _ref.invalidate(teamProvider);
    _ref.invalidate(groupProvider);
    _ref.invalidate(propertyProvider);
    _ref.invalidate(citiesProvider);
    _ref.invalidate(globalDocumentsProvider);
    _ref.invalidate(leadDocumentsProvider);
    _ref.invalidate(documentFormsProvider);
    _ref.invalidate(leadCardConfigProvider);
    _ref.invalidate(staffProvider);
    _ref.invalidate(whatsappIntegrationProvider);
    _ref.invalidate(whatsappChatsProvider);
    _ref.invalidate(whatsappMessagesProvider);
    _ref.invalidate(whatsappTemplatesProvider);
    _ref.invalidate(whatsappAutomationsProvider);
    _ref.invalidate(whatsappCampaignsProvider);
    // Note: Auto-dispose providers like leadDetailProvider will clear automatically when not watched
    debugPrint('🔄 All core providers invalidated');
  }

  Future<void> checkLoginStatus() async {
      final box = await Hive.openBox('authBox');
      final token = box.get('accessToken');
      final sessionId = box.get('sessionId');

      debugPrint('CheckLoginStatus - Token: ${token != null}, SessionId: $sessionId');

      if (token != null && sessionId != null) {
          // 1. Restore user data IMMEDIATELY from Hive so the app starts in authenticated state
          User? user;
          final userJson = box.get('user_data');
          if (userJson != null) {
              try {
                user = User.fromJson(jsonDecode(userJson));
                debugPrint('Successfully restored user data from Hive: ${user.name}');
              } catch (e) {
                debugPrint('Error restoring user data from Hive: $e');
              }
          }

          state = state.copyWith(
              isAuthenticated: true,
              user: user,
              isLoading: false
          );
          
          // Start necessary background services
          FCMService.enableNotifications();
          _locationService.startTracking();

          // 2. Verify session validity with the backend in the background
          try {
              debugPrint('Verifying session validity with backend...');
              final isValid = await _authService.checkSession(sessionId).timeout(const Duration(seconds: 15));
              debugPrint('Session Validity Result: $isValid');
              
              if (!isValid) {
                  debugPrint('⚠️ Session explicitly invalidated by server. Logging out...');
                  await logout();
              } else {
                  debugPrint('✅ Session verified successfully');
              }
          } catch (e) {
              // Network error or timeout - do NOT logout. 
              // Keep the restored session and let subsequent API calls handle auth errors (401).
              debugPrint('ℹ️ Background session check failed (likely network): $e. Keeping restored session.');
          }
      } else {
          debugPrint('Incomplete auth data - ensuring logged out state');
          state = const LoginState(isAuthenticated: false);
      }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return LoginNotifier(authService, ref);
});
