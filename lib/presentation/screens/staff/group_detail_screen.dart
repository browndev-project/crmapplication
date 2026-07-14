import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/group_model.dart';

import '../../../data/models/team_model.dart';
import '../../providers/group_provider.dart';
import '../../widgets/global_app_bar.dart';
import '../../providers/staff_provider.dart'; // For managers
import '../../providers/team_provider.dart'; // For teams
import '../../widgets/assign_managers_dialog.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({super.key, required this.groupId, required this.groupName});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  late Future<Group> _groupDetailsFuture;
  final Set<String> _selectedTeamIds = {};

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  void _fetchDetails() {
    setState(() {
      _groupDetailsFuture = ref.read(staffServiceProvider).fetchGroupDetails(widget.groupId);
      _selectedTeamIds.clear(); // Clear selection on refresh
    });
  }
  
  Future<void> _removeSelectedTeams() async {
      if (_selectedTeamIds.isEmpty) return;
      
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
          await ref.read(groupProvider.notifier).removeTeamsFromGroup(
              widget.groupId, 
              _selectedTeamIds.toList()
          );
          if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Teams removed successfully')));
          _fetchDetails();
      } catch (e) {
          if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlobalAppBar(
        title: 'Group: ${widget.groupName}',
        showBackButton: true,
      ),
      body: Stack(
        children: [
          FutureBuilder<Group>(
            future: _groupDetailsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData) {
                return const Center(child: Text('No group details found'));
              }

              final group = snapshot.data!;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manage teams and hierarchy under this group.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 24),
                    
                    // Group Name Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark ? [const Color(0xFF1A1C26), const Color(0xFF111827)] : [Colors.black, Colors.grey[900]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GROUP NAME', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(
                            widget.groupName.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        _buildActionButton(Icons.refresh, _fetchDetails, isDark),
                        const SizedBox(width: 12),
                        _buildActionButton(Icons.add, () => _showAddTeamsDialog(context, group.teams.map((t) => t.id).toList()), isDark),
                        const SizedBox(width: 12),
                        _buildActionButton(Icons.security, () => _showAssignManagerDialog(context), isDark),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Managers Card
                    _buildManagersCard(group.managerNames, isDark),
                    const SizedBox(height: 12),

                    // Total Teams Card
                    _buildInfoCard('Total Teams', '${group.teamsCount}', isDark),
                    const SizedBox(height: 12),
                    
                    // Status Card
                    _buildInfoCard('Status', group.status, isDark),

                    const SizedBox(height: 32),

                    // Teams List Section
                    Text(
                      'Teams in this Group',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    if (group.teams.isEmpty)
                      Text(
                        'No teams in this group.', 
                        style: TextStyle(color: Colors.grey[600])
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: group.teams.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final team = group.teams[index];
                          final isSelected = _selectedTeamIds.contains(team.id);
                          
                          // Member count including leaders
                          final totalCount = team.membersCount + team.leaderIds.length;
                          
                          return InkWell(
                             onTap: () {
                                 setState(() {
                                     if (isSelected) {
                                         _selectedTeamIds.remove(team.id);
                                     } else {
                                         _selectedTeamIds.add(team.id);
                                     }
                                 });
                             },
                             child: Container(
                                padding: const EdgeInsets.all(16),
                                 decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                     borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: isSelected ? (isDark ? const Color(0xFF4C6EF5) : Colors.black) : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                          width: isSelected ? 2 : 1
                                      ),
                                 ),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Expanded(
                                          child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                  Text(team.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  if (team.leaderNames.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 2),
                                                      child: Text('Leader(s): ${team.leaderNames.join(", ")}', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                                    )
                                                  else
                                                    Text('Leader: ${team.leaderName}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                                  
                                                  Text('Total Members: $totalCount (incl. leaders)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                              ],
                                          ),
                                        ),
                                        Checkbox(
                                            value: isSelected, 
                                            onChanged: (val){
                                               setState(() {
                                                   if (val == true) {
                                                       _selectedTeamIds.add(team.id);
                                                   } else {
                                                       _selectedTeamIds.remove(team.id);
                                                   }
                                               });
                                            }
                                        ) 
                                    ],
                                )
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 80), // Space for bottom card
                  ],
                ),
              );
            },
          ),
          
          // Floating Selection Card
          if (_selectedTeamIds.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedTeamIds.length} team(s) selected', 
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500
                      )
                    ),
                    const SizedBox(height: 16),
                    
                    // Remove Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _removeSelectedTeams,
                        child: const Text('Remove From Group'),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Transfer Button (Placeholder)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer feature coming soon')));
                        },
                        child: const Text('Transfer To Another Group'),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Cancel Button
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedTeamIds.clear();
                          });
                        },
                        child: Text(
                          'Cancel', 
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87
                          )
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  void _showAssignManagerDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AssignManagersDialog(
        groupId: widget.groupId,
        groupName: widget.groupName,
      ),
    );
    
    if (result == true) {
      _fetchDetails();
    }
  }

  void _showAddTeamsDialog(BuildContext context, List<String> existingTeamIds) {
      ref.read(teamProvider.notifier).refresh();

      showDialog(
        context: context,
        builder: (context) {
          final Set<String> selectedIds = {};
          return StatefulBuilder(
             builder: (context, setDialogState) {
               final isDark = Theme.of(context).brightness == Brightness.dark;
               return Consumer(
                 builder: (context, ref, _) {
                    final teamState = ref.watch(teamProvider);
                    // Filter: Only active teams that are not part of any group (indicated by groupName == '-')
                    final availableTeams = <Team>[];
                    final seenTeamIds = <String>{};
                    
                    for (final t in teamState.teams) {
                       if (!existingTeamIds.contains(t.id) && t.status == 'Active' && (t.groupName == '-' || t.groupName.isEmpty)) {
                          if (!seenTeamIds.contains(t.id)) {
                             availableTeams.add(t);
                             seenTeamIds.add(t.id);
                          }
                       }
                    }
                   
                    return AlertDialog(
                       title: const Text('Add Teams', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(24),
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select teams to add to ${widget.groupName}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const SizedBox(height: 16),
                            teamState.isLoading 
                                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                                : availableTeams.isEmpty
                                    ? const Padding(padding: EdgeInsets.all(16.0), child: Text('No teams available.'))
                                    : ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                                        child: ListView.separated(
                                            shrinkWrap: true,
                                            itemCount: availableTeams.length,
                                            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                            itemBuilder: (context, index) {
                                               final team = availableTeams[index];
                                               final isSelected = selectedIds.contains(team.id);
                                               return InkWell(
                                                 onTap: () {
                                                    setDialogState(() {
                                                      if (isSelected) {
                                                        selectedIds.remove(team.id);
                                                      } else {
                                                        selectedIds.add(team.id);
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
                                                              selectedIds.add(team.id);
                                                            } else {
                                                              selectedIds.remove(team.id);
                                                            }
                                                         });
                                                      },
                                                      activeColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                                                      title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                      subtitle: Text('Members: ${team.membersCount}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      controlAffinity: ListTileControlAffinity.trailing,
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
                                 await ref.read(groupProvider.notifier).addTeamsToGroup(widget.groupId, selectedIds.toList());
                                 if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teams added successfully'), backgroundColor: Colors.green));
                                    _fetchDetails(); // Refresh parent
                                 }
                             } catch (e) {
                                 if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                 }
                             }
                          },
                          child: Text('Add ${selectedIds.isNotEmpty ? selectedIds.length : ''} Teams'),
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

  Widget _buildInfoCard(String title, String value, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildManagersCard(List<String> managerNames, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Managers', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          if (managerNames.isEmpty)
            const Text('Unassigned', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: managerNames.map((name) => Container(
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
        child: Icon(icon, size: 20),
      ),
    );
  }
}
