import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/reminder_action_widget.dart';
import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../../data/models/dashboard_model.dart';
import '../providers/task_provider.dart';
import '../providers/lead_provider.dart';
import '../widgets/task_create_dialog.dart';
import '../providers/meeting_provider.dart';
import '../providers/visit_provider.dart';
import 'package:hive/hive.dart';
import '../widgets/custom_permission_dialog.dart';
import '../widgets/access_denied_widget.dart';
import '../providers/navigation_provider.dart';
import '../../core/utils/date_utils.dart';

// Navigation targets

import 'lead_profile_screen.dart';

// Services


// Models
import '../../data/models/lead_model.dart';
import '../../data/models/status_model.dart';
import '../../data/models/visit_model.dart';
import '../../data/models/meeting_model.dart' as mm;
import '../../data/models/task_model.dart' as tm;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunchPermissions();
    });
  }

  Future<void> _checkFirstLaunchPermissions() async {
    final box = await Hive.openBox('settingsBox');
    final bool dialogShown = box.get('permissions_dialog_shown', defaultValue: false);

    if (!dialogShown) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const CustomPermissionDialog(),
        );
        await box.put('permissions_dialog_shown', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final user = ref.watch(loginProvider).user;
    final isSalesExecutive = user?.systemRole == 'sales_executive';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: GlobalAppBar(
        title: 'Dashboard',
        actions: [
          if (isSalesExecutive) ...[
            const ReminderActionWidget(),
            //const AttendanceActionWidget(),
          ]
        ],
      ),
      body: const DashboardTab(),
    );
  }
}



class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  
  DateTime? _startDate;
  DateTime? _endDate;
  int _teamCallTab = 0; // 0=Total, 1=Incoming, 2=Outgoing
  int _teamCallTopN = 15; // -1 for Show All
  String _selectedTeamRole = 'All Roles';
  int _touchedIndex = -1;

  // Redesign state
  int _selectedCategoryTab = 0;
  
