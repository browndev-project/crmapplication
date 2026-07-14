import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../core/constants/permission_constants.dart';
import '../providers/itinerary_provider.dart';
import '../../data/models/itinerary_model.dart';
import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/simple_itinerary_card.dart';
import '../widgets/itinerary_create_dialog.dart';
import '../widgets/itinerary_template_gallery_dialog.dart';
import '../widgets/itinerary_share_dialog.dart';
import '../widgets/animated_refresh_button.dart';
import '../widgets/itinerary_explorer_dialog.dart';
import '../widgets/quotation_create_dialog.dart';
import '../widgets/itinerary_filter_bottom_sheet.dart';
import '../../core/utils/document_launcher.dart';
import '../widgets/access_denied_widget.dart';
import 'lead_profile_screen.dart';

class ItinerariesV2Screen extends ConsumerStatefulWidget {
  const ItinerariesV2Screen({super.key});

  @override
  ConsumerState<ItinerariesV2Screen> createState() => _ItinerariesV2ScreenState();
}

class _ItinerariesV2ScreenState extends ConsumerState<ItinerariesV2Screen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String quotationFilter = 'All Plans'; // 'All Plans', 'Linked to Quote', 'Standalone Plans'
  final Set<String> _cloningIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itineraryV2Provider.notifier).setLeadFilter(null);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(itineraryV2Provider.notifier).fetchItineraries();
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
    theme.brightness == Brightness.dark;
    final itineraryState = ref.watch(itineraryV2Provider);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final canView = permissions.can(
      PermissionModules.ITINERARY,
      permission: PermissionModules.ITINERARY_VIEW,
      userRole: userRole,
    );
    final canCreate = permissions.can(
      PermissionModules.ITINERARY,
      permission: PermissionModules.ITINERARY_CREATE,
      userRole: userRole,
    );
    final canViewTemplates = permissions.can(
      PermissionModules.ITINERARY,
      permission: PermissionModules.TEMPLATE_VIEW,
      userRole: userRole,
    );
  permissions.can(
      PermissionModules.ITINERARY,
      permission: PermissionModules.TEMPLATE_SELECT,
      userRole: userRole,
    );
    final canDownload = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_DOWNLOAD, userRole: userRole);
    final canSend = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_SEND, userRole: userRole);
    final canEdit = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_UPDATE, userRole: userRole);
    final canDelete = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_DELETE, userRole: userRole);
    final canDuplicate = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_DUPLICATE, userRole: userRole);
    final canGenerateQuote = permissions.can(
      PermissionModules.ITINERARY,
      permission: PermissionModules.ITINERARY_GENERATE_QUOTE,
      userRole: userRole,
    );
    final canCreateQuotation = permissions.can(
      PermissionModules.QUOTATION,
      permission: PermissionModules.QUOTATION_CREATE,
      userRole: userRole,
    );

    // Stats calculations
    final totalPlans = itineraryState.stats['totalPlans'] ?? itineraryState.totalCount;
    final engagedClients = itineraryState.stats['engagedClients'] ?? 0;
    final portfolioValue = (itineraryState.stats['portfolioValue'] ?? 0.0).toDouble();

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Itinerary'),
        body: AccessDeniedWidget(
          sectionName: "Itinerary",
          showAppBar: false,
        ),
      );
    }

    return Scaffold(

      appBar: const GlobalAppBar(title: 'Itinerary'),
      body: RefreshIndicator(
              onRefresh: () => ref.read(itineraryV2Provider.notifier).fetchItineraries(refresh: true),
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
                            'Itinerary',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create, manage, and distribute travel itineraries.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),

                          // Summary Cards stacked in 2x1 grid
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DashboardStatsCard(
                                      title: 'Total Plans',
                                      value: '$totalPlans',
                                      icon: Icons.map,
                                      backgroundColor: Colors.black,
                                      gradientColors: const [Colors.black, Color(0xFF333333)],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DashboardStatsCard(
                                      title: 'Engaged Clients',
                                      value: '$engagedClients',
                                      icon: Icons.people_outline,
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
                                      title: 'Portfolio Value',
                                      value: '₹${_formatCurrency(portfolioValue)}',
                                      icon: Icons.currency_rupee_outlined,
                                      backgroundColor: Colors.blueGrey,
                                      gradientColors: const [Colors.blueGrey, Colors.grey],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Action Row (Refresh + Templates + Create)
                          Row(
                            children: [
                              SizedBox(
                                height: 40,
                                child: AnimatedRefreshButton(
                                  isLoading: itineraryState.isLoading,
                                  onRefresh: () => ref.read(itineraryV2Provider.notifier).fetchItineraries(refresh: true),
                                ),
                              ),
                              if (canViewTemplates) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 40,
                                  width: 40,
                                  child: _buildCircleButton(Icons.style_outlined, () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => const ItineraryTemplateGalleryDialog(),
                                    );
                                  }),
                                ),
                              ],
                              const Spacer(),
                              if (canCreate)
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => const ItineraryTemplateGalleryDialog(),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, size: 20, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Search Row + Filter
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
                                        ref.read(itineraryV2Provider.notifier).setSearch(val);
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search by Client Name or Subject...',
                                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildFilterButton(itineraryState.hasQuotationFilter),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (itineraryState.isLoading && itineraryState.itineraries.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),

                          if (itineraryState.error != null && itineraryState.itineraries.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Text('Error: ${itineraryState.error}', style: const TextStyle(color: Colors.red)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (itineraryState.itineraries.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == itineraryState.itineraries.length) {
                              return itineraryState.isMoreLoading
                                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                                  : const SizedBox(height: 80);
                            }
                            final it = itineraryState.itineraries[index];
                            return SimpleItineraryCard(
                              itinerary: it,
                              isCopying: _cloningIds.contains(it.id),
                              onView: canView
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => ItineraryExplorerDialog(itineraryId: it.id),
                                      );
                                    }
                                  : null,
                              onDownload: canDownload
                                  ? () {
                                      DocumentLauncher.launchDocument(
                                        context: context,
                                        urlFetcher: () => ref.read(itineraryV2Provider.notifier).generatePdfUrl(it.id),
                                        loadingMessage: 'Generating Itinerary PDF...',
                                      );
                                    }
                                  : null,
                              onEdit: canEdit
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => ItineraryCreateDialog(itinerary: it),
                                      );
                                    }
                                  : null,
                              onCopy: canDuplicate
                                  ? () async {
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      setState(() => _cloningIds.add(it.id));
                                      try {
                                        await ref.read(itineraryV2Provider.notifier).cloneItinerary(it.id);
                                        if (mounted) {
                                           scaffoldMessenger.showSnackBar(
                                             const SnackBar(content: Text('Itinerary cloned successfully')),
                                           );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                           scaffoldMessenger.showSnackBar(
                                             SnackBar(content: Text('Error cloning itinerary: $e'), backgroundColor: Colors.red),
                                           );
                                        }
                                      } finally {
                                        if (mounted) setState(() => _cloningIds.remove(it.id));
                                      }
                                    }
                                  : null,
                              onViewLead: it.leadId != null && it.leadId!.isNotEmpty
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => LeadProfileScreen(leadId: it.leadId!)),
                                      );
                                    }
                                  : null,
                              onDelete: canDelete
                                  ? () {
                                      _showDeleteConfirm(it);
                                    }
                                  : null,
                              onShare: canSend
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => ItineraryShareDialog(itinerary: it),
                                      );
                                    }
                                  : null,
                              onGenerateQuote: (canGenerateQuote && canCreateQuotation && it.quotationId == null)
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => QuotationCreateDialog(prefilledItinerary: it),
                                      );
                                    }
                                  : null,
                            );
                          },
                          childCount: itineraryState.itineraries.length + 1,
                        ),
                      ),
                    ),

                  if (!itineraryState.isLoading && itineraryState.itineraries.isEmpty && itineraryState.error == null)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No premium itineraries found', style: TextStyle(color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, size: 20, color: Colors.grey[600]),
      ),
    );
  }

  String _formatCurrency(double val) {
    if (val >= 10000000) {
      return '${(val / 10000000).toStringAsFixed(1)}Cr';
    } else if (val >= 100000) {
      return '${(val / 100000).toStringAsFixed(1)}L';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}k';
    }
    return val.toStringAsFixed(0);
  }

  void _showDeleteConfirm(ItineraryV2 itinerary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Itinerary Plan'),
        content: Text('Are you sure you want to delete travel itinerary "${itinerary.subject}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              ref.read(itineraryV2Provider.notifier).deleteItinerary(itinerary.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(bool? hasQuotationFilter) {
    return IconButton(
      icon: Badge(
        isLabelVisible: hasQuotationFilter != false,
        child: const Icon(Icons.filter_list),
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => ItineraryFilterBottomSheet(
            currentHasQuotation: hasQuotationFilter,
            onApply: (val) {
              ref.read(itineraryV2Provider.notifier).toggleQuotationFilter(val);
            },
          ),
        );
      },
    );
  }
}
