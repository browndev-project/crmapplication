import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/report_service.dart';
import '../../../core/services/staff_service.dart';
import '../../../data/models/overall_report_model.dart';
import '../../../data/models/staff_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../providers/permissions_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../providers/login_provider.dart';
import '../../widgets/access_denied_widget.dart';

import '../../../core/utils/formatters.dart';

// Providers
final staffListProvider = FutureProvider.family<List<StaffUser>, String>((ref, role) async {
  if (role.isEmpty) return [];
  final service = StaffService(); // Using direct instance as it's not providified yet or easy to mix
  // 'staff_service.dart' defines fetchStaff taking 'systemRole'. 
  // We need to map UI roles to system roles if needed, or pass directly.
  // Assuming 'Sales Manager' -> 'sales_manager', 'Sales Executive' -> 'sales_executive'
  
  String systemRole = '';
  if (role == 'Sales Manager') systemRole = 'sales_manager';
  if (role == 'Sales Executive') systemRole = 'sales_executive';
  
  final response = await service.fetchStaff(role: systemRole, limit: 100); 
  return response.users;
});

final overallReportProvider = FutureProvider.family<OverallReportModel, String>((ref, employeeId) async {
  if (employeeId.isEmpty) throw 'Select an employee';
  final service = ref.read(reportServiceProvider);
  return service.fetchOverallReport(employeeId);
});


class OverallReportScreen extends ConsumerStatefulWidget {
  const OverallReportScreen({super.key});

  @override
  ConsumerState<OverallReportScreen> createState() => _OverallReportScreenState();
}

class _OverallReportScreenState extends ConsumerState<OverallReportScreen> {
  String _selectedDesignation = 'Sales Executive';
  String? _selectedEmployeeId;

  final List<String> _designations = ['Sales Manager', 'Sales Executive'];

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

