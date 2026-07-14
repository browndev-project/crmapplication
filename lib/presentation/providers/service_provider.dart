
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/service_model.dart';
import '../../core/services/service_service.dart';

class ServicesState {
  final bool isLoading;
  final String? error;
  final List<Service> services;
  final int totalCount;
  final Pagination? pagination;

  const ServicesState({
    this.isLoading = false,
    this.error,
    this.services = const [],
    this.totalCount = 0,
    this.pagination,
  });

  ServicesState copyWith({
    bool? isLoading,
    String? error,
    List<Service>? services,
    int? totalCount,
    Pagination? pagination,
  }) {
    return ServicesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      services: services ?? this.services,
      totalCount: totalCount ?? this.totalCount,
      pagination: pagination ?? this.pagination,
    );
  }
}

class ServicesNotifier extends StateNotifier<ServicesState> {
  final ServiceService _serviceService;

  ServicesNotifier(this._serviceService) : super(const ServicesState());

  Future<void> fetchServices({int page = 1, bool isRefresh = false}) async {
    if (state.isLoading && !isRefresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final serviceData = await _serviceService.fetchServices(page: page, forceRefresh: isRefresh);
      
      state = state.copyWith(
        isLoading: false,
        services: (isRefresh || page == 1) ? serviceData.services : [...state.services, ...serviceData.services],
        totalCount: serviceData.totalCount,
        pagination: serviceData.pagination,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await fetchServices(page: 1, isRefresh: true);
  }
  
  Future<void> loadMore() async {
      if (state.pagination != null && state.pagination!.hasNextPage && !state.isLoading) {
          await fetchServices(page: state.pagination!.page + 1);
      }
  }

  Future<void> createService(Map<String, dynamic> data) async {
      try {
          await _serviceService.createService(data);
          await refresh(); // Refresh list to show new item
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
      try {
          await _serviceService.updateService(id, data);
          await refresh(); // Refresh to ensure data consistency
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> toggleServiceStatus(Service service) async {
      final oldStatus = service.active;
      
      // Optimistic update
      final updatedServices = state.services.map((s) {
          if (s.id == service.id) {
              return Service(
                  id: s.id, 
                  active: !s.active, 
                  name: s.name, 
                  description: s.description, 
                  createdAt: s.createdAt
              );
          }
          return s;
      }).toList();
      
      state = state.copyWith(services: updatedServices);

      try {
          await _serviceService.updateService(service.id, {'active': !oldStatus});
      } catch (e) {
          // Revert on failure
          final revertedServices = state.services.map((s) {
            if (s.id == service.id) {
               return Service(
                  id: s.id, 
                  active: oldStatus, 
                  name: s.name, 
                  description: s.description, 
                  createdAt: s.createdAt
              );
            }
            return s;
          }).toList();
          state = state.copyWith(services: revertedServices, error: "Failed to update status");
      }
  }
  Future<void> deleteService(String id) async {
      try {
          await _serviceService.deleteService(id);
          // Optimistic remove or refresh
          state = state.copyWith(services: state.services.where((s) => s.id != id).toList());
          // Optional: Verify by refreshing
          // await refresh(); 
      } catch (e) {
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }
}

final serviceServiceProvider = Provider<ServiceService>((ref) => ServiceService());

final servicesProvider = StateNotifierProvider.autoDispose<ServicesNotifier, ServicesState>((ref) {
  final serviceService = ref.watch(serviceServiceProvider);
  return ServicesNotifier(serviceService);
});
