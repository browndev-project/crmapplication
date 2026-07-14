
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/team_model.dart';
import '../../core/services/staff_service.dart';
import '../../core/constants/permission_constants.dart';
import 'permissions_provider.dart';
import 'login_provider.dart';
import 'staff_provider.dart'; // To reuse staffServiceProvider

class TeamState {
  final bool isLoading;
  final List<Team> teams;
  final String? error;
  final int page;
  final int totalPages;
  final int totalCount; // Added field
  final String searchQuery;

  TeamState({
    this.isLoading = false,
    this.teams = const [],
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.totalCount = 0, // Default
    this.searchQuery = '',
  });

  TeamState copyWith({
    bool? isLoading,
    List<Team>? teams,
    String? error,
    int? page,
    int? totalPages,
    int? totalCount, 
    String? searchQuery,
  }) {
    return TeamState(
      isLoading: isLoading ?? this.isLoading,
      teams: teams ?? this.teams,
      error: error,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class TeamNotifier extends StateNotifier<TeamState> {
  final StaffService _service;
  final Ref _ref;

  TeamNotifier(this._service, this._ref) : super(TeamState()) {
    fetchTeams();
  }

  Future<void> fetchTeams({int page = 1, bool isRefresh = false}) async {
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
      // Use search query from state if not passed (or empty if refreshing)
      final query = state.searchQuery;
      
      final response = await _service.fetchTeams(
        page: page,
        search: query,
      );

      state = state.copyWith(
        isLoading: false,
        teams: isRefresh ? response.teams : [...state.teams, ...response.teams],
        page: response.page,
        totalPages: response.totalPages,
        totalCount: response.totalCount,
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

  // Next/Prev page removed in favor of infinite scroll loadMore
  Future<void> loadMore() async {
    if (state.page < state.totalPages && !state.isLoading) {
      await fetchTeams(page: state.page + 1);
    }
  }

  Future<void> refresh() async {
    await fetchTeams(page: 1, isRefresh: true);
  }

  Future<void> createTeam(String name, bool active) async {
      try {
          await _service.createTeam(name: name, active: active);
          refresh(); // Refresh list to show new team
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> updateTeam(String id, String name, bool active) async {
      try {
          await _service.updateTeam(id: id, name: name, active: active);
          refresh(); // Refresh list to show updated team
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> addMembersToTeam(String teamId, List<String> memberIds) async {
      try {
          await _service.addMembersToTeam(teamId: teamId, memberIds: memberIds);
          refresh();
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> assignLeadersToTeam(String teamId, List<String> leaderIds) async {
      try {
          await _service.assignLeadersToTeam(teamId: teamId, leaderIds: leaderIds);
          refresh();
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> removeMembersFromTeam(String teamId, List<String> memberIds) async {
      try {
          await _service.removeMembersFromTeam(teamId: teamId, memberIds: memberIds);
          refresh();
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> deleteTeam(String id) async {
      try {
          await _service.deleteTeam(id);
          refresh(); 
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }
}

final teamProvider = StateNotifierProvider<TeamNotifier, TeamState>((ref) {
  final service = ref.watch(staffServiceProvider); // Reusing service provider
  return TeamNotifier(service, ref);
});
