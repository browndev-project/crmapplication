
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lead_provider.dart';
import '../providers/service_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/property_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../core/constants/permission_constants.dart';

import '../../core/utils/formatters.dart';

class LeadBulkUpdateDialog extends ConsumerStatefulWidget {
  final List<String> leadIds;

  const LeadBulkUpdateDialog({
    super.key,
    required this.leadIds,
  });

  @override
  ConsumerState<LeadBulkUpdateDialog> createState() => _LeadBulkUpdateDialogState();
}

class _LeadBulkUpdateDialogState extends ConsumerState<LeadBulkUpdateDialog> {
  String? _selectedProjectId;
  String? _selectedPropertyId;
  String? _selectedServiceId;
  String? _statusId;
  String? _pipeline;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(servicesProvider.notifier).fetchServices(page: 1);
      ref.read(leadStatusProvider.notifier).fetchStatuses();
      ref.read(dashboardProvider.notifier).fetchDashboardData();
      ref.read(propertyProvider.notifier).fetchProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final servicesState = ref.watch(servicesProvider);
    final statusState = ref.watch(leadStatusProvider);
    final dashboardState = ref.watch(dashboardProvider);
    final projectState = ref.watch(propertyProvider);
    
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_note, color: isDark ? Colors.white : Colors.black, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bulk Update Leads",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          "Modifying ${widget.leadIds.length} records",
                          style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),
              
              _buildDropdown(
                label: "STATUS",
                value: _statusId,
                items: statuses.map((s) => DropdownMenuItem(value: s.id, child: Text(toTitleCase(s.name)))).toList(),
                onChanged: (val) => setState(() => _statusId = val),
                hint: "Select status",
              ),
              const SizedBox(height: 18),

              _buildDropdown(
                label: "LEAD STAGE (PIPELINE)",
                value: _pipeline,
                items: pipelineItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _pipeline = val),
                hint: "Select stage",
              ),
              const SizedBox(height: 18),

              if (hasServiceModule) ...[
                _buildDropdown(
                  label: "SERVICE",
                  value: _selectedServiceId,
                  items: services.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (val) => setState(() => _selectedServiceId = val),
                  hint: "Select service",
                ),
                const SizedBox(height: 18),
              ],

              if (hasPropertyModule) ...[
                _buildDropdown(
                  label: "PROJECT",
                  value: _selectedProjectId,
                  items: projectState.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProjectId = val;
                      _selectedPropertyId = null;
                    });
                  },
                  hint: "Select project",
                ),
                const SizedBox(height: 18),

                if (_selectedProjectId != null)
                  Consumer(
                    builder: (context, ref, _) {
                      final propState = ref.watch(projectPropertiesProvider(_selectedProjectId!));
                      final propItems = propState.properties.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      )).toList();

                      return _buildDropdown(
                        label: "PROPERTY", 
                        value: _selectedPropertyId,
                        items: propItems, 
                        onChanged: (val) => setState(() => _selectedPropertyId = val), 
                        hint: "Select property",
                      );
                    },
                  ),
              ],
              
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUpdating ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdating || (_statusId == null && _pipeline == null && _selectedServiceId == null && _selectedProjectId == null)
                          ? null
                          : _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isUpdating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Apply Changes", style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required ValueChanged<dynamic> onChanged,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<dynamic>(
          initialValue: value,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.normal),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5),
            ),
            isDense: true,
          ),
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
        ),
      ],
    );
  }

  Future<void> _handleUpdate() async {
    setState(() => _isUpdating = true);
    
    final updates = <String, dynamic>{};
    if (_statusId != null) updates['status'] = _statusId;
    if (_pipeline != null) updates['pipeline'] = _pipeline;
    if (_selectedServiceId != null) updates['service'] = _selectedServiceId;
    if (_selectedProjectId != null) updates['project'] = _selectedProjectId;
    if (_selectedPropertyId != null) updates['property'] = _selectedPropertyId;

    try {
      final success = await ref.read(leadsProvider.notifier).bulkUpdate(widget.leadIds, updates);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Leads updated successfully"), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update leads"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}
