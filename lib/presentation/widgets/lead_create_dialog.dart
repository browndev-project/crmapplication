import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crmapp/presentation/providers/lead_provider.dart';
import 'package:crmapp/presentation/providers/service_provider.dart';
import 'package:crmapp/presentation/providers/dashboard_provider.dart';
import 'package:crmapp/presentation/providers/property_provider.dart';
import 'package:intl/intl.dart';

import '../../data/models/lead_model.dart';
import '../../data/models/service_model.dart';
import '../../data/models/property_model.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../providers/staff_provider.dart';
import '../../core/constants/permission_constants.dart';

import '../../core/utils/formatters.dart';

import '../../core/utils/date_utils.dart';

class LeadCreateDialog extends ConsumerWidget {
  final Lead? lead;

  const LeadCreateDialog({super.key, this.lead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LeadCreateDialogForm(lead: lead);
  }
}

class _LeadCreateDialogForm extends ConsumerStatefulWidget {
  final Lead? lead;

  const _LeadCreateDialogForm({this.lead});

  @override
  ConsumerState<_LeadCreateDialogForm> createState() => _LeadCreateDialogFormState();
}

class _LeadCreateDialogFormState extends ConsumerState<_LeadCreateDialogForm> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _countryController;
  late TextEditingController _dobController;
  late TextEditingController _referralNameController;
  late TextEditingController _destinationController;
  DateTime? _travelStartDate;
  DateTime? _travelEndDate;
  late TextEditingController _adultsController;
  late TextEditingController _childrenController;
  String? _hotelPreference;
  late TextEditingController _vehiclePrefController;
  late TextEditingController _travelBudgetController;
  late TextEditingController _pickupController;
  late TextEditingController _dropController;
  late TextEditingController _specialRequestsController;

  String? _gender;
  String? _travelerType;

