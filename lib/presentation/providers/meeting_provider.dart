import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/meeting_service.dart';
import '../../data/models/meeting_model.dart';

class MeetingsState {
  final bool isLoading;
  final bool isLoadingMore; // Added property
  final String? error;
  final List<Meeting> meetings;
  final int totalCount;
  final int scheduledCount;
  final int doneCount;
  final int currentPage;
  final int totalPages;
  final String selectedStatus;
  final String search;
  final String? assignedTo;

  MeetingsState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.meetings = const [],
    this.totalCount = 0,
    this.scheduledCount = 0,
    this.doneCount = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.selectedStatus = 'All',
    this.search = '',
    this.assignedTo,
  });

  MeetingsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<Meeting>? meetings,
    int? totalCount,
    int? scheduledCount,
    int? doneCount,
    int? currentPage,
    int? totalPages,
    String? selectedStatus,
    String? search,
    String? assignedTo,
  }) {
    return MeetingsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      meetings: meetings ?? this.meetings,
      totalCount: totalCount ?? this.totalCount,
      scheduledCount: scheduledCount ?? this.scheduledCount,
      doneCount: doneCount ?? this.doneCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      search: search ?? this.search,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}

class MeetingsNotifier extends StateNotifier<MeetingsState> {
  final MeetingService _meetingService;

  MeetingsNotifier(this._meetingService) : super(MeetingsState());

  Future<void> fetchStats({String? assignedTo}) async {
    try {
      // Fetch a large batch to calculate stats locally for the specific user context
      final response = await _meetingService.fetchMeetings(
        page: 1,
        limit: 100,
        assignedTo: assignedTo,
      );

      final scheduled = response.meetings
          .where((m) => m.status == 'Scheduled')
          .length;
      final completed = response.meetings
          .where((m) => m.status == 'Completed')
          .length;

      state = state.copyWith(
        scheduledCount: scheduled,
        doneCount: completed,
        totalCount: response.totalCount,
      );
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  Future<void> fetchMeetings({
    int? page,
    String? search,
    String? status,
    String? leadId,
    String? assignedTo,
  }) async {
    final targetPage = page ?? state.currentPage;
    final isPagination = targetPage > 1;

    final currentSearch = search ?? state.search;
    final currentStatus = status ?? state.selectedStatus;
    final currentAssignedTo = assignedTo ?? state.assignedTo;

    if (!isPagination) {
      state = state.copyWith(
        isLoading: true,
        meetings: [],
        selectedStatus: currentStatus,
        search: currentSearch,
        assignedTo: currentAssignedTo,
      );
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final response = await _meetingService.fetchMeetings(
        page: targetPage,
        limit: 10,
        search: currentSearch.isEmpty ? null : currentSearch,
        status: currentStatus == 'All' ? null : currentStatus,
        assignedTo: currentAssignedTo,
        leadId: leadId,
      );

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        meetings: targetPage == 1
            ? response.meetings
            : [...state.meetings, ...response.meetings],
        totalCount: response.totalCount,
        totalPages: response.totalPages,
        currentPage: response.currentPage,
        error: null,
      );

      // Fetch stats on first load or refresh to keep cards updated
      if (targetPage == 1) {
        fetchStats(assignedTo: currentAssignedTo);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await fetchMeetings(page: 1);
  }

  Future<void> createMeeting(Map<String, dynamic> data) async {
    try {
      await _meetingService.createMeeting(data);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateMeeting(String id, Map<String, dynamic> data) async {
    try {
      await _meetingService.updateMeeting(id, data);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteMeeting(String id) async {
    // Optimistic update
    final previousMeetings = state.meetings;
    state = state.copyWith(
      meetings: state.meetings.where((m) => m.id != id).toList(),
    );

    try {
      await _meetingService.deleteMeeting(id);
      // Refresh stats to keep counts accurate
      fetchStats();
    } catch (e) {
      state = state.copyWith(
        meetings: previousMeetings,
        error: "Failed to delete meeting",
      );
      rethrow;
    }
  }
}

final meetingServiceProvider = Provider((ref) => MeetingService());

final meetingsProvider = StateNotifierProvider<MeetingsNotifier, MeetingsState>(
  (ref) {
    return MeetingsNotifier(ref.watch(meetingServiceProvider));
  },
);
