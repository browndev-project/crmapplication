import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/lead_provider.dart';
import '../../data/models/lead_model.dart';
import '../../core/utils/date_utils.dart';

import 'package:intl/intl.dart';
import '../../core/utils/formatters.dart';

class LeadStatusUpdateDialog extends ConsumerStatefulWidget {
  final Lead lead;

  const LeadStatusUpdateDialog({super.key, required this.lead});

  @override
  ConsumerState<LeadStatusUpdateDialog> createState() =>
      _LeadStatusUpdateDialogState();
}

class _LeadStatusUpdateDialogState
    extends ConsumerState<LeadStatusUpdateDialog> {
  String? _selectedStatusId;
  final TextEditingController _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  bool _scheduleFollowUp = false;
  bool _markAsLost = false;

  final TextEditingController _followUpTitleController = TextEditingController(text: 'Follow up');
  final TextEditingController _followUpDateController = TextEditingController();
  DateTime? _selectedFollowUpDate;

  @override
  void initState() {
    super.initState();
    // Fetch statuses when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leadStatusProvider.notifier).fetchStatuses();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _followUpTitleController.dispose();
    _followUpDateController.dispose();
    super.dispose();
  }

  Future<void> _selectFollowUpDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFollowUpDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2101),
      builder: (context, child) {
         final isDark = Theme.of(context).brightness == Brightness.dark;
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: isDark ? const ColorScheme.dark(primary: Colors.black) : const ColorScheme.light(primary: Colors.black),
           ),
           child: child!,
         );
      }
    );
    if (picked != null) {
      if (context.mounted) {
         final TimeOfDay? time = await showTimePicker(
             context: context,
             initialTime: TimeOfDay.fromDateTime(_selectedFollowUpDate ?? DateTime.now()),
             builder: (context, child) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: isDark ? const ColorScheme.dark(primary: Colors.black) : const ColorScheme.light(primary: Colors.black),
                  ),
                  child: child!,
                );
             }
         );
         
         if (time != null) {
             setState(() {
                _selectedFollowUpDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                _followUpDateController.text = DateFormat('MM/dd/yyyy hh:mm a').format(_selectedFollowUpDate!);
             });
         }
      }
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_scheduleFollowUp && _selectedFollowUpDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a follow up date & time')),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        if (_selectedStatusId == null) throw 'Please select a status';

        await ref
            .read(leadsProvider.notifier)
            .updateLeadStatus(
              widget.lead.id,
              _selectedStatusId!, // Send ID
              comment: _commentController.text,
              isLost: _markAsLost ? true : null,
              isScheduleFollowup: _scheduleFollowUp,
              followUpTitle: _scheduleFollowUp ? _followUpTitleController.text.trim() : null,
              followUpDate: _scheduleFollowUp ? _selectedFollowUpDate!.toUtc().toIso8601String() : null,
            );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusState = ref.watch(leadStatusProvider);
    // Filter for active statuses only (re-enabled based on user request)
    final statuses = statusState.statuses.where((s) => s.isActive).toList();

    // Initialize or validate selected ID based on Lead's current status name
    if (_selectedStatusId == null && statuses.isNotEmpty) {
      // Find status ID that matches the lead's current status name
      try {
        final currentStatus = statuses.firstWhere(
          (s) => s.name.toLowerCase() == widget.lead.status.toLowerCase(),
          orElse: () => statuses.first, // Fallback if not found
        );
        _selectedStatusId = currentStatus.id;
      } catch (e) {
        // Fallback safely
        if (statuses.isNotEmpty) _selectedStatusId = statuses.first.id;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Theme.of(context).cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 0,
      child: Container(
        // Constrain height if needed, or let it scroll
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Update Lead Status',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Dropdown
                      if (statusState.isLoading && statuses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedStatusId,
                                  hint: const Text("Select Status",
                                      style: TextStyle(fontSize: 14)),
                                  items: statuses
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(toTitleCase(s.name),
                                              style:
                                                  const TextStyle(fontSize: 14)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedStatusId = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),

                      // Comment Field
                      TextFormField(
                        controller: _commentController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Comment',
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Checkboxes: Schedule Follow Up & Mark as Lost Lead
                      InkWell(
                        onTap: () {
                          setState(() {
                            _scheduleFollowUp = !_scheduleFollowUp;
                          });
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: _scheduleFollowUp,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() {
                                  _scheduleFollowUp = val ?? false;
                                });
                              },
                            ),
                            const Text("Schedule Follow Up", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _markAsLost = !_markAsLost;
                          });
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: _markAsLost,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() {
                                  _markAsLost = val ?? false;
                                });
                              },
                            ),
                            const Text("Mark as Lost Lead", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),

                      // Follow Up Details (only if _scheduleFollowUp is checked)
                      if (_scheduleFollowUp) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Follow Up Details",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _followUpTitleController,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Follow Up Title *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                validator: (val) {
                                  if (_scheduleFollowUp && (val == null || val.trim().isEmpty)) {
                                    return 'Title is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _followUpDateController,
                                readOnly: true,
                                onTap: () => _selectFollowUpDate(context),
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Follow Up Date & Time *',
                                  hintText: "mm/dd/yyyy --:--",
                                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                validator: (val) {
                                  if (_scheduleFollowUp && _selectedFollowUpDate == null) {
                                    return 'Date and time are required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // History Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Lead History',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (widget.lead.statusHistory == null ||
                                widget.lead.statusHistory!.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No history available.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              )
                            else
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 250,
                                ),
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: widget.lead.statusHistory!.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) =>
                                      _DialogHistoryItem(
                                        history: widget.lead.statusHistory![index],
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 0.5),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'UPDATE STATUS',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogHistoryItem extends StatelessWidget {
  final StatusHistory history;

  const _DialogHistoryItem({required this.history});

  @override
  Widget build(BuildContext context) {
    final String eventType = history.status.toUpperCase();

    Color accentColor = const Color(0xFF3B82F6);

    if (eventType.contains('OWNER')) {
      accentColor = const Color(0xFF8B5CF6);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eventType,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            history.comment ?? history.status,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Updated by ${history.updatedBy?.name ?? 'Unknown'}",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            timeago.format(
              DateTimeUtils.parseSafe(history.createdAt) ?? DateTime.now(),
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
