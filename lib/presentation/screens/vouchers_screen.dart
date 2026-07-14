import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../core/constants/permission_constants.dart';
import '../providers/voucher_provider.dart';
import '../../data/models/voucher_model.dart';
import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/voucher_card.dart';
import '../widgets/voucher_create_dialog.dart';
import '../widgets/voucher_share_dialog.dart';
import '../widgets/animated_refresh_button.dart';
import '../../core/utils/document_launcher.dart';
import 'voucher_detail_screen.dart';
import '../widgets/access_denied_widget.dart';
import '../widgets/voucher_filter_bottom_sheet.dart';

class VouchersScreen extends ConsumerStatefulWidget {
  const VouchersScreen({super.key});

  @override
  ConsumerState<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends ConsumerState<VouchersScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFilters = ref.read(vouchersProvider).filters;
      if (currentFilters['lead'] != null) {
        ref.read(vouchersProvider.notifier).applyFilters({
          ...currentFilters,
          'lead': null,
        });
      } else {
        ref.read(vouchersProvider.notifier).refresh();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(vouchersProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final currentFilters = ref.read(vouchersProvider).filters;
      ref.read(vouchersProvider.notifier).applyFilters({
        ...currentFilters,
        'search': query,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voucherState = ref.watch(vouchersProvider);
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final canView = permissions.can(
      PermissionModules.VOUCHER,
      permission: PermissionModules.VOUCHER_VIEW,
      userRole: userRole,
    );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Vouchers'),
        body: AccessDeniedWidget(
          sectionName: "Vouchers",
          showAppBar: false,
        ),
      );
    }

    return Scaffold(

      appBar: const GlobalAppBar(title: 'Vouchers'),
      body: RefreshIndicator(
        onRefresh: () => ref.read(vouchersProvider.notifier).refresh(),
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
                    Text(
                      'Vouchers',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage hotel and travel vouchers.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Summary Cards
                    // Row 1: Total Vouchers + Unique Clients
                    Row(
                      children: [
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Total Vouchers',
                            value: '${voucherState.totalCount}',
                            icon: Icons.receipt_long,
                            backgroundColor: Colors.black,
                            gradientColors: const [Colors.black, Color(0xFF333333)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Unique Clients',
                            value: '${voucherState.uniqueClients}',
                            icon: Icons.people_outline,
                            backgroundColor: const Color(0xFF10B981),
                            gradientColors: const [Color(0xFF10B981), Color(0xFF34D399)],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Voucher Value (full width)
                    Row(
                      children: [
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Voucher Value',
                            value: '₹${NumberFormat('#,##,###').format(voucherState.totalValue)}',
                            icon: Icons.account_balance_wallet,
                            backgroundColor: const Color(0xFF6366F1),
                            gradientColors: const [Color(0xFF6366F1), Color(0xFF818CF8)],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action Row (Refresh + Create Voucher)
                    Row(
                      children: [
                        SizedBox(
                          height: 40,
                          child: AnimatedRefreshButton(
                            isLoading: voucherState.isLoading,
                            onRefresh: () => ref.read(vouchersProvider.notifier).refresh(),
                          ),
                        ),
                        const Spacer(),
                        if (permissions.hasPermission(PermissionModules.VOUCHER_CREATE, userRole: userRole))
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const VoucherCreateDialog(),
                                );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create Voucher', style: TextStyle(fontSize: 13)),
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

                     // Search + Filter
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
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Search by Voucher #, Client...',
                                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildFilterButton(voucherState.filters),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // List View
            if (voucherState.isLoading && voucherState.vouchers.isEmpty)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.black)))
            else if (voucherState.error != null && voucherState.vouchers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading vouchers:\n${voucherState.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.read(vouchersProvider.notifier).refresh(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (voucherState.vouchers.isEmpty)
              const SliverFillRemaining(child: Center(child: Text('No vouchers found.')))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == voucherState.vouchers.length) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                      }
                      final voucher = voucherState.vouchers[index];
                      final canEdit = permissions.hasPermission(PermissionModules.VOUCHER_UPDATE, userRole: userRole);
                      final canShare = permissions.hasPermission(PermissionModules.VOUCHER_SEND, userRole: userRole);
                      final canDownload = permissions.hasPermission(PermissionModules.VOUCHER_DOWNLOAD, userRole: userRole);
                      final canDelete = permissions.hasPermission(PermissionModules.VOUCHER_DELETE, userRole: userRole);

                      return VoucherCard(
                        voucher: voucher,
                        onView: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => VoucherDetailScreen(voucherId: voucher.id)));
                        },
                        onEdit: canEdit ? () {
                          showDialog(context: context, builder: (_) => VoucherCreateDialog(voucher: voucher));
                        } : null,
                        onShare: canShare ? () {
                          showDialog(context: context, builder: (_) => VoucherShareDialog(voucher: voucher));
                        } : null,
                        onDownload: canDownload ? () {
                          DocumentLauncher.launchDocument(
                            context: context,
                            urlFetcher: () => ref.read(vouchersProvider.notifier).generateShareLink(voucher.id),
                            loadingMessage: 'Opening voucher...',
                          );
                        } : null,
                        onDelete: canDelete ? () => _showDeleteConfirm(voucher) : null,
                      );
                    },
                    childCount: voucherState.vouchers.length + (voucherState.currentPage < voucherState.totalPages ? 1 : 0),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(Voucher voucher) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Delete Voucher'),
         content: Text('Are you sure you want to delete voucher #${voucher.voucherNo}?'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.black))),
           TextButton(
             onPressed: () {
               ref.read(vouchersProvider.notifier).deleteVoucher(voucher.id);
               Navigator.pop(context);
             },
             child: const Text('Delete', style: TextStyle(color: Colors.red)),
           ),
          ],
        ),
      );
   }

  Widget _buildFilterButton(Map<String, dynamic> filters) {
    final hasActiveFilter = filters['status'] != 'All Statuses' || filters['type'] != 'All Types';
    return IconButton(
      icon: Badge(
        isLabelVisible: hasActiveFilter,
        child: const Icon(Icons.filter_list),
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => VoucherFilterBottomSheet(
            currentFilters: filters,
            onApply: (newFilters) {
              ref.read(vouchersProvider.notifier).applyFilters(newFilters);
            },
          ),
        );
      },
    );
  }
}
