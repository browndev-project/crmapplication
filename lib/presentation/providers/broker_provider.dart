import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/broker_model.dart';
import '../../core/services/broker_service.dart';

class BrokersState {
  final bool isLoading;
  final bool isStatsLoading;
  final String? error;
  final List<Broker> brokers;
  final int totalCount;
  final BrokerPagination? pagination;
  final BrokerStats? stats;
  final String searchQuery;
  final String selectedType;
  final String selectedStatus;

  const BrokersState({
    this.isLoading = false,
    this.isStatsLoading = false,
    this.error,
    this.brokers = const [],
    this.totalCount = 0,
    this.pagination,
    this.stats,
    this.searchQuery = '',
    this.selectedType = 'All Types',
    this.selectedStatus = 'All Status',
  });

  BrokersState copyWith({
    bool? isLoading,
    bool? isStatsLoading,
    String? error,
    List<Broker>? brokers,
    int? totalCount,
    BrokerPagination? pagination,
    BrokerStats? stats,
    String? searchQuery,
    String? selectedType,
    String? selectedStatus,
  }) {
    return BrokersState(
      isLoading: isLoading ?? this.isLoading,
      isStatsLoading: isStatsLoading ?? this.isStatsLoading,
      error: error,
      brokers: brokers ?? this.brokers,
      totalCount: totalCount ?? this.totalCount,
      pagination: pagination ?? this.pagination,
      stats: stats ?? this.stats,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: selectedType ?? this.selectedType,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }
}

class BrokersNotifier extends StateNotifier<BrokersState> {
  final BrokerService _brokerService;

  BrokersNotifier(this._brokerService) : super(const BrokersState());

  Future<void> fetchBrokers({int page = 1, bool isRefresh = false}) async {
    if (state.isLoading && !isRefresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _brokerService.fetchBrokers(
        page: page,
        limit: 20,
        searchQuery: state.searchQuery,
        type: state.selectedType,
        status: state.selectedStatus,
      );

      state = state.copyWith(
        isLoading: false,
        brokers: (isRefresh || page == 1) ? data.brokers : [...state.brokers, ...data.brokers],
        totalCount: data.totalCount,
        pagination: data.pagination,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchStats() async {
    state = state.copyWith(isStatsLoading: true, error: null);
    try {
      final stats = await _brokerService.fetchStats();
      state = state.copyWith(isStatsLoading: false, stats: stats);
    } catch (e) {
      state = state.copyWith(isStatsLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    fetchStats();
    await fetchBrokers(page: 1, isRefresh: true);
  }

  Future<void> loadMore() async {
    if (state.pagination != null && state.pagination!.hasNextPage && !state.isLoading) {
      await fetchBrokers(page: state.pagination!.page + 1);
    }
  }

  void updateFilters({String? searchQuery, String? type, String? status}) {
    state = state.copyWith(
      searchQuery: searchQuery ?? state.searchQuery,
      selectedType: type ?? state.selectedType,
      selectedStatus: status ?? state.selectedStatus,
    );
    refresh();
  }

  Future<void> createBroker(Map<String, dynamic> data) async {
    try {
      await _brokerService.createBroker(data);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateBroker(String id, Map<String, dynamic> data) async {
    try {
      await _brokerService.updateBroker(id, data);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteBroker(String id) async {
    try {
      await _brokerService.deleteBroker(id);
      state = state.copyWith(
        brokers: state.brokers.where((b) => b.id != id).toList(),
        totalCount: state.totalCount - 1,
      );
      fetchStats();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final brokerServiceProvider = Provider<BrokerService>((ref) => BrokerService());

final brokersProvider = StateNotifierProvider.autoDispose<BrokersNotifier, BrokersState>((ref) {
  final service = ref.watch(brokerServiceProvider);
  final notifier = BrokersNotifier(service);
  // Auto-fetch list and stats on load
  notifier.refresh();
  return notifier;
});
