import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/staff_model.dart';
import '../../providers/staff_provider.dart'; // For staffServiceProvider
import '../../../data/models/team_model.dart';
import '../../providers/team_provider.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/assign_leaders_dialog.dart';

class TeamDetailScreen extends ConsumerStatefulWidget {
  final String teamId;
  final String teamName;

  const TeamDetailScreen({
    super.key, 
    required this.teamId,
    required this.teamName,
  });

  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen> {
  late Future<Team> _teamFuture;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  void _fetchDetails() {
    setState(() {
      _teamFuture = ref.read(staffServiceProvider).fetchTeamDetails(widget.teamId);
    });
  }

  void _confirmRemoveMember(StaffUser member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove ${member.name} from this team?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ref.read(teamProvider.notifier).removeMembersFromTeam(widget.teamId, [member.id]);
                if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Member removed successfully'), backgroundColor: Colors.green));
                _fetchDetails();
              } catch (e) {
                if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const GlobalAppBar(
        title: 'Team Details',
        showBackButton: true,
      ),
      body: FutureBuilder<Team>(
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
             return const Center(child: Text('No team data found'));
          }

          final team = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Section
                Text(
                  'Team: ${team.name}', 
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage team structure and members.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    _buildActionButton(Icons.refresh, _fetchDetails, isDark),
                    const SizedBox(width: 12),
                    _buildActionButton(Icons.security, () => _showAssignLeaderDialog(context), isDark),
                    const SizedBox(width: 12),
                    _buildActionButton(Icons.add, () => _showAddMemberDialog(context, team.memberIds), isDark),
                  ],
                ),

                const SizedBox(height: 24),

                // Group Card
                _buildInfoCard('Group', team.groupName, isDark),
                const SizedBox(height: 12),

                // Leader Card
                _buildLeadersCard(team.leaderNames, isDark),
                const SizedBox(height: 12),
                
                // Members Count Card 
                _buildInfoCard('Members', '${team.membersCount}', isDark),

                const SizedBox(height: 32),

                // Members List Section
                Text(
                  'Team Members',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                if (team.membersCount == 0 || team.members.isEmpty)
                  Text(
                    'No executives in this team.', 
                    style: TextStyle(color: Colors.grey[600])
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: team.members.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = team.members[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.withValues(alpha: 0.1),
                              child: Text(member.name[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(member.email, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                 // Logic to remove member
                                 _confirmRemoveMember(member);
                              },
                            )
                          ],
                        ),
                      );
                    },
                  ), 
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAssignLeaderDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AssignLeadersDialog(
        teamId: widget.teamId,
        teamName: widget.teamName,
      ),
    );

    if (result == true && mounted) {
      _fetchDetails(); // Refresh parent after assignment
    }
  }

  void _showAddMemberDialog(BuildContext context, List<String> existingMemberIds) {
    ref.read(staffProvider('sales_executive').notifier).refresh();

    showDialog(
      context: context,
      builder: (context) {
        // Multi-select state
        final Set<String> selectedIds = {};
        
        return StatefulBuilder(
           builder: (context, setDialogState) {
             final isDark = Theme.of(context).brightness == Brightness.dark;
             return Consumer(
               builder: (context, ref, _) {
                 final staffState = ref.watch(staffProvider('sales_executive'));
                  final availableUsers = <StaffUser>[];
                  final seenIds = <String>{};
                  
                  for (final u in staffState.users) {
                     final isStatusActive = u.status.toLowerCase() == 'active' && u.active == true;
                     final isUnassigned = u.teamName == null || u.teamName == '-' || u.teamName!.isEmpty;
                     if (isStatusActive && isUnassigned && !existingMemberIds.contains(u.id)) {
                        if (!seenIds.contains(u.id)) {
                           availableUsers.add(u);
                           seenIds.add(u.id);
                        }
                     }
                  }
                 
                 return AlertDialog(
                    title: const Text('Add Executives', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(24),
                    content: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select executives to add to ${widget.teamName}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          const SizedBox(height: 16),
                          staffState.isLoading 
                              ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                              : availableUsers.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Text('No unassigned executives available', style: TextStyle(color: Colors.grey[600])),
                                    )
                                  : ConstrainedBox(
                                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                                      child: ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: availableUsers.length,
                                          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                             final user = availableUsers[index];
                                             final isSelected = selectedIds.contains(user.id);
                                             return InkWell(
                                               onTap: () {
                                                  setDialogState(() {
                                                    if (isSelected) {
                                                      selectedIds.remove(user.id);
                                                    } else {
                                                      selectedIds.add(user.id);
                                                    }
                                                  });
                                               },
                                               borderRadius: BorderRadius.circular(12),
                                               child: Container(
                                                 decoration: BoxDecoration(
                                                   color: isSelected 
                                                      ? (isDark ? const Color(0xFF4C6EF5).withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.05)) 
                                                      : Colors.transparent,
                                                   border: Border.all(
                                                      color: isSelected 
                                                        ? (isDark ? const Color(0xFF4C6EF5) : Colors.blue) 
                                                        : Colors.grey.withValues(alpha: 0.2)
                                                   ),
                                                   borderRadius: BorderRadius.circular(12),
                                                 ),
                                                 child: CheckboxListTile(
                                                    value: isSelected,
                                                    onChanged: (val) {
                                                       setDialogState(() {
                                                          if (val == true) {
                                                            selectedIds.add(user.id);
                                                          } else {
                                                            selectedIds.remove(user.id);
                                                          }
                                                       });
                                                    },
                                                    activeColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                                                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                    subtitle: Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    controlAffinity: ListTileControlAffinity.trailing, // Checkbox on right
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                 ),
                                               ),
                                             );
                                          },
                                        ),
                                  ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: selectedIds.isEmpty ? null : () async {
                           try {
                               await ref.read(teamProvider.notifier).addMembersToTeam(widget.teamId, selectedIds.toList());
                               if (context.mounted) {
                                 Navigator.pop(context);
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${selectedIds.length} executives added successfully'), backgroundColor: Colors.green));
                                 _fetchDetails(); // Refresh parent
                               }
                           } catch (e) {
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                               }
                           }
                        },
                        child: Text('Add ${selectedIds.isNotEmpty ? selectedIds.length : ''} Executives'),
                      ),
                    ],
                 );
               }
             );
           }
        );
      }
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 50,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1C26) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black54),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            value, 
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87
            )
          ),
        ],
      ),
    );
  }

  Widget _buildLeadersCard(List<String> leaderNames, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Leaders', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          if (leaderNames.isEmpty)
            Text('-', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: leaderNames.map((name) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              )).toList(),
            ),
        ],
      ),
    );
  }
}