// Quick tab items
   List<Lead>? _newLeads;
  List<tm.Task>? _upcomingTasks;
  List<Map<String, dynamic>>? _upcomingMeetings;
  List<Map<String, dynamic>>? _upcomingVisits;
  List<Lead>? _unassignedLeads;
  List<Lead>? _convertedLeadsList;
  bool _isLoadingQuickData = false;
  String? _quickDataError;
  String? _newStatusId;
  String? _convertedStatusId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final user = ref.read(loginProvider).user;
       final isAdmin = user?.systemRole == 'company_admin';
       final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;

       ref.read(dashboardProvider.notifier).fetchDashboardData(
         isAdmin: isAdmin,
         assignedTo: assignedTo,
       );
       ref.read(tasksProvider.notifier).refresh();
       _fetchQuickData(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refresh() async {
    final user = ref.read(loginProvider).user;
    final isAdmin = user?.systemRole == 'company_admin';
    final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;

    await Future.wait<void>([
        ref.read(dashboardProvider.notifier).fetchDashboardData(
            forceRefresh: true, 
            isAdmin: isAdmin,
            assignedTo: assignedTo,
            startDate: _startDate,
            endDate: _endDate,
        ),
        ref.read(tasksProvider.notifier).refresh(),
        _fetchQuickData(forceRefresh: true),
    ]);
  }

  Future<void> _fetchQuickData({bool forceRefresh = false}) async {
    if (!forceRefresh && _newLeads != null && _upcomingTasks != null) return;
    if (_isLoadingQuickData) return;
    if (mounted) {
      setState(() {
        _isLoadingQuickData = true;
        _quickDataError = null;
      });
    }

    try {
      // Phase 1: get status IDs (needed for lead filters)
      await ref.read(leadStatusProvider.notifier).fetchStatuses();
      final statuses = ref.read(leadStatusProvider).statuses;
      final newStatus = statuses.firstWhere(
        (s) => s.name.toLowerCase() == 'new',
        orElse: () => LeadStatus(id: '', name: 'New', color: '', backgroundColor: '', isActive: true),
      );
      final convertedStatus = statuses.firstWhere(
        (s) => s.name.toLowerCase() == 'converted',
        orElse: () => LeadStatus(id: '', name: 'Converted', color: '', backgroundColor: '', isActive: true),
      );
      _newStatusId = newStatus.id;
      _convertedStatusId = convertedStatus.id;

      final user = ref.read(loginProvider).user;
      final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;

      final leadService = ref.read(leadServiceProvider);
      final taskService = ref.read(taskServiceProvider);
      final meetingService = ref.read(meetingServiceProvider);
      final visitService = ref.read(visitServiceProvider);

      Future<T?> safeFetch<T>(Future<T> future) async {
        try {
          return await future;
        } catch (e) {
          debugPrint("Dashboard Quick Fetch Error: $e");
          return null;
        }
      }

      final results = await Future.wait([
        safeFetch(leadService.fetchLeads(page: 1, limit: 10, status: newStatus.id.isNotEmpty ? newStatus.id : 'New')),
        safeFetch(taskService.fetchTasks(page: 1, limit: 100)),
        safeFetch(meetingService.fetchMeetings(page: 1, limit: 50, assignedTo: assignedTo)),
        safeFetch(visitService.fetchVisits(page: 1, limit: 50, assignedTo: assignedTo)),
        safeFetch(leadService.fetchLeads(page: 1, limit: 50)),
        safeFetch(leadService.fetchLeads(page: 1, limit: 10, status: convertedStatus.id.isNotEmpty ? convertedStatus.id : 'Converted')),
      ]);

      final newLeadsResponse = results[0] as LeadsResponse?;
      final tasksResponse = results[1] as tm.TaskData?;
      final meetingsResponse = results[2] as mm.MeetingsResponse?;
      final visitsResponse = results[3] as VisitsResponse?;
      final allLeadsResponse = results[4] as LeadsResponse?;
      final convertedLeadsResponse = results[5] as LeadsResponse?;

      final upcomingTasks = tasksResponse != null
          ? tasksResponse.tasks
              .where((t) {
                if (t.status == 'Completed' || t.status == 'Done') return false;
                final dt = DateTimeUtils.parseSafe(t.dueDate);
                return dt != null && dt.isAfter(DateTime.now());
              })
              .take(5)
              .toList()
          : <tm.Task>[];

      final List<Map<String, dynamic>> meetingsList = [];
      final List<Map<String, dynamic>> visitsList = [];
      final now = DateTime.now();
      
      if (meetingsResponse != null) {
        for (var m in meetingsResponse.meetings) {
          final statusLower = m.status.toLowerCase();
          if (statusLower != 'completed' && statusLower != 'done' && statusLower != 'cancelled') {
            final dt = DateTimeUtils.parseSafe(m.scheduledAt);
            if (dt != null && dt.isAfter(now)) {
              meetingsList.add({
                'type': 'meeting',
                'id': m.id,
                'title': m.subject,
                'description': m.description,
                'status': m.status,
                'dateTime': dt,
                'raw': m,
              });
            }
          }
        }
      }
      
      if (visitsResponse != null) {
        for (var v in visitsResponse.visits) {
          final statusLower = v.status.toLowerCase();
          if (statusLower != 'completed' && statusLower != 'done' && statusLower != 'cancelled') {
            final dt = DateTimeUtils.parseSafe(v.dateTime);
            if (dt != null && dt.isAfter(now)) {
              visitsList.add({
                'type': 'visit',
                'id': v.id,
                'title': 'Site Visit - ${v.project?.name ?? "No Project"}',
                'description': v.description,
                'status': v.status,
                'dateTime': dt,
                'raw': v,
              });
            }
          }
        }
      }
      
      meetingsList.sort((a, b) => (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));
      visitsList.sort((a, b) => (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

      final unassignedLeads = allLeadsResponse != null
          ? allLeadsResponse.leads.where((l) => l.assignedTo == null).toList()
          : <Lead>[];

      if (mounted) {
        setState(() {
          _newLeads = newLeadsResponse?.leads.take(5).toList();
          _upcomingTasks = upcomingTasks;
          _upcomingMeetings = meetingsList.take(5).toList();
          _upcomingVisits = visitsList.take(5).toList();
          _unassignedLeads = unassignedLeads;
          _convertedLeadsList = convertedLeadsResponse?.leads;
          _isLoadingQuickData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _quickDataError = e.toString();
          _isLoadingQuickData = false;
        });
      }
    }
  }



  Widget _buildDateFilterButton(BuildContext context, String label, DateTime? selectedDate, Function(DateTime) onSelect) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onSelect(picked);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            selectedDate != null ? "${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}" : label,
            style: TextStyle(color: selectedDate != null ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).hintColor),
          ),
          Icon(Icons.calendar_today_outlined, size: 18, color: Theme.of(context).iconTheme.color?.withValues(alpha:0.6))
        ],
      ),
    );
  }



  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'bulk upload': return Colors.cyan;
      case 'website': return Colors.deepPurpleAccent;
      case 'manual upload': return Colors.orange;
      case 'whatsapp': return Colors.red;
      case 'meta ads': return Colors.green;
      case 'google ads': return Colors.blueGrey;
      case 'magicbricks': return Colors.indigo;
      case 'justdial': return Colors.blue;
      case '99acres': return Colors.teal;
      default: return Colors.primaries[source.length % Colors.primaries.length];
    }
  }

  /// Builds the list of visible category tabs based on permissions.
  List<Map<String, dynamic>> _getVisibleCategories() {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    final hasLeadsAccess = permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole);
    final hasReportsAccess = permissions.hasModule(PermissionModules.REPORTS_BASE, userRole: userRole);

    final List<Map<String, dynamic>> categories = [
      {'name': 'Quick', 'icon': Icons.bolt_rounded}, // Always visible
    ];
    if (hasReportsAccess) {
      categories.add({'name': 'Stats', 'icon': Icons.bar_chart_rounded});
    }
    if (hasLeadsAccess) {
      categories.add({'name': 'Sources', 'icon': Icons.flag_rounded});
    }
    if (hasReportsAccess) {
      categories.add({'name': 'Calls', 'icon': Icons.call_rounded});
    }
    return categories;
  }

  Widget _buildAnimatedCategoryTabs() {
    final categories = _getVisibleCategories();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const indicatorWidth = 24.0;
    const indicatorHeight = 3.0;

    // Clamp the selected index to valid range for the filtered list
    final clampedTab = _selectedCategoryTab.clamp(0, categories.length - 1);

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / categories.length;
          return Stack(
            children: [
              Row(
                children: categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cat = entry.value;
                  final isSelected = clampedTab == index;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryTab = index;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 22,
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black87)
                                : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat['name'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 6),
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
                left: clampedTab * tabWidth + (tabWidth - indicatorWidth) / 2,
                width: indicatorWidth,
                height: indicatorHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black87,
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

  Widget _buildQuickSkeleton(bool isDark) {
    const items = 3;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(items, (section) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 100, height: 14, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                    Container(width: 60, height: 14, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(3, (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    ),
                  ),
                )),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQuickSectionHeader({
    required String title,
    required int count,
    String? badgeText,
    Color? badgeColor,
    IconData? icon,
    Color? iconColor,
    required VoidCallback onViewMore,
    VoidCallback? onCreateTask,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (badgeText != null && badgeColor != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (icon != null && iconColor != null)
                  Icon(icon, color: iconColor, size: 22),
                  
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              if (onCreateTask != null)
                IconButton(
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF1976D2)),
                  onPressed: onCreateTask,
                ),
              InkWell(
                onTap: onViewMore,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'View More',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLeadCard(Lead lead, bool isDark) {
    final theme = Theme.of(context);
    final serviceName = lead.service?.name ?? 'No Service Interest';
    final timeStr = DateTime.tryParse(lead.createdAt) != null
        ? timeago.format(DateTime.parse(lead.createdAt))
        : '';
        
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeadProfileScreen(
              leadId: lead.id,
              name: lead.name,
              phone: lead.phoneNo,
              details: lead.email.isNotEmpty ? lead.email : serviceName,
            ),
          ),
        ).then((_) => _fetchQuickData(forceRefresh: true));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: isDark ? Colors.grey[400]! : Colors.black87, width: 4.0),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lead.phoneNo,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (timeStr.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 10, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else const SizedBox(height: 18),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        serviceName,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _buildQuickTaskCard(tm.Task task, bool isDark) {
    final theme = Theme.of(context);
    String dueStr = 'No due date';
    final dueDate = DateTimeUtils.parseSafe(task.dueDate);
    if (dueDate != null) {
      final diff = dueDate.difference(DateTime.now());
      if (diff.isNegative) {
        dueStr = 'Overdue';
      } else {
        if (diff.inDays > 0) {
          final hours = diff.inHours % 24;
          dueStr = '${diff.inDays} Day${diff.inDays > 1 ? "s" : ""} ${hours > 0 ? "$hours Hr${hours > 1 ? "s" : ""} " : ""}Left';
        } else if (diff.inHours > 0) {
          dueStr = '${diff.inHours} Hour${diff.inHours > 1 ? "s" : ""} Left';
        } else if (diff.inMinutes > 0) {
          dueStr = '${diff.inMinutes} Min Left';
        } else {
          dueStr = 'Due now';
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: isDark ? Colors.grey[500]! : Colors.grey[700]!, width: 4.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.assignment_rounded, 
                    color: isDark ? Colors.white : Colors.black87,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.description ?? 'No description',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontSize: 11.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 10, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        const SizedBox(width: 4),
Text(
                         dueStr,
                           style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      task.status,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (task.lead != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LeadProfileScreen(
                              leadId: task.lead!.id,
                              name: task.lead!.name,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.visibility_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMeetingVisitCard(Map<String, dynamic> item, bool isDark) {
    final theme = Theme.of(context);
    final type = item['type'] as String;
    final isMeeting = type == 'meeting';
    final title = item['title'] as String;
    final desc = item['description'] as String? ?? 'No details provided';
    final dt = item['dateTime'] as DateTime;
    final status = item['status'] as String? ?? (isMeeting ? 'Meeting' : 'Site Visit');
    
    String dueStr = 'No due date';
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) {
      dueStr = 'Overdue';
    } else {
      if (diff.inDays > 0) {
        final hours = diff.inHours % 24;
        dueStr = '${diff.inDays} Day${diff.inDays > 1 ? "s" : ""} ${hours > 0 ? "$hours Hr${hours > 1 ? "s" : ""} " : ""}Left';
      } else if (diff.inHours > 0) {
        dueStr = '${diff.inHours} Hour${diff.inHours > 1 ? "s" : ""} Left';
      } else if (diff.inMinutes > 0) {
        dueStr = '${diff.inMinutes} Min Left';
      } else {
        dueStr = 'Due now';
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: isDark ? Colors.grey[400]! : Colors.black87, width: 4.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isMeeting ? Icons.videocam_rounded : Icons.location_on_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 10, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(
                          dueStr,
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (item['raw']?.lead != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        final leadData = item['raw'].lead;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LeadProfileScreen(
                              leadId: leadData.id,
                              name: leadData.name,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.visibility_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingQuickData && _newLeads == null) {
      return _buildQuickSkeleton(isDark);
    }
    
    if (_quickDataError != null && _newLeads == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load quick feeds',
                style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
              ),
              const SizedBox(height: 4),
              Text(
                _quickDataError!,
                style: TextStyle(color: theme.hintColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchQuickData(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Permission checks for Quick Tab sections
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;
    final hasLeadsAccess = permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole);
    final hasTasksAccess = permissions.hasModule(PermissionModules.TASK, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.TASKS_VIEW, userRole: userRole);
    final hasMeetingsAccess = permissions.hasModule(PermissionModules.MEETING, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.MEETINGS_VIEW, userRole: userRole);
    final hasVisitsAccess = permissions.hasModule(PermissionModules.VISITS, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.VISITS_VIEW, userRole: userRole);

    final List<Widget> sections = [];

    // New Leads — gated by LEADS_VIEW
    if (hasLeadsAccess) {
      sections.addAll([
        _buildQuickSectionHeader(
          title: 'New Leads',
          count: _newLeads?.length ?? 0,
          badgeText: 'NEW',
          badgeColor: isDark ? Colors.white24 : Colors.black87,
          onViewMore: () {
            ref.read(leadsProvider.notifier).applyFilters({
              'sort': 'updated_desc',
              'status': _newStatusId != null && _newStatusId!.isNotEmpty ? _newStatusId! : 'New',
            });
            ref.read(currentRouteProvider.notifier).state = 'Leads';
          },
        ),
        const SizedBox(height: 8),
if (_newLeads == null || _newLeads!.isEmpty)
           _buildQuickEmptyState('No new leads found')
         else
           ..._newLeads!.map((lead) => _buildQuickLeadCard(lead, isDark)),
        const SizedBox(height: 24),
      ]);
    }

    // Upcoming Tasks — gated by TASKS_VIEW
    if (hasTasksAccess) {
      sections.addAll([
        _buildQuickSectionHeader(
          title: 'Upcoming Tasks',
          count: _upcomingTasks?.length ?? 0,
          icon: Icons.check_circle_outline_rounded,
          iconColor: isDark ? Colors.grey[400] : Colors.black87,
          onViewMore: () {
            ref.read(currentRouteProvider.notifier).state = 'Tasks';
          },
          onCreateTask: () {
            _showCreateTaskDialog();
          },
        ),
        const SizedBox(height: 8),
        if (_upcomingTasks == null || _upcomingTasks!.isEmpty)
          _buildQuickEmptyState('No upcoming tasks')
        else
          ..._upcomingTasks!.map((task) => _buildQuickTaskCard(task, isDark)),
        const SizedBox(height: 24),
      ]);
    }

    // Upcoming Meetings — gated by MEETINGS_VIEW
    if (hasMeetingsAccess) {
      sections.addAll([
        _buildQuickSectionHeader(
          title: 'Upcoming Meetings',
          count: _upcomingMeetings?.length ?? 0,
          icon: Icons.videocam_rounded,
          iconColor: isDark ? Colors.grey[400] : Colors.black87,
          onViewMore: () {
            ref.read(currentRouteProvider.notifier).state = 'Meetings';
          },
        ),
        const SizedBox(height: 8),
        if (_upcomingMeetings == null || _upcomingMeetings!.isEmpty)
          _buildQuickEmptyState('No upcoming meetings')
        else
          ..._upcomingMeetings!.map((item) => _buildQuickMeetingVisitCard(item, isDark)),
        const SizedBox(height: 24),
      ]);
    }

    // Upcoming Visits — gated by VISITS_VIEW
    if (hasVisitsAccess) {
      sections.addAll([
        _buildQuickSectionHeader(
          title: 'Upcoming Visits',
          count: _upcomingVisits?.length ?? 0,
          icon: Icons.location_on_rounded,
          iconColor: isDark ? Colors.grey[400] : Colors.black87,
          onViewMore: () {
            ref.read(currentRouteProvider.notifier).state = 'Visits';
          },
        ),
        const SizedBox(height: 8),
        if (_upcomingVisits == null || _upcomingVisits!.isEmpty)
          _buildQuickEmptyState('No upcoming visits')
        else
          ..._upcomingVisits!.map((item) => _buildQuickMeetingVisitCard(item, isDark)),
        const SizedBox(height: 24),
      ]);
    }

    // Unassigned Leads — gated by LEADS_VIEW
    if (hasLeadsAccess) {
      sections.addAll([
        _buildQuickSectionHeader(
          title: 'Unassigned Leads',
          count: _unassignedLeads?.length ?? 0,
          icon: Icons.person_off_rounded,
          iconColor: isDark ? Colors.grey[400] : Colors.black87,
          onViewMore: () {
            ref.read(leadsProvider.notifier).applyFilters({
              'sort': 'updated_desc',
              'assignedTo': '',
            });
            ref.read(currentRouteProvider.notifier).state = 'Leads';
          },
        ),
        const SizedBox(height: 8),
        if (_unassignedLeads == null || _unassignedLeads!.isEmpty)
          _buildQuickEmptyState('No unassigned leads')
        else
          ..._unassignedLeads!.take(5).map((lead) => _buildQuickLeadCard(lead, isDark)),
        const SizedBox(height: 24),
      ]);
    }

    if (sections.isEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text('No sections available', style: TextStyle(color: theme.hintColor)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections,
        SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
      ],
    );
  }

  Widget buildConvertedTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingQuickData && _convertedLeadsList == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF27C16B)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickSectionHeader(
          title: 'Converted Leads',
          count: _convertedLeadsList?.length ?? 0,
          icon: Icons.check_circle_rounded,
          iconColor: Colors.green,
          onViewMore: () {
            ref.read(leadsProvider.notifier).applyFilters({
              'sort': 'updated_desc',
              'status': _convertedStatusId != null && _convertedStatusId!.isNotEmpty ? _convertedStatusId! : 'Converted',
            });
            ref.read(currentRouteProvider.notifier).state = 'Leads';
          },
        ),
        const SizedBox(height: 8),
        if (_convertedLeadsList == null || _convertedLeadsList!.isEmpty)
          _buildQuickEmptyState('No converted leads found')
        else
          ..._convertedLeadsList!.map((lead) => _buildQuickLeadCard(lead, isDark)),
      ],
    );
  }

  Widget _buildStatsTab(bool hasTasksAccess, bool hasMeetingsAccess, bool hasVisitsAccess, bool hasLeadsAccess, bool isAdmin, int tasksDue, int meetingsDue, int totalLeads, int assigned, int unassigned, TodayVisitsStats? visitsStats, BoxConstraints constraints, dynamic statusCounts, int hotLeads, int warmLeads, int coldLeads,) {
    final totalPipeline = hotLeads + warmLeads + coldLeads;
    final hotProgress = totalPipeline > 0 ? hotLeads / totalPipeline : 0.0;
    final warmProgress = totalPipeline > 0 ? warmLeads / totalPipeline : 0.0;
    final coldProgress = totalPipeline > 0 ? coldLeads / totalPipeline : 0.0;

    final Map<String, int> castedStatusCounts = (statusCounts is Map) 
        ? Map<String, int>.from(statusCounts) 
        : {};
    final List<MapEntry<String, int>> sortedStatusEntries = castedStatusCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          padding: EdgeInsets.zero,
          childAspectRatio: 1.6,
          children: [
            if (hasTasksAccess)
              DashboardStatsCard(
                title: 'Tasks Due Today',
                value: '$tasksDue',
                icon: Icons.assignment_outlined,
                backgroundColor: const Color(0xFF03A9F4),
                gradientColors: [const Color(0xFF03A9F4), const Color(0xFF039BE5)],
              ),
            if (hasMeetingsAccess)
              DashboardStatsCard(
                title: 'Meetings Today',
                value: '$meetingsDue',
                icon: Icons.calendar_today_outlined,
                backgroundColor: const Color(0xFF9C27B0),
                gradientColors: [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
              ),
            if (hasVisitsAccess)
              DashboardStatsCard(
                title: 'Visits Today',
                value: '${visitsStats?.totalVisits ?? 0}',
                icon: Icons.location_on_outlined,
                backgroundColor: const Color(0xFF7E57C2),
                gradientColors: [const Color(0xFF7E57C2), const Color(0xFF5E35B1)],
              ),
            if (hasLeadsAccess)
              DashboardStatsCard(
                title: 'Total Leads',
                value: '$totalLeads',
                icon: Icons.analytics_rounded,
                backgroundColor: const Color(0xFF009688),
                gradientColors: [const Color(0xFF009688), const Color(0xFF00796B)],
              ),
            if (isAdmin && hasLeadsAccess)
              DashboardStatsCard(
                title: 'Assigned / Unassigned',
                value: '$assigned/$unassigned',
                icon: Icons.group_rounded,
                backgroundColor: const Color(0xFF00C853),
                gradientColors: const [Color(0xFF00C853), Color(0xFF00E676)],
              ),
          ],
        ),
        
        const SizedBox(height: 16),

        if (hasLeadsAccess) ...[
          GestureDetector(
            onTap: () {
              ref.read(leadsProvider.notifier).applyFilters({
                'sort': 'updated_desc',
                'status': _convertedStatusId != null && _convertedStatusId!.isNotEmpty ? _convertedStatusId! : 'Converted',
              });
              ref.read(currentRouteProvider.notifier).state = 'Leads';
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Converted Leads',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${castedStatusCounts['Converted'] ?? 0} ',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const TextSpan(
                              text: 'closed',
                              style: TextStyle(
                                color: Color(0xFF00C853),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.0, 
                              ),
                            ),
                          ]
                        ),
                      )
                    ],
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: SvgPicture.asset(
                      'assets/icons/growth_graph.svg',
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(Color(0xFF00C853), BlendMode.srcIn),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (hasLeadsAccess && totalPipeline > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lead Stages',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current lead distribution across stages',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildLeadStageCard(
                        title: 'Hot Leads',
                        count: '$hotLeads',
                        iconPath: 'assets/icons/fire_hot.svg',
                        color: Colors.red,
                        bgColor: Colors.red.shade50,
                        progress: hotProgress,
                        onTap: () {
                          ref.read(leadsProvider.notifier).applyFilters({
                            'sort': 'updated_desc',
                            'pipeline': 'Hot,hot',
                            'status': null,
                          });
                          ref.read(currentRouteProvider.notifier).state = 'Leads';
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLeadStageCard(
                        title: 'Warm Leads',
                        count: '$warmLeads',
                        iconPath: 'assets/icons/fire_warm.svg',
                        color: Colors.orange,
                        bgColor: Colors.orange.shade50,
                        progress: warmProgress,
                        onTap: () {
                          ref.read(leadsProvider.notifier).applyFilters({
                            'sort': 'updated_desc',
                            'pipeline': 'Warm,warm',
                          });
                          ref.read(currentRouteProvider.notifier).state = 'Leads';
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLeadStageCard(
                        title: 'Cold Leads',
                        count: '$coldLeads',
                        iconPath: 'assets/icons/snowflake_cold.svg',
                        color: Colors.lightBlue,
                        bgColor: Colors.lightBlue.shade50,
                        progress: coldProgress,
                        onTap: () {
                          ref.read(leadsProvider.notifier).applyFilters({
                            'sort': 'updated_desc',
                            'pipeline': 'Cold,cold',
                          });
                          ref.read(currentRouteProvider.notifier).state = 'Leads';
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (hasLeadsAccess) ...[
          _buildStatusTab(hasLeadsAccess, sortedStatusEntries, castedStatusCounts),
        ],
      ],
    );
  }

  Widget buildStagesTab(bool hasLeadsAccess, int hotLeads, int warmLeads, int coldLeads) {
    if (!hasLeadsAccess) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lead Stages',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 4),
          Text(
            'Current lead distribution across stages',
            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildLeadStageCard(
                  title: 'Hot Leads',
                  count: '$hotLeads',
                  iconPath: 'assets/icons/fire_hot.svg',
                  color: Colors.red,
                  bgColor: Colors.red.shade50,
                  progress: 0.7,
                  onTap: () {
                    ref.read(leadsProvider.notifier).applyFilters({
                      'sort': 'updated_desc',
                      'pipeline': 'Hot,hot',
                    });
                    ref.read(currentRouteProvider.notifier).state = 'Leads';
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLeadStageCard(
                  title: 'Warm Leads',
                  count: '$warmLeads',
                  iconPath: 'assets/icons/fire_warm.svg',
                  color: Colors.orange,
                  bgColor: Colors.orange.shade50,
                  progress: 0.4,
                  onTap: () {
                    ref.read(leadsProvider.notifier).applyFilters({
                      'sort': 'updated_desc',
                      'pipeline': 'Warm,warm',
                    });
                    ref.read(currentRouteProvider.notifier).state = 'Leads';
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLeadStageCard(
                  title: 'Cold Leads',
                  count: '$coldLeads',
                  iconPath: 'assets/icons/snowflake_cold.svg',
                  color: Colors.lightBlue,
                  bgColor: Colors.lightBlue.shade50,
                  progress: 0.8,
                  onTap: () {
                    ref.read(leadsProvider.notifier).applyFilters({
                      'sort': 'updated_desc',
                      'pipeline': 'Cold,cold',
                    });
                    ref.read(currentRouteProvider.notifier).state = 'Leads';
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatusTab(bool hasLeadsAccess, List<MapEntry<String, int>> sortedStatusEntries, Map<String, int> statusCounts) {
    if (!hasLeadsAccess) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
              'Lead Status Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
           ),
           Text(
              'Showing data from all time to present',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
           ),
           const SizedBox(height: 8),
           
           Row(
            children: [
              Expanded(
                child: _buildDateFilterButton(
                  context, 
                  'Start Date', 
                  _startDate, 
                  (date) {
                    setState(() => _startDate = date);
                    _refresh();
                  }
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateFilterButton(
                  context, 
                  'End Date', 
                  _endDate, 
                  (date) {
                    setState(() => _endDate = date);
                    _refresh();
                  }
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
                _refresh();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 0),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              child: Text('Reset Dates', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color)),
            ),
          ),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              const double perStatus = 56.0;
              final double scrollableWidth = (sortedStatusEntries.length * perStatus).clamp(
                constraints.maxWidth,
                double.infinity,
              );

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: scrollableWidth,
                  height: 350,
                  child: BarChart(
                      BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: sortedStatusEntries.isEmpty ? 10 : sortedStatusEntries.first.value.toDouble() * 1.3 + 5,
                          barTouchData: BarTouchData(
                            enabled: false,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => Colors.blueGrey.shade700,
                              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              tooltipMargin: 4,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  rod.toY.toInt().toString(),
                                  const TextStyle(
                                    color: Colors.white, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 110,
                                      getTitlesWidget: (value, meta) {
                                         final idx = value.toInt();
                                         if (idx >= 0 && idx < sortedStatusEntries.length) {
                                             final label = sortedStatusEntries[idx].key;
                                             return Padding(
                                               padding: const EdgeInsets.only(top: 10),
                                               child: Transform.rotate(
                                                 angle: -0.8,
                                                 alignment: Alignment.centerRight,
                                                 child: SizedBox(
                                                   width: 90,
                                                   child: Text(
                                                     label, 
                                                     textAlign: TextAlign.right,
                                                     style: TextStyle(
                                                       fontSize: 10, 
                                                       color: Colors.grey[700], 
                                                       fontWeight: FontWeight.w600
                                                     ),
                                                     maxLines: 2,
                                                     overflow: TextOverflow.ellipsis,
                                                   ),
                                                 ),
                                               ),
                                             );
                                         }
                                         return const SizedBox();
                                      },
                                  ),
                              ),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                          barGroups: List.generate(sortedStatusEntries.length, (index) {
                               final key = sortedStatusEntries[index].key;
                               final val = sortedStatusEntries[index].value;
                               
                               Color color;
                               switch (key) {
                                 case 'New': color = const Color(0xFF673AB7); break;
                                 case 'Converted': color = const Color(0xFFFFD740); break;
                                 case 'Attempted to Contact': color = const Color(0xFF607D8B); break;
                                 case 'Contact in Future': color = const Color(0xFF2196F3); break;
                                 case 'Contacted': color = const Color(0xFFE91E63); break;
                                 case 'In Negotiation': color = const Color(0xFF00BCD4); break;
                                 case 'Junk Lead': color = const Color(0xFF78909C); break;
                                 case 'Lost': color = const Color(0xFF9E9E9E); break;
                                 default: color = Colors.grey;
                               }

                               return BarChartGroupData(
                                   x: index,
                                   showingTooltipIndicators: [0],
                                   barRods: [
                                       BarChartRodData(
                                           toY: val.toDouble(),
                                           color: color,
                                           width: 18,
                                           borderRadius: const BorderRadius.all(Radius.circular(4)),
                                           backDrawRodData: BackgroundBarChartRodData(show: false)
                                       )
                                   ]
                               );
                            })
                      )
                  ),
                ),
              );
            }
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: 4),
                ...sortedStatusEntries.map((entry) {
                   final total = statusCounts.values.fold(0, (a, b) => a + b);
                   final percentage = total == 0 ? 0.0 : (entry.value / total * 100);
                   
                    Color color;
                    switch (entry.key) {
                       case 'New': color = const Color(0xFF673AB7); break;
                       case 'Contacted': color = const Color(0xFFE91E63); break;
                       case 'In Negotiation': color = const Color(0xFF00BCD4); break;
                       case 'Contact in Future': color = const Color(0xFF009688); break;
                       case 'Converted': color = const Color(0xFFFFC107); break;
                       case 'Attempted to Contact': color = const Color(0xFF607D8B); break;
                       case 'Junk Lead': color = const Color(0xFF90A4AE); break;
                       case 'Lost': color = const Color(0xFFBDBDBD); break;
                       default: color = Colors.blue;
                    }

                   return GestureDetector(
                     onTap: () {
                       final allStatuses = ref.read(leadStatusProvider).statuses;
                       final matchedStatus = allStatuses.firstWhere(
                         (s) => s.name.toLowerCase() == entry.key.toLowerCase(),
                         orElse: () => LeadStatus(id: entry.key, name: entry.key, color: '', backgroundColor: '', isActive: true),
                       );
                       ref.read(leadsProvider.notifier).applyFilters({
                         ...ref.read(leadsProvider).filters,
                         'status': matchedStatus.id,
                       });
                       ref.read(currentRouteProvider.notifier).state = 'Leads';
                     },
                     child: Padding(
                       padding: const EdgeInsets.symmetric(vertical: 8.0),
                       child: Row(
                         children: [
                           CircleAvatar(radius: 5, backgroundColor: color),
                           const SizedBox(width: 8),
                           Expanded(child: Text(entry.key, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12, fontWeight: FontWeight.w500))),
                           Text('${entry.value}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).textTheme.bodyLarge?.color)),
                           const SizedBox(width: 8),
                           Text('(${percentage.toStringAsFixed(1)}%)', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11)),
                         ],
                       ),
                     ),
                   );
                })
              ],
            ),
          )
         ],
      ),
    );
  }

  Widget _buildSourcesTab(bool hasLeadsAccess, Map<String, int> sources) {
    if (!hasLeadsAccess) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
              'Lead Sources',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
           ),
           Text(
              'Showing data from all time to present',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
           ),
           const SizedBox(height: 12),

           Row(
            children: [
              Expanded(
                child: _buildDateFilterButton(
                  context, 
                  'From', 
                  _startDate, 
                  (date) {
                    setState(() => _startDate = date);
                    _refresh();
                  }
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateFilterButton(
                  context, 
                  'To', 
                  _endDate, 
                  (date) {
                    setState(() => _endDate = date);
                    _refresh();
                  }
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
             height: 250,
             child: PieChart(
                 PieChartData(
                     pieTouchData: PieTouchData(
                       touchCallback: (FlTouchEvent event, pieTouchResponse) {
                         setState(() {
                           if (!event.isInterestedForInteractions ||
                               pieTouchResponse == null ||
                               pieTouchResponse.touchedSection == null) {
                             _touchedIndex = -1;
                             return;
                           }
                           _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                         });
                        },
                     ),
                     sectionsSpace: 2,
                     centerSpaceRadius: 60,
                     startDegreeOffset: -90,
                     sections: sources.isEmpty 
                         ? [PieChartSectionData(color: Colors.grey.shade200, value: 1, showTitle: false, radius: 40)]
                         : List.generate(sources.length, (index) {
                             final key = sources.keys.elementAt(index);
                             final value = sources.values.elementAt(index);
                             final color = _getSourceColor(key);
                             final total = sources.values.fold(0, (a, b) => a + b);
                             final percentage = (value / total * 100);
                             final isTouched = index == _touchedIndex;
                             
                              return PieChartSectionData(
                                  color: color,
                                  value: value.toDouble(),
                                  radius: isTouched ? 60 : 50,
                                  title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                                  titleStyle: const TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                                  ),
                                  showTitle: true,
                              );
                         })
                 )
             ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sources', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color)),
              Text(
                'Total: ${sources.values.fold(0, (a, b) => a + b)}', 
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11)
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...sources.entries.map((entry) {
             final total = sources.values.fold(0, (a, b) => a + b);
             final percentage = total == 0 ? 0.0 : (entry.value / total * 100);

             return GestureDetector(
               onTap: () {
                 ref.read(leadsProvider.notifier).applyFilters({
                   'sort': 'updated_desc',
                   'source': entry.key,
                 });
                 ref.read(currentRouteProvider.notifier).state = 'Leads';
               },
               child: Padding(
                 padding: const EdgeInsets.symmetric(vertical: 6.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         CircleAvatar(radius: 5, backgroundColor: _getSourceColor(entry.key)),
                         const SizedBox(width: 10),
                         Expanded(
                           child: Text(
                             entry.key,
                             style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color),
                           ),
                         ),
                         Text(
                           '${percentage.toStringAsFixed(1)}%',
                           style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _getSourceColor(entry.key)),
                         ),
                         const SizedBox(width: 8),
                         SizedBox(
                           width: 36,
                           child: Text(
                             '${entry.value}',
                             textAlign: TextAlign.right,
                             style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 4),
                     ClipRRect(
                       borderRadius: BorderRadius.circular(2),
                       child: LinearProgressIndicator(
                         value: percentage / 100,
                         backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                         valueColor: AlwaysStoppedAnimation<Color>(_getSourceColor(entry.key)),
                         minHeight: 4,
                       ),
                     ),
                   ],
                 ),
               ),
             );
          })
        ],
      ),
    );
  }

  Widget _buildCallsTab(bool isDark, PersonalCallStats? personalCalls, bool isTeamVisible, List<TeamMemberCallStats> topTeamList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (personalCalls != null)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today\'s Call Stats',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
              const SizedBox(height: 4),
              Text('Your personal call activity for today',
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 16),
              _buildCallStatRow('Total Calls', '${personalCalls.totalCalls}', Icons.phone_rounded, Colors.blue),
              _buildCallStatDivider(),
              _buildCallStatRow('Incoming / Out', '${personalCalls.incomingCalls} / ${personalCalls.outgoingCalls}', Icons.swap_vert_rounded, Colors.purple),
              _buildCallStatDivider(),
              _buildCallStatRow('Connected', '${personalCalls.connectedCalls}', Icons.check_circle_rounded, Colors.green),
              _buildCallStatDivider(),
              _buildCallStatRow('Not Connected', '${personalCalls.notConnectedCalls}', Icons.cancel_rounded, Colors.red),
              _buildCallStatDivider(),
              _buildCallStatRow('In / Out Duration', '${_fmtDuration(personalCalls.incomingDuration)} / ${_fmtDuration(personalCalls.outgoingDuration)}', Icons.timer_outlined, Colors.orange),
              _buildCallStatDivider(),
              _buildCallStatRow('Total Duration', _fmtDuration(personalCalls.totalDuration), Icons.hourglass_bottom_rounded, Colors.teal),
            ],
          ),
        ),

        if (personalCalls != null) const SizedBox(height: 16),

        if (isTeamVisible && topTeamList.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text('Team Call Summary',
                       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    Text('Showing data from all time to present',
                       style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
                    const SizedBox(height: 12),
                    Wrap(
                       spacing: 4,
                       runSpacing: 4,
                       children: [
                         _buildTeamTab('Total', 0),
                         _buildTeamTab('Incoming', 1),
                         _buildTeamTab('Outgoing', 2),
                       ],
                    ),
                 ],
               ),
               const SizedBox(height: 16),

               Column(
                 children: [
                   Row(
                     children: [
                       Expanded(
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                             border: Border.all(color: Theme.of(context).dividerColor),
                             borderRadius: BorderRadius.circular(6),
                           ),
                           child: DropdownButtonHideUnderline(
                             child: DropdownButton<String>(
                               value: _selectedTeamRole,
                               isDense: true,
                               isExpanded: true,
                               style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                               items: ['All Roles', 'Sales Manager', 'Team Leader', 'Sales Executive'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                               onChanged: (v) => setState(() => _selectedTeamRole = v ?? 'All Roles'),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                             border: Border.all(color: Theme.of(context).dividerColor),
                             borderRadius: BorderRadius.circular(6),
                           ),
                           child: DropdownButtonHideUnderline(
                             child: DropdownButton<int>(
                               value: _teamCallTopN,
                               isDense: true,
                               isExpanded: true,
                               style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                               items: [
                                 ...[10, 15, 25].map((n) => DropdownMenuItem(value: n, child: Text('Top $n'))),
                                 const DropdownMenuItem(value: -1, child: Text('Show All')),
                               ],
                               onChanged: (v) => setState(() => _teamCallTopN = v ?? 15),
                             ),
                           ),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 12),
                   Row(
                     children: [
                       Expanded(
                         child: _buildDateFilterButton(context, 'Start Date', _startDate, (d) { setState(() => _startDate = d); _refresh(); }),
                       ),
                       const SizedBox(width: 8),
                       Expanded(
                         child: _buildDateFilterButton(context, 'End Date', _endDate, (d) { setState(() => _endDate = d); _refresh(); }),
                       ),
                       const SizedBox(width: 4),
                       IconButton(
                         onPressed: () { setState(() { _startDate = null; _endDate = null; }); _refresh(); },
                         icon: Icon(Icons.refresh, size: 18, color: Theme.of(context).iconTheme.color),
                         padding: EdgeInsets.zero,
                         visualDensity: VisualDensity.compact,
                       ),
                     ],
                   ),
                 ],
               ),
               const SizedBox(height: 16),

               Text('Call Volume Distribution',
                 style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
               const SizedBox(height: 6),
               Row(
                 children: [
                   _buildChartLegendDot(Colors.green, 'Connected'),
                   const SizedBox(width: 12),
                   _buildChartLegendDot(Colors.red, 'Missed'),
                   const SizedBox(width: 12),
                   _buildChartLegendDot(Colors.orange, 'Busy'),
                 ],
               ),
               const SizedBox(height: 8),

               if (topTeamList.isEmpty)
                 const SizedBox(
                   height: 200,
                   child: Center(child: Text('No data', style: TextStyle(color: Colors.grey))),
                 )
               else
               LayoutBuilder(builder: (ctx, bc) {
                 const double perMember = 56.0;
                 const double yAxisWidth = 32.0;
                 final double scrollableWidth = (topTeamList.length * perMember).clamp(
                   bc.maxWidth - yAxisWidth, double.infinity,
                 );
                 final double cvMaxY = topTeamList.map((m) {
                   final cat = _getCategoryStats(m, _teamCallTab);
                   return (cat.connected + cat.missed + cat.agentNotPicked).toDouble();
                 }).fold(0.0, (double a, double b) => a > b ? a : b) * 1.4 + 5;

                 return SizedBox(
                   height: 244,
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       SizedBox(
                         width: yAxisWidth,
                         child: BarChart(BarChartData(
                           alignment: BarChartAlignment.center,
                           maxY: cvMaxY,
                           barGroups: [],
                           borderData: FlBorderData(show: false),
                           gridData: FlGridData(show: false),
                           titlesData: FlTitlesData(
                             show: true,
                             leftTitles: AxisTitles(sideTitles: SideTitles(
                               showTitles: true,
                               reservedSize: yAxisWidth,
                               getTitlesWidget: (value, meta) => value == 0
                                   ? const SizedBox()
                                   : Text(value.toInt().toString(),
                                       style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                             )),
                             rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                             topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                             bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                           ),
                         )),
                       ),
                       Expanded(
                         child: SingleChildScrollView(
                           scrollDirection: Axis.horizontal,
                           child: SizedBox(
                             width: scrollableWidth,
                             child: BarChart(BarChartData(
                               alignment: BarChartAlignment.spaceAround,
                               maxY: cvMaxY,
                               barTouchData: BarTouchData(
                                 enabled: true,
                                 touchTooltipData: BarTouchTooltipData(
                                   getTooltipColor: (_) => isDark ? const Color(0xFF1F2937) : Colors.white,
                                   tooltipBorder: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                   tooltipPadding: const EdgeInsets.all(8),
                                   getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                     final m = topTeamList[groupIndex];
                                     final cat = _getCategoryStats(m, _teamCallTab);
                                     return BarTooltipItem(
                                       '${m.name}\n',
                                       TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                       children: [
                                         TextSpan(text: 'Connected: ', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.normal)),
                                         TextSpan(text: '${cat.connected}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                                         TextSpan(text: '  Missed: ', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.normal)),
                                         TextSpan(text: '${cat.missed}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                                         TextSpan(text: '  Busy: ', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.normal)),
                                         TextSpan(text: '${cat.agentNotPicked}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                                       ],
                                     );
                                   },
                                 ),
                               ),
                               titlesData: FlTitlesData(
                                 show: true,
                                 bottomTitles: AxisTitles(sideTitles: SideTitles(
                                   showTitles: true,
                                   reservedSize: 44,
                                   getTitlesWidget: (value, meta) {
                                     final idx = value.toInt();
                                     if (idx < 0 || idx >= topTeamList.length) return const SizedBox();
                                     final m = topTeamList[idx];
                                     final name = m.isSelf ? 'You' : m.name.split(' ').first;
                                     return Padding(
                                       padding: const EdgeInsets.only(top: 4),
                                       child: Transform.rotate(
                                         angle: -0.5,
                                         child: Text(
                                           name,
                                           style: TextStyle(
                                             fontSize: 9,
                                             color: m.isSelf ? Colors.blue : Colors.grey[600],
                                             fontWeight: m.isSelf ? FontWeight.bold : FontWeight.normal,
                                           ),
                                           overflow: TextOverflow.ellipsis,
                                         ),
                                       ),
                                     );
                                   },
                                 )),
                                 topTitles: AxisTitles(sideTitles: SideTitles(
                                   showTitles: true,
                                   reservedSize: 20,
                                   getTitlesWidget: (value, meta) {
                                     final idx = value.toInt();
                                     if (idx < 0 || idx >= topTeamList.length) return const SizedBox();
                                     final m = topTeamList[idx];
                                     final cat = _getCategoryStats(m, _teamCallTab);
                                     final total = cat.connected + cat.missed + cat.agentNotPicked;
                                     if (total == 0) return const SizedBox();
                                     return Text(
                                       '$total',
                                       style: TextStyle(
                                         fontSize: 9,
                                         fontWeight: FontWeight.bold,
                                         color: m.isSelf ? Colors.blue[700] : (isDark ? Colors.white70 : Colors.black87),
                                       ),
                                     );
                                   },
                                 )),
                                 leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                 rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                               ),
                               borderData: FlBorderData(show: false),
                               groupsSpace: 6,
                               gridData: FlGridData(
                                 show: true,
                                 drawVerticalLine: false,
                                 horizontalInterval: 5,
                                 getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 0.5),
                               ),
                               barGroups: List.generate(topTeamList.length, (i) {
                                 final m = topTeamList[i];
                                 final cat = _getCategoryStats(m, _teamCallTab);
                                 const double bw = 10.0;
                                 return BarChartGroupData(
                                   x: i,
                                   groupVertically: false,
                                   barRods: [
                                     BarChartRodData(toY: cat.connected.toDouble(), color: Colors.green, width: bw, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                                     BarChartRodData(toY: cat.missed.toDouble(), color: Colors.red, width: bw, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                                     BarChartRodData(toY: cat.agentNotPicked.toDouble(), color: Colors.orange, width: bw, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                                   ],
                                 );
                               }),
                             )),
                           ),
                         ),
                       ),
                     ],
                   ),
                 );
               }),

               const SizedBox(height: 20),

               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('Active Talk Time',
                     style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                   GestureDetector(
                     child: Text('✦ EFFICIENCY LEADERBOARD',
                       style: TextStyle(fontSize: 9, color: Colors.blue[600], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                   ),
                 ],
               ),
               const SizedBox(height: 6),

               if (topTeamList.isEmpty)
                 const SizedBox(
                   height: 200,
                   child: Center(child: Text('No data', style: TextStyle(color: Colors.grey))),
                 )
               else
               LayoutBuilder(builder: (ctx, bc) {
                 const double perMember = 56.0;
                 const double yAxisWidth = 44.0;
                 final double scrollableWidth = (topTeamList.length * perMember).clamp(
                   bc.maxWidth - yAxisWidth, double.infinity,
                 );
                 final double attMaxY = topTeamList
                     .map((m) => _getCategoryStats(m, _teamCallTab).duration.toDouble())
                     .fold(0.0, (double a, double b) => a > b ? a : b) * 1.4 + 60;

                 return SizedBox(
                   height: 244,
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       SizedBox(
                         width: yAxisWidth,
                         child: BarChart(BarChartData(
                           alignment: BarChartAlignment.center,
                           maxY: attMaxY,
                           barGroups: [],
                           borderData: FlBorderData(show: false),
                           gridData: FlGridData(show: false),
                           titlesData: FlTitlesData(
                             show: true,
                             leftTitles: AxisTitles(sideTitles: SideTitles(
                               showTitles: true,
                               reservedSize: yAxisWidth,
                               getTitlesWidget: (value, meta) => value == 0
                                   ? const SizedBox()
                                   : Text(_fmtDurationShort(value.toInt()),
                                       style: TextStyle(fontSize: 8, color: Colors.grey[500])),
                             )),
                             rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                             topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                             bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                           ),
                         )),
                       ),
                       Expanded(
                         child: SingleChildScrollView(
                           scrollDirection: Axis.horizontal,
                           child: SizedBox(
                             width: scrollableWidth,
                             child: BarChart(BarChartData(
                               alignment: BarChartAlignment.spaceAround,
                               maxY: attMaxY,
                               barTouchData: BarTouchData(
                                 enabled: true,
                                 touchTooltipData: BarTouchTooltipData(
                                   getTooltipColor: (_) => isDark ? const Color(0xFF1F2937) : Colors.white,
                                   tooltipBorder: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                   tooltipPadding: const EdgeInsets.all(10),
                                   getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                     final m = topTeamList[groupIndex];
                                     final cat = _getCategoryStats(m, _teamCallTab);
                                     return BarTooltipItem(
                                       '${m.name}${m.isSelf ? " (You)" : ""}\n',
                                       TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                       children: [
                                         TextSpan(text: 'Talk Time: ', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.normal, fontSize: 11)),
                                         TextSpan(text: _fmtDuration(cat.duration), style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 11)),
                                       ],
                                     );
                                   },
                                 ),
                               ),
                               titlesData: FlTitlesData(
                                 show: true,
                                 bottomTitles: AxisTitles(sideTitles: SideTitles(
                                   showTitles: true,
                                   reservedSize: 44,
                                   getTitlesWidget: (value, meta) {
                                     final idx = value.toInt();
                                     if (idx < 0 || idx >= topTeamList.length) return const SizedBox();
                                     final m = topTeamList[idx];
                                     final name = m.isSelf ? 'You' : m.name.split(' ').first;
                                     return Padding(
                                       padding: const EdgeInsets.only(top: 8),
                                       child: Transform.rotate(
                                         angle: -0.5,
                                         child: Text(
                                           name,
                                           style: TextStyle(
                                             fontSize: 9,
                                             color: m.isSelf ? Colors.blue : Colors.grey[600],
                                             fontWeight: m.isSelf ? FontWeight.bold : FontWeight.normal,
                                           ),
                                           overflow: TextOverflow.ellipsis,
                                         ),
                                       ),
                                     );
                                   },
                                 )),
                                 topTitles: AxisTitles(sideTitles: SideTitles(
                                   showTitles: true,
                                   reservedSize: 20,
                                   getTitlesWidget: (value, meta) {
                                     final idx = value.toInt();
                                     if (idx < 0 || idx >= topTeamList.length) return const SizedBox();
                                     final m = topTeamList[idx];
                                     final cat = _getCategoryStats(m, _teamCallTab);
                                     if (cat.duration == 0) return const SizedBox();
                                     return Text(
                                       _fmtDurationShort(cat.duration),
                                       style: TextStyle(
                                         fontSize: 9,
                                         fontWeight: FontWeight.bold,
                                         color: m.isSelf ? Colors.blue[700] : (isDark ? Colors.white70 : Colors.black87),
                                       ),
                                     );
                                   },
                                 )),
                                 leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                 rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                               ),
                               borderData: FlBorderData(show: false),
                               groupsSpace: 6,
                               gridData: FlGridData(
                                 show: true,
                                 drawVerticalLine: false,
                                 horizontalInterval: 300,
                                 getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 0.5),
                               ),
                               barGroups: List.generate(topTeamList.length, (i) {
                                 final m = topTeamList[i];
                                 final cat = _getCategoryStats(m, _teamCallTab);
                                 return BarChartGroupData(
                                   x: i,
                                   barRods: [
                                     BarChartRodData(
                                       toY: cat.duration.toDouble(),
                                       color: m.isSelf ? Colors.blue.shade600 : Colors.blue.shade300,
                                       width: 18,
                                       borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                       borderSide: m.isSelf
                                           ? BorderSide(color: isDark ? Colors.white : Colors.blue.shade700, width: 1.5)
                                           : BorderSide.none,
                                     ),
                                   ],
                                 );
                               }),
                             )),
                           ),
                         ),
                       ),
                     ],
                   ),
                 );
               }),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateTaskDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TaskCreateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to route changes to automatically refresh dashboard data when navigating back to it
    ref.listen<String>(currentRouteProvider, (previous, next) {
      if (next == 'Dashboard' && previous != 'Dashboard') {
        _refresh();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(loginProvider).user;
    final isAdmin = user?.systemRole == 'company_admin' || user?.systemRole == 'company';
    final state = ref.watch(dashboardProvider);
    final data = state.data;
    final tasksState = ref.watch(tasksProvider);

    if (state.isLoading && data == null) {
        return const Center(child: CircularProgressIndicator());
    }
    
    // Auto-retry quick data if dashboard loaded but quick data never fetched
    if (!state.isLoading && data != null && _newLeads == null && !_isLoadingQuickData && _quickDataError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchQuickData(forceRefresh: true));
    }
    
    // Permission Checks
    final permissions = ref.watch(permissionsProvider);
    final userRole = user?.systemRole;

    bool hasModule(String module) {
      return permissions.hasModule(module, userRole: userRole);
    }

    final hasLeadsAccess = hasModule(PermissionModules.LEADS) && permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole);
    final hasTasksAccess = hasModule(PermissionModules.TASK) && permissions.hasPermission(PermissionModules.TASKS_VIEW, userRole: userRole);
    final hasMeetingsAccess = hasModule(PermissionModules.MEETING) && permissions.hasPermission(PermissionModules.MEETINGS_VIEW, userRole: userRole);
    final hasVisitsAccess = hasModule(PermissionModules.VISITS) && permissions.hasPermission(PermissionModules.VISITS_VIEW, userRole: userRole);
    final isTeamVisible = userRole != 'sales_executive';

    final hasAnyAccess = hasLeadsAccess || hasTasksAccess || hasMeetingsAccess || hasVisitsAccess;

    if (!hasAnyAccess) {
      return const AccessDeniedWidget(
        sectionName: 'Dashboard',
        showAppBar: false,
      );
    }

    final assigned = data?.leadAssignment?.assigned ?? 0;
    final unassigned = data?.leadAssignment?.unassigned ?? 0;
    final statusCounts = data?.leadStatus?.statusCounts ?? {};
    final totalFromStatus = statusCounts.values.fold(0, (a, b) => a + b);

    final tasksDue = (data?.todaySchedule?.tasksDueToday ?? 0) > 0 
        ? (data?.todaySchedule?.tasksDueToday ?? 0) 
        : tasksState.dueTodayCount;
    final meetingsDue = data?.todaySchedule?.meetingsToday ?? 0;
    
    final totalLeads = (assigned + unassigned) > 0 ? (assigned + unassigned) : totalFromStatus;

    final hotLeads = data?.pipelines?.pipelineCounts['Hot'] ?? 0;
    final warmLeads = data?.pipelines?.pipelineCounts['Warm'] ?? 0;
    final coldLeads = data?.pipelines?.pipelineCounts['Cold'] ?? 0;

    final personalCalls = data?.personalCallStats;
    final teamCallList = data?.teamCallStats ?? [];

    List<TeamMemberCallStats> filteredTeamList = teamCallList;
    if (_selectedTeamRole != 'All Roles') {
      filteredTeamList = teamCallList.where((m) => m.role == _getRoleKey(_selectedTeamRole)).toList();
    }

    final topTeamList = (_teamCallTopN == -1 || filteredTeamList.length <= _teamCallTopN)
        ? filteredTeamList
        : filteredTeamList.sublist(0, _teamCallTopN);

    final sources = data?.leadSources?.sources ?? {};

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final topBarColor = Theme.of(context).appBarTheme.backgroundColor ?? (isDark ? Theme.of(context).cardColor : Colors.white);
          
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: topBarColor,
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dashboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 22)),
                                Text('Overview', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                              ],
                            ),
                            IconButton(
                              onPressed: _refresh, 
                              icon: Icon(Icons.refresh, size: 22, color: Theme.of(context).iconTheme.color),
                              style: IconButton.styleFrom(backgroundColor: Colors.transparent, padding: const EdgeInsets.all(8)),
                            )
                          ],
                        ),
                      ),
                      
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                          child: Text("Error: ${state.error}", style: const TextStyle(color: Colors.red, fontSize: 11)),
                        ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabDelegate(
                  child: Container(
                    color: topBarColor,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAnimatedCategoryTabs(),
                      ],
                    ),
                  ),
                  height: 58.0,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Resolve tab name from visible categories list
                      Builder(builder: (context) {
                        final visibleCategories = _getVisibleCategories();
                        final clampedTab = _selectedCategoryTab.clamp(0, visibleCategories.length - 1);
                        final tabName = visibleCategories.isNotEmpty ? visibleCategories[clampedTab]['name'] as String : 'Quick';
                        switch (tabName) {
                          case 'Stats':
                            return _buildStatsTab(
                              hasTasksAccess,
                              hasMeetingsAccess,
                              hasVisitsAccess,
                              hasLeadsAccess,
                              isAdmin,
                              tasksDue,
                              meetingsDue,
                              totalLeads,
                              assigned,
                              unassigned,
                              data?.todayVisits,
                              constraints,
                              statusCounts,
                              hotLeads,
                              warmLeads,
                              coldLeads,
                            );
                          case 'Sources':
                            return _buildSourcesTab(hasLeadsAccess, sources);
                          case 'Calls':
                            return _buildCallsTab(isDark, personalCalls, isTeamVisible, topTeamList);
                          case 'Quick':
                          default:
                            return _buildQuickTab();
                        }
                      }),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }


  String _getRoleKey(String label) {
    switch (label) {
      case 'Sales Manager': return 'sales_manager';
      case 'Team Leader': return 'team_leader';
      case 'Sales Executive': return 'sales_executive';
      default: return '';
    }
  }

  TextSpan buildTooltipRow(String label, String value, String percent, Color color) {
    return TextSpan(
      children: [
        TextSpan(
          text: '\n• ',
          style: TextStyle(color: color, fontSize: 11),
        ),
        TextSpan(
          text: '$label ',
          style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.normal),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
        ),
        if (percent.isNotEmpty)
          TextSpan(
            text: ' ($percent)',
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
      ],
    );
  }

  Widget _buildLeadStageCard({required String title, required String count, required String iconPath, required Color color, required Color bgColor, required double progress, VoidCallback? onTap}) {
      final card = Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: color.withValues(alpha: 0.2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 40 * progress,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: color,
                  ),
                ),
              ),
            )
          ],
        ),
      );

      if (onTap != null) {
        return GestureDetector(onTap: onTap, child: card);
      }
      return card;
  }

  // static Widget buildCompactPipelineCard(String title, String count, Color bgColor, Color textColor) {
  //     return Container(
  //       width: 100,
  //       padding: const EdgeInsets.all(12),
  //       decoration: BoxDecoration(
  //         color: bgColor,
  //         borderRadius: BorderRadius.circular(16),
  //       ),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
  //           Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.8))),
  //         ],
  //       ),
  //     );
  // }
  //
  // static Widget buildSectionHeader(String title, String? subtitle) {
  //     return Row(
  //       crossAxisAlignment: CrossAxisAlignment.baseline,
  //       textBaseline: TextBaseline.alphabetic,
  //       children: [
  //           Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
  //           if (subtitle != null) ...[
  //             const SizedBox(width: 8),
  //             Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
  //           ]
  //       ],
  //     );
  // }

  // static Widget buildCompactLegend(BuildContext context, String title, Color color, String value) {
  //     return Padding(
  //       padding: const EdgeInsets.symmetric(vertical: 2.0),
  //       child: Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //               Row(
  //                 children: [
  //                   CircleAvatar(radius: 3, backgroundColor: color),
  //                   const SizedBox(width: 6),
  //                   Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyLarge?.color)),
  //                 ],
  //               ),
  //               Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
  //           ],
  //         ),
  //     );
  // }

  Widget buildVisitStatBox(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCallStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }

  Widget _buildCallStatDivider() => Divider(height: 1, thickness: 0.5, color: Theme.of(context).dividerColor.withValues(alpha: 0.3));

  Widget _buildTeamTab(String label, int index) {
    final isActive = _teamCallTab == index;
    return GestureDetector(
      onTap: () => setState(() => _teamCallTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegendDot(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color)),
      ],
    );
  }

  CallCategoryStats _getCategoryStats(TeamMemberCallStats member, int tabIndex) {
    switch (tabIndex) {
      case 1: return member.incoming;
      case 2: return member.outgoing;
      default: return member.total;
    }
  }

  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0 || h > 0) parts.add('${m}m');
    parts.add('${s}s');
    return parts.join(' ');
  }

  String _fmtDurationShort(int seconds) {
    if (seconds <= 0) return '0s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0 || h > 0) parts.add('${m}m');
    parts.add('${s}s');
    return parts.join(' ');
  }
}

class _SliverTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _SliverTabDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SliverTabDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}