import 'package:flutter/material.dart';
import '../../data/models/staff_model.dart';

class StaffDetailDialog extends StatelessWidget {
  final StaffUser staff;

  const StaffDetailDialog({super.key, required this.staff});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: SingleChildScrollView( // Handle overflow for smaller screens
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Header with Icon
                   Row(
                       children: [
                           Container(
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                   color: _getRoleColor(staff.systemRole).withValues(alpha: 0.1),
                                   shape: BoxShape.circle
                               ),
                               child: Icon(Icons.person, color: _getRoleColor(staff.systemRole), size: 28),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                               child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                       Text(staff.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                       Text(_formatRole(staff.systemRole), style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                   ],
                               )
                           ),
                           Builder(
                             builder: (context) {
                               final isDeleted = staff.status == 'deleted';
                               final isInactive = staff.status == 'inactive' || (staff.status == 'active' && staff.active == false);
                               
                               final Color color;
                               final String label;
                               
                               if (isDeleted) {
                                 color = Colors.grey;
                                 label = 'Deleted';
                               } else if (isInactive) {
                                 color = Colors.red;
                                 label = 'Inactive';
                               } else {
                                 color = Colors.green;
                                 label = 'Active';
                               }
                               
                               return Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                   decoration: BoxDecoration(
                                       color: color.withValues(alpha: 0.1),
                                       borderRadius: BorderRadius.circular(8)
                                   ),
                                   child: Text(label, style: TextStyle(
                                       color: color,
                                       fontSize: 12, fontWeight: FontWeight.bold
                                   )),
                               );
                             }
                           )
                       ],
                   ),
          
                   const SizedBox(height: 24),
                   const Divider(height: 1),
                   const SizedBox(height: 24),
          
                   // Details Grid
                   _buildSectionTitle("Personal Information"),
                   const SizedBox(height: 12),
                   _buildDetailRow(Icons.email_outlined, "Email", staff.email, isDark),
                   _buildDetailRow(Icons.phone_outlined, "Phone", staff.phoneNo, isDark),
                   _buildDetailRow(Icons.badge_outlined, "Unique ID", staff.uniqueId, isDark),
          
                   const SizedBox(height: 24),
                   _buildSectionTitle("System & Team Info"),
                   const SizedBox(height: 12),
                   _buildDetailRow(Icons.admin_panel_settings_outlined, "System Role", staff.systemRole, isDark),
                   if (staff.groupName != null) _buildDetailRow(Icons.domain, "Group", staff.groupName!, isDark),
                   if (staff.teamName != null) _buildDetailRow(Icons.groups, "Team", staff.teamName!, isDark),
                   
                   // Additional conditional info
                   if (staff.teamsCount != null && staff.teamsCount! > 0)
                      _buildDetailRow(Icons.format_list_numbered, "Teams Managed", "${staff.teamsCount}", isDark),
                   if (staff.membersCount != null && staff.membersCount! > 0)
                      _buildDetailRow(Icons.people_outline, "Members Managed", "${staff.membersCount}", isDark),
          
                   const SizedBox(height: 32),
                   SizedBox(
                       width: double.infinity,
                       child: ElevatedButton(
                           style: ElevatedButton.styleFrom(
                               backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                               padding: const EdgeInsets.symmetric(vertical: 16)
                           ),
                           onPressed: () => Navigator.pop(context),
                           child: const Text("Close")
                       ),
                   )
                ],
            ),
          ),
        )
    );
  }

  Widget _buildSectionTitle(String title) {
      return Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5));
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
              children: [
                  Icon(icon, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              const SizedBox(height: 2),
                              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                          ],
                      )
                  )
              ],
          ),
      );
  }

  Color _getRoleColor(String role) {
      switch (role.toLowerCase()) {
          case 'admin': return Colors.red;
          case 'manager': return Colors.blue;
          case 'team_leader': return Colors.orange;
          case 'sales_executive': return Colors.green;
          default: return Colors.grey;
      }
  }

  String _formatRole(String role) {
      return role.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}
