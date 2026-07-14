import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/login_provider.dart';
import '../providers/task_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/notification_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';
import 'lead_profile_screen.dart';
import 'tasks_screen.dart';


class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  String _getOverdueLabel(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final due = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(due);
      if (diff.isNegative) {
        final d = -diff;
        if (d.inDays > 0) return "Due in ${d.inDays} days";
        return "Due in ${d.inHours} hrs ${d.inMinutes % 60} mins";
      } else {
        if (diff.inDays > 0) return "Overdue by ${diff.inDays} days";
        return "Overdue by ${diff.inHours} hrs ${diff.inMinutes % 60} mins";
      }
    } catch (_) {
      return "";
    }
  }

  bool _isOverdue(String? dateStr) {
    if (dateStr == null) return false;
    try {
      return DateTime.parse(dateStr).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(tasksProvider);
    final meetingState = ref.watch(meetingsProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;
    final hasTasks = permissions.hasModule(PermissionModules.TASK, userRole: userRole);
    final hasMeetings = permissions.hasModule(PermissionModules.MEETING, userRole: userRole);

    final pendingTasks = hasTasks ? taskState.tasks.where((t) {
      return t.status != 'Completed' && t.status != 'Done' && t.status != 'done';
    }).toList() : <dynamic>[]; // Empty if no permission

    // Only show upcoming meetings (not overdue)
    final upcomingMeetings = hasMeetings ? meetingState.meetings.where((m) {
      if (m.status != 'Scheduled') return false;
      try {
        return !DateTime.parse(m.scheduledAt).isBefore(DateTime.now());
      } catch (_) {
        return true;
      }
    }).toList() : <dynamic>[];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Reminders", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w800)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D324A) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: isDark ? Colors.white : Colors.black,
                  unselectedLabelColor: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.grey[500],
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.3),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2130) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("TASKS"),
                          if (pendingTasks.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: isDark ? Colors.blue : Colors.black, borderRadius: BorderRadius.circular(10)),
                              child: Text("${pendingTasks.length}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            )
                          ]
                        ],
                      ),
                    ),
                    const Tab(text: "MEETINGS"),
                    const Tab(text: "OTHERS"),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // TASKS TAB (Merged with Notifications)
            notificationsAsync.when(
              data: (notifications) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // Notifications first (Actionable alerts)
                    ...notifications.map((n) => _buildRefCard(
                          context: context,
                          title: n.title,
                          subtitle: n.message,
                          statusText: DateFormat('dd MMM, hh:mm a').format(n.createdAt),
                          isOverdue: false,
                          icon: n.type == 'task' ? Icons.assignment_outlined : Icons.notifications_none,
                          onView: () {
                            String? leadId;
                            if (n.data != null) {
                              final dataMap = n.data!;
                              leadId = dataMap['leadId']?.toString() ?? dataMap['lead_id']?.toString() ?? dataMap['leadID']?.toString();
                              if (leadId == null && dataMap['lead'] != null) {
                                final lead = dataMap['lead'];
                                if (lead is Map) {
                                  leadId = lead['_id']?.toString() ?? lead['id']?.toString();
                                } else if (lead is String) {
                                  leadId = lead;
                                }
                              }
                              if (leadId == null && dataMap['data'] != null) {
                                final innerData = dataMap['data'];
                                if (innerData is Map) {
                                  leadId = innerData['leadId']?.toString() ?? innerData['lead_id']?.toString() ?? innerData['leadID']?.toString();
                                  if (leadId == null && innerData['lead'] != null) {
                                    final lead = innerData['lead'];
                                    if (lead is Map) {
                                      leadId = lead['_id']?.toString() ?? lead['id']?.toString();
                                    } else if (lead is String) {
                                      leadId = lead;
                                    }
                                  }
                                }
                              }
                              if (leadId == null && dataMap['task'] != null) {
                                final taskData = dataMap['task'];
                                if (taskData is Map) {
                                  final leadVal = taskData['lead'];
                                  if (leadVal is Map) {
                                    leadId = leadVal['_id']?.toString() ?? leadVal['id']?.toString();
                                  } else if (leadVal is String) {
                                    leadId = leadVal;
                                  }
                                }
                              }
                              if (leadId == null && dataMap['meeting'] != null) {
                                final meetingData = dataMap['meeting'];
                                if (meetingData is Map) {
                                  final leadVal = meetingData['lead'];
                                  if (leadVal is Map) {
                                    leadId = leadVal['_id']?.toString() ?? leadVal['id']?.toString();
                                  } else if (leadVal is String) {
                                    leadId = leadVal;
                                  }
                                }
                              }
                            }
                            if (leadId != null && leadId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LeadProfileScreen(leadId: leadId!),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No lead associated with this notification')),
                              );
                            }
                          },
                        )),

                    // Regular Tasks
                    ...pendingTasks.map((task) {
                      final overdue = _isOverdue(task.dueDate);
                      final overdueLabel = _getOverdueLabel(task.dueDate);
                      return _buildRefCard(
                        context: context,
                        title: task.title,
                        subtitle: task.description ?? "No description",
                        statusText: overdueLabel,
                        isOverdue: overdue,
                        icon: Icons.assignment_outlined,
                        onView: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TasksScreen(),
                            ),
                          );
                        },
                      );
                    }),

                    if (notifications.isEmpty && pendingTasks.isEmpty)
                      _buildEmptyState("No pending tasks or alerts!", Icons.check_circle_outline)
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text("Error loading updates: $err")),
            ),

            // MEETINGS TAB (Upcoming Only)
            upcomingMeetings.isEmpty
                ? _buildEmptyState("No upcoming meetings found.", Icons.event_available)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: upcomingMeetings.length,
                    itemBuilder: (context, index) {
                      final meeting = upcomingMeetings[index];
                      final label = _getOverdueLabel(meeting.scheduledAt);

                      return _buildRefCard(
                        context: context,
                        title: meeting.subject,
                        subtitle: "With: ${meeting.lead?.name ?? 'N/A'}",
                        statusText: label,
                        isOverdue: false,
                        icon: Icons.calendar_today_outlined,
                        onView: () {
                          if (meeting.lead?.id != null && meeting.lead!.id.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadProfileScreen(leadId: meeting.lead!.id),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No lead associated with this meeting')),
                            );
                          }
                        },
                      );
                    },
                  ),

            // OTHERS TAB (Placeholder)
            _buildEmptyState("No other updates.", Icons.more_horiz),
          ],
        ),
      ),
    );
  }

  Widget _buildRefCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String statusText,
    required bool isOverdue,
    required IconData icon,
    required VoidCallback onView,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isOverdue 
        ? (isDark ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFFFF1F1)) 
        : Theme.of(context).cardColor;
    final statusColor = isOverdue ? Colors.red : Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue 
            ? Colors.red.withValues(alpha: 0.2) 
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          if (!isDark && !isOverdue)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOverdue 
                ? Colors.red.withValues(alpha: 0.05) 
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon, 
              color: isOverdue ? Colors.red : (isDark ? Colors.white70 : Colors.black54), 
              size: 20
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusText.isNotEmpty)
                  Text(
                    statusText, 
                    style: TextStyle(
                      color: statusColor, 
                      fontSize: 10, 
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )
                  ),
                const SizedBox(height: 2),
                Text(
                  title, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14, 
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  )
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle, 
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), 
                    fontSize: 12
                  )
                ),
              ],
            ),
          ),
          // View Link
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: Colors.red.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              "View", 
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }
}
