import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../data/models/quotation_model.dart';
import '../../core/services/quotation_service.dart';
import 'permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import 'login_provider.dart';

class QuotationsState {
  final List<Quotation> quotations;
  final bool isLoading;
  final bool isMoreLoading;
  final String? error;
  final int totalCount;
  final int currentPage;
  final String searchQuery;
  final String? statusFilter;
  final Map<String, dynamic> stats;
  final String? leadFilter;

  QuotationsState({
    this.quotations = const [],
    this.isLoading = false,
    this.isMoreLoading = false,
    this.error,
    this.totalCount = 0,
    this.currentPage = 1,
    this.searchQuery = '',
    this.statusFilter,
    this.stats = const {},
    this.leadFilter,
  });

  QuotationsState copyWith({
    List<Quotation>? quotations,
    bool? isLoading,
    bool? isMoreLoading,
    String? error,
    int? totalCount,
    int? currentPage,
    String? searchQuery,
    String? statusFilter,
    Map<String, dynamic>? stats,
    String? leadFilter,
    bool clearLeadFilter = false,
    bool clearStatusFilter = false,
  }) {
    return QuotationsState(
      quotations: quotations ?? this.quotations,
      isLoading: isLoading ?? this.isLoading,
      isMoreLoading: isMoreLoading ?? this.isMoreLoading,
      error: error,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      stats: stats ?? this.stats,
      leadFilter: clearLeadFilter ? null : (leadFilter ?? this.leadFilter),
    );
  }
}

class QuotationsNotifier extends StateNotifier<QuotationsState> {
  final QuotationService _service = QuotationService();
  final Ref ref;

  QuotationsNotifier(this.ref) : super(QuotationsState()) {
    fetchQuotations();
  }

  Future<void> fetchQuotations({bool refresh = false}) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.QUOTATION_VIEW, userRole: userRole)) {
      state = state.copyWith(isLoading: false, isMoreLoading: false, error: 'Permission Denied: You do not have permission to view quotations.');
      return;
    }

    if (refresh) {
      state = state.copyWith(isLoading: true, currentPage: 1, quotations: []);
    } else {
      if (state.isLoading || state.isMoreLoading) return;
      if (state.quotations.isNotEmpty && state.quotations.length >= state.totalCount) return;
      if (state.quotations.isNotEmpty) {
        state = state.copyWith(isMoreLoading: true);
      } else {
        state = state.copyWith(isLoading: true);
      }
    }

    try {
      final responseJson = await _service.getQuotations(
        searchQuery: state.searchQuery,
        status: state.statusFilter,
        page: state.currentPage,
        lead: state.leadFilter,
      );

      final data = responseJson['data'] ?? responseJson;

      final List<Quotation> newItems = (data['quotations'] as List? ?? [])
          .map((e) => Quotation.fromJson(e))
          .toList();

      final int totalCount = data['totalCount'] ?? data['total'] ?? newItems.length;

      final List<Quotation> allItems;
      if (refresh) {
        allItems = newItems;
      } else {
        final Map<String, Quotation> merged = {};
        for (var item in state.quotations) {
          merged[item.id] = item;
        }
        for (var item in newItems) {
          merged[item.id] = item;
        }
        allItems = merged.values.toList();
      }

      final Map<String, dynamic> responseStats = {
        'activeCount': allItems.where((e) => e.status.toUpperCase() != 'CANCELLED').length,
        'clientCount': allItems.map((e) => e.clientName).toSet().where((name) => name.isNotEmpty).length,
        'totalValue': allItems.fold<double>(0, (sum, item) => sum + item.grandTotal),
      };

      state = state.copyWith(
        isLoading: false,
        isMoreLoading: false,
        quotations: allItems,
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

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    fetchQuotations(refresh: true);
  }

  void setStatus(String? status) {
    state = state.copyWith(
      statusFilter: status,
      clearStatusFilter: status == null,
    );
    fetchQuotations(refresh: true);
  }

  Future<void> setLeadFilter(String? leadId) async {
    state = state.copyWith(
      leadFilter: leadId,
      clearLeadFilter: leadId == null,
    );
    await fetchQuotations(refresh: true);
  }

  int _parseSerial(String? latestNo) {
    if (latestNo == null || latestNo.isEmpty) return 0;
    final parts = latestNo.split('-');
    if (parts.length < 3) return 0;
    return int.tryParse(parts.last) ?? 0;
  }

  String _formatNextQuotation(String datePrefix, int serial) {
    return '$datePrefix-${serial.toString().padLeft(3, '0')}';
  }

  Future<void> createQuotation(Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.QUOTATION_CREATE, userRole: userRole)) {
      throw 'Permission Denied';
    }

    final quoNo = data['quotationNumber'] as String?;
    if (quoNo == null || quoNo.isEmpty) {
      throw 'Quotation number is required';
    }

    try {
      await _service.createQuotation(data);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('quotation number already exists') || msg.contains('duplicate key') || msg.contains('e11000')) {
        final today = DateFormat('yyyyMMdd').format(DateTime.now());
        final datePrefix = 'QUO-$today';
        final latest = await _service.getLatestQuotationNumberForDay(datePrefix);
        final nextSerial = _parseSerial(latest) + 1;
        final newQuoNo = _formatNextQuotation(datePrefix, nextSerial);
        final newData = Map<String, dynamic>.from(data);
        newData['quotationNumber'] = newQuoNo;
        await _service.createQuotation(newData);
      } else {
        rethrow;
      }
    }
    fetchQuotations(refresh: true);
  }

  Future<void> updateQuotation(String id, Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.QUOTATION_UPDATE, userRole: userRole)) {
      throw 'Permission Denied';
    }
    try {
      debugPrint('Updating quotation $id with payload: $data');
      await _service.updateQuotation(id, data);
    } catch (e) {
      debugPrint('Error updating quotation $id: $e');
      rethrow;
    }
    fetchQuotations(refresh: true);
  }

  Future<void> deleteQuotation(String id) async {
    if (id.isEmpty) {
      throw 'Invalid quotation: ID is missing';
    }
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.QUOTATION_DELETE, userRole: userRole)) {
      throw 'Permission Denied';
    }
    await _service.deleteQuotation(id);
    fetchQuotations(refresh: true);
  }

  Future<String?> downloadQuotation(String id, String quotationNo) async {
    return await _service.downloadQuotation(id, quotationNo);
  }

  Future<String> getShareLink(String id) async {
    return await _service.getShareLink(id);
  }

  Future<String> getShareMessage(String id) async {
    return await _service.getShareMessage(id);
  }
}

final quotationsProvider = StateNotifierProvider<QuotationsNotifier, QuotationsState>((ref) {
  return QuotationsNotifier(ref);
});

class QuotationDetailState {
  final Quotation? quotation;
  final bool isLoading;
  final String? error;

  QuotationDetailState({this.quotation, this.isLoading = false, this.error});

  QuotationDetailState copyWith({Quotation? quotation, bool? isLoading, String? error}) {
    return QuotationDetailState(
      quotation: quotation ?? this.quotation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class QuotationDetailNotifier extends StateNotifier<QuotationDetailState> {
  final QuotationService _service = QuotationService();
  QuotationDetailNotifier() : super(QuotationDetailState());

  Future<void> fetchDetails(String id) async {
    state = state.copyWith(isLoading: true, quotation: null);
    try {
      final quotation = await _service.getQuotationDetail(id);
      state = state.copyWith(isLoading: false, quotation: quotation);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final quotationDetailProvider = StateNotifierProvider<QuotationDetailNotifier, QuotationDetailState>((ref) {
  return QuotationDetailNotifier();
});
