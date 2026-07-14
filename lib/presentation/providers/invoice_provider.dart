import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/invoice_model.dart';
import '../../core/services/invoice_service.dart';
import 'package:path_provider/path_provider.dart';
import 'permissions_provider.dart';
import 'login_provider.dart';
import '../../core/constants/permission_constants.dart';

class InvoicesState {
  final bool isLoading;
  final String? error;
  final List<Invoice> invoices;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final int totalInvoices;
  final int paidInvoices;
  final Map<String, dynamic> filters;
  final bool isDownloading;
  final String? downloadingInvoiceId;

  const InvoicesState({
    this.isLoading = false,
    this.error,
    this.invoices = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalInvoices = 0,
    this.paidInvoices = 0,
    this.filters = const {'status': 'All Statuses'},
    this.isDownloading = false,
    this.downloadingInvoiceId,
  });

  InvoicesState copyWith({
    bool? isLoading,
    String? error,
    List<Invoice>? invoices,
    int? totalCount,
    int? currentPage,
    int? totalPages,
    int? totalInvoices,
    int? paidInvoices,
    Map<String, dynamic>? filters,
    bool? isDownloading,
    String? downloadingInvoiceId,
  }) {
    return InvoicesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      invoices: invoices ?? this.invoices,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalInvoices: totalInvoices ?? this.totalInvoices,
      paidInvoices: paidInvoices ?? this.paidInvoices,
      filters: filters ?? this.filters,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingInvoiceId: isDownloading == false ? null : (downloadingInvoiceId ?? this.downloadingInvoiceId),
    );
  }
}

class InvoicesNotifier extends Notifier<InvoicesState> {
  @override
  InvoicesState build() {
    return const InvoicesState();
  }

  InvoiceService get _service => ref.read(invoiceServiceProvider);

  Future<void> fetchInvoices({int page = 1, bool isRefresh = false}) async {
    if (state.isLoading && !isRefresh) return;

    state = state.copyWith(isLoading: true, error: null);
    
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;

    if (!permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_VIEW, userRole: userRole)) {
      state = state.copyWith(isLoading: false, error: 'Permission Denied: You do not have permission to view invoices.');
      return;
    }

    try {
      final response = await _service.fetchInvoices(
        page: page,
        limit: 10,
        search: state.filters['search'],
        status: state.filters['status'],
        startDate: state.filters['startDate'],
        endDate: state.filters['endDate'],
        lead: state.filters['lead'],
      );

      final List<Invoice> allItems;
      if (isRefresh) {
        allItems = response.invoices;
      } else {
        final Map<String, Invoice> merged = {};
        for (var item in state.invoices) {
          merged[item.id] = item;
        }
        for (var item in response.invoices) {
          merged[item.id] = item;
        }
        allItems = merged.values.toList();
      }

      state = state.copyWith(
        isLoading: false,
        invoices: allItems,
        totalCount: response.totalCount,
        currentPage: response.currentPage,
        totalPages: response.totalPages,
        totalInvoices: response.totalInvoices,
        paidInvoices: response.paidInvoices,
      );
      debugPrint('[InvoicesNotifier] Stats - total: ${state.totalInvoices}, paid: ${state.paidInvoices}, '
          'localPaid: ${allItems.where((i) => i.status.toUpperCase() == 'PAID').length}');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      if (isRefresh) {
        throw e.toString();
      }
    }
  }

  Future<void> refresh() async {
    await fetchInvoices(page: 1, isRefresh: true);
  }

  Future<void> loadMore() async {
    if (state.currentPage < state.totalPages) {
      await fetchInvoices(page: state.currentPage + 1);
    }
  }

  Future<void> applyFilters(Map<String, dynamic> filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> createInvoice(Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.INVOICE_CREATE, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to create invoices.';
    }
    try {
      await _service.createInvoice(data);
      await refresh();
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> updateInvoice(String id, Map<String, dynamic> data) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.INVOICE_UPDATE, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to update invoices.';
    }

    final invoice = state.invoices.firstWhere((i) => i.id == id);
    if (invoice.status.toUpperCase() == 'CANCELLED') {
      throw 'Invalid Action: Cancelled invoices cannot be edited.';
    }

    try {
      await _service.updateInvoice(id, data);
      await refresh();
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> deleteInvoice(String id) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.INVOICE_DELETE, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to delete invoices.';
    }
    try {
      final success = await _service.deleteInvoice(id);
      if (success) {
        state = state.copyWith(
          invoices: state.invoices.where((i) => i.id != id).toList(),
          totalCount: state.totalCount - 1,
        );
      }
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
    }
  }

  Future<void> updateStatus(String id, String status) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.INVOICE_UPDATE, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to update invoice status.';
    }
    try {
      final success = await _service.updateInvoiceStatus(id, status);
      if (success) {
        await refresh();
      }
    } catch (e) {
      debugPrint('Error updating invoice status: $e');
    }
  }

  Future<String?> downloadInvoice(String id, String invoiceNumber) async {
    if (state.isDownloading) return null;

    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.INVOICE_DOWNLOAD, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to download invoices.';
    }
    
    final fileName = 'INV-$invoiceNumber.pdf';
    final dir = await getApplicationDocumentsDirectory();
    final localPath = '${dir.path}/$fileName';
    final file = File(localPath);

    // 1. Check Cache
    if (await file.exists()) {
      debugPrint('[Download] Using cached file: $localPath');
      return localPath;
    }

    // 2. Download if not cached
    state = state.copyWith(isDownloading: true, downloadingInvoiceId: id);
    try {
      final pdfData = await _service.downloadInvoicePdf(id);
      if (pdfData != null) {
        await file.writeAsBytes(pdfData);
        debugPrint('[Download] New file saved at: $localPath');
        return localPath;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading invoice: $e');
      rethrow;
    } finally {
      state = state.copyWith(isDownloading: false);
    }
  }


  Future<String?> generateShareLink(String id) async {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    if (!permissions.hasPermission(PermissionModules.INVOICE_SEND, userRole: userRole)) {
      throw 'Permission Denied: You do not have permission to share invoices.';
    }
    return await _service.generateShareLink(id);
  }

  Future<String> getShareMessage(String id) async {
    return await _service.getShareMessage(id);
  }
}

