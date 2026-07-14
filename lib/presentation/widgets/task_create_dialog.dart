import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../providers/lead_provider.dart';
import '../../data/models/task_model.dart';
import '../../core/utils/date_utils.dart';

class TaskCreateDialog extends ConsumerStatefulWidget {
  final String? leadId; // Optional: If provided, pre-selects lead and hides dropdown
  final Task? task;

  const TaskCreateDialog({super.key, this.leadId, this.task});

  @override
  ConsumerState<TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends ConsumerState<TaskCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _dueDateController;
  
  DateTime? _selectedDate;
  String? _selectedLeadId;
  String _selectedStatus = 'Not Started';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    
    // Initialize Status
    if (widget.task?.status != null) {
        _selectedStatus = widget.task!.status;
    }

    // Initialize Lead ID
    if (widget.leadId != null) {
        _selectedLeadId = widget.leadId;
    } else if (widget.task?.lead?.id != null) {
        _selectedLeadId = widget.task!.lead!.id;
    }

    // Initialize Date
    if (widget.task?.dueDate != null) {
        _selectedDate = DateTimeUtils.parseSafe(widget.task!.dueDate);
        _dueDateController = TextEditingController(text: DateTimeUtils.formatDisplay(_selectedDate));
    } else {
        _dueDateController = TextEditingController();
    }

    // Fetch leads if we need to show the dropdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.leadId == null && ref.read(leadsProvider).leads.isEmpty) {
            ref.read(leadsProvider.notifier).fetchLeads();
        }
    });
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
             initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now()),
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
                _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                _dueDateController.text = DateTimeUtils.formatDisplay(_selectedDate!);
             });
         }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (widget.task == null && _selectedLeadId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please assign a lead")));
        return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> taskData = {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "status": _selectedStatus,
      };
      
      if (_selectedDate != null) {
          taskData["dueDate"] = DateTimeUtils.toApiString(_selectedDate);
      }

      if (widget.task != null) {
          await ref.read(tasksProvider.notifier).updateTask(widget.task!.id, taskData);
      } else {
          taskData["leadId"] = _selectedLeadId;
          await ref.read(tasksProvider.notifier).createTask(taskData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.task != null ? 'Task updated' : 'Task created'), backgroundColor: Colors.green),
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
    final leadsState = ref.watch(leadsProvider);

    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
       backgroundColor: Theme.of(context).cardColor,
       insetPadding: const EdgeInsets.all(16),
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 600),
         child: SingleChildScrollView(
           child: Padding(
             padding: const EdgeInsets.all(24),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Header
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(isEdit ? "Update Task" : "Create Task", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                     InkWell(
                       onTap: () => Navigator.pop(context),
                       borderRadius: BorderRadius.circular(20),
                       child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.close, size: 20, color: Theme.of(context).iconTheme.color),
                       ),
                     )
                   ],
                 ),
                 const Divider(height: 24),
                 
                 // Form
                 Form(
                   key: _formKey,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       _buildTextField("Title", _titleController, isDark, required: true),
                       const SizedBox(height: 16),
                       
                       _buildTextField("Description", _descriptionController, isDark, maxLines: 3),
                       const SizedBox(height: 16),
                       
                       // Lead Dropdown (Show only if leadId was NOT provided in constructor)
                       if (widget.leadId == null && !isEdit) ...[
                           DropdownButtonFormField<String>(
                               initialValue: _selectedLeadId,
                               decoration: _inputDecoration("Assign Lead", isDark),
                               items: leadsState.leads.map((lead) {
                                   return DropdownMenuItem(value: lead.id, child: Text(lead.name, overflow: TextOverflow.ellipsis));
                               }).toList(), 
                               onChanged: (val) => setState(() => _selectedLeadId = val),
                               hint: const Text('Select a Lead'),
                               icon: const Icon(Icons.keyboard_arrow_down),
                           ),
                           const SizedBox(height: 16),
                       ],

                        DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: _inputDecoration("Status", isDark),
                            items: ['Not Started', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _selectedStatus = val!),
                            icon: const Icon(Icons.keyboard_arrow_down),
                        ),
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

                 const SizedBox(height: 24),

                 // Footer
                 Row(
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
                                backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                elevation: 0
                            ),
                            child: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(isEdit ? "Update Task" : "Create Task"),
                        )
                    ],
                 )
               ],
             ),
           ),
         ),
       )
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
