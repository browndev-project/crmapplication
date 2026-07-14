
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/group_model.dart';
import '../../core/services/staff_service.dart';
import '../../core/constants/permission_constants.dart';
import 'permissions_provider.dart';
import 'login_provider.dart';
import 'staff_provider.dart'; // To reuse staffServiceProvider

class GroupState {
  final bool isLoading;
  final List<Group> groups;
  final String? error;
  final int page;
  final int totalPages;
  final int totalCount;
  final String searchQuery;

  GroupState({
    this.isLoading = false,
    this.groups = const [],
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.totalCount = 0,
    this.searchQuery = '',
  });

  GroupState copyWith({
    bool? isLoading,
    List<Group>? groups,
    String? error,
    int? page,
    int? totalPages,
    int? totalCount,
    String? searchQuery,
  }) {
    return GroupState(
      isLoading: isLoading ?? this.isLoading,
      groups: groups ?? this.groups,
      error: error,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class GroupNotifier extends StateNotifier<GroupState> {
  final StaffService _service;
  final Ref _ref;

  GroupNotifier(this._service, this._ref) : super(GroupState()) {
    fetchGroups();
  }

  Future<void> fetchGroups({int page = 1, bool isRefresh = false}) async {
    // If loading matches and not refreshing, return
    if (state.isLoading && !isRefresh) return;
    
    final permissions = _ref.read(permissionsProvider);
    final user = _ref.read(loginProvider).user;
    if (!permissions.hasModule(PermissionModules.STAFF_BASE, userRole: user?.systemRole)) {
      state = state.copyWith(isLoading: false, error: 'Permission Denied');
      return;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final query = state.searchQuery;
      
      final response = await _service.fetchGroups(
        page: page,
        search: query,
      );

      state = state.copyWith(
        isLoading: false,
        groups: isRefresh ? response.groups : [...state.groups, ...response.groups],
        page: response.page,
        totalPages: response.totalPages,
        totalCount: response.totalCount,
        searchQuery: query,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
      await fetchGroups(page: state.page + 1);
    }
  }

  Future<void> refresh() async {
    await fetchGroups(page: 1, isRefresh: true);
  }

  Future<void> createGroup(String name, bool active) async {
      try {
          await _service.createGroup(name: name, active: active);
          refresh(); 
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> updateGroup(String id, String name, bool active) async {
      try {
          await _service.updateGroup(id: id, name: name, active: active);
          refresh();
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> addTeamsToGroup(String groupId, List<String> teamIds) async {
      try {
          await _service.addTeamsToGroup(groupId: groupId, teamIds: teamIds);
          refresh(); 
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> removeTeamsFromGroup(String groupId, List<String> teamIds) async {
      try {
          await _service.removeTeamsFromGroup(groupId: groupId, teamIds: teamIds);
          refresh();
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> assignManagersToGroup(String groupId, List<String> managerIds) async {
      try {
          await _service.assignManagersToGroup(groupId: groupId, managerIds: managerIds);
          refresh();
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> deleteGroup(String id) async {
      try {
          await _service.deleteGroup(id);
          refresh();
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }
}


final groupProvider = StateNotifierProvider<GroupNotifier, GroupState>((ref) {
  final service = ref.watch(staffServiceProvider);
  return GroupNotifier(service, ref);
});
