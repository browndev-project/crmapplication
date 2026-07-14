import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/visit_service.dart';
import '../../data/models/visit_model.dart';
import '../../core/utils/date_utils.dart';

class VisitsState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isLoadingCounts;
  final String? error;
  final String? countsError;
  final List<Visit> visits;
  final int totalCount;
  final int scheduledCount;
  final int completedCount;
  final int cancelledCount;
  final int upcomingCount;
  final int overdueCount;
  final int currentPage;
  final int totalPages;
  final String selectedStatus;
  final String searchQuery;
  final String? assignedTo;
  final String? selectedProjectId;
  final String? selectedPropertyId;
  final String? selectedUserId;
  final String? dateFrom;
  final String? dateTo;
  final List<String> selectedStatuses;
  final String? sortBy;
  final int activeFilterCount;

  VisitsState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isLoadingCounts = false,
    this.error,
    this.countsError,
    this.visits = const [],
    this.totalCount = 0,
    this.scheduledCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.upcomingCount = 0,
    this.overdueCount = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.selectedStatus = 'All Visits',
    this.searchQuery = '',
    this.assignedTo,
    this.selectedProjectId,
    this.selectedPropertyId,
    this.selectedUserId,
    this.dateFrom,
    this.dateTo,
    this.selectedStatuses = const [],
    this.sortBy,
    this.activeFilterCount = 0,
  });

  static bool isTimeBasedFilter(String filter) {
    switch (filter) {
      case 'Today':
      case 'Tomorrow':
      case 'Next 7 Days':
      case 'Next 15 Days':
      case 'Next 30 Days':
        return true;
      default:
        return false;
    }
  }

  int get _computedFilterCount {
    int count = 0;
    if (selectedStatus != 'All Visits' && selectedStatuses.isEmpty) count++;
    if (selectedStatuses.isNotEmpty) count++;
    if (selectedProjectId != null) count++;
    if (selectedPropertyId != null) count++;
    if (selectedUserId != null) count++;
    if (dateFrom != null || dateTo != null) {
      if (!isTimeBasedFilter(selectedStatus)) count++;
    }
    if (sortBy != null) count++;
    return count;
  }

  VisitsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isLoadingCounts,
    String? error,
    String? countsError,
    List<Visit>? visits,
    int? totalCount,
    int? scheduledCount,
    int? completedCount,
    int? cancelledCount,
    int? upcomingCount,
    int? overdueCount,
    int? currentPage,
    int? totalPages,
    String? selectedStatus,
    String? searchQuery,
    String? assignedTo,
    String? selectedProjectId,
    String? selectedPropertyId,
    String? selectedUserId,
    String? dateFrom,
    String? dateTo,
    List<String>? selectedStatuses,
    String? sortBy,
    bool clearProjectId = false,
    bool clearPropertyId = false,
    bool clearUserId = false,
    bool clearDates = false,
    bool clearSortBy = false,
  }) {
    final result = VisitsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingCounts: isLoadingCounts ?? this.isLoadingCounts,
      error: error ?? this.error,
      countsError: countsError ?? this.countsError,
      visits: visits ?? this.visits,
      totalCount: totalCount ?? this.totalCount,
      scheduledCount: scheduledCount ?? this.scheduledCount,
      completedCount: completedCount ?? this.completedCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      upcomingCount: upcomingCount ?? this.upcomingCount,
      overdueCount: overdueCount ?? this.overdueCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      assignedTo: assignedTo ?? this.assignedTo,
      selectedProjectId: clearProjectId ? null : (selectedProjectId ?? this.selectedProjectId),
      selectedPropertyId: clearPropertyId ? null : (selectedPropertyId ?? this.selectedPropertyId),
      selectedUserId: clearUserId ? null : (selectedUserId ?? this.selectedUserId),
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
      sortBy: clearSortBy ? null : (sortBy ?? this.sortBy),
    );
    return VisitsState(
      isLoading: result.isLoading,
      isLoadingMore: result.isLoadingMore,
      isLoadingCounts: result.isLoadingCounts,
      error: result.error,
      countsError: result.countsError,
      visits: result.visits,
      totalCount: result.totalCount,
      scheduledCount: result.scheduledCount,
      completedCount: result.completedCount,
      cancelledCount: result.cancelledCount,
      upcomingCount: result.upcomingCount,
      overdueCount: result.overdueCount,
      currentPage: result.currentPage,
      totalPages: result.totalPages,
      selectedStatus: result.selectedStatus,
      searchQuery: result.searchQuery,
      assignedTo: result.assignedTo,
      selectedProjectId: result.selectedProjectId,
      selectedPropertyId: result.selectedPropertyId,
      selectedUserId: result.selectedUserId,
      dateFrom: result.dateFrom,
      dateTo: result.dateTo,
      selectedStatuses: result.selectedStatuses,
      sortBy: result.sortBy,
      activeFilterCount: result._computedFilterCount,
    );
  }
}

