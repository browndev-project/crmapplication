import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart'; // Verify path
import '../providers/meeting_provider.dart'; // Verify path
import '../providers/login_provider.dart';
import '../screens/reminders_screen.dart'; // Verify path

class ReminderActionWidget extends ConsumerWidget {
  const ReminderActionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch providers to get counts
    // Note: This relies on the providers having data loaded. 
    // If dashboard loads them, great. If not, we might check if they are loaded or rely on dashboard data if available.
    // For now, let's assume dashboard startup fetches or we might trigger a background fetch here if needed.
    // Ideally, we bind to the counts available.
    
    // Watch login provider for user info
    final loginState = ref.watch(loginProvider);
    final user = loginState.user;
    final userEmail = user?.email ?? '';
    final userId = user?.id ?? '';

    final tasksState = ref.watch(tasksProvider);
    final meetingsState = ref.watch(meetingsProvider);
    
    // Calculate Pending Count
    // Assuming 'tasks' list contains user's tasks. 
    // Filter logic: Status != 'Completed'
    final pendingTasks = tasksState.tasks.where((t) => t.status != 'Completed' && t.status != 'Done').length;
    
    // Calculate Scheduled Meetings
    // Filter by user email/id to match RemindersScreen logic
    final upcomingMeetings = meetingsState.meetings.where((m) {
        final isScheduled = m.status == 'Scheduled';
        final isMyMeeting = m.employeeEmail == userEmail || (m.createdBy == userId);
        return isScheduled && isMyMeeting;
    }).length;
    
    final totalCount = pendingTasks + upcomingMeetings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const RemindersScreen()));
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.checklist_rtl_rounded, size: 24, color: isDark ? Colors.white : Colors.black87),
              if (totalCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Center(
                      child: Text(
                         totalCount > 9 ? '9' : '$totalCount',
                         style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}

