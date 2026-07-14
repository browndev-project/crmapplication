import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/itinerary_model.dart';
import '../../core/services/itinerary_service.dart';
import 'permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import 'login_provider.dart';

class ItineraryV2State {
  final List<ItineraryV2> itineraries;
  final List<Map<String, dynamic>> templates;
  final String? previewHtml;
  final bool isLoading;
  final bool isMoreLoading;
  final String? error;
  final int totalCount;
  final int currentPage;
  final String searchQuery;
  final bool? hasQuotationFilter;
  final Map<String, dynamic> stats;
  final String? leadFilter;

  ItineraryV2State({
    this.itineraries = const [],
    this.templates = const [],
    this.previewHtml,
    this.isLoading = false,
    this.isMoreLoading = false,
    this.error,
    this.totalCount = 0,
    this.currentPage = 1,
    this.searchQuery = '',
    this.hasQuotationFilter = false, // Default to false (Without Quote) as per user requirement
    this.stats = const {},
    this.leadFilter,
  });

  ItineraryV2State copyWith({
    List<ItineraryV2>? itineraries,
    List<Map<String, dynamic>>? templates,
    String? previewHtml,
    bool? isLoading,
    bool? isMoreLoading,
    String? error,
    int? totalCount,
    int? currentPage,
    String? searchQuery,
    bool? hasQuotationFilter,
    bool clearQuotationFilter = false,
    Map<String, dynamic>? stats,
    String? leadFilter,
    bool clearLeadFilter = false,
    bool clearPreviewHtml = false,
  }) {
    return ItineraryV2State(
      itineraries: itineraries ?? this.itineraries,
      templates: templates ?? this.templates,
      previewHtml: clearPreviewHtml ? null : (previewHtml ?? this.previewHtml),
      isLoading: isLoading ?? this.isLoading,
      isMoreLoading: isMoreLoading ?? this.isMoreLoading,
      error: error,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      hasQuotationFilter: clearQuotationFilter ? null : (hasQuotationFilter ?? this.hasQuotationFilter),
      stats: stats ?? this.stats,
      leadFilter: clearLeadFilter ? null : (leadFilter ?? this.leadFilter),
    );
  }
}

class ItineraryV2Notifier extends StateNotifier<ItineraryV2State> {
  final ItineraryService _service = ItineraryService();
  final Ref ref;

  ItineraryV2Notifier(this.ref) : super(ItineraryV2State()) {
    fetchItineraries();
  }

  Future<void> fetchItineraries({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, currentPage: 1, itineraries: []);
    } else {
      if (state.isLoading || state.isMoreLoading) return;
      if (state.itineraries.isNotEmpty && state.itineraries.length >= state.totalCount) return;
      if (state.itineraries.isNotEmpty) {
        state = state.copyWith(isMoreLoading: true);
      } else {
        state = state.copyWith(isLoading: true);
      }
    }

