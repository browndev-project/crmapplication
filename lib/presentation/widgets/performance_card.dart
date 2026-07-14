import 'package:flutter/material.dart';
import '../../data/models/performance_report_model.dart';

class PerformanceCard extends StatelessWidget {
  final PerformanceReportModel report;

  const PerformanceCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
 isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Header: Name & Role
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getAvatarColor(report.name),
                  child: Text(
                    report.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        report.role.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                _buildRevenueBadge(context, report.revenue),
              ],
            ),
          ),
          
          Divider(height: 1, color: borderColor),
          
          // Metrics Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Row 1: Funnel
                Row(
                  children: [
                    Expanded(child: _buildMetric(context, 'Assigned', '${report.assigned}', Icons.assignment_ind, Colors.blue)),
                    Expanded(child: _buildMetric(context, 'Worked', '${report.worked}', Icons.work_history, Colors.orange)),
                    Expanded(child: _buildMetric(context, 'Converted', '${report.converted}', Icons.verified, Colors.green)),
                  ],
                ),
                const SizedBox(height: 16),
                 // Row 2: Time & Updates
                Row(
                  children: [
                     Expanded(child: _buildMetric(context, 'Updates', '${report.updates}', Icons.update, Colors.purple)),
                     Expanded(child: _buildMetric(context, 'Work Time', _formatDuration(report.workTimeMinutes), Icons.timer, Colors.teal)),
                     Expanded(child: _buildMetric(context, 'Break Time', _formatDuration(report.breakTimeMinutes), Icons.coffee, Colors.brown)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildRevenueBadge(BuildContext context, int revenue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('REVENUE', style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold)),
          Text(
            '₹$revenue', // Assuming currency based on region usually
            style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Color _getAvatarColor(String name) {
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    return colors[name.length % colors.length];
  }
}