        appBar: GlobalAppBar(title: "Overall Report"),
        body: AccessDeniedWidget(
          sectionName: "Overall Report",
          showAppBar: false,
        ),
      );
    }

    final staffAsync = ref.watch(staffListProvider(_selectedDesignation));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentReport = _selectedEmployeeId != null
        ? ref.watch(overallReportProvider(_selectedEmployeeId!)).maybeWhen(data: (d) => d, orElse: () => null)
        : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50], 
      appBar: GlobalAppBar(
        title: 'Overall Report',
        actions: [
          if (currentReport != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
              onPressed: () => _exportAsCSV(currentReport),
            ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                _selectedDesignation == 'Sales Executive'
                    ? 'Overall Report - Sales Executives'
                    : 'Overall Report - Sales Managers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),

            // Subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Select an employee to see overall status. Download CSV for entire designation.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ),

            // Download Button (Black)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: staffAsync.maybeWhen(
                data: (users) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: users.isEmpty ? null : () => _downloadOverallCSV(users),
                    icon: const Icon(Icons.download, color: Colors.white, size: 18),
                    label: const Text(
                      'DOWNLOAD OVERALL CSV',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.black38,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                  ),
                ),
                orElse: () => const SizedBox(),
              ),
            ),

            // Dropdowns Card Container
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Designation Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDesignation,
                        dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Designation',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _designations
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d, style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedDesignation = val;
                              _selectedEmployeeId = null; // Reset employee
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Employee Dropdown
                    Expanded(
                      child: staffAsync.when(
                        data: (users) {
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedEmployeeId,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Employee',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: users
                                .map((u) => DropdownMenuItem(
                                      value: u.id,
                                      child: Text(
                                        u.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedEmployeeId = val;
                              });
                            },
                            hint: Text(
                              "Select Employee",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ),
                          );
                        },
                        loading: () => Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        error: (err, _) => Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "Error loading staff",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            if (_selectedEmployeeId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildReportContent(),
              )
            else 
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Column(
                     children: [
                        Icon(Icons.touch_app, size: 48, color: isDark ? Colors.white12 : Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("Select an employee to view report", style: TextStyle(color: isDark ? Colors.white24 : Colors.grey[400])),
                     ]
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    final reportAsync = ref.watch(overallReportProvider(_selectedEmployeeId!));

    return reportAsync.when(
      data: (report) {
        return Column(
          children: [
            // Employee Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6366f1), const Color(0xFF818cf8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6366f1).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))
                ]
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.indigo[50],
                      child: Text(
                        report.employee.name.isNotEmpty ? report.employee.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Color(0xFF6366f1), fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(report.employee.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Colors.white.withValues(alpha: 0.2),
                                 borderRadius: BorderRadius.circular(6)
                               ),
                               child: Text(report.employee.designation, style: const TextStyle(fontSize: 11, color: Colors.white)),
                             )
                           ],
                         ),
                         const SizedBox(height: 8),
                         Row(
                           children: [
                             const Icon(Icons.phone, size: 14, color: Colors.white70),
                             const SizedBox(width: 4),
                             Text(report.employee.phoneNo, style: const TextStyle(fontSize: 13, color: Colors.white)),
                             const SizedBox(width: 16),
                             const Icon(Icons.email, size: 14, color: Colors.white70),
                             const SizedBox(width: 4),
                             Flexible(child: Text(report.employee.email, style: const TextStyle(fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis)),
                           ],
                         )
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Stats Row (Totals)
            Row(
              children: [
                if (ref.watch(permissionsProvider).hasModule(PermissionModules.LEADS, userRole: ref.read(loginProvider).user?.systemRole))
                _buildTotalCard("Leads Assigned", report.leads.totalAssigned.toString(), const Color(0xFF3B82F6), Icons.person_add),
                if (ref.watch(permissionsProvider).hasModule(PermissionModules.LEADS, userRole: ref.read(loginProvider).user?.systemRole))
                const SizedBox(width: 12),
                
                if (ref.watch(permissionsProvider).hasModule(PermissionModules.TASK, userRole: ref.read(loginProvider).user?.systemRole))
                _buildTotalCard("Total Tasks", report.tasks.total.toString(), const Color(0xFF10B981), Icons.task_alt),
                if (ref.watch(permissionsProvider).hasModule(PermissionModules.TASK, userRole: ref.read(loginProvider).user?.systemRole))
                const SizedBox(width: 12),

                if (ref.watch(permissionsProvider).hasModule(PermissionModules.MEETING, userRole: ref.read(loginProvider).user?.systemRole))
                _buildTotalCard("Total Meetings", report.meetings.total.toString(), const Color(0xFF8B5CF6), Icons.calendar_month),
              ],
            ),

            const SizedBox(height: 32),

            // Detailed Overviews
            // Detailed Overviews
            if (ref.watch(permissionsProvider).hasModule(PermissionModules.LEADS, userRole: ref.read(loginProvider).user?.systemRole)) ...[
              _buildSectionTitle("Leads Overview"),
              _buildStatusList(report.leads.byStatus, const Color(0xFF3B82F6)),
            ],
            
            const SizedBox(height: 24),
            
            if (ref.watch(permissionsProvider).hasModule(PermissionModules.TASK, userRole: ref.read(loginProvider).user?.systemRole)) ...[
              _buildSectionTitle("Tasks Overview"),
              _buildStatusList(report.tasks.byStatus, const Color(0xFF10B981)),
            ],

            const SizedBox(height: 24),
            
            if (ref.watch(permissionsProvider).hasModule(PermissionModules.MEETING, userRole: ref.read(loginProvider).user?.systemRole)) ...[
              _buildSectionTitle("Meetings Overview"),
              _buildStatusList(report.meetings.byStatus, const Color(0xFF8B5CF6)),
            ],
            
            const SizedBox(height: 48), // Bottom padding
          ],
        );
      },
      loading: () => const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),
      error: (err, _) => Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red)))),
    );
  }

  Widget _buildTotalCard(String title, String count, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: isDark ? 0.05 : 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
               padding: const EdgeInsets.all(6),
               decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
               child: Icon(icon, size: 16, color: color),
            ),
            const Spacer(),
            Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87, height: 1.0)),
                 const SizedBox(height: 4),
                 Text(title, style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey[600], fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
               ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
    );
  }

  Widget _buildStatusList(List<StatusCount> statuses, Color baseColor) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     if (statuses.isEmpty) {
       return Container(
         width: double.infinity,
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50], 
           borderRadius: BorderRadius.circular(8),
           border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!)
         ),
         child: const Center(child: Text("No data available", style: TextStyle(color: Colors.grey))),
       );
     }

     return SizedBox(
       height: 100,
       child: ListView.separated(
         scrollDirection: Axis.horizontal,
         itemCount: statuses.length,
         separatorBuilder: (_, _) => const SizedBox(width: 12),
         itemBuilder: (context, index) {
            final item = statuses[index];
            return Container(
              width: 130,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: baseColor.withValues(alpha: isDark ? 0.02 : 0.05), blurRadius: 8, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(toTitleCase(item.status), style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[600], fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(item.count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: baseColor)),
                ],
              ),
            );
         },
       ),
        );
  }

  Future<void> _exportAsCSV(OverallReportModel report) async {
    try {
      final rows = <List<dynamic>>[];
      rows.add(['Section', 'Status', 'Count']);

      if (report.leads.byStatus.isNotEmpty) {
        rows.add(['Leads Assigned (Total: ${report.leads.totalAssigned})', '', '']);
        for (final s in report.leads.byStatus) {
          rows.add(['Leads', s.status, s.count]);
        }
      }

      if (report.tasks.byStatus.isNotEmpty) {
        rows.add(['Tasks (Total: ${report.tasks.total})', '', '']);
        for (final s in report.tasks.byStatus) {
          rows.add(['Tasks', s.status, s.count]);
        }
      }

      if (report.meetings.byStatus.isNotEmpty) {
        rows.add(['Meetings (Total: ${report.meetings.total})', '', '']);
        for (final s in report.meetings.byStatus) {
          rows.add(['Meetings', s.status, s.count]);
        }
      }

      final csvString = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Overall_Report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);
      await Share.shareXFiles([XFile(file.path)], text: 'Overall Report CSV');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadOverallCSV(List<StaffUser> users) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing Overall CSV...'), duration: Duration(seconds: 2)),
      );

      final reports = await Future.wait(
        users.map((u) => ref.read(reportServiceProvider).fetchOverallReport(u.id))
      );

      final rows = <List<dynamic>>[];
      rows.add([
        'Name',
        'Phone',
        'Email',
        'Total Leads Assigned',
        'Total Tasks',
        'Total Meetings',
      ]);

      for (final report in reports) {
        rows.add([
          report.employee.name,
          report.employee.phoneNo,
          report.employee.email,
          report.leads.totalAssigned,
          report.tasks.total,
          report.meetings.total,
        ]);
      }

      final csvString = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Overall_Report_${_selectedDesignation.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);
      await Share.shareXFiles([XFile(file.path)], text: 'Overall CSV for $_selectedDesignation');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Overall export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
