import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/lead_model.dart';
import '../../data/models/call_log_model.dart';
import '../../data/models/status_model.dart';
import '../../core/services/lead_service.dart';
import '../../core/services/task_service.dart';
import 'login_provider.dart';

class LeadsState {
  final bool isLoading;
  final String? error;
  final List<Lead> leads;
  final int totalCount;
  final int currentPage;
  final int totalPages;

  const LeadsState({
    this.isLoading = false,
    this.error,
    this.leads = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.filters = const {'sort': 'updated_desc'},
  });

  final Map<String, dynamic> filters;

  LeadsState copyWith({
    bool? isLoading,
    String? error,
    List<Lead>? leads,
    int? totalCount,
    int? currentPage,
    int? totalPages,
    Map<String, dynamic>? filters,
  }) {
    return LeadsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      leads: leads ?? this.leads,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      filters: filters ?? this.filters,
    );
  }
}

class LeadsNotifier extends StateNotifier<LeadsState> {
  final LeadService _leadService;
  final Ref _ref;

  LeadsNotifier(this._leadService, this._ref, {Map<String, dynamic>? initialFilters})
      : super(LeadsState(filters: initialFilters ?? const {'sort': 'updated_desc'}));

  Future<void> fetchLeads({int page = 1, bool isRefresh = false}) async {
    if (state.isLoading && !isRefresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _leadService.fetchLeads(
          page: page, 
          limit: 10,
          search: state.filters['search'],
          service: state.filters['service'],
          status: state.filters['status'],
          source: state.filters['source'],
          pipeline: state.filters['pipeline'],
          assignedTo: state.filters['assignedTo'],
          team: state.filters['team'],
          group: state.filters['group'],
          project: state.filters['project'],
          sort: state.filters['sort'],
          startDate: state.filters['startDate'],
          endDate: state.filters['endDate'],
          duplicate: state.filters['duplicate'] == true || state.filters['duplicate'] == 'true',
          gender: state.filters['gender'],
          onlySubAssigned: state.filters['onlySubAssigned'] == true || state.filters['onlySubAssigned'] == 'true',
          isLost: state.filters['isLost'] == true || state.filters['isLost'] == 'true',
      );
      
      var fetchedLeads = response.leads;
      
      // Client-side fallback filter for sub-assignees
      if (state.filters['onlySubAssigned'] == true || state.filters['onlySubAssigned'] == 'true') {
        final loggedInUser = _ref.read(loginProvider).user;
        if (loggedInUser != null) {
          fetchedLeads = fetchedLeads.where((l) {
            if (l.subAssignees == null || l.subAssignees!.isEmpty) return false;
            if (l.assignedTo?.id == loggedInUser.id) return false;
            return l.subAssignees!.any((sa) => sa.id == loggedInUser.id);
          }).toList();
        }
      }
      
      // Client-side fallback filter if backend search fails
      final search = state.filters['search'];
      if (search != null && search.toString().trim().isNotEmpty) {
          final query = search.toString().toLowerCase().trim();
          fetchedLeads = fetchedLeads.where((l) {
             final name = l.name.toLowerCase();
             final phone = l.phoneNo.toLowerCase();
             // Assuming service name is also searchable
             final service = l.service?.name.toLowerCase() ?? '';
             final source = l.source.toLowerCase();
             
             return name.contains(query) || phone.contains(query) || service.contains(query) || source.contains(query);
          }).toList();
      }

      state = state.copyWith(
        isLoading: false,
        leads: isRefresh ? fetchedLeads : [...state.leads, ...fetchedLeads], // Append for pagination
        totalCount: response.totalCount,
        currentPage: response.currentPage,
        totalPages: response.totalPages,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
      await fetchLeads(page: 1, isRefresh: true);
  }
  
  Future<void> loadMore() async {
      if (state.currentPage < state.totalPages) {
          await fetchLeads(page: state.currentPage + 1);
      }
  }

  Future<void> applyFilters(Map<String, dynamic> filters) async {
      state = state.copyWith(filters: filters);
      await refresh();
  }

  Future<void> createLead(Map<String, dynamic> leadData) async {
    try {
      await _leadService.createManualLead(leadData);
      // Refresh list after successful creation
      await refresh();
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> updateLead(String id, Map<String, dynamic> leadData) async {
    try {
      await _leadService.updateLead(id, leadData);
      await refresh();
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> updateLeadStatus(
    String id,
    String status, {
    String? comment,
    bool? isLost,
    bool? isScheduleFollowup,
    String? followUpTitle,
    String? followUpDate,
  }) async {
    try {
      await _leadService.updateStatus(
        id,
        status,
        comment: comment,
        isLost: isLost,
        isScheduleFollowup: isScheduleFollowup,
        followUpTitle: followUpTitle,
        followUpDate: followUpDate,
      );

      // Call the secondary follow-up task creation API
      if (isScheduleFollowup == true && followUpDate != null) {
        try {
          final taskService = TaskService();
          await taskService.createTask({
            "title": (followUpTitle != null && followUpTitle.trim().isNotEmpty) ? followUpTitle.trim() : "Follow up",
            "description": comment != null && comment.trim().isNotEmpty ? comment.trim() : "Created during status update",
            "dueDate": followUpDate,
            "status": "Not Started",
            "leadId": id,
          });
        } catch (taskError) {
          debugPrint("[LeadsNotifier] Secondary follow-up task creation failed: $taskError");
        }
      }

      await refresh();
      try {
        final detailState = _ref.read(leadDetailProvider);
        if (detailState.lead?.id == id) {
          _ref.read(leadDetailProvider.notifier).fetchLeadDetails(id);
        }
      } catch (_) {}
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> deleteLead(String id) async {
    try {
      final success = await _leadService.deleteLead(id);
      if (success) {
        state = state.copyWith(
          leads: state.leads.where((l) => l.id != id).toList(),
          totalCount: state.totalCount - 1,
        );
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting lead: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> bulkUploadLeads(dynamic file) async {
    try {
      final result = await _leadService.bulkUploadLeads(file);
      await refresh();
      return result;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> assignLead(String id, String toUserId) async {
    try {
      final success = await _leadService.assignLead(id, toUserId);
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      debugPrint('Error assigning lead: $e');
      return false;
    }
  }

  Future<bool> bulkAssign(List<String> leadIds, String toUserId) async {
    try {
      final success = await _leadService.bulkAssign(leadIds, toUserId);
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      debugPrint('Error bulk assigning leads: $e');
      return false;
    }
  }

  Future<bool> bulkUpdate(List<String> leadIds, Map<String, dynamic> updates) async {
    try {
      final success = await _leadService.bulkUpdate(leadIds, updates);
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      debugPrint('Error bulk updating leads: $e');
      return false;
    }
  }
}


class LeadDetailState {
  final bool isLoading;
  final String? error;
  final Lead? lead;

  const LeadDetailState({this.isLoading = false, this.error, this.lead});

  LeadDetailState copyWith({bool? isLoading, String? error, Lead? lead}) {
    return LeadDetailState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lead: lead ?? this.lead,
    );
  }
}

class LeadDetailNotifier extends StateNotifier<LeadDetailState> {
  final LeadService _leadService;

  LeadDetailNotifier(this._leadService) : super(const LeadDetailState());

  Future<void> fetchLeadDetails(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final lead = await _leadService.fetchLeadDetails(id);
      state = state.copyWith(isLoading: false, lead: lead);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> deleteLead(String id) async {
    try {
      return await _leadService.deleteLead(id);
    } catch (e) {
      debugPrint('Error deleting lead: $e');
      return false;
    }
  }
}

class CallLogsState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<CallLog> logs;
  final int currentPage;
  final int totalPages;
  final int totalCount;

  const CallLogsState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.logs = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalCount = 0,
  });

  CallLogsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<CallLog>? logs,
    int? currentPage,
    int? totalPages,
    int? totalCount,
  }) {
    return CallLogsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      logs: logs ?? this.logs,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class CallLogsNotifier extends StateNotifier<CallLogsState> {
  final LeadService _leadService;

  CallLogsNotifier(this._leadService) : super(const CallLogsState());

  Future<void> fetchCallLogs(String leadId) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _leadService.fetchCallLogs(leadId, page: 1);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        logs: result.logs,
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalCount: result.totalCount,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore(String leadId) async {
    if (state.isLoadingMore || state.currentPage >= state.totalPages) return;
    if (!mounted) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _leadService.fetchCallLogs(leadId, page: state.currentPage + 1);
      if (!mounted) return;
      final existingIds = state.logs.map((l) => l.id).toSet();
      final uniqueNew = result.logs.where((l) => !existingIds.contains(l.id)).toList();
      state = state.copyWith(
        isLoadingMore: false,
        logs: [...state.logs, ...uniqueNew],
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalCount: result.totalCount,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

final leadServiceProvider = Provider<LeadService>((ref) => LeadService());

final leadsProvider = StateNotifierProvider<LeadsNotifier, LeadsState>((ref) {
  final leadService = ref.watch(leadServiceProvider);
  return LeadsNotifier(leadService, ref);
});

final lostLeadsProvider = StateNotifierProvider<LeadsNotifier, LeadsState>((ref) {
  final leadService = ref.watch(leadServiceProvider);
  return LeadsNotifier(leadService, ref, initialFilters: const {
    'sort': 'updated_desc',
    'isLost': true,
  });
});

final leadDetailProvider = StateNotifierProvider.autoDispose<LeadDetailNotifier, LeadDetailState>((ref) {
  final leadService = ref.watch(leadServiceProvider);
  return LeadDetailNotifier(leadService);
});

final callLogsProvider = StateNotifierProvider.autoDispose<CallLogsNotifier, CallLogsState>((ref) {
  final leadService = ref.watch(leadServiceProvider);
  return CallLogsNotifier(leadService);
});

// --- Lead Statuses ---

class LeadStatusState {
    final bool isLoading;
    final List<LeadStatus> statuses;
    final String? error;
    
    const LeadStatusState({this.isLoading = false, this.statuses = const [], this.error});
    
    LeadStatusState copyWith({bool? isLoading, List<LeadStatus>? statuses, String? error}) {
        return LeadStatusState(
            isLoading: isLoading ?? this.isLoading,
            statuses: statuses ?? this.statuses,
            error: error
        );
    }
}

class LeadStatusNotifier extends StateNotifier<LeadStatusState> {
    final LeadService _leadService;
    
    LeadStatusNotifier(this._leadService) : super(const LeadStatusState());
    
    Future<void> fetchStatuses() async {
        if (state.statuses.isNotEmpty) {
           debugPrint('⚠️ Statuses already loaded: ${state.statuses.length}');
           return; 
        }
        await _load();
    }
    
    Future<void> refreshStatuses() async {
        await _load();
    }
    
    Future<void> _load() async {
        debugPrint('🚀 Fetching Lead Statuses...');
        state = state.copyWith(isLoading: true);
        try {
            final statuses = await _leadService.fetchLeadStatuses();
            debugPrint('✅ Parsed Statuses for Provider: ${statuses.length}');
            state = state.copyWith(isLoading: false, statuses: statuses);
        } catch (e) {
             debugPrint('❌ Error fetching statuses: $e');
             state = state.copyWith(isLoading: false, error: e.toString());
        }
    }
    Future<void> updateStatusActiveState(String id, bool isActive) async {
        try {
            await _leadService.updateCompanyLeadStatus(id, isActive: isActive);
            
            // Optimistic update
            final index = state.statuses.indexWhere((s) => s.id == id);
            if (index != -1) {
                final updatedList = List<LeadStatus>.from(state.statuses);
                final old = updatedList[index];
                updatedList[index] = LeadStatus(
                    id: old.id, name: old.name, color: old.color, 
                    backgroundColor: old.backgroundColor, isActive: isActive, isDefault: old.isDefault
                );
                state = state.copyWith(statuses: updatedList);
            } else {
                 await _load();
            }
        } catch (e) {
             debugPrint('❌ Error updating status active state: $e');
        }
    }
}

final leadStatusProvider = StateNotifierProvider<LeadStatusNotifier, LeadStatusState>((ref) {
    final leadService = ref.watch(leadServiceProvider);
    return LeadStatusNotifier(leadService);
});
