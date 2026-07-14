
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../widgets/lead_filter_bottom_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/call_service.dart';
import '../providers/login_provider.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/global_app_bar.dart';
import 'lead_profile_screen.dart';
import 'package:crmapp/presentation/widgets/lead_bulk_upload_dialog.dart';
import '../../core/services/dialer_service.dart';
import '../providers/lead_provider.dart';
import '../widgets/lead_create_dialog.dart';
import '../widgets/lead_task_create_dialog.dart';
import '../../data/models/lead_model.dart';
import '../../data/models/quotation_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/itinerary_model.dart';
import '../../data/models/voucher_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'marketing/widgets/send_email_dialog.dart';
import '../providers/lead_card_config_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/lead_status_update_dialog.dart';
import '../widgets/meeting_create_dialog.dart';
import '../../core/utils/date_utils.dart';
import '../providers/dashboard_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';
import '../widgets/lead_bulk_update_dialog.dart';
import '../widgets/lead_bulk_assign_dialog.dart';
import '../providers/task_provider.dart';
import '../providers/quotation_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/voucher_provider.dart';
import '../widgets/quotation_share_dialog.dart';
import '../widgets/invoice_share_dialog.dart';
import '../widgets/itinerary_share_dialog.dart';
import '../widgets/voucher_share_dialog.dart';
import 'whatsapp/widgets/whatsapp_chat_panel.dart';
import '../widgets/document_selector_bottom_sheet.dart';
import '../widgets/ivr_agent_selection_dialog.dart';
import '../widgets/access_denied_widget.dart';
import '../widgets/visit_create_dialog.dart';
import '../widgets/floating_dock_nav_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/utils/formatters.dart';

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final CallService _callService = CallService();
  String? _pendingCallNumber;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  final Set<String> _selectedLeadIds = {};
  bool _showStatsCards = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // _checkDefaultDialer();

    // Clear any stale search filter from previous session
    _clearStaleSearch();

    // Fetch leads on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(leadsProvider.notifier).refresh();

      // Fetch Dashboard Stats for the cards (if missing or stale)
      if (ref.read(dashboardProvider).data == null) {
        final user = ref.read(loginProvider).user;
        final isAdmin = user?.systemRole == 'company_admin';
        ref
            .read(dashboardProvider.notifier)
            .fetchDashboardData(isAdmin: isAdmin);
      }

      // Fetch Tasks if not already loaded to get accurate Pending/Overdue counts
      if (ref.read(tasksProvider).tasks.isEmpty) {
        ref.read(tasksProvider.notifier).refresh();
      }
    });

    _scrollController.addListener(_onScroll);
  }

  void _clearStaleSearch() {
    // Clear any stale search filter when the screen loads
    final currentFilters = ref.read(leadsProvider).filters;
    if (currentFilters.containsKey('search') &&
        currentFilters['search'] != null &&
        currentFilters['search'].toString().isNotEmpty) {
      ref.read(leadsProvider.notifier).applyFilters({
        ...currentFilters,
        'search': '',
      });
    }
    _searchController.clear();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(leadsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pendingCallNumber != null) {
        _checkCallLogs();
      }
      // _checkDefaultDialer();
    }
  }

  Future<void> checkDefaultDialer() async {
    final isDefault = await DialerService().checkIsDefault();
    if (mounted && !isDefault) {
      setState(() {
        showDefaultDialerBanner = true;
      });
    } else {
      setState(() {
        showDefaultDialerBanner = false;
      });
    }
  }

  bool showDefaultDialerBanner = false;

  Future<void> _checkCallLogs() async {
    if (_pendingCallNumber == null) return;

    await Future.delayed(const Duration(seconds: 2));

    final number = _pendingCallNumber;
    if (number == null) return;

    final details = await _callService.getLastCallDetails(number);

    if (details != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Last Call: ${details['duration_seconds']}s (${details['call_type']})',
          ),
        ),
      );
    }
    _pendingCallNumber = null;
  }

  Future<void> _initiateCall(Lead lead) async {
    final hasPermissions = await _callService.requestPermissions();

    if (hasPermissions) {
      setState(() {
        _pendingCallNumber = lead.phoneNo;
      });
      try {
        final user = ref.read(loginProvider).user;
        final context = {
          'leadId': lead.id,
          'userId': user?.id,
          'companyId': lead.company,
        };

        await _callService.makeCall(lead.phoneNo, callContext: context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
        _pendingCallNumber = null;
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions denied. Check settings.')),
        );
      }
    }
  }

  Future<void> _initiateIvrCall(Lead lead) async {
    final user = ref.read(loginProvider).user;
    if (user == null) return;

    if (user.systemRole == 'company_admin') {
      _showIvrAgentSelectionDialog(lead);
    } else {
      _placeIvrCall(lead, null);
    }
  }

  void _showIvrAgentSelectionDialog(Lead lead) {
    showDialog(
      context: context,
      builder: (context) {
        return IvrAgentSelectionDialog(
          leadId: lead.id,
          onAgentSelected: (agentId) {
            Navigator.pop(context);
            _placeIvrCall(lead, agentId);
          },
        );
      },
    );
  }

  Future<void> _placeIvrCall(Lead lead, String? agentId) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Connecting IVR call... Please wait.'),
              ],
            ),
            backgroundColor: Colors.blueAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final leadService = ref.read(leadServiceProvider);
      final response = await leadService.initiateClickToCall(
        targetPhone: lead.phoneNo,
        leadId: lead.id,
        agentId: agentId,
      );

      if (mounted) {
        final message = response['message'] ?? 'Call initiated successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate IVR call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendEmail(Lead lead) {
    if (lead.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address for this lead.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => SendEmailDialog(recipients: [lead]),
    );
  }

  void _launchCrmWhatsApp(Lead lead) {
    WhatsAppChatPanel.show(context, lead);
  }

  Future<void> _launchWhatsApp(Lead lead) async {
    final phone = lead.phoneNo.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number for this lead.')),
        );
      }
      return;
    }
    final urlStr = kIsWeb
        ? 'https://wa.me/$phone'
        : 'whatsapp://send?phone=$phone';
    final uri = Uri.parse(urlStr);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse('https://wa.me/$phone');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not launch WhatsApp. Ensure it is installed.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _updateDockForSelection() {
    final isSelectionActive = _selectedLeadIds.isNotEmpty;
    ref.read(dockLockedHiddenProvider.notifier).state = isSelectionActive;
    ref.read(dockVisibilityProvider.notifier).update(!isSelectionActive);
  }

  void _toggleLeadSelection(String id) {
    setState(() {
      if (_selectedLeadIds.contains(id)) {
        _selectedLeadIds.remove(id);
      } else {
        _selectedLeadIds.add(id);
      }
    });
    _updateDockForSelection();
  }

  void _selectAllOnPage(List<Lead> leads) {
    setState(() {
      final allIds = leads.map((l) => l.id).toSet();
      if (_selectedLeadIds.containsAll(allIds)) {
        for (var id in allIds) {
          _selectedLeadIds.remove(id);
        }
      } else {
        _selectedLeadIds.addAll(allIds);
      }
    });
    _updateDockForSelection();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;

    if (!permissions.hasModule(
          PermissionModules.LEADS,
          userRole: user?.systemRole,
        ) ||
        !permissions.hasPermission(
          PermissionModules.LEADS_VIEW,
          userRole: user?.systemRole,
        )) {
      return const Scaffold(
        extendBody: true,
        appBar: GlobalAppBar(title: 'Leads'),
        body: AccessDeniedWidget(sectionName: "Leads", showAppBar: false),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    final leadsState = ref.watch(leadsProvider);
    final filters = leadsState.filters;
    final hasActiveFilters =
        (filters['service'] != null &&
            filters['service'].toString().isNotEmpty) ||
        (filters['status'] != null &&
            filters['status'].toString().isNotEmpty) ||
        (filters['pipeline'] != null &&
            filters['pipeline'].toString().isNotEmpty) ||
        (filters['source'] != null &&
            filters['source'].toString().isNotEmpty) ||
        (filters['assignedTo'] != null &&
            filters['assignedTo'].toString().isNotEmpty) ||
        (filters['team'] != null && filters['team'].toString().isNotEmpty) ||
        (filters['group'] != null && filters['group'].toString().isNotEmpty) ||
        (filters['project'] != null &&
            filters['project'].toString().isNotEmpty) ||
        (filters['startDate'] != null) ||
        (filters['endDate'] != null);
    final isAllSelected =
        leadsState.leads.isNotEmpty &&
        _selectedLeadIds.containsAll(leadsState.leads.map((l) => l.id));

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      appBar: const GlobalAppBar(title: 'Leads'),
      bottomNavigationBar: _selectedLeadIds.isNotEmpty
          ? _buildBottomActionBar(isDark)
          : null,
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: () async {
          await ref.read(leadsProvider.notifier).refresh();
          final user = ref.read(loginProvider).user;
          final isAdmin = user?.systemRole == 'company_admin';
          ref
              .read(dashboardProvider.notifier)
              .fetchDashboardData(isAdmin: isAdmin);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, hasActiveFilters),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSearchBar(isDark)),
                  const SizedBox(width: 8),
                  _buildFiltersButton(isDark, hasActiveFilters),
                  const SizedBox(width: 8),
                  _buildDuplicateFilterButton(
                    isDark,
                    leadsState.filters['duplicate'] == true ||
                        leadsState.filters['duplicate'] == 'true',
                  ),
                  const SizedBox(width: 8),
                  _buildSubAssignedFilterButton(
                    isDark,
                    leadsState.filters['onlySubAssigned'] == true ||
                        leadsState.filters['onlySubAssigned'] == 'true',
                  ),
                  const SizedBox(width: 8),
                  _buildCardToggle(isDark),
                ],
              ),
              const SizedBox(height: 16),
              if (_showStatsCards) ...[
                _buildStatsGrid(leadsState),
                const SizedBox(height: 24),
              ],
              _buildLeadsSection(leadsState, isDark, isAllSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardToggle(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showStatsCards = !_showStatsCards),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _showStatsCards
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool hasActiveFilters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leads',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your leads in a better way.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            _buildIconButton(
              Icons.refresh,
              isDark,
              onTap: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing leads...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                try {
                  if (_refreshIndicatorKey.currentState != null) {
                    await _refreshIndicatorKey.currentState!.show();
                  } else {
                    await ref.read(leadsProvider.notifier).refresh();
                    final user = ref.read(loginProvider).user;
                    final isAdmin = user?.systemRole == 'company_admin';
                    await ref
                        .read(dashboardProvider.notifier)
                        .fetchDashboardData(isAdmin: isAdmin);
                  }

                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Leads refreshed successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to refresh: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            if (ref
                .watch(permissionsProvider)
                .hasPermission(
                  PermissionModules.LEADS_CREATE_MANUAL,
                  userRole: ref.watch(loginProvider).user?.systemRole,
                ))
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildIconButton(
                  Icons.add,
                  isDark,
                  onTap: () => _showCreateLeadDialog(context),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha:0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 18,
            color: isDark ? Colors.grey[500] : Colors.black45,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  ref.read(leadsProvider.notifier).applyFilters({
                    ...ref.read(leadsProvider).filters,
                    'search': val,
                  });
                });
              },
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Search leads...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.black45,
                  height: 1.2,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textAlignVertical: TextAlignVertical.center,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                ref.read(leadsProvider.notifier).applyFilters({
                  ...ref.read(leadsProvider).filters,
                  'search': '',
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.clear,
                  size: 16,
                  color: isDark ? Colors.grey[500] : Colors.black45,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersButton(bool isDark, bool hasActiveFilters) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildIconButton(
          Icons.filter_list,
          isDark,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => LeadFilterBottomSheet(
                currentFilters: ref.read(leadsProvider).filters,
                onApply: (filters) {
                  ref.read(leadsProvider.notifier).applyFilters(filters);
                },
              ),
            );
          },
        ),
        if (hasActiveFilters)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDuplicateFilterButton(bool isDark, bool isActive) {
    final theme = Theme.of(context);
    final activeColor = isDark ? Colors.blueAccent : Colors.black;
    return Tooltip(
      message: "Show Duplicates Only",
      child: InkWell(
        onTap: () {
          final currentFilters = ref.read(leadsProvider).filters;
          final newFilters = Map<String, dynamic>.from(currentFilters);
          if (isActive) {
            newFilters.remove('duplicate');
          } else {
            newFilters['duplicate'] = true;
          }
          ref.read(leadsProvider.notifier).applyFilters(newFilters);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? activeColor.withValues(alpha: 0.2) : Colors.black)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : theme.dividerColor.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isActive ? Icons.copy_rounded : Icons.copy_outlined,
            size: 20,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
          ),
        ),
      ),
    );
  }

  Widget _buildSubAssignedFilterButton(bool isDark, bool isActive) {
    final theme = Theme.of(context);
    final activeColor = isDark
        ? const Color(0xFF818CF8)
        : const Color(0xFF3730A3);
    return Tooltip(
      message: "My Sub-assigned Leads",
      child: InkWell(
        onTap: () {
          final currentFilters = ref.read(leadsProvider).filters;
          final newFilters = Map<String, dynamic>.from(currentFilters);
          if (isActive) {
            newFilters.remove('onlySubAssigned');
          } else {
            newFilters['onlySubAssigned'] = true;
          }
          ref.read(leadsProvider.notifier).applyFilters(newFilters);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                      ? activeColor.withValues(alpha: 0.2)
                      : const Color(0xFFE0E7FF))
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : theme.dividerColor.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isActive ? Icons.group : Icons.group_outlined,
            size: 20,
            color: isActive
                ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3730A3))
                : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, bool isDark, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha:0.4),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildLeadsSection(
    LeadsState leadsState,
    bool isDark,
    bool isAllSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildColumnSelector(context)),
            if (leadsState.leads.isNotEmpty) ...[
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: isAllSelected,
                    activeColor: Colors.black,
                    onChanged: (_) => _selectAllOnPage(leadsState.leads),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "SELECT ALL",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        if (leadsState.isLoading && leadsState.leads.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(),
            ),
          )
        else if (leadsState.error != null && leadsState.leads.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(60),
              child: Text(
                'Error: ${leadsState.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          )
        else if (leadsState.leads.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(60),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No leads found',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: leadsState.leads.length + (leadsState.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= leadsState.leads.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final lead = leadsState.leads[index];
              return _buildLeadItem(context, lead, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildColumnSelector(BuildContext context) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const _ColumnConfigDialog(),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha:0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.view_column_outlined,
              size: 18,
              color: Colors.black,
            ),
            const SizedBox(width: 8),
            const Text(
              "COLUMNS",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(LeadsState leadsState) {
    // Dashboard data - not linked to lead list filters
    final dashboardState = ref.watch(dashboardProvider);
    final tasksState = ref.watch(tasksProvider);
    final data = dashboardState.data;

    final assigned = data?.leadAssignment?.assigned ?? 0;
    final unassigned = data?.leadAssignment?.unassigned ?? 0;
    final statusCounts = data?.leadStatus?.statusCounts ?? {};
    final totalFromStatus = statusCounts.values.fold(0, (a, b) => a + b);

    int totalLeads = leadsState.totalCount;
    if (totalLeads == 0) {
      totalLeads = (assigned + unassigned) > 0
          ? (assigned + unassigned)
          : totalFromStatus;
    }

    final hotLeads = data?.pipelines?.pipelineCounts['Hot'] ?? 0;
    final convertedLeads = data?.leadStatus?.statusCounts['Converted'] ?? 0;

    // Using tasksState for more accurate real-time counts
    final pendingTasks = tasksState.pendingCount;
    final overdueTasks = tasksState.overdueCount;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardStatsCard(
                title: 'Total Leads',
                value: '$totalLeads',
                icon: Icons.timeline,
                backgroundColor: Colors.blueGrey.shade800,
                gradientColors: [
                  Colors.blueGrey.shade800,
                  Colors.blueGrey.shade900,
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DashboardStatsCard(
                title: 'Hot Leads',
                value: '$hotLeads',
                icon: Icons.local_fire_department,
                backgroundColor: Colors.deepOrange,
                gradientColors: [Colors.deepOrange, Colors.orange],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DashboardStatsCard(
                title: 'Leads Converted',
                value: '$convertedLeads',
                icon: Icons.check_circle,
                backgroundColor: Colors.green,
                gradientColors: [Colors.green, Colors.teal],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DashboardStatsCard(
                title: 'Tasks Pending',
                value: '$pendingTasks',
                icon: Icons.timer,
                backgroundColor: Colors.orange,
                gradientColors: [Colors.orange, Colors.deepOrange],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DashboardStatsCard(
                title: 'Tasks Overdue',
                value: '$overdueTasks',
                icon: Icons.warning_amber_rounded,
                backgroundColor: Colors.red,
                gradientColors: [Colors.red, Colors.redAccent],
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildLeadItem(BuildContext context, Lead lead, bool isDark) {
    final user = ref.watch(loginProvider).user;
    final permissions = ref.watch(permissionsProvider);
    final userRole = user?.systemRole;

    return _LeadListItem(
      lead: lead,
      isSelected: _selectedLeadIds.contains(lead.id),
      onSelect: (_) => _toggleLeadSelection(lead.id),
      onCallPressed:
          permissions.hasPermission(
            PermissionModules.LEADS_CALL,
            userRole: userRole,
          )
          ? () => _initiateCall(lead)
          : null,
      onIvrCallPressed:
          (permissions.hasPermission(
                PermissionModules.INTEGRATION_IVR_CALL,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.INTEGRATION_IVR,
                userRole: userRole,
              ))
          ? () => _initiateIvrCall(lead)
          : null,
      onNativeWhatsAppPressed:
          permissions.hasPermission(
            PermissionModules.LEADS_WHATSAPP,
            userRole: userRole,
          )
          ? () => _launchWhatsApp(lead)
          : null,
      onCrmWhatsAppPressed:
          (permissions.hasPermission(
                PermissionModules.LEADS_WHATSAPP,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                'modules.integration',
                userRole: userRole,
              ) &&
              permissions.hasModule('modules.whatsapp', userRole: userRole))
          ? () => _launchCrmWhatsApp(lead)
          : null,
      onEmailPressed:
          (permissions.hasPermission(
                PermissionModules.LEADS_MAIL,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.TOOLS,
                userRole: userRole,
              ))
          ? () => _sendEmail(lead)
          : null,
      onEditPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => SubAssigneeDialog(lead: lead),
        );
      },
      onUpdateStatus:
          (permissions.hasPermission(
                PermissionModules.LEADS_UPDATE_STATUS,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.LEADS,
                userRole: userRole,
              ))
          ? () => _showUpdateStatusDialog(context, lead)
          : null,
      onCreateTask:
          (permissions.hasPermission(
                PermissionModules.TASKS_CREATE,
                userRole: userRole,
              ) &&
              permissions.hasModule(PermissionModules.TASK, userRole: userRole))
          ? () => _showCreateTaskDialog(context, lead)
          : null,
      onDelete:
          (permissions.hasPermission(
                PermissionModules.LEADS_DELETE,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.LEADS,
                userRole: userRole,
              ))
          ? () => _showDeleteConfirmation(context, lead)
          : null,
      onScheduleMeeting:
          (permissions.hasPermission(
                PermissionModules.MEETINGS_CREATE,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.MEETING,
                userRole: userRole,
              ))
          ? () => _showScheduleMeetingDialog(context, lead)
          : null,
      onScheduleVisit:
          (permissions.hasPermission(
                PermissionModules.VISITS_CREATE,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.VISITS,
                userRole: userRole,
              ))
          ? () => _showScheduleVisitDialog(context, lead)
          : null,
      onShareQuotation:
          (permissions.hasPermission(
                PermissionModules.QUOTATION_VIEW,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.QUOTATION,
                userRole: userRole,
              ))
          ? () => _fetchAndShowDocuments<Quotation>(
              context: context,
              title: 'Select Quotation',
              itemLabel: (q) => '${q.quotationNumber} - ${q.clientName}',
              onItemSelected: (quotation) =>
                  _showQuotationShareDialog(context, quotation, lead),
              fetchDocuments: () async {
                ref.read(quotationsProvider.notifier).setLeadFilter(lead.id);
                await ref
                    .read(quotationsProvider.notifier)
                    .fetchQuotations(refresh: true);
                return ref.read(quotationsProvider).quotations;
              },
              lead: lead,
            )
          : null,
      onShareInvoice:
          (permissions.hasPermission(
                PermissionModules.INVOICE_VIEW,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.INVOICE,
                userRole: userRole,
              ))
          ? () => _fetchAndShowDocuments<Invoice>(
              context: context,
              title: 'Select Invoice',
              itemLabel: (i) => '${i.invoiceNumber} - ${i.clientName}',
              onItemSelected: (invoice) =>
                  _showInvoiceShareDialog(context, invoice, lead),
              fetchDocuments: () async {
                await ref.read(invoicesProvider.notifier).applyFilters({
                  ...ref.read(invoicesProvider).filters,
                  'lead': lead.id,
                });
                return ref.read(invoicesProvider).invoices;
              },
              lead: lead,
            )
          : null,
      onShareItinerary:
          (permissions.hasPermission(
                PermissionModules.ITINERARY_VIEW,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.ITINERARY,
                userRole: userRole,
              ))
          ? () => _fetchAndShowDocuments<ItineraryV2>(
              context: context,
              title: 'Select Itinerary',
              itemLabel: (i) => '${i.subject} - ${i.clientName}',
              onItemSelected: (itinerary) =>
                  _showItineraryShareDialog(context, itinerary, lead),
              fetchDocuments: () async {
                ref.read(itineraryV2Provider.notifier).setLeadFilter(lead.id);
                await ref
                    .read(itineraryV2Provider.notifier)
                    .fetchItineraries(refresh: true);
                return ref.read(itineraryV2Provider).itineraries;
              },
              lead: lead,
            )
          : null,
      onShareVoucher:
          (permissions.hasPermission(
                PermissionModules.VOUCHER_VIEW,
                userRole: userRole,
              ) &&
              permissions.hasModule(
                PermissionModules.VOUCHER,
                userRole: userRole,
              ))
          ? () => _fetchAndShowDocuments<Voucher>(
              context: context,
              title: 'Select Voucher',
              itemLabel: (v) => '${v.voucherNo} - ${v.clientName}',
              onItemSelected: (voucher) =>
                  _showVoucherShareDialog(context, voucher, lead),
              fetchDocuments: () async {
                await ref.read(vouchersProvider.notifier).applyFilters({
                  ...ref.read(vouchersProvider).filters,
                  'lead': lead.id,
                });
                return ref.read(vouchersProvider).vouchers;
              },
              lead: lead,
            )
          : null,
    );
  }

  Future<void> _fetchAndShowDocuments<T>({
    required BuildContext context,
    required String title,
    required String Function(T) itemLabel,
    required void Function(T) onItemSelected,
    required Future<List<T>> Function() fetchDocuments,
    Lead? lead,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final documents = await fetchDocuments();

    if (!context.mounted) return;
    Navigator.pop(context);

    _showDocumentSelectionBottomSheet<T>(
      context: context,
      title: title,
      itemLabel: itemLabel,
      onItemSelected: onItemSelected,
      documents: documents,
      lead: lead,
    );
  }

  void _showDocumentSelectionBottomSheet<T>({
    required BuildContext context,
    required String title,
    required String Function(T) itemLabel,
    required void Function(T) onItemSelected,
    required List<T> documents,
    Lead? lead,
  }) {
    if (documents.isEmpty) {
      // Show bottom sheet anyway to allow CREATE action
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocumentSelectorBottomSheet<T>(
        title: title,
        documents: documents,
        onItemSelected: onItemSelected,
        lead: lead,
        parentContext: context,
      ),
    );
  }

  void _showQuotationShareDialog(
    BuildContext context,
    Quotation quotation, [
    Lead? lead,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => QuotationShareDialog(quotation: quotation, lead: lead),
    );
  }

  void _showInvoiceShareDialog(
    BuildContext context,
    Invoice invoice, [
    Lead? lead,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => InvoiceShareDialog(invoice: invoice, lead: lead),
    );
  }

  void _showItineraryShareDialog(
    BuildContext context,
    ItineraryV2 itinerary, [
    Lead? lead,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => ItineraryShareDialog(itinerary: itinerary, lead: lead),
    );
  }

  void _showVoucherShareDialog(
    BuildContext context,
    Voucher voucher, [
    Lead? lead,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => VoucherShareDialog(voucher: voucher, lead: lead),
    );
  }

  void _showCreateLeadDialog(BuildContext context, {Lead? lead}) {
    showDialog(
      context: context,
      builder: (context) => LeadCreateDialog(lead: lead),
    );
  }

  void showBulkUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LeadBulkUploadDialog(),
    );
  }

  void _showUpdateStatusDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) => LeadStatusUpdateDialog(lead: lead),
    );
  }

  void _showCreateTaskDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) => LeadTaskCreateDialog(leadId: lead.id),
    );
  }

  void _showScheduleMeetingDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) =>
          MeetingCreateDialog(leadId: lead.id, clientEmail: lead.email),
    );
  }

  void _showScheduleVisitDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) => VisitCreateDialog(leadId: lead.id),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Are you sure you want to delete ${lead.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              ref
                  .read(leadsProvider.notifier)
                  .deleteLead(lead.id)
                  .then((_) {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Lead deleted successfully'),
                        ),
                      );
                    }
                  })
                  .catchError((e) {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget buildActionButton(BuildContext context, IconData icon, {VoidCallback? onTap, bool isPrimary = false,}) {
    final theme = Theme.of(context);
  theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: isPrimary ? Colors.black : theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: isPrimary
                ? null
                : Border.all(color: theme.dividerColor.withValues(alpha:0.1)),
          ),
          child: Icon(
            icon,
            color: isPrimary
                ? Colors.white
                : theme.textTheme.bodyLarge?.color?.withValues(alpha:0.8),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;
 Theme.of(context);

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedLeadIds.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (permissions.hasPermission(
                      PermissionModules.LEADS_BULK_ASSIGN,
                      userRole: userRole,
                    ))
                      Expanded(
                        child: _buildBarButton(
                          label: 'Bulk Assign',
                          icon: Icons.person_add_alt_1,
                          color: const Color(0xFF1976D2),
                          onTap: () {
                            LeadBulkAssignSheet.show(
                              context,
                              _selectedLeadIds.toList(),
                            ).then((assigned) {
                              if (mounted && assigned == true) {
                                setState(() => _selectedLeadIds.clear());
                                _updateDockForSelection();
                              }
                            });
                          },
                        ),
                      ),
                    if (permissions.hasPermission(
                          PermissionModules.LEADS_BULK_ASSIGN,
                          userRole: userRole,
                        ) &&
                        permissions.hasPermission(
                          PermissionModules.LEADS_UPDATE_STATUS,
                          userRole: userRole,
                        ))
                      const SizedBox(width: 8),
                    if (permissions.hasPermission(
                      PermissionModules.LEADS_UPDATE_STATUS,
                      userRole: userRole,
                    ))
                      Expanded(
                        child: _buildBarButton(
                          label: 'Bulk Update',
                          icon: Icons.edit_note,
                          color: Colors.black,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => LeadBulkUpdateDialog(
                                leadIds: _selectedLeadIds.toList(),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() => _selectedLeadIds.clear());
                                _updateDockForSelection();
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() => _selectedLeadIds.clear());
                  _updateDockForSelection();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha:0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Tag {
  final String text;
  final Color color;
  final Color textColor;
  const Tag({
    required this.text,
    required this.color,
    required this.textColor,
  });
}

class _LeadListItem extends ConsumerWidget {
  final Lead lead;
  final bool isSelected;
  final ValueChanged<bool?> onSelect;
  final VoidCallback? onCallPressed;
  final VoidCallback? onIvrCallPressed;
  final VoidCallback? onNativeWhatsAppPressed;
  final VoidCallback? onCrmWhatsAppPressed;
  final VoidCallback? onEmailPressed;
  final VoidCallback? onEditPressed;

  // Transactional Actions
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onCreateTask;
  final VoidCallback? onScheduleMeeting;
  final VoidCallback? onScheduleVisit;
  final VoidCallback? onDelete;

  // Document Share Actions
  final VoidCallback? onShareQuotation;
  final VoidCallback? onShareInvoice;
  final VoidCallback? onShareItinerary;
  final VoidCallback? onShareVoucher;

  const _LeadListItem({
    required this.lead,
    required this.isSelected,
    required this.onSelect,
    this.onCallPressed,
    this.onIvrCallPressed,
    this.onNativeWhatsAppPressed,
    this.onCrmWhatsAppPressed,
    this.onEmailPressed,
    this.onEditPressed,
    this.onUpdateStatus,
    this.onCreateTask,
    this.onScheduleMeeting,
    this.onScheduleVisit,
    this.onDelete,
    this.onShareQuotation,
    this.onShareInvoice,
    this.onShareItinerary,
    this.onShareVoucher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(leadCardConfigProvider);
    final user = ref.watch(loginProvider).user;
    final permissions = ref.watch(permissionsProvider);
    final userRole = user?.systemRole;

    final hasServiceModule = permissions.hasModule(
      PermissionModules.SERVICES,
      userRole: userRole,
    );
     permissions.hasModule(
      PermissionModules.PROPERTY,
      userRole: userRole,
    );

    // 1. Status Colors Dynamic Logic
    Color status = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100]!;
    Color statusText = isDark ? Colors.grey[400]! : Colors.grey[800]!;

    final lowerStatus = lead.status.toLowerCase();
    if (lowerStatus == 'new') {
      status = isDark ? Colors.blue.withValues(alpha:0.12) : Colors.blue[50]!;
      statusText = isDark ? Colors.blue[300]! : Colors.blue[800]!;
    } else if (lowerStatus == 'contacted') {
      status = isDark ? Colors.green.withValues(alpha:0.12) : Colors.green[50]!;
      statusText = isDark ? Colors.green[300]! : Colors.green[800]!;
    } else if (lowerStatus == 'in negotiation' ||
        lowerStatus == 'negotiation') {
      status = isDark ? Colors.orange.withValues(alpha:0.12) : Colors.orange[50]!;
      statusText = isDark ? Colors.orange[300]! : Colors.orange[800]!;
    } else if (lowerStatus == 'lost') {
      status = isDark ? Colors.red.withValues(alpha:0.12) : Colors.red[50]!;
      statusText = isDark ? Colors.red[300]! : Colors.red[800]!;
    } else if (lowerStatus == 'converted') {
      status = isDark ? Colors.teal.withValues(alpha:0.12) : Colors.teal[50]!;
      statusText = isDark ? Colors.teal[300]! : Colors.teal[800]!;
    }

    // 2. Stage/Pipeline Colors Dynamic Logic
    Color pipelineBg = isDark
        ? Colors.white.withValues(alpha:0.05)
        : Colors.grey[100]!;
    Color pipelineText = isDark ? Colors.grey[400]! : Colors.grey[800]!;

    if (lead.pipeline.isNotEmpty) {
      switch (lead.pipeline) {
        case 'Hot':
          pipelineBg = isDark ? Colors.red.withValues(alpha:0.12) : Colors.red[50]!;
          pipelineText = isDark ? Colors.red[300]! : Colors.red[800]!;
          break;
        case 'Warm':
          pipelineBg = isDark
              ? Colors.orange.withValues(alpha:0.12)
              : Colors.orange[50]!;
          pipelineText = isDark ? Colors.orange[300]! : Colors.orange[800]!;
          break;
        case 'Cold':
          pipelineBg = isDark
              ? Colors.blue.withValues(alpha:0.12)
              : Colors.blue[50]!;
          pipelineText = isDark ? Colors.blue[300]! : Colors.blue[800]!;
          break;
      }
    }

    // 3. Date & Timeline Logic
    final updated = DateTimeUtils.parseSafe(lead.updatedAt);
    final timeAgoStr = updated != null ? timeago.format(updated) : "";
    final dateStr = updated != null ? DateTimeUtils.formatShort(updated) : "";

    return GestureDetector(
      onTap: () {
        final user = ref.read(loginProvider).user;
        final permissions = ref.read(permissionsProvider);
        if (!permissions.hasPermission(
          PermissionModules.LEADS_VIEW,
          userRole: user?.systemRole,
        )) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to view lead details'),
            ),
          );
          return;
        }
        final hasServiceModule = permissions.hasModule(
          PermissionModules.SERVICES,
          userRole: user?.systemRole,
        );
        final detailStr =
            '${hasServiceModule ? (lead.service?.name ?? "") : ""}  ${lead.source}'
                .trim();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LeadProfileScreen(
              leadId: lead.id,
              name: lead.name,
              phone: lead.phoneNo,
              details: detailStr,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha:0.08)
                : Colors.grey.withValues(alpha:0.15),
            width: 1.0,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ROW (Avatar, Info, Checkbox) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Initials Box
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blueAccent.withValues(alpha:0.2) : Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(lead.name),
                      style: TextStyle(
                        color: isDark ? Colors.blueAccent : const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Middle Info Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name.isNotEmpty ? lead.name : "Unnamed Lead",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lead.phoneNo.isNotEmpty ? lead.phoneNo : "No Phone",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.upload_outlined,
                              size: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lead.source.isNotEmpty ? lead.source : "Manual upload",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Checkbox
                  Checkbox(
                    value: isSelected,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: onSelect,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- BADGES ROW (Status, Stage, Assignee) ---
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCuratedBadgeWithPencil(
                    text: toTitleCase(lead.status.isEmpty ? 'New' : lead.status),
                    bgColor: status,
                    textColor: statusText,
                    onTap: onUpdateStatus,
                    isDark: isDark,
                  ),
                  _buildCuratedBadgeWithPencil(
                    text: lead.pipeline.isNotEmpty ? lead.pipeline : 'Cold',
                    bgColor: pipelineBg,
                    textColor: pipelineText,
                    onTap: () {}, // No-op callback to show pencil icon exactly like screenshot
                    isDark: isDark,
                  ),
                  _buildCuratedBadgeWithPencil(
                    text: lead.assignedTo != null ? lead.assignedTo!.name : 'Not Assigned',
                    bgColor: isDark ? Colors.purple.withValues(alpha:0.15) : const Color(0xFFEDE9FE),
                    textColor: isDark ? Colors.purple[300]! : const Color(0xFF5B21B6),
                    onTap: onEditPressed,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // --- QUICK ACTIONS TITLE ---
              Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // --- QUICK ACTIONS 2X4 GRID ---
              Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.25,
                      child: _buildGridActionItem(
                        icon: Icons.visibility_outlined,
                        label: 'View',
                        isActive: false,
                        onTap: () {
                          final detailStr = '${hasServiceModule ? (lead.service?.name ?? "") : ""}  ${lead.source}'.trim();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LeadProfileScreen(
                                leadId: lead.id,
                                name: lead.name,
                                phone: lead.phoneNo,
                                details: detailStr,
                              ),
                            ),
                          );
                        },
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.25,
                      child: _buildGridActionItem(
                        icon: Icons.phone_outlined,
                        label: 'Call',
                        isActive: onCallPressed != null,
                        onTap: () => _showAllActionsBottomSheet(context, ref),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.25,
                      child: _buildGridActionItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Whatsapp',
                        isActive: onNativeWhatsAppPressed != null,
                        onTap: () => _showAllActionsBottomSheet(context, ref),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.25,
                      child: _buildGridActionItem(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        isActive: false,
                        onTap: () => _showAllActionsBottomSheet(context, ref),
                        isDark: isDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.25,
                      child: _buildGridActionItem(
                        icon: Icons.note_alt_outlined,
                        label: 'Notes',
                        isActive: false,
                        onTap: () => _showAllActionsBottomSheet(context, ref),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.25,
                      child: _buildGridActionItem(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Transfer',
                        isActive: false,
                        onTap: () => _showAllActionsBottomSheet(context, ref),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.25,
                      child: _buildGridActionItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Invoice',
                        isActive: false,
                        onTap: () => _showAllActionsBottomSheet(context, ref),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.25,
                      child: _buildGridActionItem(
                        icon: Icons.star_outline_rounded,
                        label: 'Favorite',
                        isActive: false,
                        onTap: () => _showAllActionsBottomSheet(context, ref),
                        isDark: isDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- CRM Chat & IVR Call capsule row ---
              Row(
                children: [
                  if (onCrmWhatsAppPressed != null)
                    Expanded(
                      child: _buildRedesignedCapsuleButton(
                        label: 'CRM chat',
                        icon: 'assets/whatapp-ui/whatsapp.svg',
                        color: const Color(0xFF008A10),
                        onTap: onCrmWhatsAppPressed,
                        isDark: isDark,
                      ),
                    ),
                  if (onCrmWhatsAppPressed != null && onIvrCallPressed != null)
                    const SizedBox(width: 10),
                  if (onIvrCallPressed != null)
                    Expanded(
                      child: _buildRedesignedCapsuleButton(
                        label: 'IVR call',
                        icon: Icons.phone_in_talk_outlined,
                        color: const Color(0xFF6366F1),
                        onTap: onIvrCallPressed,
                        isDark: isDark,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // --- DATE & TIMELINE ROW ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (timeAgoStr.isNotEmpty)
                    Text(
                      timeAgoStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // --- BOTTOM OUTLINE ACTION BUTTONS ROW ---
              Row(
                children: [
                  if (onUpdateStatus != null)
                    Expanded(
                      child: _buildOutlineActionButtonRedesigned(
                        label: 'Update status',
                        onTap: onUpdateStatus!,
                        isDark: isDark,
                      ),
                    ),
                  if (onUpdateStatus != null && onCreateTask != null)
                    const SizedBox(width: 8),
                  if (onCreateTask != null)
                    Expanded(
                      child: _buildOutlineActionButtonRedesigned(
                        label: 'Create task',
                        onTap: onCreateTask!,
                        isDark: isDark,
                      ),
                    ),
                  if (onCreateTask != null && (onScheduleMeeting != null || onScheduleVisit != null))
                    const SizedBox(width: 8),
                  if (onScheduleMeeting != null || onScheduleVisit != null)
                    Expanded(
                      child: _buildOutlineActionButtonRedesigned(
                        label: 'Schedule',
                        onTap: () {
                          if (onScheduleMeeting != null && onScheduleVisit != null) {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.meeting_room_outlined),
                                      title: const Text('Schedule Meeting'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        onScheduleMeeting!();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.directions_run_outlined),
                                      title: const Text('Schedule Visit'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        onScheduleVisit!();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (onScheduleMeeting != null) {
                            onScheduleMeeting!();
                          } else if (onScheduleVisit != null) {
                            onScheduleVisit!();
                          }
                        },
                        isDark: isDark,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCuratedBadgeWithPencil({
    required String text,
    required Color bgColor,
    required Color textColor,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit_outlined,
              size: 12,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridActionItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final bgColor = isActive
        ? (isDark ? const Color(0xFF065F46).withValues(alpha:0.2) : const Color(0xFFD1FAE5))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB));
    final iconColor = isActive
        ? const Color(0xFF059669)
        : (isDark ? Colors.grey[400]! : const Color(0xFF4B5563));
    final textColor = isActive
        ? const Color(0xFF047857)
        : (isDark ? Colors.grey[300]! : const Color(0xFF374151));

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedesignedCapsuleButton({
    required String label,
    required dynamic icon,
    required Color color,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final isEnabled = onTap != null;
    Widget iconWidget;
    if (icon is String) {
      iconWidget = SvgPicture.asset(
        icon,
        width: 16,
        height: 16,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    } else {
      iconWidget = Icon(icon as IconData, size: 16, color: Colors.white);
    }

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineActionButtonRedesigned({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey[300]!,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'L';
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return 'L';
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
    }
    return parts[0][0].toUpperCase();
  }

  Widget buildDetailLine(BuildContext context, String label, String value, bool isDark,) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPrimaryCapsuleButton({required BuildContext context, required String label, required dynamic icon, required Color color, required VoidCallback? onTap,}) {
    final isEnabled = onTap != null;
    Widget iconWidget;
    if (icon is String) {
      iconWidget = SvgPicture.asset(
        icon,
        width: 14,
        height: 14,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    } else {
      iconWidget = Icon(icon as IconData, size: 14, color: Colors.white);
    }

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildOutlineActionButton({required BuildContext context, required String label, required VoidCallback onTap,}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha:0.1)
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[750],
            ),
          ),
        ),
      ),
    );
  }

  void _showAllActionsBottomSheet(BuildContext context, WidgetRef ref) {
    final lead = this.lead;
    final onCallPressed = this.onCallPressed;
    final onIvrCallPressed = this.onIvrCallPressed;
    final onNativeWhatsAppPressed = this.onNativeWhatsAppPressed;
    final onCrmWhatsAppPressed = this.onCrmWhatsAppPressed;
    final onEmailPressed = this.onEmailPressed;
    final onUpdateStatus = this.onUpdateStatus;
    final onCreateTask = this.onCreateTask;
    final onScheduleMeeting = this.onScheduleMeeting;
    final onScheduleVisit = this.onScheduleVisit;
    final onShareQuotation = this.onShareQuotation;
    final onShareInvoice = this.onShareInvoice;
    final onShareItinerary = this.onShareItinerary;
    final onShareVoucher = this.onShareVoucher;

    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;

    final hasServiceModule = permissions.hasModule(
      PermissionModules.SERVICES,
      userRole: userRole,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Actions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.visibility_outlined, color: Colors.blue),
                      title: const Text('View Lead Details'),
                      onTap: () {
                        Navigator.pop(ctx);
                        final detailStr = '${hasServiceModule ? (lead.service?.name ?? "") : ""}  ${lead.source}'.trim();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LeadProfileScreen(
                              leadId: lead.id,
                              name: lead.name,
                              phone: lead.phoneNo,
                              details: detailStr,
                            ),
                          ),
                        );
                      },
                    ),
                    if (onCallPressed != null)
                      ListTile(
                        leading: const Icon(Icons.phone_outlined, color: Colors.green),
                        title: const Text('Call'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onCallPressed();
                        },
                      ),
                    if (onNativeWhatsAppPressed != null)
                      ListTile(
                        leading: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                        title: const Text('WhatsApp'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onNativeWhatsAppPressed();
                        },
                      ),
                    if (onCrmWhatsAppPressed != null)
                      ListTile(
                        leading: const Icon(Icons.question_answer_outlined, color: Color(0xFF0F8C77)),
                        title: const Text('CRM Chat'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onCrmWhatsAppPressed();
                        },
                      ),
                    if (onIvrCallPressed != null)
                      ListTile(
                        leading: const Icon(Icons.phone_in_talk_outlined, color: Color(0xFF4F46E5)),
                        title: const Text('IVR Call'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onIvrCallPressed();
                        },
                      ),
                    if (onUpdateStatus != null)
                      ListTile(
                        leading: const Icon(Icons.sync_alt_outlined, color: Colors.orange),
                        title: const Text('Update Status'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onUpdateStatus();
                        },
                      ),
                    if (onCreateTask != null)
                      ListTile(
                        leading: const Icon(Icons.add_task_outlined, color: Colors.purple),
                        title: const Text('Create Task'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onCreateTask();
                        },
                      ),
                    if (onScheduleMeeting != null || onScheduleVisit != null)
                      ListTile(
                        leading: const Icon(Icons.calendar_month_outlined, color: Colors.teal),
                        title: const Text('Schedule'),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (onScheduleMeeting != null && onScheduleVisit != null) {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.meeting_room_outlined),
                                      title: const Text('Schedule Meeting'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        onScheduleMeeting();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.directions_run_outlined),
                                      title: const Text('Schedule Visit'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        onScheduleVisit();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (onScheduleMeeting != null) {
                            onScheduleMeeting();
                          } else if (onScheduleVisit != null) {
                            onScheduleVisit();
                          }
                        },
                      ),
                    if (onEmailPressed != null)
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded, color: Colors.blueGrey),
                        title: const Text('Email'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onEmailPressed();
                        },
                      ),
                    if (onShareQuotation != null)
                      ListTile(
                        leading: const Icon(Icons.request_quote_outlined, color: Colors.blue),
                        title: const Text('Notes'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onShareQuotation();
                        },
                      ),
                    if (onShareItinerary != null)
                      ListTile(
                        leading: const Icon(Icons.route_outlined, color: Colors.cyan),
                        title: const Text('Transfer'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onShareItinerary();
                        },
                      ),
                    if (onShareInvoice != null)
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined, color: Colors.amber),
                        title: const Text('Invoice'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onShareInvoice();
                        },
                      ),
                    if (onShareVoucher != null)
                      ListTile(
                        leading: const Icon(Icons.local_activity_outlined, color: Colors.red),
                        title: const Text('Favorite'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onShareVoucher();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildDynamicDetailsWrap(BuildContext context, dynamic config, bool hasServiceModule, bool hasPropertyModule,) {
    final detailTags = <Widget>[];

    if (config.showService && hasServiceModule && lead.service?.name != null) {
      detailTags.add(_buildDetailTag(context, lead.service!.name, Colors.teal));
    }
    if (config.showProject && hasPropertyModule && lead.project?.name != null) {
      detailTags.add(
        _buildDetailTag(context, lead.project!.name, Colors.blueGrey),
      );
    }
    if (config.showProperty &&
        hasPropertyModule &&
        lead.property?.name != null) {
      detailTags.add(
        _buildDetailTag(context, lead.property!.name, Colors.indigo),
      );
    }
    if (config.showDOB && lead.dob != null && lead.dob!.isNotEmpty) {
      detailTags.add(
        _buildDetailTag(context, 'DOB: ${lead.dob!}', Colors.purple),
      );
    }
    if (config.showAmount && lead.amount > 0) {
      detailTags.add(
        _buildDetailTag(
          context,
          '₹${lead.amount.toStringAsFixed(0)}',
          Colors.amber,
        ),
      );
    }
    if (config.showTeam && lead.team != null) {
      detailTags.add(
        _buildDetailTag(context, 'Team: ${lead.team!.name}', Colors.purple),
      );
    }
    if (config.showGroup && lead.group != null) {
      detailTags.add(
        _buildDetailTag(context, 'Group: ${lead.group!.name}', Colors.grey),
      );
    }

    if (detailTags.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 5, runSpacing: 5, children: detailTags),
    );
  }

  Widget _buildDetailTag(BuildContext context, String text, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha:isDark ? 0.25 : 0.12),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? color.withValues(alpha:0.9) : color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildDynamicDetailsRows(BuildContext context, dynamic config, bool hasServiceModule, bool hasPropertyModule, dynamic permissions, String? userRole,) {
    final hasTripPermission = permissions.can(
      PermissionModules.TRIP,
      permission: PermissionModules.TRIP_VIEW,
      userRole: userRole,
    );
    final showDestination =
        config.showDestination &&
        hasTripPermission &&
        lead.destination != null &&
        lead.destination!.isNotEmpty;
    final showTravelStart =
        config.showTravelStartDate &&
        hasTripPermission &&
        ((lead.travelStartDate != null && lead.travelStartDate!.isNotEmpty) ||
            (lead.travelDates != null && lead.travelDates!.isNotEmpty));
    final showTravelEnd =
        config.showTravelEndDate &&
        hasTripPermission &&
        lead.travelEndDate != null &&
        lead.travelEndDate!.isNotEmpty;
    final showTeam =
        config.showTeam && lead.team != null && lead.team!.name.isNotEmpty;
    final showGroup =
        config.showGroup && lead.group != null && lead.group!.name.isNotEmpty;

    final hasExtraBlock =
        showDestination ||
        showTravelStart ||
        showTravelEnd ||
        showTeam ||
        showGroup;

    if (!hasExtraBlock) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: DottedLine(color: Colors.grey, height: 1),
        ),
        if (showDestination)
          _buildLabeledRow(
            context,
            'Destination:',
            lead.destination!,
            Colors.blue,
          ),
        if (showTravelStart)
          _buildLabeledRow(
            context,
            'Travel Start Date:',
            _formatTravelDate(
              (lead.travelStartDate != null && lead.travelStartDate!.isNotEmpty)
                  ? lead.travelStartDate!
                  : lead.travelDates!,
            ),
            Colors.purple,
          ),
        if (showTravelEnd)
          _buildLabeledRow(
            context,
            'Travel End Date:',
            _formatTravelDate(lead.travelEndDate!),
            Colors.purple,
          ),
        if (showTeam)
          _buildLabeledRow(context, 'Team:', lead.team!.name, Colors.purple),
        if (showGroup)
          _buildLabeledRow(context, 'Group:', lead.group!.name, Colors.grey),
        const SizedBox(height: 10),
      ],
    );
  }

  String _formatTravelDate(String travelDates) {
    final date = DateTimeUtils.parseSafe(travelDates);
    return date != null ? DateFormat('dd MMM yyyy').format(date) : travelDates;
  }

  Widget _buildLabeledRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                width: 0.8,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? color.withValues(alpha: 0.9) : color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDOBBadge(BuildContext context, String dob) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dobDate = DateTimeUtils.parseSafe(dob);
    final dobStr = dobDate != null
        ? DateFormat('dd MMM yyyy').format(dobDate)
        : dob;
    final orangeColor = const Color(0xFFE65100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0).withValues(alpha:isDark ? 0.12 : 1.0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: orangeColor.withValues(alpha:isDark ? 0.25 : 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 11,
            color: isDark ? orangeColor.withValues(alpha:0.9) : orangeColor,
          ),
          const SizedBox(width: 4),
          Text(
            'DOB: $dobStr',
            style: TextStyle(
              color: isDark ? orangeColor.withValues(alpha:0.9) : orangeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAmountBadge(BuildContext context, double amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatted = NumberFormat('#,##,###').format(amount);
    final greenColor = const Color(0xFF2E7D32);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9).withValues(alpha:isDark ? 0.12 : 1.0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: greenColor.withValues(alpha:isDark ? 0.25 : 0.12),
          width: 0.8,
        ),
      ),
      child: Text(
        '₹ $formatted',
        style: TextStyle(
          color: isDark ? greenColor.withValues(alpha:0.9) : greenColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

bool isSubAssigned(Lead lead, dynamic user) {
  if (user == null || user.id == null) return false;
  if (lead.subAssignees == null || lead.subAssignees!.isEmpty) return false;
  if (lead.assignedTo?.id == user.id) return false;
  return lead.subAssignees!.any((sa) => sa.id == user.id);
}

class DottedLine extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashGap;

  const DottedLine({
    super.key,
    this.height = 1,
    this.color = Colors.grey,
    this.dashWidth = 3,
    this.dashGap = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashGap)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color.withValues(alpha: 0.3)),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ColumnConfigDialog extends ConsumerWidget {
  const _ColumnConfigDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(leadCardConfigProvider);
    final notifier = ref.read(leadCardConfigProvider.notifier);
    final user = ref.watch(loginProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final permissions = ref.watch(permissionsProvider);
    final userRole = user?.systemRole;

    final hasServiceModule = permissions.hasModule(
      PermissionModules.SERVICES,
      userRole: userRole,
    );
    final hasPropertyModule = permissions.hasModule(
      PermissionModules.PROPERTY,
      userRole: userRole,
    );
    final hasTripModule = permissions.hasModule(
      PermissionModules.TRIP,
      userRole: userRole,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Customize Card Columns",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: Checkbox(
                      value: true,
                      onChanged: null,
                      activeColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),
                    title: Text(
                      "Name\nRequired",
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  _buildCheckbox(
                    "Contact",
                    config.showContact,
                    notifier.toggleContact,
                    isDark,
                  ),
                  _buildCheckbox(
                    "DOB",
                    config.showDOB,
                    notifier.toggleDOB,
                    isDark,
                  ),
                  if (hasPropertyModule)
                    _buildCheckbox(
                      "Project",
                      config.showProject,
                      notifier.toggleProject,
                      isDark,
                    ),
                  if (hasPropertyModule)
                    _buildCheckbox(
                      "Property",
                      config.showProperty,
                      notifier.toggleProperty,
                      isDark,
                    ),
                  if (hasServiceModule)
                    _buildCheckbox(
                      "Service",
                      config.showService,
                      notifier.toggleService,
                      isDark,
                    ),
                  _buildCheckbox(
                    "Amount",
                    config.showAmount,
                    notifier.toggleAmount,
                    isDark,
                  ),
                  _buildCheckbox(
                    "Source",
                    config.showSource,
                    notifier.toggleSource,
                    isDark,
                  ),
                  _buildCheckbox(
                    "Referred By",
                    config.showReferredBy,
                    notifier.toggleReferredBy,
                    isDark,
                  ),
                  _buildCheckbox(
                    "Status",
                    config.showStatus,
                    notifier.toggleStatus,
                    isDark,
                  ),
                  _buildCheckbox(
                    "Lead Stage",
                    config.showStage,
                    notifier.toggleStage,
                    isDark,
                  ),
                  if (user?.systemRole != 'sales_executive')
                    _buildCheckbox(
                      "Assigned To",
                      config.showAssignedTo,
                      notifier.toggleAssignedTo,
                      isDark,
                    ),
                  if (user?.systemRole != 'sales_executive')
                    _buildCheckbox(
                      "Team",
                      config.showTeam,
                      notifier.toggleTeam,
                      isDark,
                    ),
                  if (user?.systemRole != 'sales_executive')
                    _buildCheckbox(
                      "Group",
                      config.showGroup,
                      notifier.toggleGroup,
                      isDark,
                    ),
                  _buildCheckbox(
                    "Timeline",
                    config.showTimeline,
                    notifier.toggleTimeline,
                    isDark,
                  ),
                  if (hasTripModule)
                    _buildCheckbox(
                      "Destination",
                      config.showDestination,
                      notifier.toggleDestination,
                      isDark,
                    ),
                  if (hasTripModule)
                    _buildCheckbox(
                      "Travel Start Date",
                      config.showTravelStartDate,
                      notifier.toggleTravelStartDate,
                      isDark,
                    ),
                  if (hasTripModule)
                    _buildCheckbox(
                      "Travel End Date",
                      config.showTravelEndDate,
                      notifier.toggleTravelEndDate,
                      isDark,
                    ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: notifier.resetToDefault,
                    child: Text(
                      'Reset to default',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.blueAccent
                          : Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Done"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    Function(bool) onChanged,
    bool isDark,
  ) {
    return ListTile(
      leading: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: isDark ? Colors.blueAccent : Colors.black,
        checkColor: isDark ? Colors.black : Colors.white,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onTap: () => onChanged(!value),
    );
  }
}

class SquareActionIcon extends StatelessWidget {
  final dynamic icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const SquareActionIcon({super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final child = icon is String
        ? SvgPicture.asset(
            icon,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          )
        : Icon(icon as IconData, size: 18, color: color);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha:0.08) : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
