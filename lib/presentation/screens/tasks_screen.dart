import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/global_app_bar.dart';
import '../providers/task_provider.dart';
import '../widgets/task_create_dialog.dart'; // Import New Dialog
import '../../data/models/task_model.dart';
import 'lead_profile_screen.dart';
import '../../core/utils/date_utils.dart';

import '../providers/login_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';
import '../widgets/access_denied_widget.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _selectedTaskTab = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tasksProvider.notifier).fetchTasks(page: 1);
    });

  }

  @override
  void dispose() {
    super.dispose();
  }

  String _filterFromTab(int tab) {
    switch (tab) {
      case 1: return 'Not Started';
      case 2: return 'In Progress';
      case 3: return 'Completed';
      default: return 'All';
    }
  }


  void _loadMore() {
    final state = ref.read(tasksProvider);
    final pagination = state.pagination;
    if (!state.isLoading && 
        !state.isLoadingMore && 
        pagination != null && 
        pagination.hasNextPage) {
      debugPrint("TasksScreen: Loading more... next page: ${pagination.page + 1}");
      ref.read(tasksProvider.notifier).fetchTasks(page: pagination.page + 1);
    }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(tasksProvider);
    final user = ref.watch(loginProvider).user;
    final topBarColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;

    final permissions = ref.watch(permissionsProvider);
    if (!permissions.hasModule(PermissionModules.TASK, userRole: user?.systemRole) ||
        !permissions.hasPermission(PermissionModules.TASKS_VIEW, userRole: user?.systemRole)) {
      return const Scaffold(
        extendBody: true,
        appBar: GlobalAppBar(title: 'Follow ups'),
        body: AccessDeniedWidget(
          sectionName: "Follow ups",
          showAppBar: false,
        ),
      );
    }

    // Server already filtered based on selected tab, locally query search & status as safety/cache fallback
    final filteredTasks = state.tasks.where((task) {
      // 1. Filter by status tab
      if (state.selectedFilter == 'Not Started') {
        final isNotStarted = task.status == 'Not Started' || task.status == 'Pending';
        if (!isNotStarted) return false;
      } else if (state.selectedFilter == 'In Progress') {
        if (task.status != 'In Progress') return false;
      } else if (state.selectedFilter == 'Completed') {
        final isCompleted = task.status == 'Completed' || task.status == 'Done';
        if (!isCompleted) return false;
      }

      // 2. Filter by search query
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final titleMatch = task.title.toLowerCase().contains(q);
      final leadMatch = task.lead != null && task.lead!.name.toLowerCase().contains(q);
      return titleMatch || leadMatch;
    }).toList();


    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: const GlobalAppBar(title: 'Follow ups'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: topBarColor,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Follow ups',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search follow ups',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildAnimatedTaskTabs(state),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: _buildTaskList(filteredTasks, state, context),
          ),
        ],
      ),
    );
  }



  Widget _buildAnimatedTaskTabs(dynamic state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tabs = [
      {
        'label': 'All · ${state.totalCount}',
        'color': isDark ? Colors.white : const Color(0xFF0F172A),
        'textColor': isDark ? Colors.black87 : Colors.white,
        'borderColor': Colors.transparent,
      },
      {
        'label': 'Not started · ${state.notStartedCount}',
        'color': isDark ? const Color(0xFFD97706).withValues(alpha: 0.12) : const Color(0xFFFFF7ED),
        'textColor': const Color(0xFFD97706),
        'borderColor': const Color(0xFFD97706).withValues(alpha: 0.4),
      },
      {
        'label': 'In Progress · ${state.inProgressCount}',
        'color': isDark ? Colors.blueAccent.withValues(alpha: 0.12) : const Color(0xFFEFF6FF),
        'textColor': Colors.blue,
        'borderColor': Colors.blue.withValues(alpha: 0.4),
      },
      {
        'label': 'Completed · ${state.completedCount}',
        'color': isDark ? const Color(0xFF059669).withValues(alpha: 0.12) : const Color(0xFFF0FDF4),
        'textColor': const Color(0xFF059669),
        'borderColor': const Color(0xFF059669).withValues(alpha: 0.4),
      },
    ];

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final isSelected = _selectedTaskTab == index;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTaskTab = index;
                  });
                  ref.read(tasksProvider.notifier).setFilter(_filterFromTab(index));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? tab['color'] as Color : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? (tab['borderColor'] as Color) 
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    tab['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? tab['textColor'] as Color : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, dynamic state, BuildContext context) {
      if (state.isLoading && tasks.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      
      if (tasks.isEmpty) {
         return Center(
             child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                     Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[300]),
                     const SizedBox(height: 16),
                     Text("No follow ups found", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                 ],
             )
         );
      }

      return RefreshIndicator(
        onRefresh: () async => ref.read(tasksProvider.notifier).refresh(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 300) {
              _loadMore();
            }
            return false;
          },
          child: ListView.separated(
             padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
             itemCount: tasks.length + 1, // Add 1 for footer (loader or end-of-list)
             separatorBuilder: (c, i) => const SizedBox(height: 12),
             itemBuilder: (c, i) {
               if (i == tasks.length) {
                 if (state.isLoadingMore) {
                   return const Center(
                     child: Padding(
                       padding: EdgeInsets.all(24), 
                       child: CircularProgressIndicator(strokeWidth: 2)
                     )
                   );
                 }
                 
                  if (state.pagination != null && 
                      !state.pagination!.hasNextPage && 
                      tasks.isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, color: Theme.of(context).hintColor.withValues(alpha: 0.2), size: 28),
                            const SizedBox(height: 12),
                            Text(
                              "All tasks loaded",
                              style: TextStyle(
                                color: Theme.of(context).hintColor.withValues(alpha: 0.5), 
                                fontSize: 13,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                 }
                 return const SizedBox(height: 20);
               }
               return _TaskItem(task: tasks[i]);
             },
          ),
        ),
      );

  }





}
class _TaskItem extends ConsumerWidget {
    final Task task;
    const _TaskItem({required this.task});
    
