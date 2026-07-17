
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
import '../../data/models/visit_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'marketing/widgets/send_email_dialog.dart';

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
import '../providers/visit_provider.dart';
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
                ],
              ),
              const SizedBox(height: 16),
              _buildLeadsSection(leadsState, isDark, isAllSelected),
            ],
          ),
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

  Widget _buildLeadsSection(LeadsState leadsState, bool isDark, bool isAllSelected,) {
    final hasHeaderFilters = leadsState.filters['isLost'] == true ||
        leadsState.filters['isLost'] == 'true' ||
        leadsState.filters['duplicate'] == true ||
        leadsState.filters['duplicate'] == 'true' ||
        leadsState.filters['onlySubAssigned'] == true ||
        leadsState.filters['onlySubAssigned'] == 'true';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leadsState.leads.isNotEmpty || hasHeaderFilters)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Side: Select All Checkbox

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: isAllSelected,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (_) => _selectAllOnPage(leadsState.leads),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "SELECT ALL",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),


              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Lost Leads Icon (Person with slash)
                  _buildHeaderActionIcon(
                    icon: Icons.person_off_outlined,
                    tooltip: "Toggle Lost Leads filter",
                    isEnabled: true,
                    isHighlighted: leadsState.filters['isLost'] == true || leadsState.filters['isLost'] == 'true',
                    onTap: () {
                      final currentFilters = ref.read(leadsProvider).filters;
                      final newFilters = Map<String, dynamic>.from(currentFilters);
                      if (newFilters['isLost'] == true || newFilters['isLost'] == 'true') {
                        newFilters.remove('isLost');
                      } else {
                        newFilters['isLost'] = true;
                      }
                      ref.read(leadsProvider.notifier).applyFilters(newFilters);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),

                  // 2. Eye Icon (View details / Toggle stats)
                  _buildHeaderActionIcon(
                    icon: _showStatsCards ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    tooltip: "Toggle dashboard stats",
                    isEnabled: true,
                    isHighlighted: _showStatsCards,
                    onTap: () {
                      setState(() {
                        _showStatsCards = !_showStatsCards;
                      });
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),

                  // 3. Copy Icon (Show Duplicates toggle)
                  _buildHeaderActionIcon(
                    icon: leadsState.filters['duplicate'] == true || leadsState.filters['duplicate'] == 'true'
                        ? Icons.content_copy
                        : Icons.content_copy_outlined,
                    tooltip: leadsState.filters['duplicate'] == true || leadsState.filters['duplicate'] == 'true'
                        ? "Hide Duplicates"
                        : "Show Duplicates",
                    isEnabled: true,
                    isHighlighted: leadsState.filters['duplicate'] == true || leadsState.filters['duplicate'] == 'true',
                    onTap: () {
                      final currentFilters = ref.read(leadsProvider).filters;
                      final newFilters = Map<String, dynamic>.from(currentFilters);
                      if (newFilters['duplicate'] == true || newFilters['duplicate'] == 'true') {
                        newFilters.remove('duplicate');
                      } else {
                        newFilters['duplicate'] = true;
                      }
                      ref.read(leadsProvider.notifier).applyFilters(newFilters);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),

                  // 5. Supervisor Account Icon (Show Sub-assigned)
                  _buildHeaderActionIcon(
                    icon: leadsState.filters['onlySubAssigned'] == true || leadsState.filters['onlySubAssigned'] == 'true'
                        ? Icons.supervisor_account
                        : Icons.supervisor_account_outlined,
                    tooltip: "My Sub-assigned Leads",
                    isEnabled: true,
                    isHighlighted: leadsState.filters['onlySubAssigned'] == true || leadsState.filters['onlySubAssigned'] == 'true',
                    onTap: () {
                      final currentFilters = ref.read(leadsProvider).filters;
                      final newFilters = Map<String, dynamic>.from(currentFilters);
                      if (newFilters['onlySubAssigned'] == true || newFilters['onlySubAssigned'] == 'true') {
                        newFilters.remove('onlySubAssigned');
                      } else {
                        newFilters['onlySubAssigned'] = true;
                      }
                      ref.read(leadsProvider.notifier).applyFilters(newFilters);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        if (_showStatsCards) ...[
          const SizedBox(height: 16),
          _buildStatsGrid(leadsState),
        ],
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
                    (leadsState.filters['duplicate'] == true || leadsState.filters['duplicate'] == 'true')
                        ? 'No duplicate data available'
                        : 'No leads found',
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

  Widget _buildHeaderActionIcon({required IconData icon, required String tooltip, required bool isEnabled, required VoidCallback onTap, required bool isDark, bool isHighlighted = false,}) {
    final Color color = isHighlighted
        ? const Color(0xFF2563EB)
        : (isEnabled
            ? (isDark ? Colors.white : Colors.black87)
            : (isDark ? Colors.white30 : Colors.black26));

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isHighlighted
                    ? const Color(0xFF2563EB)
                    : (isEnabled 
                        ? (isDark ? Colors.white24 : Colors.black12)
                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
              ),
              borderRadius: BorderRadius.circular(8),
              color: isHighlighted
                  ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                  : (isEnabled
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                      : Colors.transparent),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
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
    ).then((_) {
      ref.read(leadsProvider.notifier).refresh();
    });
  }

  void showBulkUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LeadBulkUploadDialog(),
    ).then((_) {
      ref.read(leadsProvider.notifier).refresh();
    });
  }

  void _showUpdateStatusDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) => LeadStatusUpdateDialog(lead: lead),
    ).then((_) {
      ref.read(leadsProvider.notifier).refresh();
    });
  }

  void _showCreateTaskDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) => LeadTaskCreateDialog(leadId: lead.id),
    ).then((_) {
      ref.read(leadsProvider.notifier).refresh();
    });
  }

  void _showScheduleMeetingDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) =>
          MeetingCreateDialog(leadId: lead.id, clientEmail: lead.email),
    ).then((_) {
      ref.read(leadsProvider.notifier).refresh();
    });
  }

  void _showScheduleVisitDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (context) => VisitCreateDialog(leadId: lead.id),
    ).then((_) {
      ref.read(leadsProvider.notifier).refresh();
    });
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

  String _getInitials(String name) {
    if (name.isEmpty) return "L";
    final parts = name.trim().split(' ');
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _getTravelDatesStr(Lead lead) {
    final start = (lead.travelStartDate != null && lead.travelStartDate!.isNotEmpty)
        ? lead.travelStartDate!
        : (lead.travelDates != null && lead.travelDates!.isNotEmpty ? lead.travelDates! : "");
    final end = (lead.travelEndDate != null && lead.travelEndDate!.isNotEmpty) ? lead.travelEndDate! : "";

    if (start.isNotEmpty && end.isNotEmpty) {
      return "${_formatTravelDate(start)} - ${_formatTravelDate(end)}";
    } else if (start.isNotEmpty) {
      return _formatTravelDate(start);
    } else if (end.isNotEmpty) {
      return _formatTravelDate(end);
    }
    return "Not scheduled";
  }

  String _formatTravelDate(String dateStr) {
    final date = DateTimeUtils.parseSafe(dateStr);
    return date != null ? DateFormat('dd MMM yyyy').format(date) : dateStr;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final hasServiceModule = permissions.hasModule(
      PermissionModules.SERVICES,
      userRole: userRole,
    );
    final hasPropertyModule = permissions.hasModule(
      PermissionModules.PROPERTY,
      userRole: userRole,
    );

    final bool showService = (hasServiceModule && lead.service != null && lead.service!.name.isNotEmpty)
        ? true
        : (hasPropertyModule && lead.project != null && lead.project!.name.isNotEmpty)
            ? false
            : hasServiceModule;

    // Status colors mapping from original code
    Color statusBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100]!;
    Color statusTextColor = isDark ? Colors.grey[400]! : Colors.grey[800]!;

    final lowerStatus = lead.status.toLowerCase();
    final bool isNew = lowerStatus == 'new';
    if (lowerStatus == 'new') {
      statusBg = isDark ? Colors.blue.withValues(alpha: 0.12) : const Color(0xFFEFF6FF); // Blue-50
      statusTextColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8); // Blue-700
    } else if (lowerStatus == 'contacted') {
      statusBg = isDark ? Colors.green.withValues(alpha: 0.12) : const Color(0xFFF0FDF4); // Green-50
      statusTextColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D); // Green-700
    } else if (lowerStatus == 'in negotiation' || lowerStatus == 'negotiation') {
      statusBg = isDark ? Colors.orange.withValues(alpha: 0.12) : const Color(0xFFFFF7ED); // Orange-50
      statusTextColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C); // Orange-700
    } else if (lowerStatus == 'lost') {
      statusBg = isDark ? Colors.red.withValues(alpha: 0.12) : const Color(0xFFFEF2F2); // Red-50
      statusTextColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C); // Red-700
    } else if (lowerStatus == 'converted') {
      statusBg = isDark ? Colors.teal.withValues(alpha: 0.12) : const Color(0xFFF0FDFA); // Teal-50
      statusTextColor = isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E); // Teal-700
    }

    // Pipeline/Stage colors mapping from original code
    Color pipelineBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100]!;
    Color pipelineTextColor = isDark ? Colors.grey[400]! : Colors.grey[800]!;

    final lowerPipeline = lead.pipeline.toLowerCase();
    if (lowerPipeline == 'hot') {
      pipelineBgColor = isDark ? Colors.red.withValues(alpha: 0.12) : const Color(0xFFFEF2F2);
      pipelineTextColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
    } else if (lowerPipeline == 'warm') {
      pipelineBgColor = isDark ? Colors.orange.withValues(alpha: 0.12) : const Color(0xFFFFF7ED);
      pipelineTextColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
    } else if (lowerPipeline == 'cold') {
      pipelineBgColor = isDark ? Colors.blue.withValues(alpha: 0.12) : const Color(0xFFEFF6FF);
      pipelineTextColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    }

    // Lead Card indicator stripe color & avatar accent color
    Color accentColor = const Color(0xFF2563EB); // Default Blue-600
    if (lowerPipeline == 'hot') {
      accentColor = const Color(0xFFEF4444); // Red-500
    } else if (lowerPipeline == 'warm') {
      accentColor = const Color(0xFFF97316); // Orange-500
    } else if (lowerStatus == 'new') {
      accentColor = const Color(0xFF3B82F6); // Blue-500
    }

    // Initials box colors
    final Color avatarBg = accentColor.withValues(alpha: isDark ? 0.2 : 0.08);
    final Color avatarText = isDark ? accentColor.withValues(alpha: 0.9) : accentColor;

    // Budget display formatting
    final budgetText = (lead.travelBudget != null && lead.travelBudget!.isNotEmpty)
        ? lead.travelBudget!
        : (lead.amount > 0 ? "₹${NumberFormat('#,##,###').format(lead.amount)}" : "No budget");

    // Time calculations
    final updated = DateTimeUtils.parseSafe(lead.updatedAt);
    final timeAgoStr = updated != null ? timeago.format(updated) : "Just now";

    // Permissions for Tasks & Visits
    final hasTaskPermission = permissions.can(
      PermissionModules.TASK,
      permission: PermissionModules.TASKS_VIEW,
      userRole: userRole,
    );

    final hasVisitPermission = permissions.can(
      PermissionModules.VISITS,
      permission: PermissionModules.VISITS_VIEW,
      userRole: userRole,
    );

    final hasTripPermission = permissions.hasModule(PermissionModules.TRIP, userRole: userRole);

    final bool showTravel = hasTripPermission &&
        ((lead.destination != null && lead.destination!.isNotEmpty) ||
            (lead.travelStartDate != null && lead.travelStartDate!.isNotEmpty) ||
            (lead.travelEndDate != null && lead.travelEndDate!.isNotEmpty) ||
            (lead.travelDates != null && lead.travelDates!.isNotEmpty));

    // Next Task/Follow-up detection
    Task? nextTask;
    if (hasTaskPermission && lead.tasks != null && lead.tasks!.isNotEmpty) {
      final now = DateTime.now();
      final pending = lead.tasks!.where((t) {
        final statusLower = t.status.toLowerCase();
        if (statusLower == 'completed' || statusLower == 'done') return false;
        final dueDate = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : null;
        if (dueDate == null) return false;
        return !dueDate.isBefore(now);
      }).toList();

      if (pending.isNotEmpty) {
        pending.sort((a, b) => (a.dueDate ?? "").compareTo(b.dueDate ?? ""));
        nextTask = pending.first;
      }
    }

    // Next Visit detection
    Visit? nextVisit;
    if (nextTask == null && hasVisitPermission && lead.visits != null && lead.visits!.isNotEmpty) {
      final now = DateTime.now();
      final pendingVisits = lead.visits!.where((v) {
        final statusLower = v.status.toLowerCase();
        if (statusLower == 'completed' || statusLower == 'cancelled') return false;
        final visitDate = DateTime.tryParse(v.dateTime);
        if (visitDate == null) return false;
        return !visitDate.isBefore(now);
      }).toList();

      if (pendingVisits.isNotEmpty) {
        pendingVisits.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        nextVisit = pendingVisits.first;
      }
    }

    String followUpDateStr = "";
    if (nextTask != null) {
      try {
        final taskDueDate = nextTask.dueDate != null ? DateTime.parse(nextTask.dueDate!) : null;
        if (taskDueDate != null) {
          followUpDateStr = DateFormat('dd MMM, hh:mm a').format(taskDueDate);
        }
      } catch (_) {}
    }

    String visitDateStr = "";
    if (nextVisit != null) {
      try {
        final visitDateTime = DateTime.tryParse(nextVisit.dateTime);
        if (visitDateTime != null) {
          visitDateStr = DateFormat('dd MMM, hh:mm a').format(visitDateTime);
        }
      } catch (_) {}
    }

    return GestureDetector(
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Status Accent Edge Bar
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Pipeline status indicator badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // 1. Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _toTitleCase(lead.status.isEmpty ? 'New' : lead.status),
                                  style: TextStyle(
                                    color: statusTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // 2. Stage/Pipeline Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: pipelineBgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  lead.pipeline.isNotEmpty ? lead.pipeline : 'Cold',
                                  style: TextStyle(
                                    color: pipelineTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // 3. Sub-assigned Tag (if sub-assigned)
                              if (lead.subAssignees != null && lead.subAssignees!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF6B21A8).withValues(alpha: 0.15) : const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Sub-assigned",
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6B21A8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Lead Selection Checkbox
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: onSelect,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 2: Avatar + Middle Info Column + Right Assignee Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar Initials Circle
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: avatarBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _getInitials(lead.name),
                            style: TextStyle(
                              color: avatarText,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Middle segment Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      lead.name.isNotEmpty ? lead.name : "Unnamed Lead",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isNew) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        "New",
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Phone + Small Whatsapp badge
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    lead.phoneNo.isNotEmpty ? lead.phoneNo : "No Phone",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                  ),
                                  if (lead.phoneNo.isNotEmpty && onNativeWhatsAppPressed != null) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: onNativeWhatsAppPressed,
                                      child: SvgPicture.asset(
                                        'assets/whatapp-ui/whatsapp.svg',
                                        width: 17,
                                        height: 17,
                                        colorFilter: const ColorFilter.mode(Color(0xFF25D366), BlendMode.srcIn),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Source Row
                              Row(
                                children: [
                                  Icon(Icons.ads_click_outlined, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _toTitleCase(lead.source.isNotEmpty ? lead.source : "Organic Source"),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Budget row
                              Row(
                                children: [
                                  Icon(Icons.monetization_on_outlined, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    budgetText,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Right side Assignee Profile info
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (lead.assignedTo != null) ...[
                              Text(
                                "Assigned to",
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  final permissions = ref.read(permissionsProvider);
                                  final user = ref.read(loginProvider).user;
                                  final canAssign = permissions.hasPermission(
                                    PermissionModules.LEADS_ASSIGN,
                                    userRole: user?.systemRole,
                                  );
                                  if (canAssign) {
                                    LeadBulkAssignSheet.show(context, [lead.id]);
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 11,
                                      backgroundColor: accentColor.withValues(alpha: 0.15),
                                      child: Text(
                                        _getInitials(lead.assignedTo!.name),
                                        style: TextStyle(
                                          color: avatarText,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      lead.assignedTo!.name.split(' ').first,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Visibility / View details eye button
                            GestureDetector(
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
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  size: 14,
                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                    const SizedBox(height: 12),

                    // Row 3: Grid Info Row: Project | City | Last Activity
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    showService
                                        ? Icons.build_outlined
                                        : Icons.home_work_outlined,
                                    size: 12,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    showService ? "Service" : "Project",
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                showService
                                    ? ((lead.service != null && lead.service!.name.isNotEmpty)
                                        ? lead.service!.name
                                        : "Not added yet")
                                    : ((lead.project != null && lead.project!.name.isNotEmpty) 
                                        ? lead.project!.name 
                                        : "Not added yet"),
                                style: TextStyle(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    "City",
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (lead.address?.city != null && lead.address!.city.isNotEmpty)
                                    ? lead.address!.city
                                    : (lead.destination != null && lead.destination!.isNotEmpty
                                        ? lead.destination!
                                        : "Not added yet"),
                                style: TextStyle(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time_outlined, size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Last Activity",
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeAgoStr,
                                style: TextStyle(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Travel details banner
                    if (showTravel) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.3) : const Color(0xFFEEF2F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flight_takeoff_outlined,
                              size: 14,
                              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  children: [
                                    if (lead.destination != null && lead.destination!.isNotEmpty) ...[
                                      TextSpan(
                                        text: "Trip to: ",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey[600]),
                                      ),
                                      TextSpan(
                                        text: "${lead.destination!}  ",
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                    if ((lead.travelStartDate != null && lead.travelStartDate!.isNotEmpty) ||
                                        (lead.travelEndDate != null && lead.travelEndDate!.isNotEmpty) ||
                                        (lead.travelDates != null && lead.travelDates!.isNotEmpty)) ...[
                                      TextSpan(
                                        text: (lead.destination != null && lead.destination!.isNotEmpty)
                                            ? "|  Dates: "
                                            : "Dates: ",
                                        style: TextStyle(
                                          fontWeight: (lead.destination != null && lead.destination!.isNotEmpty) ? FontWeight.normal : FontWeight.bold,
                                          color: (lead.destination != null && lead.destination!.isNotEmpty)
                                              ? (isDark ? Colors.white30 : Colors.grey[400])
                                              : (isDark ? Colors.white54 : Colors.grey[600]),
                                        ),
                                      ),
                                      TextSpan(
                                        text: _getTravelDatesStr(lead),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Row 4: Follow-up Status Banner
                    if (nextTask != null || nextVisit != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.15) : const Color(0xFFFFFBEB), // Amber-50 / Amber-900
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    size: 14,
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309), // Amber-700
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      nextTask != null 
                                          ? "Next Follow-up: $followUpDateStr"
                                          : "Next Visit: $visitDateStr",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (nextTask != null)
                              GestureDetector(
                                onTap: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(content: Text("Completing task...")),
                                  );
                                  try {
                                    await ref.read(tasksProvider.notifier).updateTask(nextTask!.id, {'status': 'Completed'});
                                    ref.read(leadsProvider.notifier).refresh();
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(content: Text("Task marked done successfully"), backgroundColor: Colors.green),
                                    );
                                  } catch (e) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(content: Text("Failed to complete task: $e"), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF3B82F6)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check, size: 10, color: Color(0xFF2563EB)),
                                      SizedBox(width: 4),
                                      Text(
                                        "Mark Done",
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (nextVisit != null)
                              GestureDetector(
                                onTap: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(content: Text("Completing visit...")),
                                  );
                                  try {
                                    await ref.read(visitsProvider.notifier).updateVisit(nextVisit!.id, {'status': 'Completed'});
                                    ref.read(leadsProvider.notifier).refresh();
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(content: Text("Visit marked done successfully"), backgroundColor: Colors.green),
                                    );
                                  } catch (e) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(content: Text("Failed to complete visit: $e"), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF3B82F6)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check, size: 10, color: Color(0xFF2563EB)),
                                      SizedBox(width: 4),
                                      Text(
                                        "Mark Done",
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Row 5: Action Button Columns (Call, WhatsApp, More)
                    Row(
                      children: [
                        // 1. Call Button
                        if (onCallPressed != null) ...[
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: onCallPressed,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF), // Soft blue
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.phone_outlined, 
                                      size: 13, 
                                      color: isDark ? Colors.white70 : const Color(0xFF2563EB)
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Call",
                                      style: TextStyle(
                                        fontSize: 11, 
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // 2. CRM Button
                        if (onCrmWhatsAppPressed != null || onNativeWhatsAppPressed != null) ...[
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: onCrmWhatsAppPressed ?? onNativeWhatsAppPressed,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4), // Soft green
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/whatapp-ui/whatsapp.svg',
                                      width: 14,
                                      height: 14,
                                      colorFilter: const ColorFilter.mode(Color(0xFF15803D), BlendMode.srcIn),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "CRM",
                                      style: TextStyle(
                                        fontSize: 11, 
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : const Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // 3. Status Button
                        if (onUpdateStatus != null) ...[
                          Expanded(
                            flex: 4,
                            child: GestureDetector(
                              onTap: onUpdateStatus,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF), // Soft blue
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit_document, 
                                      size: 13, 
                                      color: isDark ? Colors.white70 : const Color(0xFF2563EB)
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Status",
                                      style: TextStyle(
                                        fontSize: 11, 
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // 4. More Button
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () => _showAllActionsBottomSheet(context, ref),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), // Soft slate
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.more_horiz_rounded, 
                                    size: 13, 
                                    color: isDark ? Colors.white70 : const Color(0xFF475569)
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "More",
                                    style: TextStyle(
                                      fontSize: 11, 
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                        title: const Text('Quotation'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onShareQuotation();
                        },
                      ),
                    if (onShareItinerary != null)
                      ListTile(
                        leading: const Icon(Icons.route_outlined, color: Colors.cyan),
                        title: const Text('Itinerary'),
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
                        title: const Text('Voucher'),
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
