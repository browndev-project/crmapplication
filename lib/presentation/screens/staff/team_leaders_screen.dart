import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/permission_constants.dart';
import '../../providers/staff_provider.dart';
import '../../../data/models/staff_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/dashboard_stats_card.dart';
import '../../widgets/staff_create_dialog.dart';
import 'staff_detail_screen.dart';

import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../widgets/access_denied_widget.dart';

class TeamLeadersScreen extends ConsumerStatefulWidget {
  const TeamLeadersScreen({super.key});

  @override
  ConsumerState<TeamLeadersScreen> createState() => _TeamLeadersScreenState();
}

class _TeamLeadersScreenState extends ConsumerState<TeamLeadersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _systemRole = 'team_leader'; 

  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(staffProvider(_systemRole).notifier).refresh();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
          ref.read(staffProvider(_systemRole).notifier).loadMore();
      }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final canView = permissions.hasModule(PermissionModules.STAFF_BASE, userRole: userRole) &&
        permissions.hasPermission(
          PermissionModules.TEAM_LEADER_VIEW,
          userRole: userRole,
        );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Team Leaders'),
        body: AccessDeniedWidget(
          sectionName: "Team Leaders",
          showAppBar: false,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffState = ref.watch(staffProvider(_systemRole));
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: const GlobalAppBar(title: 'Team Leaders'),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(staffProvider(_systemRole).notifier).refresh(),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Region
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Team Leaders', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Manage team leaders in your organization.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                     Row(
                       children: [
                         _buildTopAction(Icons.refresh, () => ref.read(staffProvider(_systemRole).notifier).refresh(), isDark),
                         if (ref.watch(permissionsProvider).hasPermission(PermissionModules.TEAM_LEADER_CREATE, userRole: ref.watch(loginProvider).user?.systemRole))
                            ...[
                               const SizedBox(width: 12),
                               _buildTopAction(Icons.add, () {
                                  showDialog(context: context, builder: (context) => StaffCreateDialog(role: _systemRole));
                               }, isDark, isPrimary: true),
                            ]
                       ],
                     )
                  ],
                ),
                
                const SizedBox(height: 32),

                // Vibrant Stat Cards
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Total Leaders',
                            value: '${staffState.users.length}',
                            icon: Icons.people,
                            backgroundColor: const Color(0xFF6A1B9A),
                            gradientColors: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Active',
                            value: '${staffState.users.where((u) => u.status == 'active' && u.active == true).length}',
                            icon: Icons.check_circle,
                            backgroundColor: const Color(0xFF00BFA5),
                            gradientColors: const [Color(0xFF00BFA5), Color(0xFF1DE9B6)],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Inactive',
                            value: '${staffState.users.where((u) => u.status != 'active' || u.active == false).length}',
                            icon: Icons.cancel,
                            backgroundColor: const Color(0xFF5D6D7E),
                            gradientColors: const [Color(0xFF5D6D7E), Color(0xFF85929E)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                const SizedBox(height: 24),
                
                // Leaders List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Team Leader List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      _buildTableAction(Icons.refresh, () => ref.read(staffProvider(_systemRole).notifier).refresh(), isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search Bar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F111A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (v) => ref.read(staffProvider(_systemRole).notifier).setSearch(v),
                    decoration: InputDecoration(
                      hintText: 'Search leaders, email, names...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Card List View
                if (staffState.users.isEmpty && !staffState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: Text('No team leaders found', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: staffState.users.length,
                    itemBuilder: (context, index) {
                      final user = staffState.users[index];
                      return _buildStaffCard(user, isDark);
                    },
                  ),

                if (staffState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaffCard(dynamic user, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(user.uniqueId, style: TextStyle(color: Colors.grey[500], fontSize: 11, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildStatusBadge(user),
                    const SizedBox(width: 4),
                    _buildCardMenu(user),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Info Grid
            Row(
              children: [
                Expanded(child: _buildInfoItem(Icons.email_outlined, 'Email', user.email)),
                Expanded(child: _buildInfoItem(Icons.phone_outlined, 'Phone', user.phoneNo)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInfoItem(Icons.groups_outlined, 'Team', user.teamName ?? '-')),
                if (_systemRole == 'team_leader')
                  Expanded(child: _buildInfoItem(Icons.people_outline, 'Members', '${user.membersCount}')),
              ],
            ),

            const SizedBox(height: 20),
            
            // Footer: Audit Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Row(
                   children: [
                     Icon(Icons.person_add_alt, size: 12, color: Colors.grey[400]),
                     const SizedBox(width: 4),
                     Text('By: ${user.createdBy}', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                   ],
                 ),
                 Row(
                   children: [
                     Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                     const SizedBox(width: 4),
                     Text(timeago.format(user.createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w500)),
                   ],
                 ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardMenu(dynamic user) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[400]),
      onSelected: (value) {
        if (value == 'view') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => StaffDetailScreen(staff: user)));
        } else if (value == 'edit') {
          showDialog(context: context, builder: (context) => StaffCreateDialog(role: _systemRole, staff: user));
        }
      },
      itemBuilder: (context) => [
        if (ref.watch(permissionsProvider).hasPermission(PermissionModules.TEAM_LEADER_VIEW, userRole: ref.watch(loginProvider).user?.systemRole))
          const PopupMenuItem(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, size: 18),
                SizedBox(width: 8),
                Text('View Details'),
              ],
            ),
          ),
        if (ref.watch(permissionsProvider).hasPermission(PermissionModules.TEAM_LEADER_UPDATE, userRole: ref.watch(loginProvider).user?.systemRole))
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Edit Staff'),
              ],
            ),
          ),
      ],
    );
  }

  DataColumn buildHeaderCell(String label) {
    return DataColumn(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
    );
  }



  Widget _buildTopAction(IconData icon, VoidCallback onTap, bool isDark, {bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isPrimary ? (isDark ? const Color(0xFF4C6EF5) : Colors.black) : (isDark ? const Color(0xFF1A1C26) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: isPrimary ? null : Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 18, color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildTableAction(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildStatusBadge(StaffUser user) {
    final isDeleted = user.status == 'deleted';
    final isInactive = user.status == 'inactive' || (user.status == 'active' && user.active == false);
    final color = isDeleted ? Colors.grey : (isInactive ? const Color(0xFFFF5252) : const Color(0xFF00C853));
    final label = isDeleted ? 'Deleted' : (isInactive ? 'Inactive' : 'Active');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label, 
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)
      ),
    );
  }
}

