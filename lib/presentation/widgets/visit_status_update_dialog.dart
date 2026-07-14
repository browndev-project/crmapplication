
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/visit_provider.dart';
import '../../data/models/visit_model.dart';

class VisitStatusUpdateDialog extends ConsumerStatefulWidget {
  final Visit visit;

  const VisitStatusUpdateDialog({super.key, required this.visit});

  @override
  ConsumerState<VisitStatusUpdateDialog> createState() => _VisitStatusUpdateDialogState();
}

class _VisitStatusUpdateDialogState extends ConsumerState<VisitStatusUpdateDialog> {
  late String _selectedStatus;
  late TextEditingController _commentsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.visit.status;
    _commentsController = TextEditingController(text: widget.visit.comments ?? '');
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'status': _selectedStatus,
        'comments': _commentsController.text.trim(),
      };

      await ref.read(visitsProvider.notifier).updateVisit(widget.visit.id, payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit status updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: theme.cardColor,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Update Visit Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: theme.dividerColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.close, size: 20, color: theme.iconTheme.color),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Lead name
                Text(
                  widget.visit.lead?.name ?? 'Unknown Lead',
                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 20),

                // Status dropdown
                Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: ['Scheduled', 'Completed', 'Cancelled'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                const SizedBox(height: 16),

                // Comments text field
                Text('Comments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _commentsController,
                  maxLines: 4,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add comments...',
                    hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('UPDATE STATUS'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
