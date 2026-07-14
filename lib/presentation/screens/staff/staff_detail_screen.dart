import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../data/models/staff_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/staff_create_dialog.dart';
import '../../providers/staff_provider.dart';

class StaffDetailScreen extends ConsumerStatefulWidget {
  final StaffUser staff;
  const StaffDetailScreen({super.key, required this.staff});

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  late StaffUser _currentStaff;

  @override
  void initState() {
    super.initState();
    _currentStaff = widget.staff;
  }

  Future<void> _refreshStaff() async {
    // In a real app, you would fetch the latest staff details by ID
    // For now, we search in the provider or just re-emit the current one
    // Let's assume we can refresh via the role provider
    await ref.read(staffProvider(_currentStaff.systemRole).notifier).refresh();
    final updatedStaffList = ref.read(staffProvider(_currentStaff.systemRole)).users;
    final updated = updatedStaffList.firstWhere((u) => u.id == _currentStaff.id, orElse: () => _currentStaff);
    setState(() {
      _currentStaff = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlobalAppBar(
        title: '${_currentStaff.name} Details',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStaff,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header profile section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: _getRoleColor(_currentStaff.systemRole).withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: _getRoleColor(_currentStaff.systemRole), size: 35),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentStaff.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Text(_currentStaff.uniqueId, style: TextStyle(color: Colors.grey[500], fontSize: 13, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          _buildStatusBadge(_currentStaff),
                        ],
                      ),
                    ),
                    _buildTopAction(Icons.edit_outlined, () async {
                      await showDialog(
                        context: context, 
                        builder: (context) => StaffCreateDialog(role: _currentStaff.systemRole, staff: _currentStaff)
                      );
                      _refreshStaff();
                    }, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 16),

              _buildInfoGrid(isDark),

              const SizedBox(height: 32),

              Text('Assignment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 16),

              _buildAssignmentGrid(isDark),

              const SizedBox(height: 32),

              Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 16),

              _buildHistoryCard(isDark),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGrid(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildInfoCard('Email Address', _currentStaff.email, Icons.email_outlined, isDark, itemWidth),
            _buildInfoCard('Phone Number', _currentStaff.phoneNo, Icons.phone_outlined, isDark, itemWidth),
            _buildInfoCard('System Role', _formatRole(_currentStaff.systemRole), Icons.security_outlined, isDark, itemWidth),
            _buildInfoCard('User ID', _currentStaff.id, Icons.fingerprint_outlined, isDark, itemWidth),
          ],
        );
      }
    );
  }

  Widget _buildAssignmentGrid(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildInfoCard('Group', _currentStaff.groupName ?? 'Not Assigned', Icons.group_work_outlined, isDark, itemWidth),
            _buildInfoCard('Team', _currentStaff.teamName ?? 'Not Assigned', Icons.groups_outlined, isDark, itemWidth),
            if (_currentStaff.systemRole == 'sales_manager')
              _buildInfoCard('Teams Managed', '${_currentStaff.teamsCount}', Icons.layers_outlined, isDark, itemWidth),
            if (_currentStaff.systemRole == 'team_leader')
              _buildInfoCard('Members Managed', '${_currentStaff.membersCount}', Icons.people_outline, isDark, itemWidth),
          ],
        );
      }
    );
  }

  Widget _buildHistoryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildHistoryItem('Created On', timeago.format(_currentStaff.createdAt), Icons.calendar_today_outlined, isDark),
          const Divider(height: 32),
          _buildHistoryItem('Created By', _currentStaff.createdBy, Icons.person_add_alt_1_outlined, isDark),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.blue),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
          ],
        )
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, bool isDark, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(StaffUser user) {
    final isDeleted = user.status == 'deleted';
    final isInactive = user.status == 'inactive' || (user.status == 'active' && user.active == false);
    final color = isDeleted ? Colors.grey : (isInactive ? const Color(0xFFFF5252) : const Color(0xFF00C853));
    final label = isDeleted ? 'Deleted' : (isInactive ? 'Inactive' : 'Active');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTopAction(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F111A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'sales_manager': return const Color(0xFF1A73E8);
      case 'team_leader': return const Color(0xFF6A1B9A);
      case 'sales_executive': return const Color(0xFF2E3192);
      default: return Colors.blue;
    }
  }

  String _formatRole(String role) {
    return role.split('_').map((e) => e[0].toUpperCase() + e.substring(1)).join(' ');
  }
}
