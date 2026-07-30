import 'package:flutter/material.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:permission_handler/permission_handler.dart';
import '../widgets/access_denied_widget.dart';
import '../providers/navigation_provider.dart';
import '../../core/utils/date_utils.dart';
import 'package:intl/intl.dart';
import '../../core/services/admin_dashboard_service.dart';
import '../widgets/overdue_drawer_sheet.dart';

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
    if (Platform.isIOS) return;

    final box = await Hive.openBox('settingsBox');
    final bool dialogShown = box.get('permissions_dialog_shown', defaultValue: false);

    if (!dialogShown) {
      if (mounted) {
        await [
          Permission.location,
          Permission.storage,
          Permission.phone,
          Permission.photos,
        ].request();
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
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  DateTime? _startDate;
  DateTime? _endDate;
  int _teamCallTab = 0; // 0=Total, 1=Incoming, 2=Outgoing
  int _teamCallTopN = 15; // -1 for Show All
  String _selectedTeamRole = 'All Roles';

  // Redesign state
  int _selectedCategoryTab = 0;

  // Admin Dashboard State
  final _adminDashboardService = AdminDashboardService();
  int? _adminTotalLeads;
  int? _adminLostLeads;
  int? _adminUnassignedLeads;
  int? _adminConvertedLeads;

  int? _overdueTasksCount;
  int? _pendingMeetingsCount;
  int? _pendingVisitsCount;

  List<Map<String, dynamic>>? _employeeLeadMetrics;
  DateTime _perfStartDate = DateTime.now();
  DateTime _perfEndDate = DateTime.now();
  bool _isLoadingPerfMetrics = false;
  String _perfSearchQuery = '';
  final String _perfSortField = 'name';
  final bool _perfSortAscending = true;

  List<Map<String, dynamic>>? _employeeCallMetrics;
  DateTime _callStartDate = DateTime.now();
  DateTime _callEndDate = DateTime.now();
  bool _isLoadingCallMetrics = false;
  String _callSearchQuery = '';
  final String _callSortField = 'total';
  final bool _callSortAscending = false;

  bool _isLoadingAdminDashboard = false;
  Map<String, dynamic>? _timelineData;

  // Scroll Controllers for Tables to prevent scrollbar assertion crash
  late ScrollController _perfHorizScrollController;
  late ScrollController _perfVertScrollController;
  late ScrollController _callHorizScrollController;
  late ScrollController _callVertScrollController;
  
  // Quick tab items
  List<tm.Task>? _upcomingTasks;
  List<Map<String, dynamic>>? _upcomingMeetings;
  List<Map<String, dynamic>>? _upcomingVisits;
  List<Lead>? _unassignedLeads;
  List<Lead>? _convertedLeadsList;
  bool _isLoadingQuickData = false;
  String? _quickDataError;
  String? _convertedStatusId;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 15));
    _endDate = DateTime.now();
    _perfHorizScrollController = ScrollController();
    _perfVertScrollController = ScrollController();
    _callHorizScrollController = ScrollController();
    _callVertScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
       final user = ref.read(loginProvider).user;
       final isAdmin = user?.systemRole == 'company_admin';
       final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;

       ref.read(dashboardProvider.notifier).fetchDashboardData(
         isAdmin: isAdmin,
         assignedTo: assignedTo,
       );
       ref.read(tasksProvider.notifier).refresh();
       if (isAdmin) {
         _fetchAdminDashboardData(forceRefresh: true);
       } else {
         _fetchQuickData(forceRefresh: true);
       }
       _checkSubscriptionExpiry();
    });
  }

  @override
  void dispose() {
    _perfHorizScrollController.dispose();
    _perfVertScrollController.dispose();
    _callHorizScrollController.dispose();
    _callVertScrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final user = ref.read(loginProvider).user;
    final isAdmin = user?.systemRole == 'company_admin';
    final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;

    if (isAdmin) {
      await Future.wait<void>([
          ref.read(dashboardProvider.notifier).fetchDashboardData(
              forceRefresh: true, 
              isAdmin: true,
              startDate: _startDate,
              endDate: _endDate,
          ),
          ref.read(tasksProvider.notifier).refresh(),
          _fetchAdminDashboardData(forceRefresh: true),
      ]);
    } else {
      await Future.wait<void>([
          ref.read(dashboardProvider.notifier).fetchDashboardData(
              forceRefresh: true, 
              isAdmin: false,
              assignedTo: assignedTo,
              startDate: _startDate,
              endDate: _endDate,
          ),
          ref.read(tasksProvider.notifier).refresh(),
          _fetchQuickData(forceRefresh: true),
      ]);
    }
  }

  Future<void> _fetchQuickData({bool forceRefresh = false}) async {
    if (!forceRefresh && _upcomingTasks != null) return;
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
      final convertedStatus = statuses.firstWhere(
        (s) => s.name.toLowerCase() == 'converted',
        orElse: () => LeadStatus(id: '', name: 'Converted', color: '', backgroundColor: '', isActive: true),
      );
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
        safeFetch(taskService.fetchTasks(page: 1, limit: 100)),
        safeFetch(meetingService.fetchMeetings(page: 1, limit: 50, assignedTo: assignedTo)),
        safeFetch(visitService.fetchVisits(page: 1, limit: 50, assignedTo: assignedTo)),
        safeFetch(leadService.fetchLeads(page: 1, limit: 50)),
        safeFetch(leadService.fetchLeads(page: 1, limit: 10, status: convertedStatus.id.isNotEmpty ? convertedStatus.id : 'Converted')),
        safeFetch(_adminDashboardService.fetchAttentionCount()),
      ]);

      final tasksResponse = results[0] as tm.TaskData?;
      final meetingsResponse = results[1] as mm.MeetingsResponse?;
      final visitsResponse = results[2] as VisitsResponse?;
      final allLeadsResponse = results[3] as LeadsResponse?;
      final convertedLeadsResponse = results[4] as LeadsResponse?;
      final attentionData = results[5] as Map<String, int>?;

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
          // New Leads removed from dashboard
          _upcomingTasks = upcomingTasks;
          _upcomingMeetings = meetingsList.take(5).toList();
          _upcomingVisits = visitsList.take(5).toList();
          _unassignedLeads = unassignedLeads;
          _convertedLeadsList = convertedLeadsResponse?.leads;
          _overdueTasksCount = attentionData?['overdueTasksCount'] ?? 0;
          _pendingMeetingsCount = attentionData?['pendingMeetingsCount'] ?? 0;
          _pendingVisitsCount = attentionData?['pendingVisitsCount'] ?? 0;
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

  Future<void> _fetchAdminDashboardData({bool forceRefresh = false}) async {
    if (_isLoadingAdminDashboard) return;
    if (mounted) {
      setState(() {
        _isLoadingAdminDashboard = true;
        _quickDataError = null;
      });
    }

    try {
      final results = await Future.wait([
        _adminDashboardService.fetchTotalLeads(),
        _adminDashboardService.fetchUnassignedCount(),
        _adminDashboardService.fetchConvertedCount(),
        _adminDashboardService.fetchAttentionCount(),
        _adminDashboardService.fetchEmployeeLeadMetrics(
          startDate: DateFormat('yyyy-MM-dd').format(_perfStartDate),
          endDate: DateFormat('yyyy-MM-dd').format(_perfEndDate),
        ),
        _adminDashboardService.fetchEmployeeCallMetrics(
          startDate: DateFormat('yyyy-MM-dd').format(_callStartDate),
          endDate: DateFormat('yyyy-MM-dd').format(_callEndDate),
        ),
        _adminDashboardService.fetchLeadSourceTimeline(
          startDate: DateFormat('yyyy-MM-dd').format(_startDate ?? DateTime.now().subtract(const Duration(days: 15))),
          endDate: DateFormat('yyyy-MM-dd').format(_endDate ?? DateTime.now()),
        ),
      ]);

      final totalLeadsData = results[0] as Map<String, int>;
      final unassignedCount = results[1] as int;
      final convertedCount = results[2] as int;
      final attentionData = results[3] as Map<String, int>;
      final perfMetrics = results[4] as List<Map<String, dynamic>>;
      final callMetrics = results[5] as List<Map<String, dynamic>>;
      final timelineData = results[6] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _adminTotalLeads = totalLeadsData['totalLeads'];
          _adminLostLeads = totalLeadsData['lostLeads'];
          _adminUnassignedLeads = unassignedCount;
          _adminConvertedLeads = convertedCount;

          _overdueTasksCount = attentionData['overdueTasksCount'];
          _pendingMeetingsCount = attentionData['pendingMeetingsCount'];
          _pendingVisitsCount = attentionData['pendingVisitsCount'];

          _employeeLeadMetrics = perfMetrics;
          _employeeCallMetrics = callMetrics;
          _timelineData = timelineData;

          _isLoadingAdminDashboard = false;
        });
      }
    } catch (e) {
      debugPrint("Admin Dashboard Fetch Error: $e");
      if (mounted) {
        setState(() {
          _quickDataError = e.toString();
          _isLoadingAdminDashboard = false;
        });
      }
    }
  }

  Future<void> _fetchPerfMetricsOnly() async {
    if (mounted) setState(() => _isLoadingPerfMetrics = true);
    try {
      final perf = await _adminDashboardService.fetchEmployeeLeadMetrics(
        startDate: DateFormat('yyyy-MM-dd').format(_perfStartDate),
        endDate: DateFormat('yyyy-MM-dd').format(_perfEndDate),
      );
      if (mounted) {
        setState(() {
          _employeeLeadMetrics = perf;
          _isLoadingPerfMetrics = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching performance metrics: $e");
      if (mounted) {
        setState(() => _isLoadingPerfMetrics = false);
      }
    }
  }

  Future<void> _fetchCallMetricsOnly() async {
    if (mounted) setState(() => _isLoadingCallMetrics = true);
    try {
      final calls = await _adminDashboardService.fetchEmployeeCallMetrics(
        startDate: DateFormat('yyyy-MM-dd').format(_callStartDate),
        endDate: DateFormat('yyyy-MM-dd').format(_callEndDate),
      );
      if (mounted) {
        setState(() {
          _employeeCallMetrics = calls;
          _isLoadingCallMetrics = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching call metrics: $e");
      if (mounted) {
        setState(() => _isLoadingCallMetrics = false);
      }
    }
  }

  void _openOverdueDrawer(OverdueType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OverdueDrawerSheet(type: type),
    ).then((_) {
      _fetchAdminDashboardData(forceRefresh: true);
    });
  }

  Future<void> _selectStartDate({required bool isPerf}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isPerf ? _perfStartDate : _callStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        if (isPerf) {
          _perfStartDate = picked;
        } else {
          _callStartDate = picked;
        }
      });
      if (isPerf) {
        _fetchPerfMetricsOnly();
      } else {
        _fetchCallMetricsOnly();
      }
    }
  }

  Future<void> _selectEndDate({required bool isPerf}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isPerf ? _perfEndDate : _callEndDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        if (isPerf) {
          _perfEndDate = picked;
        } else {
          _callEndDate = picked;
        }
      });
      if (isPerf) {
        _fetchPerfMetricsOnly();
      } else {
        _fetchCallMetricsOnly();
      }
    }
  }

  String _formatCallDuration(int sec) {
    if (sec < 60) return '${sec}s';
    final min = sec ~/ 60;
    final remaining = sec % 60;
    if (min < 60) return '${min}m ${remaining}s';
    final hr = min ~/ 60;
    final remainingMin = min % 60;
    return '${hr}h ${remainingMin}m';
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
    switch (source.toLowerCase().trim()) {
      case 'meta ads': return const Color(0xFFE11D48); // Rose Red
      case 'leads api': return const Color(0xFF0284C7); // Light Blue
      case 'whatsapp': return const Color(0xFF16A34A); // Green
      case 'referral': return const Color(0xFF0D9488); // Teal
      case 'bulk upload': return Colors.cyan;
      case 'website': return Colors.deepPurpleAccent;
      case 'manual upload': return Colors.orange;
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
    final isDark = theme.brightness == Brightness.dark;
    final viewMoreColor = isDark ? Colors.white70 : Colors.black87;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
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
              if (onCreateTask != null) ...[
                InkWell(
                  onTap: onCreateTask,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Icon(Icons.add, size: 18, color: Color(0xFF1976D2)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: onViewMore,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View More',
                      style: TextStyle(
                        color: viewMoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: viewMoreColor,
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
      margin: const EdgeInsets.only(bottom: 6),
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
                    if (task.lead != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        "Lead: ${task.lead!.name}",
                        style: TextStyle(
                          color: isDark ? Colors.blue[300] : const Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
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
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    if (userRole == 'company_admin') {
      return _buildAdminDashboardTab();
    }

    if (_isLoadingQuickData && _upcomingTasks == null) {
      return _buildQuickSkeleton(isDark);
    }
    
    if (_quickDataError != null && _upcomingTasks == null) {
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
    final hasLeadsAccess = permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole);
    final hasTasksAccess = permissions.hasModule(PermissionModules.TASK, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.TASKS_VIEW, userRole: userRole);
    final hasMeetingsAccess = permissions.hasModule(PermissionModules.MEETING, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.MEETINGS_VIEW, userRole: userRole);
    final hasVisitsAccess = permissions.hasModule(PermissionModules.VISITS, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.VISITS_VIEW, userRole: userRole);

    final List<Widget> sections = [];

    // Attention Required (Overdue Tasks, Pending Visits, Pending Meetings)
    final totalAttention = (_overdueTasksCount ?? 0) + (_pendingVisitsCount ?? 0) + (_pendingMeetingsCount ?? 0);
    if (totalAttention > 0) {
      sections.addAll([
        Text(
          'Attention Required',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 10),
        if ((_overdueTasksCount ?? 0) > 0)
          _buildAttentionBanner(
            message: 'Overdue: ${_overdueTasksCount ?? 0} Follow up(s)',
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFEE2E2),
            textColor: const Color(0xFF991B1B),
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.red,
            onTap: () => _openOverdueDrawer(OverdueType.task),
            isDark: isDark,
          ),
        if ((_pendingVisitsCount ?? 0) > 0)
          _buildAttentionBanner(
            message: 'Pending: ${_pendingVisitsCount ?? 0} visit(s)',
            bgColor: const Color(0xFFFEF3C7),
            borderColor: const Color(0xFFFDE68A),
            textColor: const Color(0xFF92400E),
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFD97706),
            onTap: () => _openOverdueDrawer(OverdueType.visit),
            isDark: isDark,
          ),
        if ((_pendingMeetingsCount ?? 0) > 0)
          _buildAttentionBanner(
            message: 'Pending: $_pendingMeetingsCount meeting(s)',
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFDBEAFE),
            textColor: const Color(0xFF1E40AF),
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.blue,
            onTap: () => _openOverdueDrawer(OverdueType.meeting),
            isDark: isDark,
          ),
        const SizedBox(height: 24),
      ]);
    }

    // Upcoming Tasks — gated by TASKS_VIEW
    if (hasTasksAccess) {
      sections.addAll([
        _buildQuickSectionHeader(
          title: 'Upcoming Follow ups',
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
        const SizedBox(height: 2),
        if (_upcomingTasks == null || _upcomingTasks!.isEmpty)
          _buildQuickEmptyState('No upcoming follow ups')
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
        const SizedBox(height: 2),
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
        const SizedBox(height: 2),
        if (_upcomingVisits == null || _upcomingVisits!.isEmpty)
          _buildQuickEmptyState('No upcoming visits')
        else
          ..._upcomingVisits!.map((item) => _buildQuickMeetingVisitCard(item, isDark)),
        const SizedBox(height: 24),
      ]);
    }

    // Unassigned Leads — gated by LEADS_VIEW and commented out/hidden for standard employees (sales_executives)
    if (hasLeadsAccess && userRole != 'sales_executive') {
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
        const SizedBox(height: 2),
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
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildAdminDashboardTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingAdminDashboard && _adminTotalLeads == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60.0),
          child: CircularProgressIndicator(color: Color(0xFF27C16B)),
        ),
      );
    }

    if (_quickDataError != null && _adminTotalLeads == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load admin feeds',
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
                onPressed: () => _fetchAdminDashboardData(forceRefresh: true),
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

    final filteredPerfMetrics = _employeeLeadMetrics?.where((emp) {
      if (_perfSearchQuery.isEmpty) return true;
      final name = emp['name']?.toString().toLowerCase() ?? '';
      return name.contains(_perfSearchQuery.toLowerCase());
    }).toList() ?? [];

    // Sort performance metrics locally
    filteredPerfMetrics.sort((a, b) {
      final aVal = a[_perfSortField];
      final bVal = b[_perfSortField];
      int compareResult = 0;
      if (aVal is String && bVal is String) {
        compareResult = aVal.compareTo(bVal);
      } else if (aVal is num && bVal is num) {
        compareResult = aVal.compareTo(bVal);
      }
      return _perfSortAscending ? compareResult : -compareResult;
    });

    final pipelineData = ref.watch(dashboardProvider).data?.pipelines?.pipelineCounts ?? {};
    final hotCount = pipelineData['Hot'] ?? 0;
    final warmCount = pipelineData['Warm'] ?? 0;
    final coldCount = pipelineData['Cold'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lead Overview',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _buildAdminOverviewCard(
              title: 'Total',
              count: '${_adminTotalLeads ?? 0}',
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF10B981),
              onTap: () {
                ref.read(leadsProvider.notifier).applyFilters({});
                ref.read(currentRouteProvider.notifier).state = 'Leads';
              },
              isDark: isDark,
            ),
            _buildAdminOverviewCard(
              title: 'Unassigned',
              count: '${_adminUnassignedLeads ?? 0}',
              icon: Icons.person_search_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () {
                ref.read(leadsProvider.notifier).applyFilters({'assignedTo': 'unassigned'});
                ref.read(currentRouteProvider.notifier).state = 'Leads';
              },
              isDark: isDark,
            ),
            _buildAdminOverviewCard(
              title: 'Converted',
              count: '${_adminConvertedLeads ?? 0}',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () {
                ref.read(leadsProvider.notifier).applyFilters({
                  'status': '6970ef34b795f2719d7ad24b',
                  'sort': 'updated_desc',
                });
                ref.read(currentRouteProvider.notifier).state = 'Leads';
              },
              isDark: isDark,
            ),
            _buildAdminOverviewCard(
              title: 'Lost',
              count: '${_adminLostLeads ?? 0}',
              icon: Icons.cancel_rounded,
              color: const Color(0xFFEF4444),
              onTap: () {
                ref.read(leadsProvider.notifier).applyFilters({
                  'isLost': true,
                  'sort': 'updated_desc',
                });
                ref.read(currentRouteProvider.notifier).state = 'Leads';
              },
              isDark: isDark,
            ),
          ],
        ),


        Text(
          'Lead Stages',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildAdminStageCard(
                title: 'Hot',
                count: '$hotCount',
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFF43F5E),
                onTap: () {
                  ref.read(leadsProvider.notifier).applyFilters({'pipeline': 'Hot'});
                  ref.read(currentRouteProvider.notifier).state = 'Leads';
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAdminStageCard(
                title: 'Warm',
                count: '$warmCount',
                icon: Icons.wb_sunny_rounded,
                color: const Color(0xFFF97316),
                onTap: () {
                  ref.read(leadsProvider.notifier).applyFilters({'pipeline': 'Warm'});
                  ref.read(currentRouteProvider.notifier).state = 'Leads';
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAdminStageCard(
                title: 'Cold',
                count: '$coldCount',
                icon: Icons.ac_unit_rounded,
                color: const Color(0xFF06B6D4),
                onTap: () {
                  ref.read(leadsProvider.notifier).applyFilters({'pipeline': 'Cold'});
                  ref.read(currentRouteProvider.notifier).state = 'Leads';
                },
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text(
          'Attention Required',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 10),
        _buildAttentionBanner(
          message: 'Overdue: ${_overdueTasksCount ?? 0} Follow up(s)',
          bgColor: const Color(0xFFFEF2F2),
          borderColor: const Color(0xFFFEE2E2),
          textColor: const Color(0xFF991B1B),
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.red,
          onTap: () => _openOverdueDrawer(OverdueType.task),
          isDark: isDark,
        ),
        _buildAttentionBanner(
          message: 'Pending: ${_pendingVisitsCount ?? 0} visit(s)',
          bgColor: const Color(0xFFFEF3C7),
          borderColor: const Color(0xFFFDE68A),
          textColor: const Color(0xFF92400E),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFD97706),
          onTap: () => _openOverdueDrawer(OverdueType.visit),
          isDark: isDark,
        ),
        if ((_pendingMeetingsCount ?? 0) > 0)
          _buildAttentionBanner(
            message: 'Pending: $_pendingMeetingsCount meeting(s)',
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFDBEAFE),
            textColor: const Color(0xFF1E40AF),
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.blue,
            onTap: () => _openOverdueDrawer(OverdueType.meeting),
            isDark: isDark,
          ),
        const SizedBox(height: 24),

        _buildSectionCard(
          title: 'Employee Performance',
          icon: Icons.badge_outlined,
          startDate: _perfStartDate,
          endDate: _perfEndDate,
          isLoading: _isLoadingPerfMetrics,
          searchQuery: _perfSearchQuery,
          onStartDateSelect: () => _selectStartDate(isPerf: true),
          onEndDateSelect: () => _selectEndDate(isPerf: true),
          onRefresh: _fetchPerfMetricsOnly,
          onSearchChanged: (val) => setState(() => _perfSearchQuery = val),
          isDark: isDark,
          child: filteredPerfMetrics.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No employees found', style: TextStyle(fontSize: 13, color: Colors.grey))),
                )
              : Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: Scrollbar(
                    controller: _perfVertScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _perfVertScrollController,
                      child: Column(
                        children: filteredPerfMetrics.map((emp) {
                          final empId = emp['_id'] ?? '';
                          final empName = emp['name'] ?? 'Unknown';
                          final empRole = emp['systemRole'] ?? emp['role'] ?? 'agent';
                          final assigned = emp['assigned'] ?? 0;
                          final worked = emp['worked'] ?? 0;
                          final converted = emp['converted'] ?? 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark ? Colors.white10 : Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                            elevation: 0,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                ref.read(leadsProvider.notifier).applyFilters({
                                  'assignedTo': empId,
                                  'startDate': DateFormat('yyyy-MM-dd').format(_perfStartDate),
                                  'endDate': DateFormat('yyyy-MM-dd').format(_perfEndDate),
                                });
                                ref.read(currentRouteProvider.notifier).state = 'Leads';
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Profile Info (Avatar + Name & Role)
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                          child: Text(
                                            empName.isNotEmpty ? empName[0].toUpperCase() : 'U',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                empName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              Text(
                                                empRole.replaceAll('_', ' ').toUpperCase(),
                                                style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Divider(color: isDark ? Colors.white10 : Colors.grey.shade100, height: 1),
                                    const SizedBox(height: 10),
                                    // Row 2: Metrics (Assigned, Worked, Converted)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildDashboardMetricItem("ASSIGNED", "$assigned", Colors.blue, isDark),
                                        _buildDashboardMetricItem("WORKED", "$worked", Colors.orange, isDark),
                                        _buildDashboardMetricItem("CONVERTED", "$converted", Colors.green, isDark),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Divider(color: isDark ? Colors.white10 : Colors.grey.shade100, height: 1),
                                    const SizedBox(height: 10),
                                    // Row 3: Conversion Rate
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Conversion Rate",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          worked > 0
                                              ? "${((converted / worked) * 100).toStringAsFixed(1)}%"
                                              : "0.0%",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildAdminOverviewCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 0.5),
      ),
      color: isDark ? const Color(0xFF252525) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminStageCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 0.5),
      ),
      color: isDark ? const Color(0xFF252525) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttentionBanner({
    required String message,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? bgColor.withValues(alpha: 0.15) : bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? borderColor.withValues(alpha: 0.3) : borderColor, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white60 : textColor.withValues(alpha: 0.7), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required DateTime startDate,
    required DateTime endDate,
    required bool isLoading,
    required String searchQuery,
    required VoidCallback onStartDateSelect,
    required VoidCallback onEndDateSelect,
    required VoidCallback onRefresh,
    required ValueChanged<String> onSearchChanged,
    required bool isDark,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final borderCol = isDark ? Colors.white12 : Colors.grey.shade200;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol, width: 0.5),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol, width: 1),
                  ),
                  child: Icon(icon, size: 24, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1),
                    ),
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: onStartDateSelect,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white60 : Colors.black87),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'FROM',
                                          style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          DateFormat('yy/MM/dd').format(startDate),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: double.infinity,
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: onEndDateSelect,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white60 : Colors.black87),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'TO',
                                          style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          DateFormat('yy/MM/dd').format(endDate),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1),
                    ),
                    fixedSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search employee...',
                  hintStyle: TextStyle(fontSize: 12, color: theme.hintColor),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primaryColor, width: 1),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              child,
          ],
        ),
      ),
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
        const SizedBox(height: 2),
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
          childAspectRatio: 2.1,
          children: [
            if (hasTasksAccess)
              DashboardStatsCard(
                title: 'Follow ups Due Today',
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
            if (hasLeadsAccess && !isAdmin)
              DashboardStatsCard(
                title: 'Total Leads',
                value: '$totalLeads',
                icon: Icons.analytics_rounded,
                backgroundColor: const Color(0xFF009688),
                gradientColors: [const Color(0xFF009688), const Color(0xFF00796B)],
              ),
            if (isAdmin && hasLeadsAccess && !isAdmin)
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
                        style: GoogleFonts.plusJakartaSans(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
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
                  style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color),
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
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color),
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
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color),
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
                  _startDate = DateTime.now().subtract(const Duration(days: 15));
                  _endDate = DateTime.now();
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
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Format start/end date text for header subtitle
    final timelineStartDate = _startDate ?? DateTime.now().subtract(const Duration(days: 15));
    final timelineEndDate = _endDate ?? DateTime.now();
    final differenceDays = timelineEndDate.difference(timelineStartDate).inDays + 1;
    final subtitleText = "Showing data from ${DateFormat('d MMMM yyyy').format(timelineStartDate)} to ${DateFormat('d MMMM yyyy').format(timelineEndDate)} ($differenceDays days)";

    final timelineList = (_timelineData?['timeline'] as List?) ?? [];
    final activeSources = List<String>.from(_timelineData?['activeSources'] ?? []);

    // 1. Calculate source breakdown aggregates
    final Map<String, int> sourceRecd = {};
    final Map<String, int> sourceConv = {};
    int totalRecdAllSources = 0;

    for (var source in activeSources) {
      sourceRecd[source] = 0;
      sourceConv[source] = 0;
    }

    for (var entry in timelineList) {
      for (var source in activeSources) {
        final recdVal = (entry[source] as num?)?.toInt() ?? 0;
        final convVal = (entry['${source}_converted'] as num?)?.toInt() ?? 0;
        sourceRecd[source] = (sourceRecd[source] ?? 0) + recdVal;
        sourceConv[source] = (sourceConv[source] ?? 0) + convVal;
        totalRecdAllSources += recdVal;
      }
    }

    // Sort active sources by received counts descending
    final sortedActiveSources = List<String>.from(activeSources)
      ..sort((a, b) => (sourceRecd[b] ?? 0).compareTo(sourceRecd[a] ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leads Timeline & Sources',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, 
                        fontWeight: FontWeight.w900, 
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 11, 
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _refresh,
              ),
            ],
          ),
          const SizedBox(height: 16),

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

          const SizedBox(height: 20),

          if (_isLoadingAdminDashboard)
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (timelineList.isEmpty)
            SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  "No timeline data available for the selected range",
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else ...[
            // Render Chart Legend
            Center(child: _buildChartLegend(activeSources, isDark)),
            const SizedBox(height: 16),

            // Render Spline Line/Area Chart
            SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, left: 0),
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => isDark ? Colors.grey[900]! : Colors.white,
                        tooltipBorder: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final sourceName = activeSources[spot.barIndex];
                            return LineTooltipItem(
                              '$sourceName: ${spot.y.toInt()}',
                              TextStyle(
                                color: _getSourceColor(sourceName),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: isDark ? Colors.white10 : Colors.black12,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) => _bottomTitleWidgets(value, meta, timelineList, isDark),
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, isDark),
                          reservedSize: 28,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                        left: BorderSide.none,
                        right: BorderSide.none,
                        top: BorderSide.none,
                      ),
                    ),
                    minX: 0,
                    maxX: (timelineList.length - 1).toDouble(),
                    minY: 0,
                    maxY: _getMaxY(timelineList, activeSources),
                    lineBarsData: _getLineBarsData(timelineList, activeSources),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Source Breakdown table header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Source Breakdown',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                'Total: $totalRecdAllSources',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color, 
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Breakdown table columns
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'SOURCE',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RECD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'CONV',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RATE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Breakdown List Items
          if (!_isLoadingAdminDashboard)
            ...sortedActiveSources.map((source) {
              final recd = sourceRecd[source] ?? 0;
              final conv = sourceConv[source] ?? 0;
              final rate = recd == 0 ? 0.0 : (conv / recd * 100);
              final pct = totalRecdAllSources == 0 ? 0.0 : (recd / totalRecdAllSources * 100);
              final color = _getSourceColor(source);

              IconData getSourceIcon(String src) {
                switch (src.toLowerCase().trim()) {
                  case 'meta ads':
                  case 'facebook':
                    return Icons.facebook;
                  case 'whatsapp':
                    return Icons.chat_bubble_outline;
                  case 'leads api':
                  case 'api':
                    return Icons.api;
                  case 'referral':
                    return Icons.people_outline;
                  default:
                    return Icons.language;
                }
              }

              return GestureDetector(
                onTap: () {
                  ref.read(leadsProvider.notifier).applyFilters({
                    'sort': 'updated_desc',
                    'source': source,
                    'from': DateFormat('yyyy-MM-dd').format(timelineStartDate),
                    'to': DateFormat('yyyy-MM-dd').format(timelineEndDate),
                  });
                  ref.read(currentRouteProvider.notifier).state = 'Leads';
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
                  ),
                  child: Row(
                    children: [
                      // Source label & icon
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Icon(getSourceIcon(source), size: 14, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                source,
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w600, 
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Received counts & percentage
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$recd',
                              style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold, 
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            Text(
                              '(${pct.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontSize: 9, 
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Converted counts
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$conv',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold, 
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      // Conversion Rate
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${rate.toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold, 
                            color: rate > 0 ? const Color(0xFF10B981) : (isDark ? Colors.white30 : Colors.grey[400]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildChartLegend(List<String> activeSources, bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: activeSources.map((source) {
        final color = _getSourceColor(source);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              source,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta, List<dynamic> timelineList, bool isDark) {
    final index = value.toInt();
    if (index < 0 || index >= timelineList.length) {
      return const SizedBox.shrink();
    }
    
    // Choose label interval dynamically
    int interval = 1;
    if (timelineList.length > 20) {
      interval = 4;
    } else if (timelineList.length > 10) {
      interval = 2;
    }

    if (index % interval != 0 && index != timelineList.length - 1) {
      return const SizedBox.shrink();
    }

    final entry = timelineList[index];
    final dateStr = entry['date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return const SizedBox.shrink();
    
    return SideTitleWidget(
      meta: meta,
      space: 6,
      child: Text(
        DateFormat('dd MMM').format(date),
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.grey[600],
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta, bool isDark) {
    if (value % 1 != 0) return const SizedBox.shrink();
    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        value.toInt().toString(),
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.grey[600],
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  double _getMaxY(List<dynamic> timelineList, List<String> activeSources) {
    double maxVal = 5.0;
    for (var entry in timelineList) {
      for (var source in activeSources) {
        final val = (entry[source] as num?)?.toDouble() ?? 0.0;
        if (val > maxVal) {
          maxVal = val;
        }
      }
    }
    return (maxVal * 1.15).ceilToDouble();
  }

  List<LineChartBarData> _getLineBarsData(List<dynamic> timelineList, List<String> activeSources) {
    final List<LineChartBarData> bars = [];
    
    for (var source in activeSources) {
      final List<FlSpot> spots = [];
      for (int i = 0; i < timelineList.length; i++) {
        final entry = timelineList[i];
        final val = (entry[source] as num?)?.toDouble() ?? 0.0;
        spots.add(FlSpot(i.toDouble(), val));
      }
      
      final color = _getSourceColor(source);
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 2,
          color: color,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      );
    }
    return bars;
  }

  Widget _buildCallsTab(bool isDark, PersonalCallStats? personalCalls, bool isTeamVisible, List<TeamMemberCallStats> topTeamList) {
    final user = ref.read(loginProvider).user;
    final userRole = user?.systemRole;
    final isAdmin = userRole == 'company_admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdmin) ...[
          _buildSectionCard(
            title: 'Employee Call Analytics',
            icon: Icons.call_outlined,
            startDate: _callStartDate,
            endDate: _callEndDate,
            isLoading: _isLoadingCallMetrics,
            searchQuery: _callSearchQuery,
            onStartDateSelect: () => _selectStartDate(isPerf: false),
            onEndDateSelect: () => _selectEndDate(isPerf: false),
            onRefresh: _fetchCallMetricsOnly,
            onSearchChanged: (val) => setState(() => _callSearchQuery = val),
            isDark: isDark,
            child: () {
              final filteredCallMetrics = _employeeCallMetrics?.where((emp) {
                if (_callSearchQuery.isEmpty) return true;
                final name = emp['name']?.toString().toLowerCase() ?? '';
                return name.contains(_callSearchQuery.toLowerCase());
              }).toList() ?? [];

              // Sort call metrics locally
              filteredCallMetrics.sort((a, b) {
                final aVal = a[_callSortField];
                final bVal = b[_callSortField];
                int compareResult = 0;
                if (aVal is String && bVal is String) {
                  compareResult = aVal.compareTo(bVal);
                } else if (aVal is num && bVal is num) {
                  compareResult = aVal.compareTo(bVal);
                }
                return _callSortAscending ? compareResult : -compareResult;
              });

              return filteredCallMetrics.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(child: Text('No employees found', style: TextStyle(fontSize: 13, color: Colors.grey))),
                    )
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: Scrollbar(
                        controller: _callVertScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _callVertScrollController,
                          child: Column(
                            children: filteredCallMetrics.map((emp) {
                              final empName = emp['name'] ?? 'Unknown';
                              final empRole = emp['systemRole'] ?? emp['role'] ?? 'agent';
                              final total = emp['total'] ?? 0;
                              final connected = emp['connected'] ?? 0;
                              final duration = emp['duration'] ?? 0;
                              final incoming = emp['incoming'] ?? 0;
                              final outgoing = emp['outgoing'] ?? 0;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Row 1: Profile Info (Avatar + Name & Role)
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                            child: Text(
                                              empName.isNotEmpty ? empName[0].toUpperCase() : 'U',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  empName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                Text(
                                                  empRole.replaceAll('_', ' ').toUpperCase(),
                                                  style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Divider(color: isDark ? Colors.white10 : Colors.grey.shade100, height: 1),
                                      const SizedBox(height: 10),
                                      // Row 2: Call Metrics (Total, Connected, Duration)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildDashboardMetricItem("TOTAL CALLS", "$total", Colors.blue, isDark),
                                          _buildDashboardMetricItem("CONNECTED", "$connected", Colors.green, isDark),
                                          _buildDashboardMetricItem("DURATION", _formatCallDuration(duration), Colors.purple, isDark),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Divider(color: isDark ? Colors.white10 : Colors.grey.shade100, height: 1),
                                      const SizedBox(height: 10),
                                      // Row 3: Call Details (Incoming/Outgoing, Connection Rate)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "$incoming Incoming / $outgoing Outgoing",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            total > 0
                                                ? "Connected: ${((connected / total) * 100).toStringAsFixed(1)}%"
                                                : "Connected: 0.0%",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
            }(),
          ),
          const SizedBox(height: 16),
        ],

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
                style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color)),
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
                       style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color)),
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
                         onPressed: () {
                           setState(() {
                             _startDate = DateTime.now().subtract(const Duration(days: 15));
                             _endDate = DateTime.now();
                           });
                           _refresh();
                         },
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
    final isAdmin = user?.systemRole == 'company_admin' ;
    final state = ref.watch(dashboardProvider);
    final data = state.data;
    final tasksState = ref.watch(tasksProvider);

    // Auto-retry quick data if quick data never fetched and not currently loading
    if (_upcomingTasks == null && !_isLoadingQuickData && _quickDataError == null) {
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
      key: _refreshIndicatorKey,
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
                                Text(
                                  'Dashboard',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                // Text('Overview', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                              ],
                            ),
                            IconButton(
                              onPressed: () => _refreshIndicatorKey.currentState?.show(), 
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
                            if (state.isLoading && data == null) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
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
                            if (state.isLoading && data == null) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildSourcesTab(hasLeadsAccess, sources);
                          case 'Calls':
                            if (state.isLoading && data == null) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
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

  Future<void> _checkSubscriptionExpiry() async {
    final user = ref.read(loginProvider).user;
    if (user == null || user.companyDetails == null) return;

    final billing = user.companyDetails!.billing;
    if (billing == null) return;

    final planType = billing.planType.toLowerCase();
    final endDateStr = billing.endDate;
    if (planType.isEmpty || endDateStr.isEmpty) return;

    final endDate = DateTime.parse(endDateStr);
    final now = DateTime.now();

    // Calculate days remaining (ceiling calculation)
    final diff = endDate.difference(now);
    final daysRemaining = (diff.inSeconds / (24 * 60 * 60)).ceil();

    bool shouldShow = false;
    if (planType == 'trial') {
      // Trial Accounts: show if daysRemaining <= 3
      if (daysRemaining <= 3) {
        shouldShow = true;
      }
    } else if (planType == 'billing') {
      // Paid Accounts: show at exactly 15, or <= 7
      if (daysRemaining == 15 || daysRemaining <= 7) {
        shouldShow = true;
      }
    }

    if (!shouldShow) return;

    // Trigger showing frequency (once per calendar day for both trial and billing accounts)
    final box = await Hive.openBox('settingsBox');
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final lastShown = box.get('lastExpiryWarningShownDate');
    if (lastShown == todayStr) {
      return; // Already shown today
    }
    await box.put('lastExpiryWarningShownDate', todayStr);

    if (mounted) {
      _showSubscriptionExpiryDialog(context, planType: planType, daysRemaining: daysRemaining);
    }
  }

  void _showSubscriptionExpiryDialog(BuildContext context, {
    required String planType,
    required int daysRemaining,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmergency = (planType == 'trial') || (planType == 'billing' && daysRemaining <= 7);
    final isExpired = daysRemaining <= 0;
    
    final accentColor = isEmergency ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final alertIcon = isEmergency ? Icons.error_outline_rounded : Icons.warning_amber_rounded;
    
    final title = isExpired ? "Subscription Expired" : "Subscription Expiring Soon";
    
    final String accountTypeText = planType == 'trial' ? 'trial account' : 'billing period';
    final String timeText = isExpired 
        ? 'has already expired' 
        : 'is expiring in $daysRemaining ${daysRemaining == 1 ? 'day' : 'days'}';
    
    final copyText = "Your company's $accountTypeText $timeText. Please extend your plan immediately to ensure your operations continue running smoothly.";
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // Prevent back button dismissal
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 8,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                border: Border(
                  top: BorderSide(color: accentColor, width: 6.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      alertIcon,
                      color: accentColor,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      copyText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.03) 
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "For any queries, contact us at 8750938653 or click Open WhatsApp below.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              "Close",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final Uri url = Uri.parse("https://wa.me/918750938653");
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: Text(
                              "Open WhatsApp",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
          ),
        );
      },
    );
  }

  Widget _buildDashboardMetricItem(String label, String value, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
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