    try {
      final responseJson = await _service.getItineraries(
        searchQuery: state.searchQuery,
        page: state.currentPage,
        hasQuotation: state.hasQuotationFilter,
        lead: state.leadFilter,
      );

      final data = responseJson['data'] ?? responseJson;

      final List<ItineraryV2> newItems = (data['itineraries'] as List? ?? [])
          .map((e) => ItineraryV2.fromJson(e))
          .toList();

      final int totalCount = data['totalCount'] ?? data['total'] ?? newItems.length;

      final List<ItineraryV2> allItems;
      if (refresh) {
        allItems = newItems;
      } else {
        final Map<String, ItineraryV2> merged = {};
        for (var item in state.itineraries) {
          merged[item.id] = item;
        }
        for (var item in newItems) {
          merged[item.id] = item;
        }
        allItems = merged.values.toList();
      }

      // Stats extraction
      final Map<String, dynamic> responseStats = responseJson['stats'] ?? data['stats'] ?? {
        'totalPlans': totalCount,
        'engagedClients': allItems.map((e) => e.customerName).toSet().where((name) => name.isNotEmpty).length,
        'portfolioValue': allItems.fold<double>(0, (sum, item) => sum + item.totalPrice),
      };

      state = state.copyWith(
        isLoading: false,
        isMoreLoading: false,
        itineraries: allItems,
        totalCount: totalCount,
        currentPage: refresh ? 2 : state.currentPage + 1,
        stats: responseStats,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isMoreLoading: false, error: e.toString());
      if (refresh) {
        throw e.toString();
      }
    }
  }

  Future<void> fetchTemplates() async {
    try {
      final templates = await _service.getTemplates();
      state = state.copyWith(templates: templates);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> fetchPreviewHtml(String key) async {
    state = state.copyWith(isLoading: true);
    try {
      final html = await _service.getTemplatePreviewHtml(key);
      state = state.copyWith(isLoading: false, previewHtml: html);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    fetchItineraries(refresh: true);
  }

  void toggleQuotationFilter(bool? val) {
    state = state.copyWith(
      hasQuotationFilter: val,
      clearQuotationFilter: val == null,
    );
    fetchItineraries(refresh: true);
  }

  Future<void> setLeadFilter(String? leadId) async {
    state = state.copyWith(
      leadFilter: leadId,
      clearLeadFilter: leadId == null,
    );
    await fetchItineraries(refresh: true);
  }

  Future<void> createItinerary(Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_CREATE, userRole: userRole)) {
      throw 'Permission Denied';
    }
    await _service.createItinerary(data);
    fetchItineraries(refresh: true);
  }

  Future<void> updateItinerary(String id, Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_CREATE, userRole: userRole)) {
      // Create permission acts as update here, or if there's separate update logic:
      // In roles.dart it's ITINERARY_CREATE or we can check can update
    }
    await _service.updateItinerary(id, data);
    fetchItineraries(refresh: true);
  }

  Future<void> deleteItinerary(String id) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_DELETE, userRole: userRole)) {
      throw 'Permission Denied';
    }
    await _service.deleteItinerary(id);
    fetchItineraries(refresh: true);
  }

  Future<void> cloneItinerary(String id) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_DUPLICATE, userRole: userRole)) {
      throw 'Permission Denied';
    }
    await _service.cloneItinerary(id);
    fetchItineraries(refresh: true);
  }

  Future<String?> downloadPdf(String id, String title) async {
    return await _service.downloadItinerary(id, title);
  }

  Future<String?> generatePdfUrl(String id) async {
    return await _service.generateItineraryPdf(id);
  }

  Future<String> getShareMessage(String id) async {
    return await _service.getShareMessage(id);
  }
}

final itineraryV2Provider = StateNotifierProvider<ItineraryV2Notifier, ItineraryV2State>((ref) {
  return ItineraryV2Notifier(ref);
});

// For detail explorer
class ItineraryDetailState {
  final ItineraryV2? itinerary;
  final bool isLoading;
  final String? error;

  ItineraryDetailState({this.itinerary, this.isLoading = false, this.error});

  ItineraryDetailState copyWith({ItineraryV2? itinerary, bool? isLoading, String? error}) {
    return ItineraryDetailState(
      itinerary: itinerary ?? this.itinerary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ItineraryDetailNotifier extends StateNotifier<ItineraryDetailState> {
  final ItineraryService _service = ItineraryService();
  ItineraryDetailNotifier() : super(ItineraryDetailState());

  Future<void> fetchDetails(String id) async {
    state = state.copyWith(isLoading: true, itinerary: null);
    try {
      final itinerary = await _service.getItineraryDetail(id);
      state = state.copyWith(isLoading: false, itinerary: itinerary);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final itineraryDetailProvider = StateNotifierProvider<ItineraryDetailNotifier, ItineraryDetailState>((ref) {
  return ItineraryDetailNotifier();
});
