
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/staff_service.dart';
import '../../data/models/staff_model.dart';
import '../../core/constants/permission_constants.dart';
import 'permissions_provider.dart';
import 'login_provider.dart';

// State Class
class StaffState {
  final bool isLoading;
  final List<StaffUser> users;
  final String? error;
  final int page;
  final int totalPages;
  final String searchQuery;

  StaffState({
    this.isLoading = false,
    this.users = const [],
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.searchQuery = '',
  });

  StaffState copyWith({
    bool? isLoading,
    List<StaffUser>? users,
    String? error,
    int? page,
    int? totalPages,
    String? searchQuery,
  }) {
    return StaffState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      error: error, // Nullable to clear error
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// Notifier
class StaffNotifier extends StateNotifier<StaffState> {
  final StaffService _service;
  final String _role;
  final Ref _ref;

  StaffNotifier(this._service, this._role, this._ref) : super(StaffState()) {
    fetchUsers();
  }

  Future<void> fetchUsers({int page = 1, bool isRefresh = false}) async {
    
    final permissions = _ref.read(permissionsProvider);
    final user = _ref.read(loginProvider).user;
    if (!permissions.hasModule(PermissionModules.STAFF_BASE, userRole: user?.systemRole)) {
      state = state.copyWith(isLoading: false, error: 'Permission Denied');
      return;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final query = state.searchQuery;
      
      final response = await _service.fetchStaff(
        role: _role,
        page: page,
        search: query,
      );

      // Client-side filtering (kept for safety, though API handles it)
      final fetchedUsers = _role.isEmpty 
          ? response.docs 
          : response.docs.where((user) => user.systemRole == _role).toList();

      final List<StaffUser> updatedUsers;
      if (isRefresh || page == 1) {
        updatedUsers = fetchedUsers;
      } else {
        // Merge and Deduplicate
        final existingIds = state.users.map((u) => u.id).toSet();
        final newUsers = fetchedUsers.where((u) => !existingIds.contains(u.id)).toList();
        updatedUsers = [...state.users, ...newUsers];
      }

      state = state.copyWith(
        isLoading: false,
        users: updatedUsers,
        page: response.page,
        totalPages: response.totalPages,
        searchQuery: query,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setSearch(String query) {
    if (state.searchQuery != query) {
       state = state.copyWith(searchQuery: query);
       refresh();
    }
  }

  Future<void> loadMore() async {
    if (state.page < state.totalPages && !state.isLoading) {
      state = state.copyWith(isLoading: true);
      await fetchUsers(page: state.page + 1);
    }
  }

  Future<void> createStaff(Map<String, dynamic> data) async {
    // Add systemRole to data if not present (though dialog likely handles it)
    data['systemRole'] = _role;
    
    try {
        await _service.createStaff(data);
        await refresh();
    } catch (e) {
        rethrow; // Rethrow to let UI handle error display
    }
  }

  Future<void> updateStaff(String staffId, Map<String, dynamic> data) async {
    try {
        await _service.updateStaff(staffId, data);
        await refresh();
    } catch (e) {
        rethrow; // Rethrow to let UI handle error display
    }
  }

  Future<void> refresh() async {
    await fetchUsers(page: 1, isRefresh: true);
  }

  Future<void> deleteStaff(String id) async {
      try {
          await _service.deleteStaff(id);
          await refresh();
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }
}


// Providers
final staffServiceProvider = Provider((ref) => StaffService());

// Family provider to get notifier by Role
final staffProvider = StateNotifierProvider.family<StaffNotifier, StaffState, String>((ref, role) {
  final service = ref.watch(staffServiceProvider);
  return StaffNotifier(service, role, ref);
});
