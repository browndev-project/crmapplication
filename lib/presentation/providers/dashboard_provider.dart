
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/dashboard_service.dart';
import '../../data/models/dashboard_model.dart';

class DashboardState {
  final bool isLoading;
  final String? error;
  final DashboardData? data;

  DashboardState({
    this.isLoading = false,
    this.error,
    this.data,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    DashboardData? data,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      data: data ?? this.data,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardService _service;

  DashboardNotifier(this._service) : super(DashboardState());

  Future<void> fetchDashboardData({
      bool forceRefresh = false, 
      DateTime? startDate, 
      DateTime? endDate, 
      bool isAdmin = false,
      String? assignedTo
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _service.fetchDashboardData(
          forceRefresh: forceRefresh,
          startDate: startDate,
          endDate: endDate,
          isAdmin: isAdmin,
          assignedTo: assignedTo,
      );
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final dashboardServiceProvider = Provider((ref) => DashboardService());

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref.watch(dashboardServiceProvider));
});
