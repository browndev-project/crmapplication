import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/permission_constants.dart';
import '../../../core/utils/roles.dart';
import '../../../core/services/report_service.dart';
import '../../../data/models/todays_report_model.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/access_denied_widget.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/call_logs_bottom_sheet.dart';

final todaysReportProvider = FutureProvider.family<TodaysReportV2Model, String>((ref, key) async {
  final parts = key.split('|');
  final systemRole = parts[0];
  final from = parts[1];
  final to = parts[2];
  final service = ref.read(reportServiceProvider);
  return service.fetchTodaysReport(
    systemRole: systemRole.isEmpty ? null : systemRole,
    from: from.isEmpty ? null : from,
    to: to.isEmpty ? null : to,
  );
});

class TodaysReportScreen extends ConsumerStatefulWidget {
  const TodaysReportScreen({super.key});

  @override
  ConsumerState<TodaysReportScreen> createState() => _TodaysReportScreenState();
}

class _TodaysReportScreenState extends ConsumerState<TodaysReportScreen> {
  String _selectedRole = 'team_leader';
  bool _isRoleInitialized = false;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  EmployeeReportV2? _selectedEmployee;
  bool _statsExpanded = true;

  bool _handleBack() {
    if (_selectedEmployee != null) {
      setState(() => _selectedEmployee = null);
      return true;
    }
    return false;
  }

  late final StateController<BackHandler?> _backHandlerController;

  @override
  void initState() {
    super.initState();
    _backHandlerController = ref.read(backHandlerProvider.notifier);
  }

  @override
  void dispose() {
    _backHandlerController.state = null;
    super.dispose();
  }

  final List<Map<String, String>> _roleOptions = const [
    {'label': 'Company Admin', 'value': 'company_admin'},
    {'label': 'Sales Manager', 'value': 'sales_manager'},
    {'label': 'Team Leader', 'value': 'team_leader'},
    {'label': 'Sales Executive', 'value': 'sales_executive'},
  ];

