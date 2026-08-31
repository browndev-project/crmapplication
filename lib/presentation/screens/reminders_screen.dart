import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/notification_model.dart';
import '../providers/meeting_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/task_provider.dart';
import 'lead_profile_screen.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  String _getOverdueLabel(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final due = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(due);
      if (diff.isNegative) {
        final d = -diff;
        if (d.inDays > 0) {
          return "Due in ${d.inDays} days (${DateFormat('dd MMM, hh:mm a').format(due)})";
        }
        if (d.inHours > 0) {
          return "Due in ${d.inHours} hrs ${d.inMinutes % 60} mins";
        }
        return "Due in ${d.inMinutes} mins";
      } else {
        if (diff.inDays > 0) {
          return "Overdue by ${diff.inDays} days (${DateFormat('dd MMM, hh:mm a').format(due)})";
        }
        if (diff.inHours > 0) {
          return "Overdue by ${diff.inHours} hrs ${diff.inMinutes % 60} mins";
        }
        return "Overdue by ${diff.inMinutes} mins";
      }
    } catch (_) {
      return "";
    }
  }

  bool _isOverdue(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      return DateTime.parse(dateStr).toLocal().isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _handleNotificationNavigation(
      BuildContext context, WidgetRef ref, AppNotification n) {
    String? leadId;

    if (n.relationId != null && n.relationId!.isNotEmpty) {
      leadId = n.relationId;
    }

    if (leadId == null &&
        n.entityType.toLowerCase() == 'lead' &&
        n.entityId != null &&
        n.entityId!.isNotEmpty) {
      leadId = n.entityId;
    }

    if (leadId == null && n.data != null) {
      final dataMap = n.data!;
      if (dataMap['lead'] != null) {
        final lead = dataMap['lead'];
        if (lead is Map) {
          leadId = lead['_id']?.toString() ?? lead['id']?.toString();
        } else if (lead is String) {
          leadId = lead;
        }
      }
    }

    if (leadId == null && n.entityId != null && n.entityId!.isNotEmpty) {
      final taskState = ref.read(tasksProvider);
      final taskMatches =
          taskState.tasks.where((t) => t.id == n.entityId).toList();
      if (taskMatches.isNotEmpty && taskMatches.first.lead?.id != null) {
        leadId = taskMatches.first.lead!.id;
      }

      if (leadId == null) {
        final meetingState = ref.read(meetingsProvider);
        final meetingMatches =
            meetingState.meetings.where((m) => m.id == n.entityId).toList();
        if (meetingMatches.isNotEmpty &&
            meetingMatches.first.lead?.id != null) {
          leadId = meetingMatches.first.lead!.id;
        }
      }
    }

    if (leadId != null && leadId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LeadProfileScreen(
            leadId: leadId!,
            reminderNotification: n,
            initialTab: 'Reminder Detail',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              n.message.isNotEmpty ? "${n.title}: ${n.message}" : n.title),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Reminders",
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () => ref.refresh(notificationsProvider),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          final tabCategories = ['FOLLOW UPS', 'VISITS', 'MEETINGS', 'OTHERS'];

          List<AppNotification> getItemsForCategory(String category) {
            switch (category) {
              case 'FOLLOW UPS':
                return notifications.where((n) {
                  final t = (n.entityType.isNotEmpty ? n.entityType : n.sourceType).toLowerCase();
                  return t.contains('task') || t.contains('follow');
                }).toList();
              case 'VISITS':
                return notifications.where((n) {
                  final t = (n.entityType.isNotEmpty ? n.entityType : n.sourceType).toLowerCase();
                  return t.contains('visit');
                }).toList();
              case 'MEETINGS':
                return notifications.where((n) {
                  final t = (n.entityType.isNotEmpty ? n.entityType : n.sourceType).toLowerCase();
                  return t.contains('meeting');
                }).toList();
              case 'OTHERS':
                return notifications.where((n) {
                  final t = (n.entityType.isNotEmpty ? n.entityType : n.sourceType).toLowerCase();
                  return !t.contains('task') && !t.contains('follow') && !t.contains('visit') && !t.contains('meeting');
                }).toList();
              default:
                return [];
            }
          }

          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(notificationsProvider.future),
              child: ListView(
                children: [
                  const SizedBox(height: 150),
                  _buildEmptyState("No reminders found!", Icons.notifications_off_outlined),
                ],
              ),
            );
          }

          return DefaultTabController(
            length: tabCategories.length,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D324A) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      isScrollable: false,
                      padding: EdgeInsets.zero,
                      labelPadding: EdgeInsets.zero,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: isDark ? Colors.white : Colors.black,
                      unselectedLabelColor: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.grey[500],
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.2),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
                      indicator: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2130) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      dividerColor: Colors.transparent,
                      tabs: tabCategories.map((category) {
                        final items = getItemsForCategory(category);
                        return Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(category),
                              if (items.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: isDark ? Colors.blue : Colors.black, borderRadius: BorderRadius.circular(10)),
                                  child: Text("${items.length}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: tabCategories.map((category) {
                      final items = getItemsForCategory(category);
                      if (items.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: () async => ref.refresh(notificationsProvider.future),
                          child: ListView(
                            children: [
                              const SizedBox(height: 100),
                              _buildEmptyState("No $category reminders!", Icons.check_circle_outline),
                            ],
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async => ref.refresh(notificationsProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final n = items[index];
                            final dueString = n.dueAt ?? n.createdAt.toIso8601String();
                            final overdue = _isOverdue(dueString);
                            final overdueLabel = _getOverdueLabel(dueString);
                            IconData icon;
                            final tLower = (n.entityType.isNotEmpty ? n.entityType : n.sourceType).toLowerCase();
                            if (tLower.contains('task') || tLower.contains('follow')) {
                              icon = Icons.assignment_outlined;
                            } else if (tLower.contains('meeting')) {
                              icon = Icons.event_outlined;
                            } else if (tLower.contains('lead')) {
                              icon = Icons.person_outline;
                            } else if (tLower.contains('call')) {
                              icon = Icons.phone_outlined;
                            } else if (tLower.contains('visit')) {
                              icon = Icons.location_on_outlined;
                            } else {
                              icon = Icons.notifications_none_outlined;
                            }
                            return _buildRefCard(
                              context: context,
                              title: n.title,
                              subtitle: n.message,
                              statusText: overdueLabel.isNotEmpty ? overdueLabel : DateFormat('dd MMM, hh:mm a').format(n.createdAt),
                              isOverdue: overdue,
                              icon: icon,
                              onView: () => _handleNotificationNavigation(context, ref, n),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Error loading reminders: $err", style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton.icon(onPressed: () => ref.refresh(notificationsProvider), icon: const Icon(Icons.refresh), label: const Text("Retry"))
            ],
          ),
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
    final cardColor = isOverdue ? (isDark ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFFFF1F1)) : Theme.of(context).cardColor;
    final statusColor = isOverdue ? Colors.red : Colors.blueGrey;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverdue ? Colors.red.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1))),
        boxShadow: [if (!isDark && !isOverdue) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isOverdue ? Colors.red.withValues(alpha: 0.05) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: isOverdue ? Colors.red : (isDark ? Colors.white70 : Colors.black54), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusText.isNotEmpty) Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: Colors.red.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            child: const Text("View", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
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
