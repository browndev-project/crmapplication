import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/whatsapp_provider.dart';
import '../../widgets/global_app_bar.dart';
import 'widgets/whatsapp_icon.dart';
import 'whatsapp_permission_guard.dart';
import '../../providers/login_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../../core/constants/permission_constants.dart';
import 'widgets/whatsapp_create_automation_dialog.dart';
import 'widgets/whatsapp_create_status_dialog.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/constants/whatsapp_constants.dart';
import '../../providers/lead_provider.dart';

class WhatsAppAutomationScreen extends ConsumerStatefulWidget {
  const WhatsAppAutomationScreen({super.key});

  @override
  ConsumerState<WhatsAppAutomationScreen> createState() => _WhatsAppAutomationScreenState();
}

class _WhatsAppAutomationScreenState extends ConsumerState<WhatsAppAutomationScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(whatsappAutomationsProvider.notifier).fetchIncomingLeadsRules();
      ref.read(whatsappAutomationsProvider.notifier).fetchEventRules();
      ref.read(whatsappTemplatesProvider.notifier).fetchTemplates();
    });
  }

  Future<void> _refreshAutomations() async {
    await Future.wait([
      ref.read(whatsappAutomationsProvider.notifier).fetchIncomingLeadsRules(),
      ref.read(whatsappAutomationsProvider.notifier).fetchEventRules(),
      ref.read(whatsappTemplatesProvider.notifier).fetchTemplates(),
    ]);
  }

  /// Returns true if the user can access the given tab index.
  bool _canAccessTab(int index, dynamic permissions, String? userRole) {
    // company_admin always has full access
    if (userRole == 'company_admin' || userRole == 'company') return true;
    switch (index) {
      case 0: // Incoming Leads — needs modules.lead + leads.view
        return permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
               permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole);
      case 1: // Meetings — needs modules.meeting + meetings.view
        return permissions.hasModule(PermissionModules.MEETING, userRole: userRole) &&
               permissions.hasPermission(PermissionModules.MEETINGS_VIEW, userRole: userRole);
      case 2: // Status — needs modules.lead + leads.view
        return permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
               permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole);
      case 3: // Visits — needs modules.visit + visits.view
        return permissions.hasModule(PermissionModules.VISITS, userRole: userRole) &&
               permissions.hasPermission(PermissionModules.VISITS_VIEW, userRole: userRole);
      default:
        return false;
    }
  }

  List<Map<String, dynamic>> _getVisibleTabs(dynamic permissions, String? userRole) {
    final tabs = <Map<String, dynamic>>[];
    if (_canAccessTab(0, permissions, userRole)) tabs.add({'index': 0, 'label': 'Leads', 'icon': Icons.call_received_rounded});
    if (_canAccessTab(1, permissions, userRole)) tabs.add({'index': 1, 'label': 'Meetings', 'icon': Icons.calendar_today_rounded});
    if (_canAccessTab(3, permissions, userRole)) tabs.add({'index': 3, 'label': 'Visits', 'icon': Icons.place_rounded});
    if (_canAccessTab(2, permissions, userRole)) tabs.add({'index': 2, 'label': 'Status', 'icon': Icons.autorenew_rounded});
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final autState = ref.watch(whatsappAutomationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final accessibleTabs = [0, 1, 2, 3]
        .where((i) => _canAccessTab(i, permissions, userRole))
        .toList();
    if (!_canAccessTab(_selectedIndex, permissions, userRole) && accessibleTabs.isNotEmpty) {
      _selectedIndex = accessibleTabs.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

    return WhatsAppPermissionGuard(
      requiredModules: const ['modules.integration', 'modules.whatsapp'],
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: GlobalAppBar(
          title: 'WhatsApp Automation',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 24),
              onPressed: _refreshAutomations,
              tooltip: 'Refresh',
            ),
          ],
        ),

        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            final content = _canAccessTab(_selectedIndex, permissions, userRole)
                ? _buildContentArea(isDark, autState, permissions, userRole)
                : _buildAccessDeniedTab(isDark);

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 250, child: _buildSidebar(isDark, permissions, userRole)),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshAutomations,
                      child: content,
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildMobileCategoryTabs(isDark, permissions, userRole),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshAutomations,
                      child: content,
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Access Denied
  // ---------------------------------------------------------------------------
  Widget _buildAccessDeniedTab(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline_rounded, size: 36, color: isDark ? Colors.grey[400] : Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Text('Access Restricted',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 6),
          Text('You do not have permission to access this section.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Sidebar
  // ---------------------------------------------------------------------------
  Widget _buildSidebar(bool isDark, dynamic permissions, String? userRole) {
    final theme = Theme.of(context);
    return Container(
      color: theme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                whatsAppIcon(size: 24, color: const Color(0xFF25D366)),
                const SizedBox(width: 8),
                Text(
                  "Automation",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "TRIGGERS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_canAccessTab(0, permissions, userRole))
            _buildSidebarItem(0, "Incoming Leads", Icons.call_received_rounded, isDark),
          if (_canAccessTab(1, permissions, userRole))
            _buildSidebarItem(1, "Meetings", Icons.calendar_today_rounded, isDark),
          if (_canAccessTab(3, permissions, userRole))
            _buildSidebarItem(3, "Visits", Icons.place_rounded, isDark),
          if (_canAccessTab(2, permissions, userRole))
            _buildSidebarItem(2, "Status", Icons.autorenew_rounded, isDark),
          const Spacer(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF5A75FA), size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Smart AI Agent",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Let our intelligent automation handle your routine customer responses securely in the background.",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.5),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, String title, IconData icon, bool isDark, {bool isMobile = false}) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.grey[800]! : Colors.grey[100]!)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black87 : const Color(0xFF6B7280)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.black87 : theme.textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                   color: Colors.black87,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile Category Tabs (Home Screen pattern)
  // ---------------------------------------------------------------------------
  Widget _buildMobileCategoryTabs(bool isDark, dynamic permissions, String? userRole) {
    final tabs = _getVisibleTabs(permissions, userRole);
    if (tabs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    const indicatorWidth = 24.0;
    const indicatorHeight = 3.0;

    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          final clampedIdx = tabs.indexWhere((t) => t['index'] == _selectedIndex);
          final safeIdx = clampedIdx == -1 ? 0 : clampedIdx;

          return Stack(
            children: [
              Row(
                children: tabs.map((tab) {
                  final isSelected = tab['index'] == _selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedIndex = tab['index'] as int),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab['icon'] as IconData,
                            size: 22,
                            color: isSelected
                                ? Colors.black87
                                : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            tab['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.black87
                                  : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                bottom: 0,
                left: safeIdx * tabWidth + (tabWidth - indicatorWidth) / 2,
                width: indicatorWidth,
                height: indicatorHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Content Area
  // ---------------------------------------------------------------------------
  Widget _buildContentArea(bool isDark, dynamic autState, dynamic permissions, String? userRole) {
    String header = "";
    String sub = "";
    IconData headerIcon = Icons.settings_rounded;
    List<Map<String, dynamic>> rules = [];

    if (_selectedIndex == 0) {
      header = "Incoming Leads";
      sub = "Manage automated replies for incoming leads.";
      headerIcon = Icons.call_received_rounded;
      rules = autState.incomingLeadsRules;
    } else if (_selectedIndex == 1) {
      header = "Meetings";
      sub = "Sends when \"Send on WhatsApp\" is checked and automation is active.";
      headerIcon = Icons.calendar_today_rounded;
      rules = autState.eventRules.where((r) => (r['eventType'] as String).startsWith('MEETING_')).toList();
    } else if (_selectedIndex == 3) {
      header = "Visits";
      sub = "Sends when visit events occur.";
      headerIcon = Icons.place_rounded;
      rules = autState.eventRules.where((r) => (r['eventType'] as String).startsWith('VISIT_')).toList();
    } else if (_selectedIndex == 2) {
      header = "Status Triggers";
      sub = "Fires when lead statuses change.";
      headerIcon = Icons.autorenew_rounded;
      rules = autState.eventRules.where((r) => r['eventType'] == 'LEAD_STATUS_CHANGED').toList();
    }

    return Container(
      color: isDark ? const Color(0xFF12141D) : const Color(0xFFF5F6F8),
      child: CustomScrollView(
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black87.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(headerIcon, color: Colors.black87, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(header, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            if (rules.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${rules.length}',
                                   style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildCreateButton(isDark),
                ],
              ),
            ),
          ),
          // Rule list or empty state
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: rules.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState(isDark))
                : SliverList.separated(
                    itemCount: rules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildRuleCard(rules[index], isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(bool isDark) {
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_selectedIndex == 0) {
            showDialog(context: context, builder: (c) => const CreateAutomationDialog(triggerMode: 'lead'));
          } else if (_selectedIndex == 1) {
            showDialog(context: context, builder: (c) => const CreateAutomationDialog(triggerMode: 'meeting'));
          } else if (_selectedIndex == 3) {
            showDialog(context: context, builder: (c) => const CreateAutomationDialog(triggerMode: 'visit'));
          } else if (_selectedIndex == 2) {
            showDialog(context: context, builder: (c) => const CreateStatusAutomationDialog());
          }
        },
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(bool isDark) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedIndex == 2 ? Icons.autorenew_rounded : Icons.rocket_launch_rounded,
              size: 32,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedIndex == 2 ? "No status triggers yet" : "No automations yet",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedIndex == 2
                ? "Create a status trigger to auto-send messages when lead statuses change."
                : "Create your first automation to start sending messages automatically.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_selectedIndex == 2) {
                  showDialog(context: context, builder: (c) => const CreateStatusAutomationDialog());
                } else {
                  final mode = _selectedIndex == 1 ? 'meeting' : (_selectedIndex == 3 ? 'visit' : 'lead');
                  showDialog(context: context, builder: (c) => CreateAutomationDialog(triggerMode: mode));
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Create Automation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule, bool isDark) {
    final theme = Theme.of(context);
    final String id = rule['_id'] ?? rule['id'] ?? '';
    final String name = rule['name'] ?? 'Untitled Rule';
    final bool isActive = rule['isActive'] ?? false;
    final template = rule['template'] as Map?;
    final String tempName = template?['name'] ?? 'Unknown Template';
    final int mappingsCount = (rule['variableMappings'] as List?)?.length ?? 0;

    // Date formatting using DateTimeUtils
    final createdDateStr = rule['createdAt'] != null
        ? "Created on ${DateTimeUtils.formatSafe(rule['createdAt'], format: 'dd MMM yyyy, hh:mm a')}"
        : "Created recently";

    return GestureDetector(
      onTap: () => _showRuleDetails(rule, isDark),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row: WhatsApp Icon & Name & Created Date
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2B22) : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: whatsAppIcon(size: 22, color: const Color(0xFF25D366)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          createdDateStr,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Active/Inactive Toggle Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark ? const Color(0xFF1B2E1C) : Colors.white)
                      : (isDark ? const Color(0xFF1F222F) : const Color(0xFFF5F5F5)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF25D366)
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isActive ? "ACTIVE" : "INACTIVE",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? const Color(0xFF25D366)
                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: isActive,
                        activeThumbColor: const Color(0xFF25D366),
                        activeTrackColor: const Color(0xFF25D366).withValues(alpha: 0.2),
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade200,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) {
                          if (_selectedIndex == 0) {
                            ref.read(whatsappAutomationsProvider.notifier).toggleIncomingLeadsRule(id);
                          } else {
                            ref.read(whatsappAutomationsProvider.notifier).toggleEventRule(id, val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nested Card 1: Lead Sources or Event
              if (_selectedIndex == 0) ...[
                _buildNestedBox(
                  icon: Icons.account_tree_outlined,
                  label: 'LEAD SOURCES',
                  isDark: isDark,
                  child: _buildSourceChipsWrap(rule['leadSources'] as List? ?? ['All'], isDark),
                ),
                const SizedBox(height: 12),
                _buildNestedBox(
                  icon: Icons.description_outlined,
                  label: 'FORM OVERRIDES',
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(rule['formOverrides'] as List?)?.length ?? 0} Override${(rule['formOverrides'] as List?)?.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Form-specific template configurations',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ] else if (_selectedIndex == 2) ...[
                _buildNestedBox(
                  icon: Icons.bolt_outlined,
                  label: 'TARGET STATUS',
                  isDark: isDark,
                  child: Text(
                    toTitleCase(_getStatusName(rule['targetStatus'] as String?)),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ] else ...[
                _buildNestedBox(
                  icon: Icons.bolt_outlined,
                  label: 'EVENT TYPE',
                  isDark: isDark,
                  child: Text(
                    _formatEventType(rule['eventType'] ?? ''),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Nested Card 2: Template
              _buildNestedBox(
                icon: Icons.article_outlined,
                label: 'TEMPLATE',
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tempName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.public_outlined, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          template?['language'] ?? 'en_US',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Nested Card 3: Mappings
              _buildNestedBox(
                icon: Icons.tag,
                label: 'MAPPINGS',
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$mappingsCount Variable${mappingsCount == 1 ? "" : "s"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Source-mapped dynamic data',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons Row: Edit, Delete
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: isDark ? Colors.grey[400] : Colors.grey[700], size: 20),
                    onPressed: () {
                      if (_selectedIndex == 2) {
                        showDialog(context: context, builder: (_) => CreateStatusAutomationDialog(editRule: rule));
                      } else {
                        showDialog(
                          context: context,
                          builder: (_) => CreateAutomationDialog(
                            triggerMode: _selectedIndex == 1 ? 'meeting' : (_selectedIndex == 3 ? 'visit' : 'lead'),
                            editRule: rule,
                          ),
                        );
                      }
                    },
                    tooltip: 'Edit',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_rounded, color: isDark ? Colors.grey[400] : Colors.grey[700], size: 20),
                    onPressed: () => _showDeleteConfirmation(id, isDark),
                    tooltip: 'Delete',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNestedBox({
    required IconData icon,
    required String label,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildSourceChipsWrap(List items, bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
        child: Text(
          e.toString(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
      )).toList(),
    );
  }

  String _formatEventType(String type) {
    switch (type) {
      case 'VISIT_CREATED':
        return 'Visit Created';
      case 'VISIT_RESCHEDULED':
        return 'Visit Rescheduled';
      case 'VISIT_CANCELLED':
        return 'Visit Cancelled';
      case 'VISIT_COMPLETED':
        return 'Visit Completed';
      case 'VISIT_REMINDER_DAY_BEFORE':
        return 'Day Before Reminder (8:00 PM)';
      case 'VISIT_REMINDER_MORNING':
        return 'Visit Day Reminder (9:30 AM)';
      case 'VISIT_REMINDER_1_HOUR':
        return 'Reminder 1 Hour Before Visit';
      default:
        return type.replaceAll('_', ' ').toLowerCase().split(' ').map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        }).join(' ');
    }
  }

  // Returns the human‑readable status name for a given status ID.
  // Falls back to the raw ID if the status cannot be found.
  String _getStatusName(String? id) {
    if (id == null) return 'Unknown Status';
    final statuses = ref.watch(leadStatusProvider).statuses;
    for (final s in statuses) {
      if (s.id == id) {
        return s.name;
      }
    }
    return id; // fallback to raw id if not found
  }


  void _showRuleDetails(Map<String, dynamic> rule, bool isDark) {
    final theme = Theme.of(context);
    final String name = rule['name'] ?? 'Untitled Rule';
    final bool isActive = rule['isActive'] ?? false;
    final template = rule['template'] as Map?;
    final String tempName = template?['name'] ?? 'Unknown Template';
    final String tempLang = template?['language'] ?? 'en';
    final String eventType = rule['eventType'] ?? '';
    final List sources = rule['leadSources'] as List? ?? [];
    final List mappings = rule['variableMappings'] as List? ?? [];
    final String createdAt = rule['createdAt'] != null
        ? DateTimeUtils.formatSafe(rule['createdAt'], format: 'dd MMM yyyy, hh:mm a')
        : 'N/A';
    final String updatedAt = rule['updatedAt'] != null
        ? DateTimeUtils.formatSafe(rule['updatedAt'], format: 'dd MMM yyyy, hh:mm a')
        : 'N/A';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.cardColor,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2B22) : const Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: whatsAppIcon(size: 18, color: const Color(0xFF25D366)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green
                                        : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[850]
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? Colors.grey[800]!
                              : Colors.grey[200]!),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Created', createdAt, isDark),
                        _buildDetailRow('Updated', updatedAt, isDark),
                        const SizedBox(height: 12),
                        Divider(
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        if (_selectedIndex == 0 && sources.isNotEmpty) ...[
                          _buildDetailLabel('Lead Sources', isDark),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: sources
                                .map((s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[700]
                                            : Colors.grey[200],
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(s.toString(),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.grey[300]
                                                  : Colors.grey[700],
                                              fontWeight:
                                                  FontWeight.w500)),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_selectedIndex != 0 && eventType.isNotEmpty)
_buildDetailRow(
                               _selectedIndex == 2 ? 'Target Status' : 'Event Type',
                               _selectedIndex == 2
                                   ? toTitleCase(_getStatusName(rule['targetStatus'] as String?))
                                   : _formatEventType(eventType),
                               isDark),
                        if (_selectedIndex != 0) const SizedBox(height: 12),
                        _buildDetailLabel('Template', isDark),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.article_rounded,
                                  size: 16,
                                  color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(tempName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[200],
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(tempLang,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[600],
                                        fontWeight:
                                            FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                        if (mappings.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildDetailLabel(
                              'Variable Mappings (${mappings.length})',
                              isDark),
                          const SizedBox(height: 6),
                          ...mappings.map((m) {
                            final map = m is Map ? m : {};
                            final key = map['key'] ?? '';
                            final source = map['source'] ?? '';
                            final customValue = map['customValue'] ?? '';
                            
                            final varName = '{{$key}}';
                            final mappedTo = source == 'custom' 
                                ? 'Custom: "$customValue"' 
                                : WhatsAppVariableSources.getLabelForValue(source.toString());
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.data_object_rounded,
                                      size: 12,
                                      color:
                                          Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                        varName,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors
                                                .grey.shade600)),
                                  ),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 12,
                                      color:
                                          Colors.grey.shade400),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                        mappedTo,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w500),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white
                            : Colors.black87,
                        side: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLabel(String text, bool isDark) {
    return Text(text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500));
  }

  void _showDeleteConfirmation(String id, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Automation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this automation rule?', style: TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_selectedIndex == 0) {
                ref.read(whatsappAutomationsProvider.notifier).deleteIncomingLeadsRule(id);
              } else {
                ref.read(whatsappAutomationsProvider.notifier).deleteEventRule(id);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