  static const List<String> standardStatuses = [
    'New',
    'Converted',
    'Meeting Scheduled',
    'Attempted To Contact',
    'Contact In Future',
    'Contacted',
    'In Negotiation',
    'Junk Lead',
    'Lost',
    'Test',
    'Test1',
    'Visit Scheduled',
    'Partner',
    'Interested',
  ];

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0 || parts.isEmpty) parts.add('${s}s');
    return parts.join(' ');
  }

  String _formatDurationShort(int seconds) {
    if (seconds == 0) return '0s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0 || h > 0) parts.add('${m}m');
    parts.add('${s}s');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final canView = permissions.hasModule(
      PermissionModules.REPORTS_BASE,
      userRole: userRole,
    ) && userRole != SystemRoles.SALES_EXECUTIVE;

    if (!canView) {
      return const Scaffold(
        appBar: GlobalAppBar(title: "Calls Summary"),
        body: AccessDeniedWidget(
          sectionName: "Calls Summary",
          showAppBar: false,
        ),
      );
    }

    if (!_isRoleInitialized && userRole != null) {
      _selectedRole = userRole;
      _isRoleInitialized = true;
    }

    final List<Map<String, String>> filteredRoleOptions = _roleOptions.where((opt) {
      if (userRole == SystemRoles.COMPANY_ADMIN || userRole == SystemRoles.COMPANY) return true;
      if (userRole == SystemRoles.SALES_MANAGER) {
        return opt['value'] == SystemRoles.SALES_MANAGER
            || opt['value'] == SystemRoles.TEAM_LEADER
            || opt['value'] == SystemRoles.SALES_EXECUTIVE;
      }
      if (userRole == SystemRoles.TEAM_LEADER) {
        return opt['value'] == SystemRoles.TEAM_LEADER
            || opt['value'] == SystemRoles.SALES_EXECUTIVE;
      }
      return false;
    }).toList();

    if (filteredRoleOptions.isNotEmpty && !filteredRoleOptions.any((o) => o['value'] == _selectedRole)) {
      _selectedRole = filteredRoleOptions.first['value']!;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(_toDate);
    final requestKey = '$_selectedRole|$fromStr|$toStr';
    final reportAsync = ref.watch(todaysReportProvider(requestKey));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(backHandlerProvider.notifier).state = _selectedEmployee != null ? _handleBack : null;
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: const GlobalAppBar(title: 'Calls Summary'),
      body: PopScope(
        canPop: _selectedEmployee == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _selectedEmployee != null) {
            setState(() => _selectedEmployee = null);
          }
        },
        child: RefreshIndicator(
        onRefresh: () async => ref.refresh(todaysReportProvider(requestKey)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedEmployee != null ? 'Call Details' : 'Call Summary',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (_selectedEmployee == null)
                    reportAsync.maybeWhen(
                      data: (report) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : Colors.black54),
                            onPressed: () => ref.refresh(todaysReportProvider(requestKey)),
                          ),
                          IconButton(
                            icon: Icon(Icons.download, color: isDark ? Colors.white70 : Colors.black54),
                            onPressed: () => _exportAsCSV(report),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month, color: Colors.purple),
                            onPressed: () {
                              // Secondary action if needed
                            },
                          ),
                        ],
                      ),
                      orElse: () => const SizedBox(),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (_selectedEmployee == null) ...[
                // Date Pickers Row
                Row(
                  children: [
                    _buildDatePickerField(
                      context: context,
                      label: 'From',
                      date: _fromDate,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => _fromDate = date);
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildDatePickerField(
                      context: context,
                      label: 'To',
                      date: _toDate,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _toDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => _toDate = date);
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Designation Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filteredRoleOptions.map((opt) {
                      final isSelected = _selectedRole == opt['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedRole = opt['value']!;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade600 : (isDark ? Colors.white10 : Colors.white),
                              border: Border.all(
                                color: isSelected ? Colors.blue.shade600 : (isDark ? Colors.white24 : Colors.grey.shade300),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              opt['label']!,
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Rankings List
                reportAsync.when(
                  data: (report) {
                    if (report.employees.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.call_end, size: 48, color: isDark ? Colors.white12 : Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text("No records found.", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: report.employees.length,
                      itemBuilder: (context, index) {
                        return _buildEmployeeRankCard(
                          report.employees[index],
                          index + 1,
                          isDark,
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text('Error: $err', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ] else ...[
                // Detail view layout
                reportAsync.when(
                  data: (report) {
                    final emp = report.employees.firstWhere(
                      (e) => e.employeeId == _selectedEmployee!.employeeId,
                      orElse: () => _selectedEmployee!,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Navigation
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedEmployee = null;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back, color: Colors.blue, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Back to Rankings',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Profile Card
                        Card(
                          elevation: 0,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                                      child: Icon(
                                        Icons.person,
                                        size: 36,
                                        color: isDark ? Colors.white30 : Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  emp.name,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                                                ),
                                                child: Text(
                                                  emp.designation.isNotEmpty ? emp.designation : 'Staff',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.phone, size: 14, color: Colors.blue.shade600),
                                              const SizedBox(width: 6),
                                              Text(
                                                emp.phoneNo,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _statsExpanded = !_statsExpanded;
                                          });
                                        },
                                        icon: Icon(
                                          _statsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                          size: 16,
                                        ),
                                        label: Text(
                                          _statsExpanded ? 'Collapse Stats' : 'Expand Stats',
                                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                            ),
                                            builder: (context) => CallLogsBottomSheet(
                                              employee: emp,
                                              isDark: isDark,
                                              fromDate: fromStr,
                                              toDate: toStr,
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade600,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        child: const Text(
                                          'View Call Logs',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stats Grid (Collapsible)
                        AnimatedCrossFade(
                          firstChild: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildLeftBorderCard(
                                      label: 'ASSIGNED LEADS',
                                      value: '${emp.assignedLeadsToday}',
                                      color: const Color(0xFF2196F3),
                                      icon: Icons.people_outline,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildLeftBorderCard(
                                      label: 'LEADS WORKED',
                                      value: '${emp.leadsWorkedToday}',
                                      color: const Color(0xFF4CAF50),
                                      icon: Icons.people_alt_outlined,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                               Row(
                                 children: [
                                   Expanded(
                                     child: _buildLeftBorderCard(
                                       label: 'IN DURATION',
                                       value: _formatDuration(emp.incomingDuration),
                                       color: const Color(0xFF03A9F4),
                                       icon: Icons.access_time_outlined,
                                       isDark: isDark,
                                     ),
                                   ),
                                   const SizedBox(width: 12),
                                   Expanded(
                                     child: _buildLeftBorderCard(
                                       label: 'OUT DURATION',
                                       value: _formatDuration(emp.outgoingDuration),
                                       color: const Color(0xFFFF9800),
                                       icon: Icons.access_time_outlined,
                                       isDark: isDark,
                                     ),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 12),
                               Row(
                                 children: [
                                   Expanded(
                                     child: _buildLeftBorderCard(
                                       label: 'TOTAL DURATION',
                                       value: _formatDuration(emp.totalDuration),
                                       color: const Color(0xFF00BCD4),
                                       icon: Icons.access_time_outlined,
                                       isDark: isDark,
                                     ),
                                   ),
                                   const SizedBox(width: 12),
                                   Expanded(
                                     child: _buildLeftBorderCard(
                                       label: 'TALK TIME (ACTIVE)',
                                       value: _formatDuration(emp.talkTime),
                                       color: const Color(0xFFE91E63),
                                       icon: Icons.access_time_outlined,
                                       isDark: isDark,
                                     ),
                                   ),
                                 ],
                               ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildLeftBorderCard(
                                      label: 'AGENT NOT PICKED',
                                      value: '${emp.agentNotPickedUpCalls}',
                                      color: const Color(0xFFF44336),
                                      icon: Icons.phone_callback_outlined,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                          secondChild: const SizedBox(),
                          crossFadeState: _statsExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 250),
                        ),

                        // Outcome Counters
                        Row(
                          children: [
                            Expanded(
                              child: _buildOutcomeCounterCard(
                                label: 'TOTAL CALLS',
                                value: '${emp.totalCalls}',
                                valueColor: isDark ? Colors.white : Colors.black87,
                                iconBgColor: Colors.grey.shade600,
                                icon: Icons.phone,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildOutcomeCounterCard(
                                label: 'INCOMING/OUT',
                                value: '${emp.incomingCalls} / ${emp.outgoingCalls}',
                                valueColor: Colors.blue.shade700,
                                iconBgColor: Colors.blue,
                                icon: Icons.sync,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildOutcomeCounterCard(
                                label: 'CONNECTED',
                                value: '${emp.connectedCalls}',
                                valueColor: Colors.green.shade700,
                                iconBgColor: Colors.green,
                                icon: Icons.phone_callback,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildOutcomeCounterCard(
                                label: 'MISSED/FAILED',
                                value: '${emp.notConnectedCalls}',
                                valueColor: Colors.red.shade700,
                                iconBgColor: Colors.red,
                                icon: Icons.phone_disabled,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildOutcomeCounterCard(
                                label: 'AGENT NOT PICKED',
                                value: '${emp.agentNotPickedUpCalls}',
                                valueColor: Colors.orange.shade800,
                                iconBgColor: Colors.orange,
                                icon: Icons.phone_missed,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Worked Lead Sources
                        Card(
                          elevation: 0,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'WORKED LEAD SOURCES',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'TODAY',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (emp.workedSourceBreakdown.isEmpty)
                                  Text(
                                    'No source data available for worked leads today.',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: emp.workedSourceBreakdown.entries.map((entry) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              entry.key,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${entry.value}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Lead Statuses
                        Card(
                          elevation: 0,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'LEAD STATUSES',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'TODAY',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: standardStatuses.map((status) {
                                    final count = emp.statusCounts[status] ??
                                        emp.statusCounts[status.toLowerCase()] ??
                                        emp.statusCounts[status.replaceAll(' ', '_').toLowerCase()] ??
                                        0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text('Error: $err', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MM/dd/yyyy').format(date),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isDark ? Colors.white30 : Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeRankCard(EmployeeReportV2 emp, int rank, bool isDark) {
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFB300);
    } else if (rank == 2) {
      rankColor = const Color(0xFFB0BEC5);
    } else if (rank == 3) {
      rankColor = const Color(0xFFFF7043);
    } else {
      rankColor = const Color(0xFF9E9E9E);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedEmployee = emp;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                    child: Text(
                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: rankColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _bulletMetric(Colors.blue, 'Inc: ${_formatDurationShort(emp.incomingDuration)}'),
                        _bulletMetric(Colors.orange, 'Out: ${_formatDurationShort(emp.outgoingDuration)}'),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              'Total: ${_formatDurationShort(emp.totalDuration)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '${emp.totalCalls} CALLS',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bulletMetric(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLeftBorderCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
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
      ),
    );
  }

  Widget _buildOutcomeCounterCard({
    required String label,
    required String value,
    required Color valueColor,
    required Color iconBgColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconBgColor),
          ),
        ],
      ),
    );
  }



  Future<void> _exportAsCSV(TodaysReportV2Model report) async {
    try {
      final rows = <List<dynamic>>[];
      rows.add([
        'Rank', 'Name', 'Designation', 'Phone', 'Total Calls', 'Incoming Calls',
        'Outgoing Calls', 'Connected Calls', 'Missed/Failed Calls', 'Incoming Duration',
        'Outgoing Duration', 'Total Duration', 'Talk Time', 'Leads Worked', 'Tasks Completed'
      ]);

      for (int i = 0; i < report.employees.length; i++) {
        final emp = report.employees[i];
        rows.add([
          i + 1,
          emp.name,
          emp.designation,
          emp.phoneNo,
          emp.totalCalls,
          emp.incomingCalls,
          emp.outgoingCalls,
          emp.connectedCalls,
          emp.notConnectedCalls,
          _formatDuration(emp.incomingDuration),
          _formatDuration(emp.outgoingDuration),
          _formatDuration(emp.totalDuration),
          _formatDuration(emp.talkTime),
          emp.leadsWorkedToday,
          emp.tasksCompletedToday
        ]);
      }

      final csvString = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Call_Summary_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);
      await Share.shareXFiles([XFile(file.path)], text: 'Call Summary CSV');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
