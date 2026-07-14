import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/meeting_provider.dart';
import '../providers/lead_provider.dart';
import '../providers/login_provider.dart';
import '../../data/models/meeting_model.dart';
import '../../core/utils/date_utils.dart';

class MeetingCreateDialog extends ConsumerStatefulWidget {
  final String? leadId; // Optional pre-selected lead
  final Meeting? meeting;
  final String? clientEmail;

  const MeetingCreateDialog({super.key, this.leadId, this.meeting, this.clientEmail});

  @override
  ConsumerState<MeetingCreateDialog> createState() => _MeetingCreateDialogState();
}

class _MeetingCreateDialogState extends ConsumerState<MeetingCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectController;
  late TextEditingController _descriptionController;
  late TextEditingController _scheduledAtController;
  late TextEditingController _hostController;
  late TextEditingController _linkController;
  late TextEditingController _clientEmailController;
  late TextEditingController _employeeEmailController;
  
  String? _sendBy;
  List<String> _sendOptions = [];
  
  bool _sendMail = false;
  bool _sendWhatsapp = false;
  DateTime? _selectedDate;
  String? _selectedLeadId;
  String _selectedStatus = 'Scheduled';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final userEmail = ref.read(loginProvider).user?.email ?? '';
    
    // Initialize _sendBy from meeting model FIRST (synchronously)
    if (widget.meeting?.type != null) {
      String backendType = widget.meeting!.type!;
      if (backendType == 'Custom Email') backendType = 'Custom SMTP';
      _sendBy = backendType;
    }
    // Then check services asynchronously - it will only verify/fallback, not reset
    _checkServices();
    
    _subjectController = TextEditingController(text: widget.meeting?.subject ?? '');
    _descriptionController = TextEditingController(text: widget.meeting?.description ?? '');
    _hostController = TextEditingController(text: widget.meeting?.host ?? '');
    _linkController = TextEditingController(text: widget.meeting?.meetLink ?? '');
    String initialClientEmail = '';
    if (widget.meeting?.clientEmail != null && widget.meeting!.clientEmail!.isNotEmpty) {
      initialClientEmail = widget.meeting!.clientEmail!;
    } else if (widget.clientEmail != null && widget.clientEmail!.isNotEmpty) {
      initialClientEmail = widget.clientEmail!;
    }
    _clientEmailController = TextEditingController(text: initialClientEmail);
    _employeeEmailController = TextEditingController(text: widget.meeting?.employeeEmail ?? userEmail);
    _sendMail = widget.meeting?.sendMail ?? false;
    _sendWhatsapp = widget.meeting?.whatsappAutomation ?? false;
    debugPrint('DIALOG_INIT: meeting sendMail=${widget.meeting?.sendMail} whatsappAutomation=${widget.meeting?.whatsappAutomation} -> _sendMail=$_sendMail _sendWhatsapp=$_sendWhatsapp');

    if (widget.meeting != null) {
      final rawStatus = widget.meeting!.status.replaceAll('_', ' ').toLowerCase();
      if (rawStatus == 'scheduled') {
        _selectedStatus = 'Scheduled';
      } else if (rawStatus == 'not started') {
        _selectedStatus = 'Not Started';
      } else if (rawStatus == 'completed') {
        _selectedStatus = 'Completed';
      } else if (rawStatus == 'cancelled') {
        _selectedStatus = 'Cancelled';
      } else {
        _selectedStatus = 'Scheduled';
      }
    }

    // Initialize Lead Selection
    if (widget.leadId != null) {
        _selectedLeadId = widget.leadId;
    } else if (widget.meeting?.lead?.id != null) {
        _selectedLeadId = widget.meeting!.lead!.id;
    }
    
    // Ensure we have a lead ID from meeting if not provided
    if (_selectedLeadId == null && widget.meeting?.lead?.id != null) {
      _selectedLeadId = widget.meeting!.lead!.id;
    }

    // Initialize Date
    if (widget.meeting?.scheduledAt != null) {
        _selectedDate = DateTimeUtils.parseSafe(widget.meeting!.scheduledAt);
        _scheduledAtController = TextEditingController(text: DateTimeUtils.formatDisplay(_selectedDate));
    } else {
        _scheduledAtController = TextEditingController();
    }
    
    // Fetch leads if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_clientEmailController.text.isEmpty && widget.leadId != null) {
          try {
            final leadOpt = ref.read(leadsProvider).leads.where((l) => l.id == widget.leadId).toList();
            if (leadOpt.isNotEmpty && leadOpt.first.email.isNotEmpty) {
              setState(() {
                _clientEmailController.text = leadOpt.first.email;
              });
            }
          } catch (_) {}
        }
        if (widget.leadId == null && ref.read(leadsProvider).leads.isEmpty) {
            ref.read(leadsProvider.notifier).fetchLeads();
        }
    });
  }

  Future<void> _checkServices() async {
      try {
          final gmail = await ref.read(leadServiceProvider).getGoogleAuthStatus();
          final outlook = await ref.read(leadServiceProvider).getMicrosoftAuthStatus();
          
          if (mounted) {
              setState(() {
                  _sendOptions = ['Custom SMTP'];
                  if (gmail != null) _sendOptions.add('Gmail');
                  if (outlook != null) _sendOptions.add('Outlook');
                  
                  // Only set default if _sendBy is not already set or is invalid
                  if (_sendBy == null || !_sendOptions.contains(_sendBy)) {
                     _sendBy = 'Custom SMTP';
                  }
              });
          }
      } catch (e) {
          debugPrint('Error checking services: $e');
      }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _scheduledAtController.dispose();
    _hostController.dispose();
    _linkController.dispose();
    _clientEmailController.dispose();
    _employeeEmailController.dispose();
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
                _scheduledAtController.text = DateTimeUtils.formatDisplay(_selectedDate);
             });
         }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (widget.meeting == null && _selectedLeadId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please assign a lead")));
        return;
    }
    
    if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a scheduled date")));
        return;
    }

    setState(() => _isLoading = true);

    try {
      String? backendSendBy = _sendBy;
      if (backendSendBy == 'Custom SMTP') {
        backendSendBy = 'Custom Email';
      }

      final meetingData = {
        "subject": _subjectController.text.trim(),
        "description": _descriptionController.text.trim(),
        "scheduledAt": DateTimeUtils.toApiString(_selectedDate),
        "status": _selectedStatus,
        "host": _hostController.text.trim(),
        "sendMail": _sendMail,
        "whatsappAutomation": _sendWhatsapp,
        "meetLink": _linkController.text.trim(),
        "clientEmail": _clientEmailController.text.trim(),
        "employeeEmail": _employeeEmailController.text.trim(),
        "type": backendSendBy,
        "sendBy": backendSendBy,
      };

      if (widget.meeting != null) {
          await ref.read(meetingsProvider.notifier).updateMeeting(widget.meeting!.id, meetingData);
      } else {
          meetingData["leadId"] = _selectedLeadId;
          await ref.read(meetingsProvider.notifier).createMeeting(meetingData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.meeting != null ? 'Meeting updated' : 'Meeting scheduled'), backgroundColor: Colors.green),
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
    final isEdit = widget.meeting != null;
    final leadsState = ref.watch(leadsProvider);

    // Resolve lead name for the header pill
    String leadName = '';
    if (_selectedLeadId != null) {
      try {
        final matching = leadsState.leads.firstWhere((l) => l.id == _selectedLeadId);
        leadName = matching.name;
      } catch (_) {
        if (widget.meeting?.lead?.name != null) {
          leadName = widget.meeting!.lead!.name;
        }
      }
    }

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
               children: [
                 // Header
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             children: [
                               Text(
                                 isEdit ? "Update Meeting" : "Schedule Meeting",
                                 style: TextStyle(
                                   fontSize: 18,
                                   fontWeight: FontWeight.bold,
                                   color: Theme.of(context).textTheme.bodyLarge?.color,
                                 ),
                               ),
                               if (leadName.isNotEmpty) ...[
                                 const SizedBox(width: 8),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFFA855F7), // Vibrant purple
                                     borderRadius: BorderRadius.circular(20),
                                   ),
                                   child: Text(
                                     leadName,
                                     style: const TextStyle(
                                       color: Colors.white,
                                       fontSize: 10,
                                       fontWeight: FontWeight.bold,
                                     ),
                                   ),
                                 ),
                               ],
                             ],
                           ),
                           const SizedBox(height: 6),
                           Text(
                             "Email and WhatsApp options are optional. Check Send Mail or Send on WhatsApp only when you want those notifications sent.",
                             style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.3),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(width: 8),
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
                        // Lead Display/Selection
                        if (isEdit) ...[
                          Text("Lead", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                          const SizedBox(height: 4),
                          Text(widget.meeting?.lead?.name ?? 'Unknown Lead', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(height: 16),
                        ] else if (widget.leadId == null && widget.meeting?.lead == null) ...[
                            DropdownButtonFormField<String>(
                                initialValue: _selectedLeadId,
                                decoration: _inputDecoration("Assign Lead", isDark),
                                items: leadsState.leads.map((lead) {
                                    return DropdownMenuItem(value: lead.id, child: Text(lead.name, overflow: TextOverflow.ellipsis));
                                }).toList(), 
                                onChanged: (val) {
                                  setState(() {
                                    _selectedLeadId = val;
                                    if (val != null && _clientEmailController.text.isEmpty) {
                                      try {
                                        final lead = leadsState.leads.firstWhere((l) => l.id == val);
                                        if (lead.email.isNotEmpty) {
                                          _clientEmailController.text = lead.email;
                                        }
                                      } catch (_) {}
                                    }
                                  });
                                }, 
                                hint: const Text('Select a Lead'),
                                icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                            const SizedBox(height: 16),
                        ],

                        _buildTextField("Meeting Host", _hostController, isDark),
                        const SizedBox(height: 16),

                        _buildTextField("Subject", _subjectController, isDark, required: true),
                        const SizedBox(height: 16),
                        
                        _buildTextField("Description", _descriptionController, isDark, maxLines: 3),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _scheduledAtController,
                          readOnly: true,
                          onTap: () => _selectDate(context),
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                          decoration: _inputDecoration("Scheduled At", isDark).copyWith(
                              hintText: "mm/dd/yyyy --:--",
                              suffixIcon: const Icon(Icons.calendar_today, size: 20)
                          ),
                        ),
                        if (isEdit && widget.meeting?.scheduledAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Current: ${DateTimeUtils.formatDisplay(DateTimeUtils.parseSafe(widget.meeting!.scheduledAt))}",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Checkbox(
                                value: _sendMail,
                                onChanged: (val) => setState(() => _sendMail = val ?? false),
                                activeColor: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("Send Mail", style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        
                        if (_sendMail) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Email Scheduling Options", 
                                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                if (_sendOptions.isNotEmpty) ...[
                                    DropdownButtonFormField<String>(
                                        initialValue: _sendOptions.contains(_sendBy) ? _sendBy : null,
                                        decoration: _inputDecoration('Send by', isDark),
                                        items: _sendOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                        onChanged: (val) {
                                            if (val != null) setState(() => _sendBy = val);
                                        },
                                        icon: const Icon(Icons.keyboard_arrow_down),
                                    ),
                                    const SizedBox(height: 16),
                                ],
                                _buildTextField("Client Email", _clientEmailController, isDark),
                                const SizedBox(height: 16),
                                _buildTextField("Employee Email", _employeeEmailController, isDark),
                                const SizedBox(height: 16),
                                _buildTextField("Meeting Link", _linkController, isDark),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Checkbox(
                                value: _sendWhatsapp,
                                onChanged: (val) => setState(() => _sendWhatsapp = val ?? false),
                                activeColor: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("Send on WhatsApp", style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),

                         DropdownButtonFormField<String>(
                             initialValue: _selectedStatus,
                             decoration: _inputDecoration('Status', isDark),
                             items: ['Scheduled', 'Not Started', 'Completed', 'Cancelled'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                             onChanged: (val) => setState(() => _selectedStatus = val!),
                             icon: const Icon(Icons.keyboard_arrow_down),
                         ),
                      ],
                    ),
                  ),
            
                  const SizedBox(height: 24),
            
                  // Footer
                  Wrap(
                     alignment: isEdit ? WrapAlignment.spaceBetween : WrapAlignment.end,
                     crossAxisAlignment: WrapCrossAlignment.center,
                     spacing: 8,
                     runSpacing: 12,
                     children: [
                         if (isEdit)
                           TextButton(
                               onPressed: () {
                                   ref.read(meetingsProvider.notifier).deleteMeeting(widget.meeting!.id);
                                   Navigator.pop(context);
                               },
                               style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero, minimumSize: const Size(60, 36)),
                               child: const Text("DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
                           ),
                         
                         Wrap(
                           spacing: 8,
                           runSpacing: 12,
                           alignment: WrapAlignment.end,
                           crossAxisAlignment: WrapCrossAlignment.center,
                           children: [
                             TextButton(
                                 onPressed: () => Navigator.pop(context),
                                 style: TextButton.styleFrom(foregroundColor: Theme.of(context).textTheme.bodyLarge?.color, padding: EdgeInsets.zero, minimumSize: const Size(60, 36)),
                                 child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)),
                             ),
                             ElevatedButton(
                                 onPressed: _isLoading ? null : _submit,
                                 style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.black,
                                     foregroundColor: Colors.white,
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                     elevation: 0
                                 ),
                                 child: _isLoading 
                                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                     : Text(isEdit ? "SAVE CHANGES" : "SCHEDULE", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                             )
                           ]
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