class VisitsNotifier extends StateNotifier<VisitsState> {
  final VisitService _visitService;

  VisitsNotifier(this._visitService) : super(VisitsState());

  Future<void> fetchVisitCounts({String? assignedTo}) async {
    state = state.copyWith(isLoadingCounts: true, countsError: null);
    try {
      final counts = await _visitService.fetchVisitCounts(assignedTo: assignedTo);
      state = state.copyWith(
        isLoadingCounts: false,
        scheduledCount: counts['scheduled'] ?? 0,
        completedCount: counts['completed'] ?? 0,
        cancelledCount: counts['cancelled'] ?? 0,
        upcomingCount: counts['upcoming'] ?? 0,
        overdueCount: counts['overdue'] ?? 0,
        totalCount: counts['total'] ?? 0,
      );
    } catch (e) {
      debugPrint('Error fetching visit counts: $e');
      state = state.copyWith(isLoadingCounts: false, countsError: e.toString());
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  (String? apiStatus, String? dateFrom, String? dateTo) _resolveFilterParams(String filterLabel, {String? existingDateFrom, String? existingDateTo}) {
    if (VisitsState.isTimeBasedFilter(filterLabel)) {
      final now = DateTime.now();
      switch (filterLabel) {
        case 'Today':
          final ds = _formatDate(now);
          return (null, ds, ds);
        case 'Tomorrow':
          final ds = _formatDate(now.add(const Duration(days: 1)));
          return (null, ds, ds);
        case 'Next 7 Days':
          return (null, _formatDate(now), _formatDate(now.add(const Duration(days: 7))));
        case 'Next 15 Days':
          return (null, _formatDate(now), _formatDate(now.add(const Duration(days: 15))));
        case 'Next 30 Days':
          return (null, _formatDate(now), _formatDate(now.add(const Duration(days: 30))));
        default:
          return (null, existingDateFrom, existingDateTo);
      }
    } else {
      final apiStatus = filterLabel == 'All Visits' ? null : filterLabel;
      return (apiStatus, existingDateFrom, existingDateTo);
    }
  }

  String _computeApiStatus() {
    if (state.selectedStatuses.isNotEmpty) {
      return state.selectedStatuses.join(',');
    }
    if (state.selectedStatus != 'All Visits' && !VisitsState.isTimeBasedFilter(state.selectedStatus)) {
      return state.selectedStatus;
    }
    return '';
  }

  Future<void> fetchVisits({
    int? page, 
    String? search, 
    String? status, 
    String? filterLabel, 
    String? assignedTo, 
    String? projectId, 
    String? propertyId, 
    String? dateFrom, 
    String? dateTo, 
    String? sort, 
    List<String>? statuses,
    bool clearProject = false,
    bool clearProperty = false,
    bool clearUser = false,
    bool clearDates = false,
    bool clearSort = false,
  }) async {
    final targetPage = page ?? 1;
    final isPagination = targetPage > 1;
    
    final currentSearch = search ?? state.searchQuery;

    final effectiveFilterLabel = filterLabel ?? (status ?? state.selectedStatus);

    final resolved = _resolveFilterParams(effectiveFilterLabel, existingDateFrom: clearDates ? null : (dateFrom ?? state.dateFrom), existingDateTo: clearDates ? null : (dateTo ?? state.dateTo));
    final apiStatus = status ?? resolved.$1;
    final currentDateFrom = clearDates ? null : (dateFrom ?? resolved.$2);
    final currentDateTo = clearDates ? null : (dateTo ?? resolved.$3);
    
    final currentAssignedTo = clearUser ? null : (assignedTo ?? state.assignedTo);
    final currentProjectId = clearProject ? null : (projectId ?? state.selectedProjectId);
    final currentPropertyId = clearProperty ? null : (propertyId ?? state.selectedPropertyId);
    final currentStatuses = statuses ?? state.selectedStatuses;
    final currentSortBy = clearSort ? null : (sort ?? state.sortBy);

    final String effectiveApiStatus;
    if (statuses != null) {
      effectiveApiStatus = statuses.join(',');
    } else {
      effectiveApiStatus = apiStatus ?? (currentStatuses.isNotEmpty ? currentStatuses.join(',') : (_computeApiStatus()));
    }

    if (!isPagination) {
      state = state.copyWith(
        isLoading: true, 
        visits: [],
        searchQuery: currentSearch,
        selectedStatus: effectiveFilterLabel,
        assignedTo: currentAssignedTo,
        selectedProjectId: currentProjectId,
        selectedPropertyId: currentPropertyId,
        dateFrom: currentDateFrom,
        dateTo: currentDateTo,
        selectedStatuses: currentStatuses,
        sortBy: currentSortBy,
        clearProjectId: clearProject,
        clearPropertyId: clearProperty,
        clearUserId: clearUser,
        clearDates: clearDates,
        clearSortBy: clearSort,
      );
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final response = await _visitService.fetchVisits(
        page: targetPage,
        limit: 20,
        search: currentSearch.isEmpty ? null : currentSearch,
        status: effectiveApiStatus.isEmpty ? null : effectiveApiStatus,
        assignedTo: currentAssignedTo,
        projectId: currentProjectId,
        propertyId: currentPropertyId,
        dateFrom: currentDateFrom,
        dateTo: currentDateTo,
        sort: currentSortBy,
      );

      final currentVisits = targetPage == 1 ? response.visits : [...state.visits, ...response.visits];
      
      // Local/Client-side filter fallback for robustness
      List<Visit> filteredVisits = currentVisits;

      // 1. Project Filter Fallback
      if (currentProjectId != null && currentProjectId.isNotEmpty) {
        filteredVisits = filteredVisits.where((v) => v.project?.id == currentProjectId).toList();
      }

      // 1b. Client-side Search by Project or Lead Name
      if (currentSearch.isNotEmpty) {
        final query = currentSearch.toLowerCase();
        filteredVisits = filteredVisits.where((v) =>
            (v.project?.name ?? '').toLowerCase().contains(query) ||
            (v.lead?.name ?? '').toLowerCase().contains(query)
        ).toList();
      }

      // 2. Property Filter Fallback
      if (currentPropertyId != null && currentPropertyId.isNotEmpty) {
        filteredVisits = filteredVisits.where((v) => v.property?.id == currentPropertyId).toList();
      }

      // 3. Status Filter Fallback - Case-insensitive matching
      if (currentStatuses.isNotEmpty) {
        final lowerStatuses = currentStatuses.map((s) => s.toLowerCase()).toSet();
        filteredVisits = filteredVisits.where((v) => lowerStatuses.contains(v.status.toLowerCase())).toList();
      }

      // 4. Date Range Filter Fallback - Robust parsing
      if (currentDateFrom != null && currentDateFrom.isNotEmpty) {
        final fromDate = DateTimeUtils.parseSafe(currentDateFrom);
        if (fromDate != null) {
          final fromDateOnly = DateTime(fromDate.year, fromDate.month, fromDate.day);
          filteredVisits = filteredVisits.where((v) {
            final vDate = DateTimeUtils.parseSafe(v.dateTime);
            if (vDate == null) return false;
            final vDateOnly = DateTime(vDate.year, vDate.month, vDate.day);
            return vDateOnly.isAfter(fromDateOnly) || vDateOnly.isAtSameMomentAs(fromDateOnly);
          }).toList();
        }
      }
      if (currentDateTo != null && currentDateTo.isNotEmpty) {
        final toDate = DateTimeUtils.parseSafe(currentDateTo);
        if (toDate != null) {
          final toDateOnly = DateTime(toDate.year, toDate.month, toDate.day);
          filteredVisits = filteredVisits.where((v) {
            final vDate = DateTimeUtils.parseSafe(v.dateTime);
            if (vDate == null) return false;
            final vDateOnly = DateTime(vDate.year, vDate.month, vDate.day);
            return vDateOnly.isBefore(toDateOnly) || vDateOnly.isAtSameMomentAs(toDateOnly);
          }).toList();
        }
      }

      // 5. Client-side Sort Fallback
      if (currentSortBy != null && currentSortBy.isNotEmpty) {
        filteredVisits.sort((a, b) {
          switch (currentSortBy) {
            case 'created_desc':
              final ad = DateTimeUtils.parseSafe(a.createdAt) ?? DateTime(1970);
              final bd = DateTimeUtils.parseSafe(b.createdAt) ?? DateTime(1970);
              return bd.compareTo(ad);
            case 'created_asc':
              final ad = DateTimeUtils.parseSafe(a.createdAt) ?? DateTime(1970);
              final bd = DateTimeUtils.parseSafe(b.createdAt) ?? DateTime(1970);
              return ad.compareTo(bd);
            case 'updated_desc':
              final ad = DateTimeUtils.parseSafe(a.updatedAt) ?? DateTime(1970);
              final bd = DateTimeUtils.parseSafe(b.updatedAt) ?? DateTime(1970);
              return bd.compareTo(ad);
            case 'updated_asc':
              final ad = DateTimeUtils.parseSafe(a.updatedAt) ?? DateTime(1970);
              final bd = DateTimeUtils.parseSafe(b.updatedAt) ?? DateTime(1970);
              return ad.compareTo(bd);
            case 'visit_date_desc':
              final ad = DateTimeUtils.parseSafe(a.dateTime) ?? DateTime(1970);
              final bd = DateTimeUtils.parseSafe(b.dateTime) ?? DateTime(1970);
              return bd.compareTo(ad);
            case 'visit_date_asc':
              final ad = DateTimeUtils.parseSafe(a.dateTime) ?? DateTime(1970);
              final bd = DateTimeUtils.parseSafe(b.dateTime) ?? DateTime(1970);
              return ad.compareTo(bd);
            default:
              return 0;
          }
        });
      }
      
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        visits: filteredVisits,
        totalCount: response.totalCount,
        totalPages: response.totalPages,
        currentPage: response.currentPage,
        error: null,
        searchQuery: currentSearch,
      );

      if (targetPage == 1) {
        fetchVisitCounts(assignedTo: currentAssignedTo);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, isLoadingMore: false, error: e.toString());
    }
  }

  void setStatus(String filterLabel) {
    if (state.selectedStatus != filterLabel) {
      fetchVisits(page: 1, filterLabel: filterLabel, statuses: []);
    }
  }

  void setSearch(String query) {
    if (state.searchQuery != query) {
      fetchVisits(page: 1, search: query);
    }
  }

  void setProjectFilter(String? projectId) {
    if (state.selectedProjectId != projectId) {
      fetchVisits(page: 1, projectId: projectId, clearProject: projectId == null, clearProperty: true);
    }
  }

  void setPropertyFilter(String? propertyId) {
    if (state.selectedPropertyId != propertyId) {
      fetchVisits(page: 1, propertyId: propertyId, clearProperty: propertyId == null);
    }
  }

  void setUserFilter(String? userId) {
    if (state.selectedUserId != userId) {
      fetchVisits(page: 1, assignedTo: userId, clearUser: userId == null);
    }
  }

  void setDateRange(String? from, String? to) {
    if (state.dateFrom != from || state.dateTo != to) {
      fetchVisits(page: 1, dateFrom: from, dateTo: to, clearDates: from == null && to == null);
    }
  }

  void clearFilters() {
    fetchVisits(
      page: 1,
      filterLabel: 'All Visits',
      search: '',
      clearProject: true,
      clearProperty: true,
      clearUser: true,
      clearDates: true,
      clearSort: true,
      statuses: [],
    );
  }

  void setSortBy(String? sort) {
    if (state.sortBy != sort) {
      fetchVisits(page: 1, sort: sort, clearSort: sort == null);
    }
  }

  void setFilterPanelFilters({List<String>? statuses, String? projectId, String? propertyId, String? from, String? to, String? sort, String? quickFilter}) {
    final effectiveLabel = (quickFilter != null && quickFilter != 'Quick') ? quickFilter : 'All Visits';
    fetchVisits(
      page: 1,
      filterLabel: effectiveLabel,
      statuses: statuses,
      projectId: projectId,
      propertyId: propertyId,
      dateFrom: from,
      dateTo: to,
      sort: sort,
      clearProject: projectId == null,
      clearProperty: propertyId == null,
      clearDates: (from == null && to == null) && !VisitsState.isTimeBasedFilter(effectiveLabel),
      clearSort: sort == null,
    );
  }

  Future<void> createVisit(Map<String, dynamic> data) async {
    try {
      await _visitService.createVisit(data);
      await fetchVisits(page: 1); // Refresh list
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateVisit(String id, Map<String, dynamic> data) async {
    try {
      await _visitService.updateVisit(id, data);
      await fetchVisits(page: 1); // Refresh list
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteVisit(String id) async {
    try {
      await _visitService.deleteVisit(id);
      await fetchVisits(page: 1); // Refresh list
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final visitServiceProvider = Provider((ref) => VisitService());

final visitsProvider = StateNotifierProvider<VisitsNotifier, VisitsState>((ref) {
  return VisitsNotifier(ref.watch(visitServiceProvider));
});

class ProjectVisitsState {
  final List<Visit> visits;
  final bool isLoading;
  final String? error;

  ProjectVisitsState({
    this.visits = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectVisitsState copyWith({
    List<Visit>? visits,
    bool? isLoading,
    String? error,
  }) {
    return ProjectVisitsState(
      visits: visits ?? this.visits,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get scheduledCount => visits.where((v) => v.status.toLowerCase() == 'scheduled').length;
  int get completedCount => visits.where((v) => v.status.toLowerCase() == 'completed').length;
  int get cancelledCount => visits.where((v) => v.status.toLowerCase() == 'cancelled').length;
}

class ProjectVisitsNotifier extends StateNotifier<ProjectVisitsState> {
  final VisitService _service;
  final String projectId;

  ProjectVisitsNotifier(this._service, this.projectId) : super(ProjectVisitsState()) {
    fetchProjectVisits();
  }

  Future<void> fetchProjectVisits() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _service.fetchVisits(
        page: 1,
        limit: 1000,
        projectId: projectId,
      );
      
      // Filter client-side just in case the backend query is less precise or doesn't support projectId parameter
      final filteredVisits = response.visits.where((v) => v.project?.id == projectId).toList();
      
      state = state.copyWith(
        visits: filteredVisits,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final projectVisitsProvider = StateNotifierProvider.family<ProjectVisitsNotifier, ProjectVisitsState, String>((ref, projectId) {
  final service = ref.watch(visitServiceProvider);
  return ProjectVisitsNotifier(service, projectId);
});
