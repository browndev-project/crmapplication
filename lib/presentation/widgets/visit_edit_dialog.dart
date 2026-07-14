
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/visit_provider.dart';
import '../providers/property_provider.dart';
import '../../data/models/property_model.dart';
import '../../data/models/visit_model.dart';
import '../../core/utils/date_utils.dart';

class VisitEditDialog extends ConsumerStatefulWidget {
  final String leadId;
  final Visit visit;

  const VisitEditDialog({super.key, required this.leadId, required this.visit});

  @override
  ConsumerState<VisitEditDialog> createState() => _VisitEditDialogState();
}

class _VisitEditDialogState extends ConsumerState<VisitEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _dateTimeController;
  late TextEditingController _commentsController;
  
  String? _selectedProjectId;
  String? _selectedPropertyId;
  String _selectedStatus = 'Scheduled';
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.visit.description);
    _commentsController = TextEditingController(text: widget.visit.comments ?? '');
    
    _selectedStatus = widget.visit.status;
    _selectedProjectId = widget.visit.project?.id;
    _selectedPropertyId = widget.visit.property?.id;

    _selectedDate = DateTimeUtils.parseSafe(widget.visit.dateTime);
    _dateTimeController = TextEditingController(text: DateTimeUtils.formatDisplay(_selectedDate));
    
    // Refresh project list if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(propertyProvider).projects.isEmpty) {
        ref.read(propertyProvider.notifier).fetchProjects();
      }
      ref.read(allPropertiesProvider.notifier).resetFilters();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _dateTimeController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
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
      if (mounted) {
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
                _dateTimeController.text = DateTimeUtils.formatDisplay(_selectedDate);
             });
         }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a date & time")));
        return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        "projectId": _selectedProjectId,
        "project": _selectedProjectId,
        "propertyId": _selectedPropertyId,
        "property": _selectedPropertyId,
        "dateTime": DateTimeUtils.toApiString(_selectedDate),
        "visitDate": DateTimeUtils.toApiString(_selectedDate),
        "description": _descriptionController.text.trim(),
        "notes": _descriptionController.text.trim(),
        "status": _selectedStatus,
        "comments": _commentsController.text.trim(),
        "leadId": widget.leadId,
        "lead": widget.leadId,
      };

      await ref.read(visitsProvider.notifier).updateVisit(widget.visit.id, payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site visit updated successfully'), backgroundColor: Colors.green),
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
    final propertyState = ref.watch(propertyProvider);
    final allPropertiesState = ref.watch(allPropertiesProvider);

    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
       backgroundColor: Theme.of(context).cardColor,
       insetPadding: const EdgeInsets.all(16),
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 450),
         child: SingleChildScrollView(
           child: Padding(
             padding: const EdgeInsets.all(24),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 // Header
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text("Edit Visit", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
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
                 const Divider(height: 32),
                 
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project Dropdown
                        DropdownButtonFormField<String?>(
                            initialValue: _selectedProjectId,
                            decoration: _inputDecoration("Project (Optional)", isDark),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('None / Standalone')),
                              ...propertyState.projects.map<DropdownMenuItem<String?>>((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (val) {
                                setState(() {
                                  _selectedProjectId = val;
                                });
                            },
                            hint: const Text('Select a Project'),
                            icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        const SizedBox(height: 16),

                        // Property Dropdown
                         Builder(
                           builder: (context) {
                             final List<Property> filteredProperties;
                             if (_selectedProjectId == null) {
                               filteredProperties = allPropertiesState.properties
                                   .where((p) => p.projectId.isEmpty)
                                   .toList();
                             } else {
                               filteredProperties = allPropertiesState.properties
                                   .where((p) => p.projectId.isEmpty || p.projectId == _selectedProjectId)
                                   .toList();
                             }

                             final List<DropdownMenuItem<String?>> propItems = [
                               const DropdownMenuItem<String?>(value: null, child: Text('None')),
                               ...filteredProperties.map((p) => DropdownMenuItem<String?>(
                                 value: p.id,
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Text(
                                       p.name,
                                       style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                     ),
                                     const SizedBox(height: 2),
                                     Text(
                                       (p.projectId.isEmpty)
                                           ? 'Standalone Property'
                                           : (p.project?.name ?? 'Project'),
                                       style: TextStyle(
                                         fontSize: 11,
                                         color: Colors.grey[500],
                                       ),
                                     ),
                                   ],
                                 ),
                               )),
                             ];

                             final validPropertyId = filteredProperties.any((p) => p.id == _selectedPropertyId)
                                 ? _selectedPropertyId
                                 : null;

                             if (validPropertyId == null && _selectedPropertyId != null) {
                               WidgetsBinding.instance.addPostFrameCallback((_) {
                                 if (mounted) setState(() => _selectedPropertyId = null);
                               });
                             }

                             return DropdownButtonFormField<String?>(
                               initialValue: validPropertyId,
                               decoration: _inputDecoration("Property (Optional)", isDark),
                               isExpanded: true,
                               itemHeight: null,
                               dropdownColor: Theme.of(context).cardColor,
                               items: propItems,
                               selectedItemBuilder: (context) => propItems.map((item) {
                                 final child = item.child;
                                 if (child is Column) {
                                   final textChild = child.children.whereType<Text>().firstOrNull;
                                   return Text(
                                     textChild?.data ?? '',
                                     overflow: TextOverflow.ellipsis,
                                     maxLines: 1,
                                     style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                                   );
                                 }
                                 if (child is Text) {
                                   return Text(
                                     child.data ?? '',
                                     overflow: TextOverflow.ellipsis,
                                     maxLines: 1,
                                     style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                                   );
                                 }
                                 return child ;
                               }).toList(),
                               onChanged: (val) => setState(() => _selectedPropertyId = val),
                               hint: const Text('Select a Property'),
                               icon: const Icon(Icons.keyboard_arrow_down),
                             );
                           },
                         ),
                        const SizedBox(height: 16),
            
                        _buildTextField("Description", _descriptionController, isDark, maxLines: 4),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _dateTimeController,
                          readOnly: true,
                          onTap: _selectDate,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                          decoration: _inputDecoration("Date & Time", isDark).copyWith(
                              hintText: "mm/dd/yyyy --:--",
                              suffixIcon: const Icon(Icons.calendar_today, size: 20)
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                         DropdownButtonFormField<String>(
                             initialValue: _selectedStatus,
                             decoration: _inputDecoration('Status', isDark),
                             items: ['Scheduled', 'Completed', 'Cancelled'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                             onChanged: (val) => setState(() => _selectedStatus = val!),
                             icon: const Icon(Icons.keyboard_arrow_down),
                         ),
                         const SizedBox(height: 16),

                         _buildTextField("Comments", _commentsController, isDark, maxLines: 4),
                      ],
                    ),
                  ),
            
                  const SizedBox(height: 32),
            
                  // Footer
                  Row(
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                         TextButton(
                             onPressed: () => Navigator.pop(context),
                             style: TextButton.styleFrom(foregroundColor: Colors.grey),
                             child: const Text("CANCEL"),
                         ),
                         const SizedBox(width: 16),
                         ElevatedButton(
                             onPressed: _isLoading ? null : _submit,
                             style: ElevatedButton.styleFrom(
                                 backgroundColor: Colors.black,
                                 foregroundColor: Colors.white,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                 elevation: 0
                             ),
                             child: _isLoading 
                                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                 : const Text("UPDATE VISIT"),
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
    return TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
        validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
        decoration: _inputDecoration(label, isDark),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
      return InputDecoration(
          labelText: label,
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
