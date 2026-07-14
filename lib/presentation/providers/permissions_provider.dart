
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/permission_model.dart';
import '../providers/login_provider.dart';

class PermissionsState {
  final UserPermissionInfo? userPermissions;
  final bool isLoading;
  final String? error;

  PermissionsState({
    this.userPermissions,
    this.isLoading = false,
    this.error,
  });

  PermissionsState copyWith({
    UserPermissionInfo? userPermissions,
    bool? isLoading,
    String? error,
  }) {
    return PermissionsState(
      userPermissions: userPermissions ?? this.userPermissions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool hasModule(String moduleName, {String? userRole}) {
    // Enforce module checks even for admins (Subscription based)
    // if (userRole == 'company_admin' || userRole == 'company') return true;
    
    if (userPermissions == null) return false;
    return userPermissions!.modules.contains(moduleName);
  }

  bool hasPermission(String permissionName, {String? userRole}) {
    // Admin or Company role bypasses all checks
    if (userRole == 'company_admin' || userRole == 'company') return true;

    if (userPermissions == null) return false;
    return userPermissions!.permissions.contains(permissionName);
  }

  /// Unified check for both Module availability and User-level permission
  bool can(String module, {String? permission, String? userRole}) {
    // 1. Check if the module is enabled at the company/subscription level
    if (!hasModule(module)) return false;

    // 2. If a specific permission is requested, check user-level permission
    if (permission != null) {
      return hasPermission(permission, userRole: userRole);
    }

    // If only module is checked, it's allowed if module is present
    return true;
  }

  /// Strict permission check - does NOT bypass admin roles.
  /// Use this for screens that should show AccessDeniedWidget even for admins
  /// when the specific permission is not granted.
  bool canStrict(String module, {String? permission, String? userRole}) {
    // 1. Check if the module is enabled at the company/subscription level
    if (!hasModule(module)) return false;

    // 2. If a specific permission is requested, check without admin bypass
    if (permission != null) {
      if (userPermissions == null) return false;
      return userPermissions!.permissions.contains(permission);
    }

    // If only module is checked, it's allowed if module is present
    return true;
  }

  bool canEditLead(dynamic lead, {String? userRole, String? userId}) {
    // Admin bypass
    if (userRole == 'company_admin' || userRole == 'company') return true;
    
    // 1. Check global update permission
    if (hasPermission('leads.updateDetails', userRole: userRole)) return true;
    
    // 2. Check ownership (if assigned to this user)
    String? assignedId;
    try {
      if (lead is Map) {
        final assigned = lead['assignedTo'];
        if (assigned is Map) {
          assignedId = assigned['_id']?.toString();
        } else if (assigned is String) {
          assignedId = assigned;
        }
      } else {
        // Handle as Lead object
        assignedId = lead.assignedTo?.id;
      }
    } catch (e) {
      debugPrint('PermissionsState: Error checking lead ownership: $e');
    }
    
    return assignedId == userId;
  }

  bool canDeleteLead({String? userRole}) {
    // Typically only admins or those with explicit permission can delete
    return hasPermission('leads.delete', userRole: userRole);
  }

  bool canUpdateProperty(dynamic property, {String? userRole, String? userName}) {
    // 1. Full update permission (Admin bypass included in hasPermission)
    if (hasPermission('property.update', userRole: userRole)) return true;

    // 2. Restricted update (last updated by this user)
    if (hasPermission('property.lastUpdate', userRole: userRole)) {
      final updatedBy = property.updatedBy is String ? property.updatedBy : property.updatedBy?.name;
      return updatedBy == userName;
    }

    return false;
  }
}

class PermissionsNotifier extends StateNotifier<PermissionsState> {
  final AuthService _authService;
  final Ref _ref;
  Timer? _pollingTimer;

  PermissionsNotifier(this._authService, this._ref) : super(PermissionsState()) {
    // Listen for authentication changes to start/stop polling
    _ref.listen(loginProvider, (previous, next) {
      if (next.isAuthenticated && (previous == null || !previous.isAuthenticated)) {
        debugPrint('PermissionsNotifier: User authenticated, starting polling...');
        startPolling();
      } else if (!next.isAuthenticated && previous?.isAuthenticated == true) {
        debugPrint('PermissionsNotifier: User logged out, stopping polling...');
        stopPolling();
      }
    });

    // Initial check if already authenticated (e.g. session restored)
    final loginState = _ref.read(loginProvider);
    if (loginState.isAuthenticated) {
      debugPrint('PermissionsNotifier: Already authenticated on init, starting polling...');
      startPolling();
    }
  }

  void startPolling() {
    _pollingTimer?.cancel();
    
    // Immediate fetch
    fetchPermissions();
    
    // Set up 1-minute interval for subsequent fetches
    _pollingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      fetchPermissions();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    state = PermissionsState(); // Reset permissions on logout
  }

  Future<void> fetchPermissions() async {
    // Only fetch if authenticated
    if (!_ref.read(loginProvider).isAuthenticated) return;

    try {
      final response = await _authService.getPermissions();
      if (response.success) {
        debugPrint('Permissions Notifier Updated: ${response.data.user.modules}');
        state = state.copyWith(
          userPermissions: response.data.user,
          isLoading: false,
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final permissionsProvider = StateNotifierProvider<PermissionsNotifier, PermissionsState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return PermissionsNotifier(authService, ref);
});