  String? _selectedProjectId;
  String? _selectedPropertyId;
  String? _selectedServiceId;
  String _source = 'Manual Upload';
  String? _statusId;
  String _pipeline = 'Cold'; 
  String? _assignedTo;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.lead?.name ?? '');
    _emailController = TextEditingController(text: widget.lead?.email ?? '');
    _phoneController = TextEditingController(text: widget.lead?.phoneNo ?? '');
    _amountController = TextEditingController(); 
    _descriptionController = TextEditingController(text: widget.lead?.description ?? '');
    _address1Controller = TextEditingController();
    _address2Controller = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _zipController = TextEditingController();
    _countryController = TextEditingController();
    _dobController = TextEditingController(text: DateTimeUtils.formatSafe(widget.lead?.dob, format: 'dd MMM yyyy'));
    _referralNameController = TextEditingController(text: widget.lead?.referralName ?? '');
    _destinationController = TextEditingController(text: widget.lead?.destination ?? '');
    // Parse travelStartDate and travelEndDate from the lead model or fallback from combined string
    _travelStartDate = DateTimeUtils.parseSafe(widget.lead?.travelStartDate ?? '');
    if (_travelStartDate == null && widget.lead?.travelDates != null) {
      final parts = widget.lead!.travelDates!.split(' to ');
      _travelStartDate = DateTimeUtils.parseSafe(parts[0].trim());
    }
    _travelEndDate = DateTimeUtils.parseSafe(widget.lead?.travelEndDate ?? '');
    if (_travelEndDate == null && widget.lead?.travelDates != null) {
      final parts = widget.lead!.travelDates!.split(' to ');
      if (parts.length > 1) _travelEndDate = DateTimeUtils.parseSafe(parts[1].trim());
    }
    _adultsController = TextEditingController(text: widget.lead?.adultCount != null ? widget.lead!.adultCount.toString() : (widget.lead?.travellers != null ? widget.lead!.travellers.toString() : ''));
    _childrenController = TextEditingController(text: widget.lead?.childrenCount != null ? widget.lead!.childrenCount.toString() : '');
    _hotelPreference = widget.lead?.hotelPreference;
    _vehiclePrefController = TextEditingController(text: widget.lead?.vehiclePreference ?? '');
    _travelBudgetController = TextEditingController(text: widget.lead?.travelBudget ?? '');
    _pickupController = TextEditingController(text: widget.lead?.pickupDrop ?? widget.lead?.pickup ?? '');
    _dropController = TextEditingController(text: widget.lead?.drop ?? '');
    _specialRequestsController = TextEditingController(text: widget.lead?.specialRequests ?? '');

    if (widget.lead != null) {
        _source = (widget.lead!.source ).isNotEmpty ? widget.lead!.source : 'Manual Upload';
        _pipeline = (widget.lead!.pipeline ).isNotEmpty ? widget.lead!.pipeline : 'Cold';
        _selectedServiceId = widget.lead!.service?.id;
        _selectedProjectId = widget.lead!.project?.id;
        _selectedPropertyId = widget.lead!.property?.id;
        _gender = widget.lead!.gender;
        _travelerType = widget.lead!.travelerType;
        _assignedTo = widget.lead!.assignedTo?.id;
        // Pre-fill amount and address
        if (widget.lead!.amount > 0) {
          _amountController.text = widget.lead!.amount.toStringAsFixed(0);
        }
        if (widget.lead!.address != null) {
          _address1Controller.text = widget.lead!.address!.address1;
          _address2Controller.text = widget.lead!.address!.address2;
          _cityController.text = widget.lead!.address!.city;
          _stateController.text = widget.lead!.address!.state;
          _zipController.text = widget.lead!.address!.pinCode;
          _countryController.text = widget.lead!.address!.country;
        }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(servicesProvider.notifier).fetchServices(page: 1);
      ref.read(leadStatusProvider.notifier).fetchStatuses();
      ref.read(dashboardProvider.notifier).fetchDashboardData();
      ref.read(propertyProvider.notifier).fetchProjects();
      ref.read(staffProvider('company_admin').notifier).fetchUsers();
      ref.read(staffProvider('sales_executive').notifier).fetchUsers();
      ref.read(staffProvider('team_leader').notifier).fetchUsers();
      ref.read(staffProvider('sales_manager').notifier).fetchUsers();
      ref.read(allPropertiesProvider.notifier).resetFilters();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _dobController.dispose();
    _referralNameController.dispose();
    _destinationController.dispose();
    _adultsController.dispose();
    _childrenController.dispose();
    _vehiclePrefController.dispose();
    _travelBudgetController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
        final startStr = _travelStartDate != null ? DateFormat('yyyy-MM-dd').format(_travelStartDate!) : '';
        final endStr   = _travelEndDate   != null ? DateFormat('yyyy-MM-dd').format(_travelEndDate!)   : '';
        final travelDatesStr = endStr.isNotEmpty ? '$startStr to $endStr' : startStr;

      final tripDetails = <String, dynamic>{
        "destination": _destinationController.text.trim(),
        "travelDates": travelDatesStr,
        "startDate": startStr,
        "endDate": endStr,
        "travellers": (int.tryParse(_adultsController.text.trim()) ?? 0) + (int.tryParse(_childrenController.text.trim()) ?? 0),
        "numAdults": int.tryParse(_adultsController.text.trim()) ?? 0,
        "numChildren": int.tryParse(_childrenController.text.trim()) ?? 0,
        "hotelPreference": _hotelPreference ?? '',
        "hotelCategory": _hotelPreference ?? '',
        "vehiclePreference": _vehiclePrefController.text.trim(),
        "travelBudget": _travelBudgetController.text.trim(),
        "pickupDrop": _pickupController.text.trim(),
        "pickup": _pickupController.text.trim(),
        "drop": _dropController.text.trim(),
        "specialRequests": _specialRequestsController.text.trim(),
      };
      if (_travelerType != null) {
        tripDetails["travelerType"] = _travelerType;
      }

      // Trip object matching backend schema (PATCH endpoint expects "trip" key)
      final tripData = <String, dynamic>{
        "destination": _destinationController.text.trim(),
        "startDate": startStr,
        "endDate": endStr,
        "numAdults": int.tryParse(_adultsController.text.trim()) ?? 0,
        "numChildren": int.tryParse(_childrenController.text.trim()) ?? 0,
        "hotelCategory": _hotelPreference ?? '',
        "vehiclePreference": _vehiclePrefController.text.trim(),
        "pickupLocation": _pickupController.text.trim(),
        "dropLocation": _dropController.text.trim(),
        "specialRequests": _specialRequestsController.text.trim(),
        "budgetRange": _travelBudgetController.text.trim(),
      };
      if (_travelerType != null) {
        tripData["travelerType"] = _travelerType;
      }

      final leadData = <String, dynamic>{
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "phoneNo": _phoneController.text.trim(),
        "amount": double.tryParse(_amountController.text.trim()) ?? 0.0,
        "description": _descriptionController.text.trim(),
        "dob": DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_dobController.text)),
        "gender": _gender,
        "referralName": _referralNameController.text.trim(),
        "address": {
          "address1": _address1Controller.text.trim(),
          "address2": _address2Controller.text.trim(),
          "city": _cityController.text.trim(),
          "state": _stateController.text.trim(),
          "pinCode": _zipController.text.trim(),
          "country": _countryController.text.trim(),
        },
        "service": _selectedServiceId ?? "",
        "project": _selectedProjectId ?? "",
        "property": _selectedPropertyId ?? "",
        "source": _source,
        if (widget.lead == null) "status": _statusId,
        "pipeline": _pipeline,
        "assignedTo": _assignedTo,
        "travelDetails": tripDetails,
        "trip": tripData,
        // Flatten trip fields to root for backend compatibility
        "destination": _destinationController.text.trim(),
        "travelDates": travelDatesStr,
        "startDate": startStr,
        "endDate": endStr,
        "travellers": ((int.tryParse(_adultsController.text.trim()) ?? 0) + (int.tryParse(_childrenController.text.trim()) ?? 0)).toString(),
        "hotelPreference": _hotelPreference ?? '',
        "vehiclePreference": _vehiclePrefController.text.trim(),
        "travelBudget": _travelBudgetController.text.trim(),
        "pickupDrop": _pickupController.text.trim(),
        "pickup": _pickupController.text.trim(),
        "drop": _dropController.text.trim(),
        "specialRequests": _specialRequestsController.text.trim(),
        if (_travelerType != null) "travelerType": _travelerType,
      };

      if (widget.lead != null) {
         await ref.read(leadsProvider.notifier).updateLead(widget.lead!.id, leadData);
      } else {
         await ref.read(leadsProvider.notifier).createLead(leadData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lead != null ? 'Lead updated successfully' : 'Lead created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesState = ref.watch(servicesProvider);
    final statusState = ref.watch(leadStatusProvider);
    final dashboardState = ref.watch(dashboardProvider);
    
    final services = servicesState.services;
    final statuses = statusState.statuses.where((s) => s.isActive).toList();
    
    final pipelineItems = <String>[];
    if (dashboardState.data?.pipelines?.pipelineCounts != null) {
        pipelineItems.addAll(dashboardState.data!.pipelines!.pipelineCounts.keys);
    }
    for (var s in ['Hot', 'Warm', 'Cold', 'Closed', 'Lost']) {
        if (!pipelineItems.contains(s)) pipelineItems.add(s);
    }

    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final hasPropertyModule = permissions.hasModule(PermissionModules.PROPERTY, userRole: userRole);
    final hasServiceModule = permissions.hasModule(PermissionModules.SERVICES, userRole: userRole);
    final canAssign = permissions.hasPermission(PermissionModules.LEADS_ASSIGN, userRole: userRole);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final executives = ref.watch(staffProvider('sales_executive')).users;
    final leaders = ref.watch(staffProvider('team_leader')).users;
    final managers = ref.watch(staffProvider('sales_manager')).users;
    final admins = ref.watch(staffProvider('company_admin')).users;

    final currentAssignedId = _assignedTo;
    final activeAdmins = admins.where((u) => (u.status.toLowerCase() == 'active' && u.active == true) || u.id == currentAssignedId).toList();
    final activeManagers = managers.where((u) => (u.status.toLowerCase() == 'active' && u.active == true) || u.id == currentAssignedId).toList();
    final activeLeaders = leaders.where((u) => (u.status.toLowerCase() == 'active' && u.active == true) || u.id == currentAssignedId).toList();
    final activeExecutives = executives.where((u) => (u.status.toLowerCase() == 'active' && u.active == true) || u.id == currentAssignedId).toList();

    final allRaw = [...activeAdmins, ...activeManagers, ...activeLeaders, ...activeExecutives];
    
    String formatSystemRole(String role) {
      switch (role.toLowerCase()) {
        case 'company_admin': return 'Company Admin';
        case 'sales_manager': return 'Sales Manager';
        case 'team_leader': return 'Team Leader';
        case 'sales_executive': return 'Sales Executive';
        default: return role.replaceAll('_', ' ');
      }
    }

    // Unique items just in case
    final List<DropdownMenuItem<String>> uniqueAssignedToItems = [];
    for (var u in allRaw) {
        if (!uniqueAssignedToItems.any((e) => e.value == u.id)) {
            uniqueAssignedToItems.add(
              DropdownMenuItem(
                value: u.id, 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        u.name, 
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.blue : Colors.blue.shade700).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (isDark ? Colors.blue : Colors.blue.shade700).withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        formatSystemRole(u.systemRole),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
        }
    }
    
    final isEdit = widget.lead != null;

    if (isEdit && statuses.isNotEmpty) {
      if (_statusId == null && (widget.lead!.status ).isNotEmpty) {
        final match = statuses.where(
          (s) => s.name.toLowerCase() == widget.lead!.status.toLowerCase()
        );
        if (match.isNotEmpty) {
          _statusId = match.first.id;
        }
      }
      if (_statusId == null || !statuses.any((s) => s.id == _statusId)) {
        _statusId = statuses.first.id;
      }
    }

    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
       backgroundColor: Theme.of(context).cardColor,
       insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 900),
         child: Column(
           children: [
             Padding(
               padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(isEdit ? "Edit Lead" : "Create Lead", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                   IconButton(
                     onPressed: () => Navigator.pop(context),
                     icon: const Icon(Icons.close),
                     style: IconButton.styleFrom(backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                   )
                 ],
               ),
             ),
             const Divider(height: 1, thickness: 0.5),
             Expanded(
               child: SingleChildScrollView(
                 padding: const EdgeInsets.all(24),
                 child: Form(
                   key: _formKey,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       _buildTextField("Name", _nameController, isDark, required: true),
                       const SizedBox(height: 16),
                       _buildTextField("Email", _emailController, isDark, keyboardType: TextInputType.emailAddress),
                       const SizedBox(height: 16),
                       Row(
                         children: [
                            Expanded(child: _buildTextField("Phone Number", _phoneController, isDark, required: false, keyboardType: TextInputType.phone)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField("Amount", _amountController, isDark, keyboardType: TextInputType.number)),
                         ],
                       ),
                       const SizedBox(height: 16),
                       TextFormField(
                         controller: _dobController,
                         readOnly: true,
                         onTap: () async {
                             final picked = await showDatePicker(
                                 context: context,
                                 initialDate: DateTimeUtils.parseSafe(_dobController.text) ?? DateTime.now(),
                                 firstDate: DateTime(1900),
                                 lastDate: DateTime.now(),
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
                                 setState(() {
                                     _dobController.text = DateTimeUtils.formatDayMonthYear(picked);
                                 });
                             }
                         },
                         style: const TextStyle(fontSize: 14),
                         decoration: InputDecoration(
                             labelText: "Date of Birth",
                             hintText: "DD MMM YYYY",
                             hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 13),
                             floatingLabelBehavior: FloatingLabelBehavior.always,
                             suffixIcon: const Icon(Icons.calendar_today, size: 20),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
                             enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
                             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                         ),
                       ),
                        const SizedBox(height: 16),
                        _buildDropdown("Gender", [
                          const DropdownMenuItem(value: null, child: Text('Select Gender')),
                          const DropdownMenuItem(value: 'male', child: Text('Male')),
                          const DropdownMenuItem(value: 'female', child: Text('Female')),
                          const DropdownMenuItem(value: 'other', child: Text('Other')),
                        ], (val) => setState(() => _gender = val as String?), _gender, isDark),
                        const SizedBox(height: 16),
                        _buildTextField("Description", _descriptionController, isDark, maxLines: 3),
                        const SizedBox(height: 24),
                       
                       const Text('Address Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 12),
                       _buildTextField("Address Line 1", _address1Controller, isDark),
                       const SizedBox(height: 12),
                       _buildTextField("Address Line 2", _address2Controller, isDark),
                       const SizedBox(height: 16),
                       Row(
                         children: [
                           Expanded(child: _buildTextField("City", _cityController, isDark)),
                           const SizedBox(width: 16),
                           Expanded(child: _buildTextField("State", _stateController, isDark)),
                         ],
                       ),
                       const SizedBox(height: 16),
                       Row(
                         children: [
                           Expanded(child: _buildTextField("Pin Code", _zipController, isDark)),
                           const SizedBox(width: 16),
                           Expanded(child: _buildTextField("Country", _countryController, isDark)),
                         ],
                       ),
                       
                       if (hasPropertyModule) ...[
                           const SizedBox(height: 24),
                           const Text('Project & Property Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 12),

                            Consumer(
                                    builder: (context, ref, _) {
                                      final projectState = ref.watch(propertyProvider);
                                      final List<DropdownMenuItem<String?>> projectItems = [
                                        const DropdownMenuItem<String?>(value: null, child: Text('None')),
                                        ...projectState.projects.map((p) => DropdownMenuItem<String?>(
                                          value: p.id,
                                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                                        )),
                                      ];

                                      final validProjectId = projectState.projects.any((p) => p.id == _selectedProjectId) 
                                          ? _selectedProjectId 
                                          : null;

                                      return _buildDropdown(
                                        "Project", 
                                        projectItems, 
                                        (val) {
                                          setState(() {
                                            _selectedProjectId = val as String?;
                                            _selectedPropertyId = null;
                                          });
                                        }, 
                                        validProjectId, 
                                        isDark
                                      );
                                    },
                                  ),
                                const SizedBox(height: 16),

                                  // Property dropdown — filtered by selected project
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final allPropState = ref.watch(allPropertiesProvider);
                                      final List<Property> filteredProperties;

                                      if (_selectedProjectId == null) {
                                        // No project → show standalone properties
                                        filteredProperties = allPropState.properties
                                            .where((p) => p.projectId.isEmpty)
                                            .toList();
                                      } else {
                                        // Project selected → show standalone + that project's properties
                                        filteredProperties = allPropState.properties
                                            .where((p) => p.projectId.isEmpty || p.projectId == _selectedProjectId)
                                            .toList();
                                      }

                                      final List<DropdownMenuItem<String?>> propItems = [
                                        const DropdownMenuItem<String?>(value: null, child: Text('None')),
                                        ...filteredProperties.map((p) => DropdownMenuItem<String?>(
                                          value: p.id,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
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

                                      // Removed premature nullification of _selectedPropertyId here

                                      return _buildDropdown(
                                        "Property",
                                        propItems,
                                        (val) => setState(() => _selectedPropertyId = val as String?),
                                        validPropertyId,
                                        isDark,
                                        itemHeight: null,
                                      );
                                    },
                                  ),
                        ],

                        const SizedBox(height: 24),
                        const Text('Lead Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        
                        Row(
                            children: [
                                if (hasServiceModule)
                                Expanded(
                                     child: Builder(
                                       builder: (context) {
                                         final uniqueServices = <String, Service>{};
                                         for (var s in services) {
                                             uniqueServices[s.id] = s;
                                         }
                                         if (_selectedServiceId != null && !uniqueServices.containsKey(_selectedServiceId)) {
                                             if (widget.lead?.service?.id == _selectedServiceId) {
                                                 uniqueServices[_selectedServiceId!] = widget.lead!.service!;
                                             }
                                         }
                                         if (_selectedServiceId == null && widget.lead?.service?.id != null && uniqueServices.containsKey(widget.lead!.service!.id)) {
                                           WidgetsBinding.instance.addPostFrameCallback((_) {
                                             if (mounted) setState(() => _selectedServiceId = widget.lead!.service!.id);
                                           });
                                         }
                                         final serviceItems = <DropdownMenuItem<String?>>[
                                           const DropdownMenuItem<String?>(value: null, child: Text('None', overflow: TextOverflow.ellipsis)),
                                           ...uniqueServices.values.map((s) => DropdownMenuItem<String?>(
                                              value: s.id,
                                              child: Text(s.name, overflow: TextOverflow.ellipsis),
                                           )),
                                         ];
                                         final validValue = uniqueServices.containsKey(_selectedServiceId) ? _selectedServiceId : null;
                                         return _buildDropdown(
                                             "Service", 
                                             serviceItems, 
                                             (val) => setState(() => _selectedServiceId = val as String?), 
                                             validValue, 
                                             isDark
                                         );
                                       }
                                     )
                                ),
                                if (hasServiceModule) const SizedBox(width: 16),
                                Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        var items = <String>[];
                                        if (dashboardState.data?.leadSources?.sources != null) {
                                            items.addAll(dashboardState.data!.leadSources!.sources.keys);
                                        }
                                        if (items.isEmpty) {
                                            items = ["Manual Upload", "Website", "Referral", "Other", "Whatsapp", "Justdial", "GMB", "Google Ads", "IndiaMart", "Tradeindia", "Sulekha", "Housing.com", "MagicBricks", "99Acre"];
                                        }
                                        if (!items.contains(_source) && _source.isNotEmpty) items.add(_source);
                                        return _buildDropdown("Source", items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
                                        (val) => setState(() => _source = val as String), _source, isDark);
                                      }
                                    )
                                )
                            ]
                        ),
                        const SizedBox(height: 16),
                        
                        _buildDropdown(
                            "Assigned To", 
                            [
                              const DropdownMenuItem(value: null, child: Text("Unassigned")),
                              ...uniqueAssignedToItems
                            ], 
                            canAssign ? (val) => setState(() => _assignedTo = val as String?) : null, 
                            uniqueAssignedToItems.any((e) => e.value == _assignedTo) ? _assignedTo : null, 
                            isDark
                        ),
                        const SizedBox(height: 16),
                        
                        if (_source == "Referral") ...[
                          _buildTextField("Referral Name", _referralNameController, isDark, required: true),
                          const SizedBox(height: 16),
                        ],

                        if (widget.lead == null)
                          _buildDropdown(
                              "Status", 
                              statuses.map((s) => DropdownMenuItem(value: s.id, child: Text(toTitleCase(s.name)))).toList(), 
                              (val) => setState(() => _statusId = val as String), 
                              statuses.any((s) => s.id == _statusId) ? _statusId : (statuses.isNotEmpty ? statuses.first.id : null), 
                              isDark
                          ),
                        if (widget.lead == null) const SizedBox(height: 16),
                        _buildDropdown(
                            "Lead Stage", 
                            pipelineItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
                            (val) => setState(() => _pipeline = val as String), 
                            _pipeline, 
                            isDark
                        ),
                        const SizedBox(height: 16),

                        // Trip / Travel Details
                        if (permissions.can(PermissionModules.TRIP, permission: PermissionModules.TRIP_VIEW, userRole: userRole)) ...[
                          const Text('Trip & Travel Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildDropdown("Traveler Type", [
                            const DropdownMenuItem(value: null, child: Text('Select Traveler Type')),
                            const DropdownMenuItem(value: 'solo', child: Text('Solo')),
                            const DropdownMenuItem(value: 'couple', child: Text('Couple')),
                            const DropdownMenuItem(value: 'family', child: Text('Family')),
                            const DropdownMenuItem(value: 'group', child: Text('Group')),
                          ], (val) => setState(() => _travelerType = val as String?), _travelerType, isDark),
                          const SizedBox(height: 16),
                           Row(
                            children: [
                              Expanded(child: _buildTextField("Destination", _destinationController, isDark)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Travel Start & End Date pickers
                          Row(
                            children: [
                              Expanded(child: _buildDatePickerField(
                                'Travel Start Date',
                                _travelStartDate,
                                (picked) => setState(() => _travelStartDate = picked),
                                isDark,
                              )),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDatePickerField(
                                'Travel End Date',
                                _travelEndDate,
                                (picked) => setState(() => _travelEndDate = picked),
                                isDark,
                              )),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Adults", _adultsController, isDark, keyboardType: TextInputType.number)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField("Children", _childrenController, isDark, keyboardType: TextInputType.number)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDropdown(
                            "Hotel Preference",
                            ['Standard', 'Premium', 'Luxury'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            (val) => setState(() => _hotelPreference = val as String?),
                            _hotelPreference,
                            isDark,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Vehicle Preference", _vehiclePrefController, isDark)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField("Travel Budget", _travelBudgetController, isDark)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Pickup", _pickupController, isDark)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField("Drop", _dropController, isDark)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField("Special Requests", _specialRequestsController, isDark, maxLines: 3),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              const Divider(height: 1, thickness: 0.5),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                     TextButton(
                       onPressed: () => Navigator.pop(context),
                       child: const Text("Cancel"),
                     ),
                     const SizedBox(width: 16),
                     ElevatedButton(
                       onPressed: _isLoading ? null : _submit,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0
                       ),
                       child: _isLoading 
                         ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                         : Text(widget.lead != null ? "Save Changes" : "Create Lead"),
                     ),
                  ],
                ),
              )
            ],
          ),
        )
     );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, {
      bool required = false, 
      int maxLines = 1,
      TextInputType? keyboardType,
  }) {
    return TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter $label',
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 13),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
    );
  }

  Widget _buildDropdown(String label, List<DropdownMenuItem<dynamic>> items, Function(dynamic)? onChanged, dynamic value, bool isDark, {double? itemHeight}) {
    return DropdownButtonFormField(
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        itemHeight: itemHeight,
        dropdownColor: Theme.of(context).cardColor,
        style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
        selectedItemBuilder: (context) => items.map((item) {
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
          return child;
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
    );
  }

  /// Reusable read-only date picker field with calendar icon
  Widget _buildDatePickerField(
    String label,
    DateTime? currentValue,
    void Function(DateTime picked) onPicked,
    bool isDark,
  ) {
    final formatted = currentValue != null
        ? DateFormat('dd MMM yyyy').format(currentValue)
        : '';
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: formatted),
      style: const TextStyle(fontSize: 14),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: currentValue ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? const ColorScheme.dark(primary: Colors.blueAccent)
                    : const ColorScheme.light(primary: Colors.black),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onPicked(picked);
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select date',
        hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 13),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: const Icon(Icons.calendar_today, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
