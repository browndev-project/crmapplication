import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/cold_lead_service.dart';
import '../../data/models/cold_lead_model.dart';

final coldLeadServiceProvider = Provider<ColdLeadService>((ref) {
  return ColdLeadService();
});

class ColdLeadsState {
  final List<ColdLead> coldLeads;
  final bool isLoading;
  final bool isMoreLoading;
  final String? error;
  final int page;
  final int limit;
  final int totalPages;
  final int totalCount;
  final bool hasNextPage;
  final String searchQuery;
  final String selectedStatus; // 'all', 'New', 'Connected', 'Not Connected', 'Invalid', 'Qualified', 'Unqualified'

  // Original:
  // const ColdLeadsState({
  //   this.coldLeads = const [],
  //   this.isLoading = false,
  //   this.isMoreLoading = false,
  //   this.error,
  //   this.page = 1,
  //   this.limit = 20,
  //   this.totalPages = 1,
  //   this.totalCount = 0,
  //   this.hasNextPage = false,
  //   this.searchQuery = '',
  //   this.selectedStatus = 'all',
  // });
  const ColdLeadsState({
    this.coldLeads = const [],
    this.isLoading = false,
    this.isMoreLoading = false,
    this.error,
    this.page = 1,
    this.limit = 10,
    this.totalPages = 1,
    this.totalCount = 0,
    this.hasNextPage = false,
    this.searchQuery = '',
    this.selectedStatus = 'all',
  });

  ColdLeadsState copyWith({
    List<ColdLead>? coldLeads,
    bool? isLoading,
    bool? isMoreLoading,
    String? error,
    bool clearError = false,
    int? page,
    int? limit,
    int? totalPages,
    int? totalCount,
    bool? hasNextPage,
    String? searchQuery,
    String? selectedStatus,
  }) {
    return ColdLeadsState(
      coldLeads: coldLeads ?? this.coldLeads,
      isLoading: isLoading ?? this.isLoading,
      isMoreLoading: isMoreLoading ?? this.isMoreLoading,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      limit: limit ?? this.limit,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }
}

class _ColdLeadStatusCache {
  final List<ColdLead> coldLeads;
  final int page;
  final int totalPages;
  final int totalCount;
  final bool hasNextPage;

  _ColdLeadStatusCache({
    required this.coldLeads,
    required this.page,
    required this.totalPages,
    required this.totalCount,
    required this.hasNextPage,
  });
}

class ColdLeadsNotifier extends StateNotifier<ColdLeadsState> {
  final ColdLeadService _service;
  final Map<String, _ColdLeadStatusCache> _statusCache = {};

  List<ColdLead>? getCachedLeadsForStatus(String status) {
    return _statusCache[status]?.coldLeads;
  }

  ColdLeadsNotifier(this._service) : super(const ColdLeadsState()) {
    fetchColdLeads();
  }

  Future<void> fetchColdLeads({bool isRefresh = false}) async {
    if (state.isLoading) return;

    // Original:
    // state = state.copyWith(
    //   isLoading: true,
    //   clearError: true,
    //   page: 1,
    //   if (isRefresh) ...{
    //     coldLeads: [],
    //   },
    // );
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      page: 1,
      coldLeads: isRefresh ? [] : state.coldLeads,
    );

