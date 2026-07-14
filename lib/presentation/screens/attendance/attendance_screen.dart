import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../widgets/global_app_bar.dart';
import '../../../data/models/attendance_model.dart';
import '../../../providers/attendance_provider.dart';
import '../../providers/login_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../widgets/access_denied_widget.dart';

import '../../../core/utils/date_utils.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All'; // All, Active, Break, Inactive

  // For Sales Executive History
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(loginProvider).user;
      if (user?.systemRole == 'sales_executive') {
        ref.read(attendanceHistoryProvider.notifier).fetchHistory(userId: user!.id);
      }
    });
  }

  String _formatDateTime(String? dateStr) {
    return DateTimeUtils.formatTime(DateTimeUtils.parseSafe(dateStr));
  }

  String _formatDuration(int ms) {
    if (ms == 0) return '0m';
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours == 0 && minutes == 0 && ms > 0) {
      return '<1m';
    }
    
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🖥️ AttendanceScreen: BUILD called');
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final canView = permissions.hasModule(PermissionModules.ATTENDANCE, userRole: userRole);

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Activity Tracker'),
        body: AccessDeniedWidget(
          sectionName: "Activity Tracker",
          showAppBar: false,
        ),
      );
    }

    final isSalesExecutive = userRole == 'sales_executive';

    if (isSalesExecutive) {
      return _buildSalesExecutiveView(context, user!);
    }

    final attendanceAsync = ref.watch(companyAttendanceProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],

      appBar: const GlobalAppBar(title: 'Attendance'),
      body: Column(
        children: [
          // Filter Tabs
          // We need to fetch data first to count, or just show filters but counts as 0?
          // Let's rely on the AsyncValue to build the content.
          
          Expanded(
            child: attendanceAsync.when(
              data: (response) {
                if (response == null) {
                   return const Center(child: Text("Critical Error: Service returned null"));
                }
                if (!response.success) {
                   return Center(
                     child: Padding(
                       padding: const EdgeInsets.all(20.0),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           const Icon(Icons.error_outline, color: Colors.red, size: 48),
                           const SizedBox(height: 16),
                           const Text("API Request Failed", style: TextStyle(fontWeight: FontWeight.bold)),
                           const SizedBox(height: 8),
                           Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                             child: Text(response.message, style: const TextStyle(fontFamily: 'monospace', fontSize: 12), textAlign: TextAlign.center),
                           ),
                           const SizedBox(height: 16),
                           ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry"),
                              onPressed: () => ref.refresh(companyAttendanceProvider),
                           )
                         ],
                       ),
                     ),
                   );
                }
                if (response.data == null) {
                   return const Center(child: Text("Success, but Data is Null"));
                }

                final records = response.data!.records;
                
                // Calculate counts
                final total = records.length;
                final active = records.where((r) => r.status.toLowerCase() == 'active').length;
                final onBreak = records.where((r) => r.status.toLowerCase() == 'break').length;
                final inactive = records.where((r) => r.status.toLowerCase() == 'inactive').length;

                // Filter list
                final filteredRecords = _selectedFilter == 'All' 
                    ? records 
                    : records.where((r) => r.status.toLowerCase() == _selectedFilter.toLowerCase()).toList();

                return Column(
                  children: [
                    // Filter Tabs Header
                    Container(
                      color: Theme.of(context).cardColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          _FilterTab(label: "All", count: total, isSelected: _selectedFilter == 'All', onTap: () => setState(() => _selectedFilter = 'All')),
                          const SizedBox(width: 8),
                          _FilterTab(label: "Active", count: active, color: Colors.green, isSelected: _selectedFilter == 'Active', onTap: () => setState(() => _selectedFilter = 'Active')),
                          const SizedBox(width: 8),
                          _FilterTab(label: "Break", count: onBreak, color: Colors.orange, isSelected: _selectedFilter == 'Break', onTap: () => setState(() => _selectedFilter = 'Break')),
                          const SizedBox(width: 8),
                          _FilterTab(label: "Inactive", count: inactive, color: Colors.grey, isSelected: _selectedFilter == 'Inactive', onTap: () => setState(() => _selectedFilter = 'Inactive')),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                    
                    // Main List
                    Expanded(
                      child: filteredRecords.isEmpty 
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_off_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  "No executives found in this status.", 
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 14)
                                ),
                              ],
                            )
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredRecords.length,
                            itemBuilder: (context, index) {
                              return _AttendanceCard(record: filteredRecords[index]);
                            },
                          ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text("Error: $err")),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sales Executive View ---
  Widget _buildSalesExecutiveView(BuildContext context, dynamic user) {
    final historyState = ref.watch(attendanceHistoryProvider);
    final history = historyState.history;
    
    // Find today's record (Assuming backend returns sorted or checking date)
    // Note: API returns history directly. For "today's live status", we might need the other API or just infer from history if updated.
    // The requirement is to show the history table and "today's" card.
    // Let's assume the first record is today if dates match.
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    AttendanceRecordHistory? todaysRecord;
    try {
        todaysRecord = history.firstWhere((r) => r.date == todayStr);
    } catch (e) {
        todaysRecord = null;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        appBar: const GlobalAppBar(title: 'Attendance'),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text("View your daily attendance record.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    
                    // 1. Profile & Today's Card
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                                                const SizedBox(height: 4),
                                                Text(user.phoneNo, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 13)),
                                            ],
                                        ),
                                        // Status Badge
                                        Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.green.shade100)
                                            ),
                                            child: Text(
                                                todaysRecord?.status.toUpperCase() ?? "NOT APPLICABLE",
                                                style: TextStyle(color: isDark ? Colors.green[300] : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)
                                            ),
                                        )
                                    ],
                                ),
                                const SizedBox(height: 20),
                                
                                // Stats Grid
                                Row(
                                    children: [
                                        Expanded(child: _buildBlinkitStat(context, "Login", _formatDateTime(todaysRecord?.loginAt))),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildBlinkitStat(context, "Logout", _formatDateTime(todaysRecord?.logoutAt))),
                                    ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                    children: [
                                        Expanded(child: _buildBlinkitStat(context, "Work Time", _formatDuration(todaysRecord?.totalWorkMs ?? 0))),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildBlinkitStat(context, "Break Time", _formatDuration(todaysRecord?.totalBreakMs ?? 0))),
                                    ],
                                ),
                                
                                // Breaks Today (Placeholder if data available)
                                if (todaysRecord != null && todaysRecord.totalBreakMs > 0) ...[
                                    const SizedBox(height: 20),
                                    const Text("Breaks Today", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 8),
                                    Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                                        child: Text("Total Break Duration: ${_formatDuration(todaysRecord.totalBreakMs)}", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                                    )
                                ]
                            ],
                        ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 2. Attendance Records History
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const Text("Attendance Records", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                const SizedBox(height: 16),
                                
                                // Date Filter Row
                                Row(
                                    children: [
                                        Expanded(child: _buildDateInput("From Date", _dateRange?.start)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildDateInput("To Date", _dateRange?.end)),
                                    ],
                                ),
                                const SizedBox(height: 24),
                                
                                // Table / List
                                if (historyState.isLoading)
                                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                                else if (history.isEmpty)
                                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No records found.")))
                                else
                                    SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                            horizontalMargin: 12,
                                            columnSpacing: 24,
                                            columns: [
                                                DataColumn(label: Text("Sr No", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey))),
                                                DataColumn(label: Text("Date", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey))),
                                                DataColumn(label: Text("Login", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey))),
                                                DataColumn(label: Text("Logout", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey))),
                                                DataColumn(label: Text("Work", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey))),
                                                DataColumn(label: Text("Break", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey))),
                                            ],
                                            rows: List.generate(history.length, (index) {
                                                final record = history[index];
                                                return DataRow(
                                                    cells: [
                                                        DataCell(Text("${index + 1}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                        DataCell(Text(DateTimeUtils.formatDayMonthYear(DateTime.tryParse(record.date)), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                        DataCell(Text(_formatDateTime(record.loginAt), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                        DataCell(Text(_formatDateTime(record.logoutAt ?? ''), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))), // Handle null logout
                                                        DataCell(Text(_formatDuration(record.totalWorkMs), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                        DataCell(Text(_formatDuration(record.totalBreakMs), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                    ]
                                                );
                                            }),
                                        ),
                                    )
                            ],
                        ),
                    ),
                    const SizedBox(height: 40),
                ],
            ),
        ),
    );
  }
  Widget _buildBlinkitStat(BuildContext context, String label, String value) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12)
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                   Text(label, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              ],
          ),
      );
  }
  
  Widget _buildDateInput(String hint, DateTime? value) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return InkWell(
          onTap: () async {
            final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (picked != null) {
                setState(() {
                    _dateRange = picked;
                });
                // Fetch with dates
                final user = ref.read(loginProvider).user;
                if (user != null) {
                    ref.read(attendanceHistoryProvider.notifier).fetchHistory(
                        userId: user.id,
                        fromDate: DateFormat('yyyy-MM-dd').format(picked.start),
                        toDate: DateFormat('yyyy-MM-dd').format(picked.end),
                    );
                }
            }
          },
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8)
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      Text(
                          value != null ? DateTimeUtils.formatDayMonthYear(value) : hint,
                          style: TextStyle(color: value != null ? (isDark ? Colors.white : Colors.black) : Colors.grey)
                      ),
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey)
                  ],
              ),
          ),
      );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey[600])),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]),
                shape: BoxShape.circle,
              ),
              child: Text(
                count.toString(), 
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87)
                )
              ),
            )
          ],
      ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;

  const _AttendanceCard({required this.record});

  String _formatDateTime(String? dateStr) {
    return DateTimeUtils.formatTime(DateTimeUtils.parseSafe(dateStr));
  }
  
  String _formatDuration(int ms) {
    if (ms == 0) return '0m';
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours == 0 && minutes == 0 && ms > 0) {
      return '<1m';
    }
    
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(record.status, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: Text(record.user.name.isNotEmpty ? record.user.name[0] : '?', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.user.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(record.user.phoneNo, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[500])),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3))
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          
          // Stats Row
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               _StatItem(label: "Login", value: _formatDateTime(record.loginAt), icon: Icons.login),
               _StatItem(label: "Logout", value: _formatDateTime(record.logoutAt), icon: Icons.logout),
               _StatItem(label: "Work Time", value: _formatDuration(record.totalWorkMs), icon: Icons.access_time),
               _StatItem(label: "Break", value: _formatDuration(record.totalBreakMs), icon: Icons.coffee),
             ],
          ),
          
          if (record.breaks.isNotEmpty) ...[
             const SizedBox(height: 16),
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.05))
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text("Break History", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey)),
                   const SizedBox(height: 4),
                   ...record.breaks.map((b) => Padding(
                     padding: const EdgeInsets.symmetric(vertical: 2.0),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          Text(b.reason, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87)),
                          Text(
                            "${_formatDateTime(b.startAt)} - ${_formatDateTime(b.endAt)} (${_formatDuration(b.durationMs)})",
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[600]),
                          )
                       ],
                     ),
                   )),
                 ],
               ),
             )
          ]
        ],
      ),
    );
  }

  Color _getStatusColor(String status, bool isDark) {
    switch(status.toLowerCase()) {
      case 'active': return Colors.green;
      case 'break': return Colors.orange;
      case 'inactive': return isDark ? Colors.white54 : Colors.grey;
      default: return isDark ? Colors.white : Colors.black;
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.grey[400]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey[500])),
      ],
    );
  }
}
