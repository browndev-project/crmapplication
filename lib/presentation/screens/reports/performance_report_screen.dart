import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/report_service.dart';
import '../../../data/models/performance_report_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/performance_card.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../widgets/access_denied_widget.dart';

final performanceReportProvider = FutureProvider.family<List<PerformanceReportModel>, String>((ref, key) async {
  final parts = key.split('|');
  final role = parts[0];
  final from = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
  final to = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2]));

  final service = ref.read(reportServiceProvider);
  return service.fetchPerformanceReport(role, from, to);
});

class PerformanceReportScreen extends ConsumerStatefulWidget {
  const PerformanceReportScreen({super.key});

  @override
  ConsumerState<PerformanceReportScreen> createState() => _PerformanceReportScreenState();
}

class _PerformanceReportScreenState extends ConsumerState<PerformanceReportScreen> {
  String _selectedRole = 'sales_executive';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final canView = permissions.hasModule(
      PermissionModules.REPORTS_BASE,
      userRole: userRole,
    );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: "Performance"),
        body: AccessDeniedWidget(
          sectionName: "Performance Report",
          showAppBar: false,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Construct unique key for params
    final requestKey = '$_selectedRole|${_fromDate.millisecondsSinceEpoch}|${_toDate.millisecondsSinceEpoch}';
    final reportAsync = ref.watch(performanceReportProvider(requestKey));

    final currentData = reportAsync.maybeWhen(data: (d) => d, orElse: () => null);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      appBar: GlobalAppBar(
        title: 'Performance Report',
        actions: [
          if (currentData != null && currentData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
              onPressed: () => _exportAsCSV(currentData),
            ),
        ],
      ),

      body: Column(
        children: [
          // Filter Bar
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                // Role Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      items: [
                        {'label': 'Sales Executive', 'value': 'sales_executive'},
                        {'label': 'Sales Manager', 'value': 'sales_manager'},
                        {'label': 'Team Leader', 'value': 'team_leader'},
                      ].map((item) => DropdownMenuItem(
                            value: item['value'],
                            child: Text(item['label']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          )).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Date Range & Action
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${DateFormat('MMM dd').format(_fromDate)} - ${DateFormat('MMM dd').format(_toDate)}',
                                  style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () {
                        final requestKey = '$_selectedRole|${_fromDate.millisecondsSinceEpoch}|${_toDate.millisecondsSinceEpoch}';
                        final _ = ref.refresh(performanceReportProvider(requestKey));
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: reportAsync.when(
              data: (data) {
                if (data.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, size: 64, color: isDark ? Colors.white12 : Colors.grey),
                        const SizedBox(height: 16),
                        Text('No performance records found.', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    return PerformanceCard(report: data[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error: $err', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAsCSV(List<PerformanceReportModel> data) async {
    try {
      final rows = <List<dynamic>>[
        ['Name', 'Role', 'Assigned', 'Worked', 'Converted', 'Revenue', 'Updates', 'Work (min)', 'Break (min)', 'Active Days', 'Breaks', 'Leads/hr', 'Updates/hr', 'Revenue/hr', 'Conv %', 'Rev %']
      ];
      for (final item in data) {
        rows.add([
          item.name, item.role, item.assigned, item.worked, item.converted,
          item.revenue, item.updates, item.workTimeMinutes, item.breakTimeMinutes,
          item.activeDays, item.totalBreaks,
          item.leadsWorkedPerHour.toStringAsFixed(1),
          item.statusUpdatesPerHour.toStringAsFixed(1),
          item.revenuePerHour.toStringAsFixed(0),
          item.conversionContributionPercent.toStringAsFixed(1),
          item.revenueContributionPercent.toStringAsFixed(1),
        ]);
      }
      final csvString = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Performance_Report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);
      await Share.shareXFiles([XFile(file.path)], text: 'Performance Report CSV');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
         final isDark = Theme.of(context).brightness == Brightness.dark;
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: isDark ? const ColorScheme.dark(primary: Colors.blue) : const ColorScheme.light(primary: Colors.black),
           ),
           child: child!,
         );
       }
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }
}
