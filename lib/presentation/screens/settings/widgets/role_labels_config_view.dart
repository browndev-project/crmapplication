import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../data/models/role_labels_model.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/login_provider.dart';
import '../../../../core/constants/permission_constants.dart';

class RoleLabelsConfigView extends ConsumerStatefulWidget {
  const RoleLabelsConfigView({super.key});

  @override
  ConsumerState<RoleLabelsConfigView> createState() => _RoleLabelsConfigViewState();
}

class _RoleLabelsConfigViewState extends ConsumerState<RoleLabelsConfigView> {
  bool _isLoading = false;
  
  // Local Data
  String _ownerLabel = 'Company Owner';
  String _managerLabel = 'Sales Manager';
  String _leaderLabel = 'Team Leader';
  String _executiveLabel = 'Sales Executive';

  @override
  void initState() {
    super.initState();
    _fetchLabels();
  }

  Future<void> _fetchLabels() async {
    setState(() => _isLoading = true);
    try {
      final labels = await ref.read(settingsServiceProvider).fetchRoleLabels();
      if (labels != null) {
        setState(() {
          _ownerLabel = labels.companyAdmin;
          _managerLabel = labels.salesManager;
          _leaderLabel = labels.teamLeader;
          _executiveLabel = labels.salesExecutive;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading labels: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLabels() async {
    setState(() => _isLoading = true);
    try {
      final newLabels = RoleLabelsModel(
        companyAdmin: _ownerLabel,
        salesManager: _managerLabel,
        teamLeader: _leaderLabel,
        salesExecutive: _executiveLabel,
      );

      await ref.read(settingsServiceProvider).updateRoleLabels(newLabels);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration Saved!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _ownerLabel == 'Company Owner' && _managerLabel == 'Sales Manager') { // Initial load check
       return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    
    // Check module access
    final hasStaffGroup = permissions.hasModule(PermissionModules.STAFF_GROUP, userRole: user?.systemRole);
    final hasStaffTeam = permissions.hasModule(PermissionModules.STAFF_TEAM, userRole: user?.systemRole);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Role Labels Configuration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              // First row: Company Owner (always shown) and Sales Manager (conditional)
              if (hasStaffGroup)
                _buildRow("Company Owner Label", _ownerLabel, (val) => _ownerLabel = val, "Sales Manager Label", _managerLabel, (val) => _managerLabel = val)
              else
                _buildSingleField("Company Owner Label", _ownerLabel, (val) => _ownerLabel = val),
              const SizedBox(height: 24),
              // Second row: Team Leader (conditional) and Sales Executive (always shown)
              if (hasStaffTeam)
                _buildRow("Team Leader Label", _leaderLabel, (val) => _leaderLabel = val, "Sales Executive Label", _executiveLabel, (val) => _executiveLabel = val)
              else
                _buildSingleField("Sales Executive Label", _executiveLabel, (val) => _executiveLabel = val),
              
              const SizedBox(height: 32),
              
              Align(
                alignment: Alignment.centerRight,
                child: _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveLabels,
                    style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Save Configuration", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label1, String val1, Function(String) onChange1, String label2, String val2, Function(String) onChange2) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final field1 = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey[600]), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: val1,
          onChanged: onChange1,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50], 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        )
      ],
    );

    final field2 = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label2, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey[600]), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: val2,
          onChanged: onChange2,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
             isDense: true,
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50], 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        )
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field1,
          const SizedBox(height: 24),
          field2,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: field1),
        const SizedBox(width: 12),
        Expanded(child: field2),
      ],
    );
  }

  Widget _buildSingleField(String label, String value, Function(String) onChange) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey[600]), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onChanged: onChange,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        )
      ],
    );
  }
}
