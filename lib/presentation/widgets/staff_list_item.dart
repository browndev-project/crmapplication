import 'package:flutter/material.dart';
import '../../../core/utils/roles.dart';
import '../../data/models/staff_model.dart';

class StaffListItem extends StatelessWidget {
  final StaffUser staff;
  final VoidCallback? onTap;

  const StaffListItem({
    super.key,
    required this.staff,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data from model
    final name = staff.name;
    final role = staff.systemRole;
 staff.status == 'active' && staff.active == true;
    final isInactive = staff.status == 'inactive' || (staff.status == 'active' && staff.active == false);
    final isDeleted = staff.status == 'deleted';

    final Color badgeBgColor;
    final Color badgeTextColor;
    final String statusLabel;

    if (isDeleted) {
      badgeBgColor = Colors.grey.shade100;
      badgeTextColor = Colors.grey;
      statusLabel = 'Deleted';
    } else if (isInactive) {
      badgeBgColor = Colors.red.shade50;
      badgeTextColor = Colors.red;
      statusLabel = 'Inactive';
    } else {
      badgeBgColor = Colors.green.shade50;
      badgeTextColor = Colors.green;
      statusLabel = 'Active';
    }
    final email = staff.email;

    // Role Colors (Pastel Theme)
    final roleColors = _getRoleColors(context, role);
    final bgColor = roleColors['bg']!;
    final textColor = roleColors['text']!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          // Subtle shadow for lift
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Squircle Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status Dot
                     Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.bold, 
                            color: badgeTextColor
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Text(
                       role.replaceAll('_', ' ').toUpperCase(),
                       style: TextStyle(
                         fontSize: 10,
                         fontWeight: FontWeight.w600,
                         color: Theme.of(context).textTheme.bodySmall?.color,
                         letterSpacing: 0.5
                       ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Contact Row
                  Row(
                    children: [
                      /* Phone removed as it's not in model yet
                      if (phone.isNotEmpty) ...[
                        Icon(Icons.phone, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                      ], 
                      */
                      if (email.isNotEmpty) 
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.email, size: 12, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                ],
              ),
            ),

             // Call Button (Only if phone exists, which implies logic update later or check if I can assume it exists)
             /*
            if (phone.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _launchDialer(phone),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                     ...
                  ),
                ),
              ),
             */
          ],
        ),
      ),
    );
  }



  Map<String, Color> _getRoleColors(BuildContext context, String role) {
    switch (role) {
      case SystemRoles.SALES_MANAGER:
        return {'bg': Colors.purple.shade50, 'text': Colors.purple.shade700};
      case SystemRoles.TEAM_LEADER:
        return {'bg': Colors.blue.shade50, 'text': Colors.blue.shade700};
      case SystemRoles.SALES_EXECUTIVE:
        return {'bg': Colors.orange.shade50, 'text': Colors.orange.shade800};
      default:
        return {
          'bg': Theme.of(context).dividerColor.withValues(alpha: 0.1),
          'text': Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87
        };
    }
  }
}
