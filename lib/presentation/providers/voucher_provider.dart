import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/voucher_model.dart';
import '../../core/services/voucher_service.dart';
import 'permissions_provider.dart';
import 'login_provider.dart';
import '../../core/constants/permission_constants.dart';

class VouchersState {
  final bool isLoading;
  final String? error;
  final List<Voucher> vouchers;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final double totalValue;
  final int uniqueClients;
  final Map<String, dynamic> filters;
  final bool isDownloading;
  final String? downloadingVoucherId;
  const VouchersState({
    this.isLoading = false,
    this.error,
    this.vouchers = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalValue = 0,
    this.uniqueClients = 0,
    this.filters = const {'status': 'All Statuses', 'type': 'All Types'},
    this.isDownloading = false,
    this.downloadingVoucherId,
  });

  VouchersState copyWith({
    bool? isLoading,
    String? error,
    List<Voucher>? vouchers,
    int? totalCount,
    int? currentPage,
    int? totalPages,
    double? totalValue,
    int? uniqueClients,
    Map<String, dynamic>? filters,
    bool? isDownloading,
    String? downloadingVoucherId,
  }) {
    return VouchersState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      vouchers: vouchers ?? this.vouchers,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalValue: totalValue ?? this.totalValue,
      uniqueClients: uniqueClients ?? this.uniqueClients,
      filters: filters ?? this.filters,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingVoucherId: isDownloading == false ? null : (downloadingVoucherId ?? this.downloadingVoucherId),
    );
  }
}

class VouchersNotifier extends Notifier<VouchersState> {
  @override
  VouchersState build() {
    return const VouchersState();
  }

  VoucherService get _service => ref.read(voucherServiceProvider);

  Future<void> fetchVouchers({int page = 1, bool isRefresh = false}) async {
    if (state.isLoading && !isRefresh) return;

    state = state.copyWith(isLoading: true, error: null);
    
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;

    if (!permissions.hasPermission(PermissionModules.VOUCHER_VIEW, userRole: userRole)) {
      state = state.copyWith(isLoading: false, error: 'Permission Denied: You do not have permission to view vouchers.');
      return;
    }

    try {
      final response = await _service.fetchVouchers(
        page: page,
        limit: 10,
        search: state.filters['search'],
        type: state.filters['type'],
        status: state.filters['status'],
        lead: state.filters['lead'],
      );

      final List<Voucher> allItems;
      if (isRefresh) {
        allItems = response.vouchers;
      } else {
        final Map<String, Voucher> merged = {};
        for (var item in state.vouchers) {
          merged[item.id] = item;
        }
        for (var item in response.vouchers) {
          merged[item.id] = item;
        }
        allItems = merged.values.toList();
      }

      final uniqueClientCount = allItems.map((v) => v.clientName).where((n) => n.isNotEmpty).toSet().length;
      final localTotalValue = allItems.fold<double>(0, (sum, v) => sum + v.financials.totalAmount);

      state = state.copyWith(
        isLoading: false,
        vouchers: allItems,
        totalCount: response.totalCount,
        currentPage: response.currentPage,
        totalPages: response.totalPages,
        totalValue: localTotalValue,
        uniqueClients: uniqueClientCount,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await fetchVouchers(page: 1, isRefresh: true);
  }

  Future<void> loadMore() async {
    if (state.currentPage < state.totalPages) {
      await fetchVouchers(page: state.currentPage + 1);
    }
  }

  Future<void> applyFilters(Map<String, dynamic> filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> createVoucher(Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.VOUCHER_CREATE, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to create vouchers.';
    }
    try {
      await _service.createVoucher(data);
      await refresh();
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> updateVoucher(String id, Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.VOUCHER_UPDATE, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to update vouchers.';
    }

    final voucher = state.vouchers.firstWhere((v) => v.id == id);
    if (voucher.status.toUpperCase() == 'CANCELLED') {
      throw 'Invalid Action: Cancelled vouchers cannot be edited.';
    }

    try {
      await _service.updateVoucher(id, data);
      await refresh();
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> deleteVoucher(String id) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.VOUCHER_DELETE, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to delete vouchers.';
    }
    try {
      final success = await _service.deleteVoucher(id);
      if (success) {
        state = state.copyWith(
          vouchers: state.vouchers.where((v) => v.id != id).toList(),
          totalCount: state.totalCount - 1,
        );
      }
    } catch (e) {
      debugPrint('Error deleting voucher: $e');
    }
  }

  Future<String?> downloadVoucher(String id, String voucherNo) async {
    if (state.isDownloading) return null;

    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.VOUCHER_DOWNLOAD, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to download vouchers.';
    }
    
    final fileName = 'VOUCHER-$voucherNo.pdf';
    final dir = await getApplicationDocumentsDirectory();
    final localPath = '${dir.path}/$fileName';
    final file = File(localPath);

    if (await file.exists()) {
      return localPath;
    }

    state = state.copyWith(isDownloading: true, downloadingVoucherId: id);
    try {
      final pdfData = await _service.downloadVoucherPdf(id);
      if (pdfData != null) {
        await file.writeAsBytes(pdfData);
        return localPath;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading voucher: $e');
      rethrow;
    } finally {
      state = state.copyWith(isDownloading: false);
    }
  }

  Future<String?> generateShareLink(String id) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.VOUCHER_SEND, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to share vouchers.';
    }
    return await _service.generateShareLink(id);
  }

  Future<String> getShareMessage(String id) async {
    return await _service.getShareMessage(id);
  }
}

class VoucherDetailState {
  final bool isLoading;
  final String? error;
  final Voucher? voucher;

  const VoucherDetailState({this.isLoading = false, this.error, this.voucher});

  VoucherDetailState copyWith({bool? isLoading, String? error, Voucher? voucher}) {
    return VoucherDetailState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      voucher: voucher ?? this.voucher,
    );
  }
}

class VoucherDetailNotifier extends Notifier<VoucherDetailState> {
  @override
  VoucherDetailState build() {
    return const VoucherDetailState();
  }

  VoucherService get _service => ref.read(voucherServiceProvider);

  Future<void> fetchDetails(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final voucher = await _service.fetchVoucherDetails(id);
      state = VoucherDetailState(voucher: voucher);
    } catch (e) {
      state = VoucherDetailState(error: e.toString());
    }
  }
}

final voucherServiceProvider = Provider<VoucherService>((ref) => VoucherService());

final vouchersProvider = NotifierProvider<VouchersNotifier, VouchersState>(() {
  return VouchersNotifier();
});

final voucherDetailProvider = NotifierProvider<VoucherDetailNotifier, VoucherDetailState>(() {
  return VoucherDetailNotifier();
});