class InvoiceDetailState {
  final bool isLoading;
  final String? error;
  final Invoice? invoice;

  const InvoiceDetailState({this.isLoading = false, this.error, this.invoice});

  InvoiceDetailState copyWith({bool? isLoading, String? error, Invoice? invoice}) {
    return InvoiceDetailState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      invoice: invoice ?? this.invoice,
    );
  }
}

class InvoiceDetailNotifier extends Notifier<InvoiceDetailState> {
  String? _lastFetchedId;
  Invoice? _cachedInvoice;

  @override
  InvoiceDetailState build() {
    debugPrint('[InvoiceDetailNotifier] build() called');
    return const InvoiceDetailState();
  }

  InvoiceService get _service => ref.read(invoiceServiceProvider);

  Future<void> fetchDetails(String id) async {
    debugPrint('[InvoiceDetailNotifier] fetchDetails called for id: $id');

    if (_cachedInvoice != null && _lastFetchedId == id) {
      debugPrint('[InvoiceDetailNotifier] Already cached, using: ${_cachedInvoice?.invoiceNumber}');
      state = InvoiceDetailState(invoice: _cachedInvoice);
      return;
    }

    _lastFetchedId = id;
    final currentState = state;
    state = InvoiceDetailState(isLoading: true, error: null, invoice: currentState.invoice);

    try {
      final invoice = await _service.fetchInvoiceDetails(id);
      debugPrint('[InvoiceDetailNotifier] API Response - invoiceNumber: ${invoice.invoiceNumber}, id: ${invoice.id}');
      debugPrint('[InvoiceDetailNotifier] clientName: ${invoice.clientName}, grandTotal: ${invoice.grandTotal}');
      _cachedInvoice = invoice;
      state = InvoiceDetailState(invoice: invoice);
      debugPrint('[InvoiceDetailNotifier] State updated with invoice, state.invoice: ${state.invoice?.invoiceNumber}');
    } catch (e) {
      debugPrint('[InvoiceDetailNotifier] fetchDetails error: $e');
      state = InvoiceDetailState(error: e.toString(), invoice: _cachedInvoice);
    }
  }
}

final invoiceServiceProvider = Provider<InvoiceService>((ref) => InvoiceService());

final invoicesProvider = NotifierProvider<InvoicesNotifier, InvoicesState>(() {
  return InvoicesNotifier();
});

final invoiceDetailProvider = NotifierProvider<InvoiceDetailNotifier, InvoiceDetailState>(() {
  return InvoiceDetailNotifier();
});
