import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/todays_report_model.dart';
import '../../data/models/status_model.dart';
import '../../core/utils/formatters.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../core/constants/permission_constants.dart';

class EmployeeReportCard extends ConsumerWidget {
  final EmployeeReportV2 employee;
  final List<LeadStatus> activeStatuses;

  const EmployeeReportCard({
    super.key, 
    required this.employee,
    required this.activeStatuses, // Required now
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
   isDark ? const Color(0xFF1E1E1E) : Colors.white;
 isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Header: Name & Designation
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getAvatarColor(employee.name),
                  child: Text(
                    employee.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                      ),
                      Text(
                        employee.designation,
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (ref.watch(permissionsProvider).hasModule(PermissionModules.LEADS, userRole: ref.read(loginProvider).user?.systemRole))
                   _buildCompactBadge(context, 'Worked', employee.leadsWorkedToday, Colors.blue),
              ],
            ),
          ),
          
          Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          
          // Stats Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Fixed Items - Wrapped in SizedBox for consistent width
                if (ref.watch(permissionsProvider).hasModule(PermissionModules.LEADS, userRole: ref.read(loginProvider).user?.systemRole))
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 100) / 3,
                    child: _buildStatItem(context, 'Assigned', employee.assignedLeadsToday, null)
                  ),
                
                if (ref.watch(permissionsProvider).hasModule(PermissionModules.TASK, userRole: ref.read(loginProvider).user?.systemRole))
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 100) / 3,
                    child: _buildStatItem(context, 'Tasks', employee.tasksCompletedToday, null)
                  ),
                
                // Dynamic Status Items
                if (ref.watch(permissionsProvider).hasModule(PermissionModules.LEADS, userRole: ref.read(loginProvider).user?.systemRole))
                  ...activeStatuses.map((status) {
                     final rawCount = employee.statusCounts[status.name];
                     int count = 0;
                     if (rawCount is int) {
                       count = rawCount;
                     } else if (rawCount is String) {
                       count = int.tryParse(rawCount) ?? 0;
                     }
                     
                     return SizedBox(
                        width: (MediaQuery.of(context).size.width - 100) / 3,
                        child: _buildStatItem(
                          context, 
                          toTitleCase(status.name), 
                          count, 
                          _getStatusColor(status.backgroundColor)
                        )
                     );
                  }),
              ],
            ),
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String bgString) {
    if (bgString.contains('blue')) return Colors.blue;
    if (bgString.contains('green')) return Colors.green;
    if (bgString.contains('purple')) return Colors.purple;
    if (bgString.contains('orange')) return Colors.orange;
    if (bgString.contains('red')) return Colors.red;
    if (bgString.contains('gray') || bgString.contains('grey')) return Colors.grey;
    if (bgString.contains('teal')) return Colors.teal;
    if (bgString.contains('cyan')) return Colors.cyan;
    if (bgString.contains('indigo')) return Colors.indigo;
    if (bgString.contains('amber')) return Colors.amber;
    return Colors.blue; // Default
  }

  Widget _buildStatItem(BuildContext context, String label, int value, Color? color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = color ?? (isDark ? Colors.white70 : Colors.black87);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        ),
      ],
    );
  }

  Widget _buildCompactBadge(BuildContext context, String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold)),
          Text('$value', style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    return colors[name.length % colors.length];
  }
}
