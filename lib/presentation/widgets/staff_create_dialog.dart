import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/staff_model.dart';
import '../providers/staff_provider.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';

class StaffCreateDialog extends ConsumerStatefulWidget {
  final String role;
  final StaffUser? staff;

  const StaffCreateDialog({super.key, required this.role, this.staff});

  @override
  ConsumerState<StaffCreateDialog> createState() => _StaffCreateDialogState();
}

class _StaffCreateDialogState extends ConsumerState<StaffCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _uniqueIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final TextEditingController _passwordController = TextEditingController();
  
  late bool _active;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Which permission groups are visible for each role
  static const Map<String, List<String>> _roleVisibleGroups = {
    'sales_executive': [
      'leads', 'lead_Documents', 'marketing', 'tasks', 'meetings', 'visits',
      'itinerary', 'invoice', 'quotation', 'project', 'property',
      'services', 'assets', 'voucher',
    ],
    'team_leader': [
      'leads', 'lead_Documents', 'marketing', 'tasks', 'meetings', 'visits',
      'itinerary', 'invoice', 'quotation', 'project', 'property',
      'services', 'assets', 'voucher',
    ],
    'sales_manager': [
      'leads', 'lead_Documents', 'marketing', 'tasks', 'meetings', 'visits',
      'itinerary', 'invoice', 'quotation', 'project', 'property',
      'services', 'assets', 'salesExecutives', 'voucher',
    ],
  };

  // Permissions mapping: UI Label -> API Permission String
  Map<String, List<Map<String, String>>> _getPermissionGroups(String role) {
    final Map<String, List<Map<String, String>>> groups = {};

    // 1. Leads Group — role-specific: delete for exec, bulkUpdate for manager/tl
    final bool isExecutive = role == 'sales_executive';
    groups['leads'] = [
      {'key': PermissionModules.LEADS_VIEW, 'label': 'View'},
      {'key': PermissionModules.LEADS_DOWNLOAD, 'label': 'Download'},
      {'key': PermissionModules.LEADS_CREATE_MANUAL, 'label': 'Create Manual'},
      {'key': PermissionModules.LEADS_BULK_UPLOAD, 'label': 'Bulk Upload'},
      {'key': PermissionModules.LEADS_ASSIGN, 'label': 'Assign'},
      {'key': PermissionModules.LEADS_BULK_ASSIGN, 'label': 'Bulk Assign'},
      {'key': PermissionModules.LEADS_CALL, 'label': 'Call'},
      {'key': PermissionModules.LEADS_CALL_PLAY, 'label': 'Play Call Recording'},
      {'key': PermissionModules.LEADS_CALL_DOWNLOAD, 'label': 'Download Call Recording'},
      {'key': PermissionModules.INTEGRATION_IVR_CALL, 'label': 'IVR Call'},
      {'key': PermissionModules.LEADS_WHATSAPP, 'label': 'WhatsApp'},
      {'key': PermissionModules.LEADS_MAIL, 'label': 'Mail'},
      {'key': PermissionModules.LEADS_UPDATE_DETAILS, 'label': 'Update Details'},
      {'key': PermissionModules.LEADS_UPDATE_STATUS, 'label': 'Update Status'},
      {'key': PermissionModules.LEADS_UPDATE_PIPELINE, 'label': 'Update Lead Stage'},
      if (isExecutive)
        {'key': PermissionModules.LEADS_DELETE, 'label': 'Delete'},
      if (!isExecutive)
        {'key': PermissionModules.LEADS_BULK_UPDATE, 'label': 'Bulk Update'},
    ];

    // 2. Lead Documents Group
    groups['lead_Documents'] = [
      {'key': PermissionModules.LEAD_DOCS_VIEW, 'label': 'View'},
      {'key': PermissionModules.LEAD_DOCS_UPLOAD, 'label': 'Upload'},
      {'key': PermissionModules.LEAD_DOCS_DELETE, 'label': 'Delete'},
      {'key': PermissionModules.LEAD_DOCS_DOWNLOAD, 'label': 'Download'},
      {'key': PermissionModules.LEAD_DOCS_REQUEST, 'label': 'Create Request'},
      {'key': PermissionModules.LEAD_DOCS_FORM_CREATE, 'label': 'Create Form'},
      {'key': PermissionModules.LEAD_DOCS_FORM_EDIT, 'label': 'Edit Form'},
      {'key': PermissionModules.LEAD_DOCS_FORM_DELETE, 'label': 'Delete Form'},
    ];

    // 3. Marketing Group
    groups['marketing'] = [
      {'key': PermissionModules.MARKETING_TEMPLATES_VIEW, 'label': 'View Templates'},
      {'key': PermissionModules.MARKETING_TEMPLATES_CREATE, 'label': 'Create Templates'},
    ];

    // 4. Tasks Group
    groups['tasks'] = [
      {'key': PermissionModules.TASKS_VIEW, 'label': 'View'},
      {'key': PermissionModules.TASKS_CREATE, 'label': 'Create'},
      {'key': PermissionModules.TASKS_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.TASKS_DELETE, 'label': 'Delete'},
    ];

    // 5. Meetings Group
    groups['meetings'] = [
      {'key': PermissionModules.MEETINGS_VIEW, 'label': 'View'},
      {'key': PermissionModules.MEETINGS_CREATE, 'label': 'Create'},
      {'key': PermissionModules.MEETINGS_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.MEETINGS_DELETE, 'label': 'Delete'},
    ];

    // 6. Visits Group — no updateStatus / delete
    groups['visits'] = [
      {'key': PermissionModules.VISITS_VIEW, 'label': 'View'},
      {'key': PermissionModules.VISITS_CREATE, 'label': 'Create'},
      {'key': PermissionModules.VISITS_UPDATE, 'label': 'Update'},
    ];

    // 7. Itinerary Group
    groups['itinerary'] = [
      {'key': PermissionModules.ITINERARY_VIEW, 'label': 'View'},
      {'key': PermissionModules.ITINERARY_DOWNLOAD, 'label': 'Download'},
      {'key': PermissionModules.ITINERARY_CREATE, 'label': 'Create'},
      {'key': PermissionModules.ITINERARY_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.ITINERARY_SEND, 'label': 'Send'},
      {'key': PermissionModules.ITINERARY_DELETE, 'label': 'Delete'},
    ];

    // 8. Invoice Group
    groups['invoice'] = [
      {'key': PermissionModules.INVOICE_VIEW, 'label': 'View'},
      {'key': PermissionModules.INVOICE_DOWNLOAD, 'label': 'Download'},
      {'key': PermissionModules.INVOICE_CREATE, 'label': 'Create'},
      {'key': PermissionModules.INVOICE_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.INVOICE_SEND, 'label': 'Send'},
      {'key': PermissionModules.INVOICE_DELETE, 'label': 'Delete'},
    ];

    // 9. Quotation Group
    groups['quotation'] = [
      {'key': PermissionModules.QUOTATION_VIEW, 'label': 'View'},
      {'key': PermissionModules.QUOTATION_DOWNLOAD, 'label': 'Download'},
      {'key': PermissionModules.QUOTATION_CREATE, 'label': 'Create'},
      {'key': PermissionModules.QUOTATION_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.QUOTATION_SEND, 'label': 'Send'},
      {'key': PermissionModules.QUOTATION_DELETE, 'label': 'Delete'},
    ];

    // 10. Project Group — no updateStatus / delete
    groups['project'] = [
      {'key': PermissionModules.PROJECT_VIEW, 'label': 'View'},
      {'key': PermissionModules.PROJECT_CREATE, 'label': 'Create'},
      {'key': PermissionModules.PROJECT_UPDATE, 'label': 'Update'},
    ];

    // 11. Property Group — no updateStatus / delete, add lastUpdate
    groups['property'] = [
      {'key': PermissionModules.PROPERTY_VIEW, 'label': 'View'},
      {'key': PermissionModules.PROPERTY_CREATE, 'label': 'Create'},
      {'key': PermissionModules.PROPERTY_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.PROPERTY_LAST_UPDATED, 'label': 'Last Update'},
    ];

    // 12. Services Group
    groups['services'] = [
      {'key': PermissionModules.SERVICES_VIEW, 'label': 'View'},
      {'key': PermissionModules.SERVICES_CREATE, 'label': 'Create'},
      {'key': PermissionModules.SERVICES_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.SERVICES_DELETE, 'label': 'Delete'},
    ];

    // 13. Assets Group
    groups['assets'] = [
      {'key': PermissionModules.ASSETS_VIEW, 'label': 'View'},
      {'key': PermissionModules.ASSETS_CREATE, 'label': 'Create'},
      {'key': PermissionModules.ASSETS_DELETE, 'label': 'Delete'},
      {'key': PermissionModules.ASSETS_DOWNLOAD, 'label': 'Download'},
    ];

    // 14. Voucher Group
    groups['voucher'] = [
      {'key': PermissionModules.VOUCHER_VIEW, 'label': 'View'},
      {'key': PermissionModules.VOUCHER_CREATE, 'label': 'Create'},
      {'key': PermissionModules.VOUCHER_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.VOUCHER_SEND, 'label': 'Send/Share'},
      {'key': PermissionModules.VOUCHER_DOWNLOAD, 'label': 'Download'},
      {'key': PermissionModules.VOUCHER_DELETE, 'label': 'Delete'},
    ];

    // 15. Staff Management Group (Sales Executives)
    groups['salesExecutives'] = [
      {'key': PermissionModules.SALES_EXEC_VIEW, 'label': 'View'},
      {'key': PermissionModules.SALES_EXEC_CREATE, 'label': 'Create'},
      {'key': PermissionModules.SALES_EXEC_UPDATE, 'label': 'Update'},
      {'key': PermissionModules.SALES_EXEC_DELETE, 'label': 'Delete'},
    ];

    // Filter groups based on role visibility
    final visibleGroups = _roleVisibleGroups[role];
    if (visibleGroups != null) {
      groups.removeWhere((key, _) => !visibleGroups.contains(key));
    }

    return groups;
  }

  String? _getModuleForGroup(String groupKey) {
    switch (groupKey) {
      case 'leads': return PermissionModules.LEADS;
      case 'lead_Documents': return PermissionModules.LEAD_DOCS;
      case 'marketing': return PermissionModules.MARKETING;
      case 'tasks': return PermissionModules.TASK;
      case 'meetings': return PermissionModules.MEETING;
      case 'visits': return PermissionModules.VISITS;
      case 'itinerary': return PermissionModules.ITINERARY;
      case 'invoice': return PermissionModules.INVOICE;
      case 'quotation': return PermissionModules.QUOTATION;
      case 'project': return PermissionModules.PROPERTY;
      case 'property': return PermissionModules.PROPERTY;
      case 'services': return PermissionModules.SERVICES;
      case 'assets': return PermissionModules.ASSETS;
      case 'voucher': return PermissionModules.VOUCHER;
      case 'salesExecutives': return PermissionModules.STAFF_BASE;
      default: return null;
    }
  }

  String _getCategoryLabel(String key) {
    switch (key) {
      case 'lead_Documents': return 'Lead Documents';
      case 'marketing': return 'Marketing';
      case 'itinerary': return 'Itinerary';
      case 'invoice': return 'Invoice';
      case 'quotation': return 'Quotation';
      case 'services': return 'Services';
      case 'assets': return 'Assets';
      case 'voucher': return 'Voucher';
      case 'salesExecutives': return 'Sales Executives';
      default: return key[0].toUpperCase() + key.substring(1);
    }
  }

  // Selected permissions (API format)
  final Set<String> _selectedPermissions = {};

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _uniqueIdController = TextEditingController(text: s?.uniqueId ?? '');
    _nameController = TextEditingController(text: s?.name ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _phoneController = TextEditingController(text: s?.phoneNo ?? '');
    _active = s == null || s.active;
    
    // Initialize permissions from existing staff
    if (s != null) {
      debugPrint('============ LOADING STAFF PERMISSIONS ============');
      debugPrint('Staff ID: ${s.id}');
      debugPrint('Staff Name: ${s.name}');
      debugPrint('Permissions from API: ${s.permissions}');
      _selectedPermissions.addAll(s.permissions);
      debugPrint('Selected Permissions Set: $_selectedPermissions');
      debugPrint('===================================================');
    }
  }

  @override
  void dispose() {
    _uniqueIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _getRoleTitle(widget.role);
    final isEdit = widget.staff != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: Theme.of(context).cardColor,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 900),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                     isEdit ? 'Edit $title' : 'Create $title', 
                     style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)
                   ),
                   IconButton(
                     icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
                     onPressed: () => Navigator.pop(context),
                   )
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Unique ID', _uniqueIdController, isDark, isEdit)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Name', _nameController, isDark, false)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Email', _emailController, isDark, isEdit, TextInputType.emailAddress)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Phone Number', _phoneController, isDark, isEdit, TextInputType.phone)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      // Password and Active Account Row - separate them to avoid overflow
                      _buildTextField(isEdit ? 'New Password (Optional)' : 'Password', _passwordController, isDark, false, TextInputType.visiblePassword, true),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F111A) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Active Account', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                            Switch(
                              value: _active, 
                              onChanged: (v) => setState(() => _active = v),
                              activeThumbColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Permissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 4),
                      Text('Manage access levels for this staff member', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _getPermissionGroups(widget.role).entries.where((entry) {
                            final module = _getModuleForGroup(entry.key);
                            if (module == null) return true;
                            // Special check for integrations.ivr.call inside leads
                            // if (entry.key == 'leads') {
                            //    // We handle individual permissions filtering inside the card if needed, 
                            //    // but here we just check if the main LEADS module is enabled.
                            // }
                            return ref.watch(permissionsProvider).hasModule(module);
                        }).map((entry) {
                            return SizedBox(
                              width: 400,
                              child: _buildPermissionCard(_getCategoryLabel(entry.key), entry.value, isDark),
                            );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   TextButton(
                     onPressed: _isLoading ? null : () => Navigator.pop(context),
                     child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                   ),
                   const SizedBox(width: 16),
                   ElevatedButton(
                     onPressed: _isLoading ? null : _submit,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                     ),
                     child: _isLoading 
                       ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                       : Text(isEdit ? 'Update Staff' : 'Create Staff'),
                   )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4), 
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
  );

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, bool isReadOnly, [TextInputType? type, bool isPassword = false]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: type,
          readOnly: isReadOnly,
          obscureText: isPassword && _obscurePassword,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: label.contains('Password') ? (isReadOnly ? 'Leave blank to keep current' : 'Enter Password') : 'Enter $label',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F111A) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ) : null,
          ),
          validator: (v) => (!isReadOnly && !label.contains('Optional') && (v == null || v.isEmpty)) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildPermissionCard(String category, List<Map<String, String>> actions, bool isDark) {
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: isDark ? const Color(0xFF0F111A) : Colors.white,
         borderRadius: BorderRadius.circular(8), 
         border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Icon(_getCategoryIcon(category), size: 18, color: isDark ? const Color(0xFF4C6EF5) : Colors.black87),
               const SizedBox(width: 8),
               Text(category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
             ],
           ),
           const SizedBox(height: 12),
           Wrap(
             spacing: 8,
             runSpacing: 8,
             children: actions.where((e) {
                // Individual action modular checks
                if (e['key'] == PermissionModules.INTEGRATION_IVR_CALL) {
                   return ref.watch(permissionsProvider).hasModule(PermissionModules.INTEGRATION_IVR);
                }
                return true;
             }).map((e) {
               final pKey = e['key']!;
               final pLabel = e['label']!;
               final isSelected = _selectedPermissions.contains(pKey);
               
               return InkWell(
                 onTap: () {
                   setState(() {
                     if (isSelected) {
                       _selectedPermissions.remove(pKey);
                     } else {
                       _selectedPermissions.add(pKey);
                     }
                   });
                 },
                 borderRadius: BorderRadius.circular(8),
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                   decoration: BoxDecoration(
                     color: isSelected 
                       ? (isDark ? const Color(0xFF4C6EF5).withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05))
                       : Colors.transparent,
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(
                       color: isSelected 
                         ? (isDark ? const Color(0xFF4C6EF5) : Colors.black)
                         : Colors.grey.withValues(alpha: 0.3),
                     ),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(
                         isSelected ? Icons.check_circle : Icons.circle_outlined,
                         size: 14,
                         color: isSelected ? (isDark ? const Color(0xFF4C6EF5) : Colors.black) : Colors.grey,
                       ),
                       const SizedBox(width: 6),
                       Text(
                         pLabel, 
                         style: TextStyle(
                           fontSize: 12, 
                           fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                           color: isDark ? Colors.white : Colors.black87,
                         )
                       ),
                     ],
                   ),
                 ),
               );
             }).toList(),
           )
         ],
       ),
     );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Leads': return Icons.leaderboard;
      case 'Lead Documents': return Icons.description;
      case 'Marketing': return Icons.campaign;
      case 'Tasks': return Icons.task_alt;
      case 'Meetings': return Icons.calendar_month;
      case 'Visits': return Icons.location_on;
      case 'Itinerary': return Icons.route;
      case 'Invoice': return Icons.receipt_long;
      case 'Quotation': return Icons.request_quote;
      case 'Project': return Icons.apartment;
      case 'Property': return Icons.home;
      case 'Services': return Icons.business_center;
      case 'Assets': return Icons.inventory_2;
      case 'Voucher': return Icons.discount;
      case 'Sales Executives': return Icons.person;
      default: return Icons.category;
    }
  }

  String _getRoleTitle(String role) {
    if (role == 'sales_manager') return 'Sales Manager';
    if (role == 'team_leader') return 'Team Leader';
    return 'Sales Executive';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final data = {
        "uniqueId": _uniqueIdController.text.trim(),
        "name": _nameController.text.trim(),
        "permissions": _selectedPermissions.toList(),
        "systemRole": widget.role,
        "status": "active",
        "active": _active,
      };
      
      if (_passwordController.text.isNotEmpty) {
        data["password"] = _passwordController.text;
      }

      if (widget.staff != null) {
        // Update existing staff
        debugPrint('========== UPDATING STAFF ==========');
        debugPrint('Staff ID: ${widget.staff!.id}');
        debugPrint('Role: ${widget.role}');
        debugPrint('Payload: $data');
        debugPrint('====================================');
        
        await ref.read(staffProvider(widget.role).notifier).updateStaff(widget.staff!.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff updated successfully'), backgroundColor: Colors.green)
          );
        }
      } else {
        // Create new staff - include all required fields
        data["email"] = _emailController.text.trim();
        data["phoneNo"] = _phoneController.text.trim();
        
        debugPrint('========== CREATING STAFF ==========');
        debugPrint('Role: ${widget.role}');
        debugPrint('Payload: $data');
        debugPrint('====================================');

        await ref.read(staffProvider(widget.role).notifier).createStaff(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff created successfully'), backgroundColor: Colors.green)
          );
        }
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
