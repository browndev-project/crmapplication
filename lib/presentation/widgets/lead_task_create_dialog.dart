import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/date_utils.dart';
import '../providers/task_provider.dart';
import '../../data/models/task_model.dart';

class LeadTaskCreateDialog extends ConsumerStatefulWidget {
  final String leadId;
  final Task? task;

  const LeadTaskCreateDialog({super.key, required this.leadId, this.task});

  @override
  ConsumerState<LeadTaskCreateDialog> createState() => _LeadTaskCreateDialogState();
}

class _LeadTaskCreateDialogState extends ConsumerState<LeadTaskCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _dueDateController;
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? 'Follow up');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    
    if (widget.task?.dueDate != null) {
        _selectedDate = DateTimeUtils.parseSafe(widget.task!.dueDate!);
        _dueDateController = TextEditingController(text: DateFormat('dd/MM/yyyy hh:mm a').format(_selectedDate!));
    } else {
        _dueDateController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      // Pick Time
      if (context.mounted) {
         final TimeOfDay? time = await showTimePicker(
             context: context,
             initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now())
         );
         
         if (time != null) {
             setState(() {
                _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                _dueDateController.text = DateFormat('dd/MM/yyyy hh:mm a').format(_selectedDate!);
             });
         }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a due date")));
        return;
    }

    setState(() => _isLoading = true);

    try {
      final taskData = {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "dueDate": _selectedDate!.toUtc().toIso8601String(),
        "status": widget.task?.status ?? "Not Started"
      };

      if (widget.task != null) {
          await ref.read(tasksProvider.notifier).updateTask(widget.task!.id, taskData);
      } else {
          taskData["leadId"] = widget.leadId;
          await ref.read(tasksProvider.notifier).createTask(taskData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.task != null ? 'Follow up updated' : 'Follow up created'), backgroundColor: Colors.green),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.task != null;

    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       backgroundColor: Theme.of(context).cardColor,
       insetPadding: const EdgeInsets.all(16),
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 600),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             // Header
             Padding(
               padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(isEdit ? "Update Follow up" : "Create Follow up", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                   InkWell(
                     onTap: () => Navigator.pop(context),
                     borderRadius: BorderRadius.circular(20),
                     child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.close, size: 20, color: Theme.of(context).iconTheme.color),
                     ),
                   )
                 ],
               ),
             ),
             const Divider(height: 1, thickness: 0.5),
             
             // Form
             Padding(
               padding: const EdgeInsets.all(24),
               child: Form(
                 key: _formKey,
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     _buildTextField("Title", _titleController, isDark, required: true),
                     const SizedBox(height: 16),
                     
                     _buildTextField("Description", _descriptionController, isDark, maxLines: 4),
                     const SizedBox(height: 16),
                     
                     TextFormField(
                       controller: _dueDateController,
                       readOnly: true,
                       onTap: () => _selectDate(context),
                       style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                       decoration: _inputDecoration("Due Date", isDark).copyWith(
                           hintText: "mm/dd/yyyy --:--",
                           suffixIcon: const Icon(Icons.calendar_today, size: 20)
                       ),
                     ),
                   ],
                 ),
               ),
             ),

             const Divider(height: 1, thickness: 0.5),

             // Footer
             Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(foregroundColor: Colors.grey),
                            child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                elevation: 0
                            ),
                            child: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(isEdit ? "Update Task" : "Create Task"),
                        )
                    ],
                ),
             )
           ],
         ),
       )
    );
  }

  Widget buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, {
      bool required = false, 
      int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
          validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
          decoration: _inputDecoration(label, isDark),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
      return InputDecoration(
          labelText: label,
          hintText: 'Enter $label',
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 13),
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: false,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
  }
}
