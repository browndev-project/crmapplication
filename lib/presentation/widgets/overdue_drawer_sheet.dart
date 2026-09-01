import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/admin_dashboard_service.dart';
import '../../core/services/task_service.dart';
import '../../core/services/meeting_service.dart';
import '../../core/services/visit_service.dart';
import '../../data/models/task_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/meeting_model.dart';
import '../../data/models/visit_model.dart';
import '../screens/lead_profile_screen.dart';
import 'task_create_dialog.dart';
import 'meeting_create_dialog.dart';
import 'visit_edit_dialog.dart';

enum OverdueType { task, meeting, visit }

class OverdueDrawerSheet extends StatefulWidget {
  final OverdueType type;

  const OverdueDrawerSheet({super.key, required this.type});

  @override
  State<OverdueDrawerSheet> createState() => _OverdueDrawerSheetState();
}

class _OverdueDrawerSheetState extends State<OverdueDrawerSheet> {
  final _adminService = AdminDashboardService();
  final _taskService = TaskService();
  final _meetingService = MeetingService();
  final _visitService = VisitService();

  bool _isLoading = true;
  String? _error;
  List<dynamic> _items = [];
  String _selectedEmployee = 'All Employees';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<dynamic> fetched = [];
      switch (widget.type) {
        case OverdueType.task:
          fetched = await _adminService.fetchOverdueTasks();
          break;
        case OverdueType.meeting:
          fetched = await _adminService.fetchOverdueMeetings();
          break;
        case OverdueType.visit:
          fetched = await _adminService.fetchOverdueVisits();
          break;
      }
      if (mounted) {
        setState(() {
          _items = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getEmployeeName(dynamic item) {
    if (widget.type == OverdueType.task) {
      final t = item as Task;
      return t.assignedTo?.name ?? 'Unassigned';
    } else if (widget.type == OverdueType.meeting) {
      final m = item as Meeting;
      // Meetings use employeeEmail or host name
      return m.host ?? m.employeeEmail ?? 'Unassigned';
    } else {
      final v = item as Visit;
      return v.createdBy?.name ?? 'Unassigned';
    }
  }

  List<String> _getEmployeeList() {
    final Set<String> names = {'All Employees'};
    for (var item in _items) {
      names.add(_getEmployeeName(item));
    }
    return names.toList()..sort();
  }

  String _formatOverdueDuration(String dateStr) {
    if (dateStr.isEmpty) return '';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return '';
    final now = DateTime.now();
    if (now.isBefore(parsed)) return '';
    final diff = now.difference(parsed);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m Overdue';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m Overdue';
    } else {
      return '${minutes}m Overdue';
    }
  }

  String _formatDisplayDate(String dateStr) {
    if (dateStr.isEmpty) return 'No Date';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  Future<void> _handleDelete(dynamic item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Overdue Item'),
        content: Text('Are you sure you want to delete this ${widget.type.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        if (widget.type == OverdueType.task) {
          await _taskService.deleteTask((item as Task).id);
        } else if (widget.type == OverdueType.meeting) {
          await _meetingService.deleteMeeting((item as Meeting).id);
        } else {
          await _visitService.deleteVisit((item as Visit).id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.type.name.toUpperCase()} deleted successfully.')),
          );
          _loadItems();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete item: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _handleEdit(dynamic item) {
    Widget dialog;
    if (widget.type == OverdueType.task) {
      dialog = TaskCreateDialog(task: item as Task);
    } else if (widget.type == OverdueType.meeting) {
      dialog = MeetingCreateDialog(meeting: item as Meeting);
    } else {
      final v = item as Visit;
      dialog = VisitEditDialog(leadId: v.lead?.id ?? '', visit: v);
    }

    showDialog(
      context: context,
      builder: (context) => dialog,
    ).then((_) {
      _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String title;
    final IconData icon;
    final Color iconColor;


    switch (widget.type) {
      case OverdueType.task:
        title = 'Overdue Follow Ups';
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.red;
        break;
      case OverdueType.meeting:
        title = 'Overdue Meetings';
        icon = Icons.event_busy_rounded;
        iconColor = Colors.orange;
        break;
      case OverdueType.visit:
        title = 'Overdue Visits';
        icon = Icons.location_off_rounded;
        iconColor = Colors.orange;
        break;
    }

    final filteredItems = _items.where((item) {
      if (_selectedEmployee == 'All Employees') return true;
      return _getEmployeeName(item) == _selectedEmployee;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Urgent ${widget.type.name}s that require immediate attention',
                        style: TextStyle(color: theme.hintColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          // Filter section
          if (!_isLoading && _error == null && _items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Filter: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 0.5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedEmployee,
                          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          items: _getEmployeeList().map((emp) {
                            return DropdownMenuItem<String>(
                              value: emp,
                              child: Text(emp),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedEmployee = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          // Main Body
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          const Text('Failed to load overdue items', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_error!, style: TextStyle(color: theme.hintColor, fontSize: 12), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _loadItems, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  );
                }
                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade400, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'No overdue items found',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedEmployee == 'All Employees'
                              ? 'You are all caught up!'
                              : 'No overdue items for $_selectedEmployee',
                          style: TextStyle(color: theme.hintColor, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];

                    final String title;
                    final String? descVal;
                    final String dateVal;
                    final String? leadName;
                    final String? leadId;
                    final String ownerName = _getEmployeeName(item);

                    if (widget.type == OverdueType.task) {
                      final t = item as Task;
                      title = t.title;
                      descVal = t.description;
                      dateVal = t.dueDate ?? '';
                      leadName = t.lead?.name;
                      leadId = t.lead?.id;
                    } else if (widget.type == OverdueType.meeting) {
                      final m = item as Meeting;
                      title = m.subject;
                      descVal = m.description;
                      dateVal = m.scheduledAt;
                      leadName = m.lead?.name;
                      leadId = m.lead?.id;
                    } else {
                      final v = item as Visit;
                      title = v.project?.name != null ? 'Site Visit - ${v.project!.name}' : 'Site Visit';
                      descVal = v.description;
                      dateVal = v.dateTime;
                      leadName = v.lead?.name;
                      leadId = v.lead?.id;
                    }

                    final overdueStr = _formatOverdueDuration(dateVal);
                    final Color overdueBadgeBg = isDark
                        ? const Color(0x33F97316)
                        : (widget.type == OverdueType.task ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED));
                    final Color overdueTextCol = isDark
                        ? (widget.type == OverdueType.task ? const Color(0xFFFCA5A5) : const Color(0xFFFDBA74))
                        : (widget.type == OverdueType.task ? const Color(0xFF991B1B) : const Color(0xFFC2410C));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.0),
                      ),
                      color: isDark ? const Color(0xFF252525) : Colors.white,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                if (overdueStr.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: overdueBadgeBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      overdueStr,
                                      style: TextStyle(
                                        color: overdueTextCol,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (descVal != null && descVal.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                descVal,
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Due Date Badge Container matching the image
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 14, color: theme.hintColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Scheduled: ${_formatDisplayDate(dateVal)}',
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white12 : Colors.grey.shade200),
                            const SizedBox(height: 12),
                            // Actions and details row matching the image layout
                             Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left details: Lead and Owner
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline_rounded, size: 16, color: theme.hintColor),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: RichText(
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              text: TextSpan(
                                                style: TextStyle(
                                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                                  fontSize: 13,
                                                ),
                                                children: [
                                                  const TextSpan(text: 'Lead: '),
                                                  TextSpan(
                                                    text: leadName ?? 'Unknown',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 22.0),
                                        child: RichText(
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                                              fontSize: 11,
                                            ),
                                            children: [
                                              const TextSpan(text: 'Owner: '),
                                              TextSpan(
                                                text: ownerName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Right buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (leadId != null && leadId.isNotEmpty)
                                      OutlinedButton(
                                        onPressed: () {
                                          AppNotification? notif;
                                          if (widget.type == OverdueType.task && item is Task) {
                                            final t = item;
                                            notif = AppNotification(
                                              id: t.id,
                                              title: t.title,
                                              message: t.description ?? '',
                                              dueAt: t.dueDate,
                                              entityId: t.id,
                                              entityType: 'task',
                                              sourceType: 'task',
                                              relationId: leadId!,
                                              createdAt: DateTime.tryParse(t.createdAt ?? '') ?? DateTime.now(),
                                              updatedAt: DateTime.now(),
                                            );
                                          }
                                          Navigator.pop(context); // Close bottom sheet
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => LeadProfileScreen(
                                                leadId: leadId!,
                                                initialTab: widget.type == OverdueType.task
                                                    ? 'Reminder Detail'
                                                    : widget.type == OverdueType.meeting
                                                        ? 'Meetings'
                                                        : 'Visit',
                                                reminderNotification: notif,
                                              ),
                                            ),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1.0),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'View Lead',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Container(
                                      height: 32,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1.0),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _handleEdit(item),
                                        icon: Icon(Icons.edit_outlined, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      height: 32,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.3) : const Color(0xFFFEE2E2), width: 1.0),
                                        borderRadius: BorderRadius.circular(8),
                                        color: isDark ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFFEF2F2),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _handleDelete(item),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
