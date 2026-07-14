import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/staff_provider.dart';
import '../providers/lead_provider.dart';

class LeadBulkAssignSheet extends ConsumerStatefulWidget {
  final List<String> leadIds;
  const LeadBulkAssignSheet({super.key, required this.leadIds});

  static Future<bool?> show(BuildContext context, List<String> leadIds) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeadBulkAssignSheet(leadIds: leadIds),
    );
  }

  @override
  ConsumerState<LeadBulkAssignSheet> createState() => _LeadBulkAssignSheetState();
}

class _LeadBulkAssignSheetState extends ConsumerState<LeadBulkAssignSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedUserId;
  bool _isLoading = false;

  static const _roles = ['company_admin', 'sales_manager', 'team_leader', 'sales_executive'];
  static const _roleLabels = ['Company Admin', 'Sales Manager', 'Team Leader', 'Sales Executive'];
  static const _roleIcons = [
    Icons.admin_panel_settings_outlined,
    Icons.manage_accounts_outlined,
    Icons.groups_outlined,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_selectedUserId == null) return;
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(leadsProvider.notifier).bulkAssign(widget.leadIds, _selectedUserId!);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Leads assigned successfully'),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to assign leads'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.12),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          color: bgColor,
          child: Column(
            children: [
              _buildHandle(isDark),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildHeader(theme, isDark),
                      _buildTabBar(isDark),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: _roles.map((role) =>
                            _UserListTab(
                              role: role,
                              selectedUserId: _selectedUserId,
                              onSelect: (id) => setState(() => _selectedUserId = id),
                            )
                          ).toList(),
                        ),
                      ),
                      _buildBottomButton(isDark),
                      SizedBox(height: bottomInset > 0 ? 0 : 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? Colors.white30 : Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_add_alt_1, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assign Leads',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                Text('${widget.leadIds.length} lead${widget.leadIds.length == 1 ? '' : 's'} selected',
                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white54 : Colors.black45),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: theme.textTheme.bodySmall?.color,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.center,
        tabs: _roleLabels.asMap().entries.map((e) =>
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_roleIcons[e.key], size: 14),
                const SizedBox(width: 4),
                Text(e.value),
              ],
            ),
          ),
        ).toList(),
      ),
    );
  }

  Widget _buildBottomButton(bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_selectedUserId != null && !_isLoading) ? _assign : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Assign', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (_selectedUserId != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('to ${_getSelectedUserName()}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary.withValues(alpha: 0.8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
        ),
      ),
    );
  }

  String _getSelectedUserName() {
    for (final role in _roles) {
      final users = ref.read(staffProvider(role)).users;
      final match = users.where((u) => u.id == _selectedUserId).firstOrNull;
      if (match != null) return match.name;
    }
    return '';
  }
}

class _UserListTab extends ConsumerStatefulWidget {
  final String role;
  final String? selectedUserId;
  final Function(String) onSelect;

  const _UserListTab({
    required this.role,
    required this.selectedUserId,
    required this.onSelect,
  });

  @override
  ConsumerState<_UserListTab> createState() => _UserListTabState();
}

class _UserListTabState extends ConsumerState<_UserListTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(staffProvider(widget.role).notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(staffProvider(widget.role).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(staffProvider(widget.role));
    final users = state.users.where((u) => u.status.toLowerCase() == 'active' && u.active == true).toList();
    final theme = Theme.of(context);

    String formatSystemRole(String role) {
      switch (role.toLowerCase()) {
        case 'company_admin': return 'Company Admin';
        case 'sales_manager': return 'Sales Manager';
        case 'team_leader': return 'Team Leader';
        case 'sales_executive': return 'Sales Executive';
        default: return role.replaceAll('_', ' ');
      }
    }

    if (state.isLoading && users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 40, color: theme.textTheme.bodySmall?.color),
              const SizedBox(height: 12),
              Text('No users in this role',
                style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return TextSelectionTheme(
      data: TextSelectionThemeData(selectionColor: Colors.transparent),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: users.length + (state.isLoading ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index == users.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final user = users[index];
        final isSelected = widget.selectedUserId == user.id;
        return GestureDetector(
          onTap: () => widget.onSelect(user.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _getAvatarColor(user.name).withValues(alpha: 0.12),
                      child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _getAvatarColor(user.name),
                        )),
                    ),
                    if (isSelected)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 8, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        )),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              formatSystemRole(user.systemRole),
                              style: TextStyle(
                                fontSize: 9, 
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          if (user.email != '-') ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                user.email,
                                style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      width: 2,
                    ),
                    color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Color _getAvatarColor(String name) {
    const colors = [Color(0xFF1976D2), Color(0xFF388E3C), Color(0xFFF57C00), Color(0xFF7B1FA2), Color(0xFF00796B), Color(0xFFC2185B), Color(0xFF455A64)];
    return colors[name.length % colors.length];
  }
}
