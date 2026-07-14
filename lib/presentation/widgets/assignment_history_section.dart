import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/lead_model.dart';
import '../../core/utils/date_utils.dart';

class AssignmentHistorySection extends StatelessWidget {
  final List<AssignHistory> assignHistory;
  final bool isDark;

  const AssignmentHistorySection({
    super.key,
    required this.assignHistory,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sortedHistory = List<AssignHistory>.from(assignHistory)
      ..sort((a, b) {
        final aTime = DateTimeUtils.parseSafe(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = DateTimeUtils.parseSafe(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    final limitedHistory = sortedHistory.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.assignment_ind_outlined,
              color: Colors.blue.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Assignment History',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (limitedHistory.isEmpty)
          const AssignmentEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Scroll handled by parent
            padding: EdgeInsets.zero,
            itemCount: limitedHistory.length,
            itemBuilder: (context, index) {
              return AssignmentTimelineTile(
                history: limitedHistory[index],
                isDark: isDark,
              );
            },
          ),
      ],
    );
  }
}

class AssignmentTimelineTile extends StatelessWidget {
  final AssignHistory history;
  final bool isDark;

  const AssignmentTimelineTile({
    super.key,
    required this.history,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AssignmentTimelineCard(
        h: history,
        isDark: isDark,
      ),
    );
  }
}

class AssignmentTimelineCard extends StatefulWidget {
  final AssignHistory h;
  final bool isDark;

  const AssignmentTimelineCard({
    super.key,
    required this.h,
    required this.isDark,
  });

  @override
  State<AssignmentTimelineCard> createState() => _AssignmentTimelineCardState();
}

class _AssignmentTimelineCardState extends State<AssignmentTimelineCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final isDark = widget.isDark;
    final isSubAssigneeChange = h.actionType == 'subAssigneeChange';
    final baseColor = isSubAssigneeChange ? Colors.blue.shade500 : Colors.purple.shade500;

    final dateTime = DateTimeUtils.parseSafe(h.createdAt);
    final ago = dateTime != null ? timeago.format(dateTime) : '';
    final exactDate = dateTime != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dateTime) : '';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left border running full height of the card
              Container(width: 4, color: baseColor),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: _isHovered ? baseColor.withValues(alpha: 0.4) : (isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
                      right: BorderSide(color: _isHovered ? baseColor.withValues(alpha: 0.4) : (isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
                      bottom: BorderSide(color: _isHovered ? baseColor.withValues(alpha: 0.4) : (isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Text (uppercase, small, colored)
                      Text(
                        isSubAssigneeChange ? 'SUB-ASSIGNEE CHANGE' : 'OWNER ASSIGNMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: baseColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isSubAssigneeChange) ...[
                        _buildSubAssigneeDetails(h, isDark),
                      ] else ...[
                        _buildOwnerDetails(h, isDark),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        isSubAssigneeChange
                            ? 'Updated by ${h.changedBy?.name ?? "System"}'
                            : 'Assigned by ${h.changedBy?.name ?? "System"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Tooltip(
                        message: exactDate,
                        child: Text(
                          ago,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          ),
                        ),
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

  Widget _buildSubAssigneeDetails(AssignHistory h, bool isDark) {
    final addedNames = (h.subAssigneesAdded ?? []).map((u) => u.name).where((name) => name.isNotEmpty).join(", ");
    final removedNames = (h.subAssigneesRemoved ?? []).map((u) => u.name).where((name) => name.isNotEmpty).join(", ");
    final currentNames = (h.currentSubAssignees ?? []).map((u) => u.name).where((name) => name.isNotEmpty).join(", ");

    String changeText = "";
    if (addedNames.isNotEmpty && removedNames.isNotEmpty) {
      changeText = "Added: $addedNames. Removed: $removedNames";
    } else if (addedNames.isNotEmpty) {
      changeText = "Added: $addedNames";
    } else if (removedNames.isNotEmpty) {
      changeText = "Removed: $removedNames";
    } else {
      changeText = "Sub-assignees list updated";
    }

    final currentText = currentNames.isNotEmpty
        ? "New sub-assignees: $currentNames"
        : "All sub-assignees removed";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          changeText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          currentText,
          style: TextStyle(
            fontSize: 11,
            color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerDetails(AssignHistory h, bool isDark) {
    final fromName = h.fromUser?.name ?? 'Unassigned';
    final toName = h.toUser?.name ?? 'Unassigned';
    final removedNames = (h.subAssigneesRemoved ?? []).map((u) => u.name).where((name) => name.isNotEmpty).join(", ");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$fromName ➔ $toName',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (removedNames.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '(Removed from sub-assignees: $removedNames)',
            style: TextStyle(
              fontSize: 11,
              color: widget.isDark ? Colors.amber.shade400 : Colors.amber.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class AssignmentEmptyState extends StatelessWidget {
  const AssignmentEmptyState({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_ind_outlined, size: 24, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          const SizedBox(height: 4),
          Text(
            'No assignment history',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}