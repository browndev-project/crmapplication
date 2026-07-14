import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../core/constants/permission_constants.dart';
import '../providers/invoice_provider.dart';
import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/invoice_card.dart';
import '../widgets/invoice_filter_bottom_sheet.dart';
import 'invoice_detail_screen.dart';
import '../widgets/invoice_create_dialog.dart';
import '../widgets/invoice_share_dialog.dart';
import '../../core/utils/document_launcher.dart';
import '../widgets/animated_refresh_button.dart';
import '../widgets/access_denied_widget.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFilters = ref.read(invoicesProvider).filters;
      if (currentFilters['lead'] != null) {
        ref.read(invoicesProvider.notifier).applyFilters({
          ...currentFilters,
          'lead': null,
        });
      } else {
        ref.read(invoicesProvider.notifier).refresh();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(invoicesProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoiceState = ref.watch(invoicesProvider);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    int overdueInvoices = 0;
    for (final inv in invoiceState.invoices) {
      if (inv.status.toUpperCase() != 'PAID' && inv.status.toUpperCase() != 'CANCELLED') {
        try {
          final due = DateTime.parse(inv.dueDate);
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final dueDateOnly = DateTime(due.year, due.month, due.day);
          if (dueDateOnly.isBefore(todayDate)) {
            overdueInvoices++;
          }
        } catch (_) {}
      }
    }

    final canView = permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_VIEW, userRole: userRole);

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Invoices'),
        body: AccessDeniedWidget(
          sectionName: "Invoices",
          showAppBar: false,
        ),
      );
    }

    return Scaffold(

      appBar: const GlobalAppBar(title: 'Invoices'),
      body: RefreshIndicator(
        onRefresh: () => ref.read(invoicesProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Invoices',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create, manage and track customer invoices.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Summary Cards Grid
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DashboardStatsCard(
                                title: 'Total Invoices',
                                value: '${invoiceState.totalInvoices}',
                                icon: Icons.receipt_long,
                                backgroundColor: Colors.black,
                                gradientColors: const [Colors.black, Color(0xFF333333)],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashboardStatsCard(
                                title: 'Paid Invoices',
                                value: '${invoiceState.paidInvoices}',
                                icon: Icons.check_circle,
                                backgroundColor: const Color(0xFF10B981),
                                gradientColors: const [Color(0xFF10B981), Color(0xFF34D399)],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DashboardStatsCard(
                                title: 'Unpaid Invoices',
                                value: '${invoiceState.totalInvoices - invoiceState.paidInvoices}',
                                icon: Icons.pending_actions_rounded,
                                backgroundColor: Colors.orange,
                                gradientColors: const [Colors.orange, Colors.deepOrange],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashboardStatsCard(
                                title: 'Overdue Invoices',
                                value: '$overdueInvoices',
                                icon: Icons.warning_amber_rounded,
                                backgroundColor: Colors.red,
                                gradientColors: const [Colors.red, Colors.redAccent],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action Row (Refresh + Create Invoice)
                    Row(
                      children: [
                        SizedBox(
                          height: 40,
                          child: AnimatedRefreshButton(
                            isLoading: invoiceState.isLoading,
                            onRefresh: () => ref.read(invoicesProvider.notifier).refresh(),
                          ),
                        ),
                        const Spacer(),
                        if (permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_CREATE, userRole: userRole))
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const InvoiceCreateDialog(),
                                );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create Invoice', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search & Filter
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                if (_debounce?.isActive ?? false) _debounce!.cancel();
                                _debounce = Timer(const Duration(milliseconds: 500), () {
                                  ref.read(invoicesProvider.notifier).applyFilters({
                                    ...invoiceState.filters,
                                    'search': val,
                                  });
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search by Invoice #, Client...',
                                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildFilterButton(invoiceState.filters),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    if (invoiceState.isLoading && invoiceState.invoices.isEmpty)
                       const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                    
                    if (invoiceState.error != null && invoiceState.invoices.isEmpty)
                       Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('Error: ${invoiceState.error}', style: const TextStyle(color: Colors.red)))),
                  ],
                ),
              ),
            ),

            if (invoiceState.invoices.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == invoiceState.invoices.length) {
                        return invoiceState.isLoading 
                            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                            : const SizedBox(height: 80);
                      }
                      final invoice = invoiceState.invoices[index];
                      return InvoiceCard(
                        invoice: invoice,
                        onView: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (context) => InvoiceDetailScreen(invoiceId: invoice.id, initialInvoice: invoice),
                             ),
                           );
                        },
                         onShare: permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_SEND, userRole: userRole) ? () {
                           showDialog(
                             context: context,
                             builder: (context) => InvoiceShareDialog(invoice: invoice),
                           );
                         } : null,
                         onDownload: permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_DOWNLOAD, userRole: userRole) ? () {
                            DocumentLauncher.launchDocument(
                              context: context,
                              urlFetcher: () => ref.read(invoicesProvider.notifier).generateShareLink(invoice.id),
                              loadingMessage: 'Opening invoice...',
                            );
                          } : null,
                         onEdit: (permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_UPDATE, userRole: userRole) && invoice.status.toUpperCase() != 'CANCELLED') ? () {
                           showDialog(
                             context: context,
                             builder: (context) => InvoiceCreateDialog(invoice: invoice),
                           );
                         } : null,
                         onDelete: permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_DELETE, userRole: userRole) ? () {
                           _showDeleteConfirm(invoice);
                         } : null,
                         onStatusChanged: (permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_UPDATE, userRole: userRole) && invoice.status.toUpperCase() != 'CANCELLED') ? (newStatus) async {
                           try {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Updating status to $newStatus...'), duration: const Duration(seconds: 1)),
                             );
                             await ref.read(invoicesProvider.notifier).updateStatus(invoice.id, newStatus);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Status updated to $newStatus successfully!'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                         } : null,
                      );
                    },
                    childCount: invoiceState.invoices.length + 1,
                  ),
                ),
              ),

            if (!invoiceState.isLoading && invoiceState.invoices.isEmpty && invoiceState.error == null)
               const SliverFillRemaining(
                 child: Center(
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                       SizedBox(height: 16),
                       Text('No invoices found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                     ],
                   ),
                 ),
               ),
          ],
        ),
      ),
    );
  }



  Widget _buildFilterButton(Map<String, dynamic> filters) {
    final hasActiveFilters = filters['status'] != 'All Statuses' || (filters['startDate'] != null);
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => InvoiceFilterBottomSheet(
            currentFilters: filters,
            onApply: (newFilters) {
              ref.read(invoicesProvider.notifier).applyFilters(newFilters);
            },
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasActiveFilters ? Colors.black : theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.tune, color: hasActiveFilters ? Colors.black : Colors.grey[600]),
            if (hasActiveFilters)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(dynamic invoice) {
    // Release active input focus to completely stop search bar keyboard popping or viewport shifting
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
          title: Text(
            'Delete Invoice',
            style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Delete Invoice? This action cannot be undone.',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(invoicesProvider.notifier).deleteInvoice(invoice.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invoice deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
