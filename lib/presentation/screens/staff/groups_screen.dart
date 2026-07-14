import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/permission_constants.dart';
import '../../../data/models/group_model.dart';
import '../../providers/group_provider.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/dashboard_stats_card.dart';
import 'group_detail_screen.dart';

import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import 'package:intl/intl.dart';
import '../../widgets/access_denied_widget.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupProvider.notifier).refresh();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(groupProvider.notifier).loadMore();
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
          PermissionModules.STAFF_GROUP,
          permission: PermissionModules.STAFF_GROUP_VIEW,
          userRole: userRole,
        );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Staff Groups'),
        body: AccessDeniedWidget(
          sectionName: "Staff Groups",
          showAppBar: false,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupState = ref.watch(groupProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: const GlobalAppBar(title: 'Groups'),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(groupProvider.notifier).refresh(),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                        Text('Groups', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 2),
                        Text('Manage organization groups.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        _buildTopAction(Icons.refresh, () => ref.read(groupProvider.notifier).refresh(), isDark),
                        if (ref.watch(permissionsProvider).hasPermission(PermissionModules.STAFF_GROUP_CREATE, userRole: ref.watch(loginProvider).user?.systemRole)) ...[
                          const SizedBox(width: 8),
                          _buildTopAction(Icons.add, () => _showAddGroupDialog(context), isDark, isPrimary: true),
                        ]
                      ],
                    )
                  ],
                ),

                const SizedBox(height: 24),

                // Vibrant Stat Cards
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Total Groups',
                            value: '${groupState.totalCount}',
                            icon: Icons.domain,
                            backgroundColor: const Color(0xFF6A1B9A),
                            gradientColors: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DashboardStatsCard(
                            title: 'Active',
                            value: '${groupState.groups.where((g) => g.status == 'Active').length}',
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
                            value: '${groupState.groups.where((g) => g.status != 'Active').length}',
                            icon: Icons.cancel,
                            backgroundColor: const Color(0xFF263238),
                            gradientColors: const [Color(0xFF263238), Color(0xFF455A64)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Groups List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Groups List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      _buildTableAction(Icons.refresh, () => ref.read(groupProvider.notifier).refresh(), isDark),
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
                    onSubmitted: (v) => ref.read(groupProvider.notifier).setSearch(v),
                    decoration: InputDecoration(
                        hintText: 'Search Groups...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Card List View
                if (groupState.groups.isEmpty && !groupState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: Text('No groups found', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: groupState.groups.length,
                    itemBuilder: (context, index) {
                      final group = groupState.groups[index];
                      return _buildGroupCard(group, isDark);
                    },
                  ),

                if (groupState.isLoading)
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

  void _showAddGroupDialog(BuildContext context, {Group? group}) {
    final nameController = TextEditingController(text: group?.name ?? '');
    bool isActive = group != null ? group.status == 'Active' : true;
    final isEdit = group != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'Update Group' : 'Create New Group', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Group Name'),
                    TextField(
                      controller: nameController,
                      decoration: _inputDecoration('Enter Group Name', isDark),
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
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: Colors.grey), child: const Text('Cancel')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () async {
                      if (nameController.text.isNotEmpty) {
                        try {
                          Navigator.pop(context); // Close first
                          if (isEdit) {
                            await ref.read(groupProvider.notifier).updateGroup(group.id, nameController.text.trim(), isActive);
                          } else {
                            await ref.read(groupProvider.notifier).createGroup(nameController.text.trim(), isActive);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Group Updated Successfully' : 'Group Created Successfully')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      }
                    },
                    child: Text(isEdit ? 'Update Group' : 'Create Group')),
              ],
            );
          });
        });
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

  Widget _buildGroupCard(Group group, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => GroupDetailScreen(groupId: group.id, groupName: group.name)));
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
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        _buildStatusBadge(group.status),
                      ],
                    ),
                  ),
                  _buildGroupPopupMenu(group),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: _buildCardInfoItem("MANAGERS", '${group.managerNames.length}')),
                  Expanded(child: _buildCardInfoItem("TEAMS", '${group.teamsCount}')),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildFooterInfo("Created By", group.createdBy)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Created At", style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                        const SizedBox(height: 2),
                        Text(_formatCreatedAt(group.createdAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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

  String _formatCreatedAt(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
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

  Widget _buildGroupPopupMenu(Group group) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'view') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => GroupDetailScreen(groupId: group.id, groupName: group.name)));
        } else if (value == 'edit') {
          _showAddGroupDialog(context, group: group);
        } else if (value == 'delete') {
          _showDeleteConfirmation(context, group.id, group.name);
        }
      },
      itemBuilder: (context) => [
        if (ref.watch(permissionsProvider).hasPermission(PermissionModules.STAFF_GROUP_VIEW, userRole: ref.watch(loginProvider).user?.systemRole))
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
        if (ref.watch(permissionsProvider).hasPermission(PermissionModules.STAFF_GROUP_UPDATE, userRole: ref.watch(loginProvider).user?.systemRole))
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Edit Group'),
              ],
            ),
          ),
      ],
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
          border: isPrimary ? null : Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
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

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'Active';
    final color = isActive ? const Color(0xFF00C853) : const Color(0xFFFF5252);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String groupId, String groupName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete group "$groupName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(groupProvider.notifier).deleteGroup(groupId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted successfully')),
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
