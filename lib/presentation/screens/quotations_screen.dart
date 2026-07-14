import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../core/constants/permission_constants.dart';
import '../providers/quotation_provider.dart';
import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/quotation_card.dart';
import '../widgets/quotation_create_dialog.dart';
import '../widgets/animated_refresh_button.dart';
import '../widgets/access_denied_widget.dart';
import '../widgets/quotation_filter_bottom_sheet.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quotationsProvider.notifier).setLeadFilter(null);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(quotationsProvider.notifier).fetchQuotations();
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
    final state = ref.watch(quotationsProvider);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final canView = permissions.can(
      PermissionModules.QUOTATION,
      permission: PermissionModules.QUOTATION_VIEW,
      userRole: userRole,
    );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Quotations'),
        body: AccessDeniedWidget(
          sectionName: "Quotations",
          showAppBar: false,
        ),
      );
    }

    return Scaffold(

      appBar: const GlobalAppBar(title: 'Quotations'),
      body: RefreshIndicator(
              onRefresh: () => ref.read(quotationsProvider.notifier).fetchQuotations(refresh: true),
              color: Colors.black,
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
                            'Quotations',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create, manage and share customer proposals and quotes.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),

                          // Summary Cards
                          _buildSummaryCards(state),
                          const SizedBox(height: 24),

                          // Action Row (Refresh + Create Quotation)
                          Row(
                            children: [
                              SizedBox(
                                height: 40,
                                child: AnimatedRefreshButton(
                                  isLoading: state.isLoading,
                                  onRefresh: () => ref.read(quotationsProvider.notifier).fetchQuotations(refresh: true),
                                ),
                              ),
                              const Spacer(),
                              if (permissions.hasPermission(PermissionModules.QUOTATION_CREATE, userRole: userRole))
                                SizedBox(
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => const QuotationCreateDialog(),
                                      );
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Create Quotation', style: TextStyle(fontSize: 13)),
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
                                      onChanged: (val) {
                                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                                        _debounce = Timer(const Duration(milliseconds: 500), () {
                                          ref.read(quotationsProvider.notifier).setSearch(val);
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Search by Quotation #, Client...',
                                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildFilterButton(state.statusFilter),
                              ],
                            ),
                          const SizedBox(height: 20),

                          if (state.isLoading && state.quotations.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),

                          if (state.error != null && state.quotations.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (state.quotations.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == state.quotations.length) {
                              return state.isMoreLoading
                                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                                  : const SizedBox(height: 80);
                            }
                            final quotation = state.quotations[index];
                            return QuotationCard(quotation: quotation);
                          },
                          childCount: state.quotations.length + 1,
                        ),
                      ),
                    ),
                  if (!state.isLoading && state.quotations.isEmpty && state.error == null)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No quotations found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(QuotationsState state) {
    final stats = state.stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardStatsCard(
                title: 'Active Quotes',
                value: '${stats['activeCount'] ?? 0}',
                icon: Icons.request_quote_outlined,
                backgroundColor: Colors.black,
                gradientColors: const [Colors.black, Color(0xFF333333)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DashboardStatsCard(
                title: 'Clients',
                value: '${stats['clientCount'] ?? 0}',
                icon: Icons.people_outline,
                backgroundColor: const Color(0xFFF59E0B),
                gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DashboardStatsCard(
                title: 'Quoted Value',
                value: '₹${NumberFormat.compact().format(stats['totalValue'] ?? 0)}',
                icon: Icons.account_balance_wallet_outlined,
                backgroundColor: const Color(0xFF10B981),
                gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButton(String? currentStatus) {
    final hasActiveFilter = currentStatus != null;
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
          builder: (ctx) => QuotationFilterBottomSheet(
            currentStatus: currentStatus,
            onApply: (status) {
              if (status == null || status == 'ALL') {
                ref.read(quotationsProvider.notifier).setStatus(null);
              } else {
                ref.read(quotationsProvider.notifier).setStatus(status);
              }
            },
          ),
        );
      },
    );
  }
}