    try {
      final response = await _service.fetchColdLeads(
        page: 1,
        limit: state.limit,
        searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        status: state.selectedStatus != 'all' ? state.selectedStatus : null,
      );

      state = state.copyWith(
        isLoading: false,
        coldLeads: response.coldLeads,
        page: response.pagination.page,
        totalPages: response.pagination.totalPages,
        totalCount: response.totalCount,
        hasNextPage: response.pagination.hasNextPage,
        clearError: true,
      );

      // Cache page 1 results for the current status when not searching
      if (state.searchQuery.isEmpty) {
        _statusCache[state.selectedStatus] = _ColdLeadStatusCache(
          coldLeads: response.coldLeads,
          page: response.pagination.page,
          totalPages: response.pagination.totalPages,
          totalCount: response.totalCount,
          hasNextPage: response.pagination.hasNextPage,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isMoreLoading || !state.hasNextPage) return;

    final nextPage = state.page + 1;
    state = state.copyWith(isMoreLoading: true);

    try {
      final response = await _service.fetchColdLeads(
        page: nextPage,
        limit: state.limit,
        searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        status: state.selectedStatus != 'all' ? state.selectedStatus : null,
      );

      final combined = List<ColdLead>.from(state.coldLeads)
        ..addAll(response.coldLeads);

      state = state.copyWith(
        isMoreLoading: false,
        coldLeads: combined,
        page: response.pagination.page,
        totalPages: response.pagination.totalPages,
        totalCount: response.totalCount,
        hasNextPage: response.pagination.hasNextPage,
      );
    } catch (e) {
      state = state.copyWith(
        isMoreLoading: false,
        error: e.toString(),
      );
    }
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    fetchColdLeads(isRefresh: true);
  }

  // Original:
  // void setStatusFilter(String status) {
  //   if (state.selectedStatus == status) return;
  //   state = state.copyWith(selectedStatus: status);
  //   fetchColdLeads(isRefresh: true);
  // }

  void setStatusFilter(String status) {
    if (state.selectedStatus == status) return;

    // Cache current status state if we have leads and not actively searching
    if (state.coldLeads.isNotEmpty && state.searchQuery.isEmpty) {
      _statusCache[state.selectedStatus] = _ColdLeadStatusCache(
        coldLeads: state.coldLeads,
        page: state.page,
        totalPages: state.totalPages,
        totalCount: state.totalCount,
        hasNextPage: state.hasNextPage,
      );
    }

    // Restore from cache if available and not searching
    final cached = _statusCache[status];
    if (cached != null && state.searchQuery.isEmpty) {
      state = state.copyWith(
        selectedStatus: status,
        coldLeads: cached.coldLeads,
        page: cached.page,
        totalPages: cached.totalPages,
        totalCount: cached.totalCount,
        hasNextPage: cached.hasNextPage,
        isLoading: false,
        isMoreLoading: false,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(selectedStatus: status);
    fetchColdLeads(isRefresh: true);
  }

  // Original:
  // Future<bool> updateStatus(String id, String status) async {
  //   try {
  //     final updated = await _service.updateColdLead(id, status: status);
  //     _updateLocalLead(updated);
  //     return true;
  //   } catch (e) {
  //     state = state.copyWith(error: e.toString());
  //     return false;
  //   }
  // }

  Future<bool> updateStatus(String id, String status) async {
    try {
      final updated = await _service.updateColdLead(id, status: status);
      _statusCache.clear();
      _updateLocalLead(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Original:
  // Future<bool> updateNotes(String id, String notes) async {
  //   try {
  //     final updated = await _service.updateColdLead(id, notes: notes);
  //     _updateLocalLead(updated);
  //     return true;
  //   } catch (e) {
  //     state = state.copyWith(error: e.toString());
  //     return false;
  //   }
  // }

  Future<bool> updateNotes(String id, String notes) async {
    try {
      final updated = await _service.updateColdLead(id, notes: notes);
      _statusCache.clear();
      _updateLocalLead(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Original:
  // Future<bool> updateStatusAndNotes(String id, {String? status, String? notes}) async {
  //   try {
  //     final updated = await _service.updateColdLead(id, status: status, notes: notes);
  //     _updateLocalLead(updated);
  //     return true;
  //   } catch (e) {
  //     state = state.copyWith(error: e.toString());
  //     return false;
  //   }
  // }

  Future<bool> updateStatusAndNotes(String id, {String? status, String? notes}) async {
    try {
      final updated = await _service.updateColdLead(id, status: status, notes: notes);
      _statusCache.clear();
      _updateLocalLead(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Original:
  // Future<bool> deleteColdLead(String id) async {
  //   try {
  //     final success = await _service.deleteColdLead(id);
  //     if (success) {
  //       final updatedList = state.coldLeads.where((lead) => lead.id != id).toList();
  //       state = state.copyWith(
  //         coldLeads: updatedList,
  //         totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
  //       );
  //     }
  //     return success;
  //   } catch (e) {
  //     state = state.copyWith(error: e.toString());
  //     return false;
  //   }
  // }

  Future<bool> deleteColdLead(String id) async {
    try {
      final success = await _service.deleteColdLead(id);
      if (success) {
        _statusCache.clear();
        final updatedList = state.coldLeads.where((lead) => lead.id != id).toList();
        state = state.copyWith(
          coldLeads: updatedList,
          totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
        );
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void _updateLocalLead(ColdLead updated) {
    final index = state.coldLeads.indexWhere((l) => l.id == updated.id);
    if (index != -1) {
      final updatedList = List<ColdLead>.from(state.coldLeads);
      updatedList[index] = updated;
      state = state.copyWith(coldLeads: updatedList);
    }
  }
}

final coldLeadsProvider =
    StateNotifierProvider<ColdLeadsNotifier, ColdLeadsState>((ref) {
  final service = ref.watch(coldLeadServiceProvider);
  return ColdLeadsNotifier(service);
});
