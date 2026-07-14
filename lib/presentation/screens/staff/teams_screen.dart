import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/permission_constants.dart';
import '../../../data/models/team_model.dart';
import '../../providers/team_provider.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/dashboard_stats_card.dart';
import 'team_detail_screen.dart';

import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import 'package:intl/intl.dart';
import '../../widgets/access_denied_widget.dart';

class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(teamProvider.notifier).refresh();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
          ref.read(teamProvider.notifier).loadMore();
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
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final canView = permissions.hasModule(PermissionModules.STAFF_BASE, userRole: userRole) &&
        permissions.can(
          PermissionModules.STAFF_TEAM,
          permission: PermissionModules.STAFF_TEAM_VIEW,
          userRole: userRole,
        );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Teams'),
        body: AccessDeniedWidget(
          sectionName: "Teams",
          showAppBar: false,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teamState = ref.watch(teamProvider);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: const GlobalAppBar(title: 'Teams'),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(teamProvider.notifier).refresh(),
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
                        Text('Teams', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Manage teams inside the company.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                     Row(
                       children: [
                         _buildTopAction(Icons.refresh, () => ref.read(teamProvider.notifier).refresh(), isDark),
                         if (ref.watch(permissionsProvider).hasPermission(PermissionModules.STAFF_TEAM_CREATE, userRole: ref.watch(loginProvider).user?.systemRole))
                            ...[
                               const SizedBox(width: 12),
                               _buildTopAction(Icons.add, () => _showAddTeamDialog(context), isDark, isPrimary: true),
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
                            title: 'Total Teams',
                            value: '${teamState.totalCount}',
                            icon: Icons.groups,
                            backgroundColor: const Color(0xFF4527A0),
                            gradientColors: const [Color(0xFF4527A0), Color(0xFF5E35B1)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Active',
                            value: '${teamState.teams.where((t) => t.status == 'Active').length}',
                            icon: Icons.check_circle,
                            backgroundColor: const Color(0xFF00897B),
                            gradientColors: const [Color(0xFF00897B), Color(0xFF009688)],
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
                            value: '${teamState.teams.where((t) => t.status != 'Active').length}',
                            icon: Icons.cancel,
                            backgroundColor: const Color(0xFF37474F),
                            gradientColors: const [Color(0xFF37474F), Color(0xFF455A64)],
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
                
                // Teams List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Teams List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      _buildTableAction(Icons.refresh, () => ref.read(teamProvider.notifier).refresh(), isDark),
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
                    onSubmitted: (v) => ref.read(teamProvider.notifier).setSearch(v),
                    decoration: InputDecoration(
                      hintText: 'Search Teams...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                      // Card List View
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: teamState.teams.length,
                        itemBuilder: (context, index) {
                          final team = teamState.teams[index];
                          return _buildTeamCard(team, isDark);
                        },
                      ),
                      
                      if (teamState.teams.isEmpty && !teamState.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No teams found', style: TextStyle(color: Colors.grey))),
                        ),
                      
                      if (teamState.isLoading)
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

  void _showAddTeamDialog(BuildContext context, {Team? team}) {
      final nameController = TextEditingController(text: team?.name ?? '');
      bool isActive = team != null ? team.status == 'Active' : true;
      final isEdit = team != null;

      final isDark = Theme.of(context).brightness == Brightness.dark;

      showDialog(
          context: context, 
          builder: (context) {
              return StatefulBuilder(
                  builder: (context, setState) {
                      return AlertDialog(
                          title: Text(isEdit ? 'Update Team' : 'Create New Team', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(24),
                          content: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    _buildLabel('Team Name'),
                                    TextField(
                                        controller: nameController,
                                        decoration: _inputDecoration('Enter Team Name', isDark),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F111A) : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                              const Text('Active Status', style: TextStyle(fontWeight: FontWeight.w600)),
                                              Switch(
                                                  value: isActive, 
                                                  onChanged: (val) => setState(() => isActive = val),
                                                  activeThumbColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                                              )
                                          ],
                                      ),
                                    )
                                ]
                            ),
                          ),
                          actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context), 
                                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                  child: const Text('Cancel')
                              ),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                  ),
                                  onPressed: () async {
                                      if (nameController.text.isNotEmpty) {
                                          try {
                                            Navigator.pop(context); // Close first
                                            if (isEdit) {
                                                await ref.read(teamProvider.notifier).updateTeam(team.id, nameController.text.trim(), isActive);
                                            } else {
                                                await ref.read(teamProvider.notifier).createTeam(nameController.text.trim(), isActive);
                                            }
                                            if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Team Updated Successfully' : 'Team Created Successfully')));
                                            }
                                          } catch (e) {
                                              if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                              }
                                          }
                                      }
                                  }, 
                                  child: Text(isEdit ? 'Update Team' : 'Create Team')
                              ),
                          ],
                      );
                  }
              );
          }
      );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F111A) : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildTeamCard(Team team, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => TeamDetailScreen(teamId: team.id, teamName: team.name)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.groups_outlined, color: Colors.deepPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        _buildStatusBadge(team.status),
                      ],
                    ),
                  ),
                  _buildTeamPopupMenu(team),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: _buildCardInfoItem("MEMBERS", '${team.membersCount}')),
                  Expanded(child: _buildCardInfoItem("LEADERS", '${team.leaderNames.length}')),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildFooterInfo("Group", team.groupName)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Created At", style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                        const SizedBox(height: 2),
                        Text(_formatCreatedAt(team.createdAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
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

  String _formatCreatedAt(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Widget _buildCardInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFooterInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildTeamPopupMenu(Team team) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'view') {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => TeamDetailScreen(teamId: team.id, teamName: team.name))
          );
        } else if (value == 'edit') {
          _showAddTeamDialog(context, team: team);
        } else if (value == 'delete') {
          _showDeleteConfirmation(context, team.id, team.name);
        }
      },
      itemBuilder: (context) => [
        if (ref.watch(permissionsProvider).hasPermission(PermissionModules.STAFF_TEAM_VIEW, userRole: ref.watch(loginProvider).user?.systemRole))
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
        if (ref.watch(permissionsProvider).hasPermission(PermissionModules.STAFF_TEAM_UPDATE, userRole: ref.watch(loginProvider).user?.systemRole))
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Edit Team'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTopAction(IconData icon, VoidCallback onTap, bool isDark, {bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
      borderRadius: BorderRadius.circular(8),
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

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'Active';
    final color = isActive ? const Color(0xFF00C853) : const Color(0xFFFF5252);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status, 
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)
      ),
    );
  }

  String formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays} Days Ago';
    if (diff.inHours > 0) return '${diff.inHours} Hours Ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} Minutes Ago';
    return 'Just Now';
  }
  void _showDeleteConfirmation(BuildContext context, String teamId, String teamName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete team "$teamName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(teamProvider.notifier).deleteTeam(teamId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Team deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