    @override
    Widget build(BuildContext context, WidgetRef ref) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dueDate = DateTimeUtils.parseSafe(task.dueDate);
        final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && task.status != 'Completed';
        
        final accentColor = task.status == 'Completed'
            ? const Color(0xFF059669)
            : (isOverdue ? const Color(0xFFDC2626) : const Color(0xFFD97706));

        final displayName = task.lead?.name ?? '?';

        return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
                  width: 1.0,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accent color strip on the left edge
                    Container(
                      width: 5,
                      color: accentColor,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar circle/box
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.blue[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: isDark ? Colors.blueAccent : const Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title and Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (task.lead != null)
                                        Text(
                                          "With: ${task.lead!.name}",
                                          style: TextStyle(
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusBadge(task.status, isOverdue, isDark),
                              ],
                            ),
                            if (task.description != null && task.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                task.description!,
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100),
                            const SizedBox(height: 12),
                            // Date row with custom relative time on the same line, and action buttons on the right
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: isOverdue ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[500]),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              dueDate != null
                                                  ? "${_formatDate(dueDate)} · ${_formatTime(dueDate)}"
                                                  : 'No Due Date',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isOverdue ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (dueDate != null) ...[
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 20.0),
                                          child: Text(
                                            _getCustomRelativeTime(dueDate),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isOverdue ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                              fontWeight: isOverdue ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (task.lead != null && ref.watch(permissionsProvider).can(PermissionModules.LEADS, permission: PermissionModules.LEADS_VIEW, userRole: ref.watch(loginProvider).user?.systemRole))
                                      _buildSmallOutlineActionButton(
                                        icon: Icons.remove_red_eye,
                                        color: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => LeadProfileScreen(
                                                leadId: task.lead!.id,
                                                name: task.lead!.name,
                                                phone: '',
                                                details: 'Task Ref: ${task.title}',
                                              ),
                                            ),
                                          );
                                        },
                                        isDark: isDark,
                                      ),
                                    const SizedBox(width: 6),
                                    if (ref.watch(permissionsProvider).can(PermissionModules.TASK, permission: PermissionModules.TASKS_UPDATE, userRole: ref.watch(loginProvider).user?.systemRole))
                                      _buildSmallOutlineActionButton(
                                        icon: Icons.edit_outlined,
                                        color: Colors.blue,
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => TaskCreateDialog(task: task),
                                          );
                                        },
                                        isDark: isDark,
                                      ),
                                    const SizedBox(width: 6),
                                    if (ref.watch(permissionsProvider).can(PermissionModules.TASK, permission: PermissionModules.TASKS_DELETE, userRole: ref.watch(loginProvider).user?.systemRole))
                                      _buildSmallOutlineActionButton(
                                        icon: Icons.delete_outline_rounded,
                                        color: Colors.red,
                                        onTap: () => _confirmDelete(context, ref, task.id),
                                        isDark: isDark,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        );
    }

    Widget _buildSmallOutlineActionButton({
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      required bool isDark,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
    }

    String _getCustomRelativeTime(DateTime dateTime) {
      final now = DateTime.now();
      final difference = dateTime.difference(now);
      final isPast = difference.isNegative;
      final absDiff = difference.abs();
      
      final days = absDiff.inDays;
      final hours = absDiff.inHours % 24;
      
      String timeStr = '';
      if (days > 0) {
        timeStr += '$days day${days > 1 ? 's' : ''}';
        if (hours > 0) {
          timeStr += ' $hours hour${hours > 1 ? 's' : ''}';
        }
      } else {
        if (hours > 0) {
          timeStr += '$hours hour${hours > 1 ? 's' : ''}';
        } else {
          final minutes = absDiff.inMinutes % 60;
          timeStr += '$minutes minute${minutes > 1 ? 's' : ''}';
        }
      }
      
      if (isPast) {
        return '$timeStr ago';
      } else {
        String formatted = timeStr;
        if (days > 0 && hours > 0) {
          formatted = '$days day${days > 1 ? 's' : ''} and $hours hour${hours > 1 ? 's' : ''}';
        }
        return '$formatted after';
      }
    }
    
    void _confirmDelete(BuildContext context, WidgetRef ref, String taskId) {
        showDialog(
            context: context, 
            builder: (context) {
                return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    title: const Text('Delete Follow up?', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('Are you sure you want to delete this follow up? This action cannot be undone.', style: TextStyle(fontSize: 13)),
                    actions: [
                         TextButton(
                             onPressed: () => Navigator.pop(context),
                             style: TextButton.styleFrom(foregroundColor: Colors.grey),
                             child: const Text('Cancel')
                         ),
                         ElevatedButton(
                             onPressed: () {
                                 Navigator.pop(context);
                                 ref.read(tasksProvider.notifier).deleteTask(taskId);
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Follow up deleted successfully')));
                             }, 
                             style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                             ),
                             child: const Text('Delete')
                         ),
                    ],
                );
            }
        );
    }
    
    String _formatDate(DateTime date) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${date.day} ${months[date.month - 1]}";
    }
    
    String _formatTime(DateTime date) {
        final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
        final minute = date.minute.toString().padLeft(2, '0');
        final amPm = date.hour >= 12 ? 'PM' : 'AM';
        return "$hour:$minute $amPm";
    }

    Widget _buildStatusBadge(String status, bool isOverdue, bool isDark) {
      Color color;
      if (status == 'Completed') {
        color = const Color(0xFF059669);
      } else if (isOverdue) {
        color = const Color(0xFFDC2626);
      } else {
        color = const Color(0xFFD97706);
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withValues(alpha: 0.24),
            width: 1,
          ),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      );
    }
}
