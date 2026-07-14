import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../core/services/attendance_service.dart';
import '../data/models/attendance_model.dart';

final attendanceServiceProvider = Provider<AttendanceService>((ref) => AttendanceService());

final companyAttendanceProvider = FutureProvider.autoDispose<CompanyAttendanceResponse?>((ref) async {
  final service = ref.watch(attendanceServiceProvider);
  return service.getCompanyAttendanceCurrent();
});

// --- History State Management ---

class AttendanceHistoryState {
  final bool isLoading;
  final String? error;
  final List<AttendanceRecordHistory> history;
  final Pagination? pagination;

  const AttendanceHistoryState({
    this.isLoading = false,
    this.error,
    this.history = const [],
    this.pagination,
  });

  AttendanceHistoryState copyWith({
    bool? isLoading,
    String? error,
    List<AttendanceRecordHistory>? history,
    Pagination? pagination,
  }) {
    return AttendanceHistoryState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      history: history ?? this.history,
      pagination: pagination ?? this.pagination,
    );
  }
}

class AttendanceHistoryNotifier extends StateNotifier<AttendanceHistoryState> {
  final AttendanceService _service;

  AttendanceHistoryNotifier(this._service) : super(const AttendanceHistoryState());

  Future<void> fetchHistory({
    required String userId,
    int page = 1,
    int limit = 10,
    String? fromDate,
    String? toDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _service.getAttendanceRecords(
        userId: userId,
        page: page,
        limit: limit,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (response.success && response.data != null) {
        state = state.copyWith(
          isLoading: false,
          history: response.data!.records,
          pagination: response.data!.pagination,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty ? response.message : 'Failed to fetch history',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final attendanceHistoryProvider = StateNotifierProvider<AttendanceHistoryNotifier, AttendanceHistoryState>((ref) {
  final service = ref.watch(attendanceServiceProvider);
  return AttendanceHistoryNotifier(service);
});
