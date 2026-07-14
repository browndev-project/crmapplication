import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/staff_model.dart';
import '../providers/staff_provider.dart';
import '../providers/group_provider.dart';

class AssignManagersDialog extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const AssignManagersDialog({
    super.key, 
    required this.groupId, 
    required this.groupName
  });

  @override
  ConsumerState<AssignManagersDialog> createState() => _AssignManagersDialogState();
}

class _AssignManagersDialogState extends ConsumerState<AssignManagersDialog> {
  final Set<String> _selectedManagerIds = {};
  bool _showOnlyUnassigned = false;
  bool _isSaving = false;

  bool _isFetchingInitialData = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(staffProvider('sales_manager').notifier).refresh();
      if (mounted) {
        final staffState = ref.read(staffProvider('sales_manager'));
        final activeManagers = staffState.users.where((u) => u.status.toLowerCase() == 'active' && u.active == true);
        
        setState(() {
          for (var u in activeManagers) {
            if (u.groupName == widget.groupName) {
              _selectedManagerIds.add(u.id);
            }
          }
          _isFetchingInitialData = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffState = ref.watch(staffProvider('sales_manager'));
    
    final allActiveManagers = staffState.users.where((u) => u.status.toLowerCase() == 'active' && u.active == true).toList();

    final filteredManagers = allActiveManagers.where((u) {
      final isUnassigned = u.groupName == null || u.groupName == '-' || u.groupName!.isEmpty;
      final isCurrentManager = u.groupName == widget.groupName;
      if (_showOnlyUnassigned) {
        return isUnassigned || isCurrentManager;
      }
      return true;
    }).toList();

    // Check if any selected manager is currently assigned to ANOTHER group
    bool showWarning = false;
    for (var id in _selectedManagerIds) {
      final user = allActiveManagers.cast<StaffUser?>().firstWhere((u) => u?.id == id, orElse: () => null);
      if (user != null) {
        final isUnassigned = user.groupName == null || user.groupName == '-' || user.groupName!.isEmpty;
        final isCurrentManager = user.groupName == widget.groupName;
        if (!isUnassigned && !isCurrentManager) {
          showWarning = true;
          break;
        }
      }
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Assign managers to ${widget.groupName} Group',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _showOnlyUnassigned,
                        onChanged: (val) {
                          setState(() {
                            _showOnlyUnassigned = val ?? false;
                          });
                        },
                        activeColor: isDark ? Colors.white : Colors.black,
                        checkColor: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Show only unassigned', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                Text(
                  '${filteredManagers.length} total',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Warning Box
            if (showWarning)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5), // Light orange background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Important Notice',
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(color: Color(0xFFE65100), fontSize: 11, height: 1.3),
                        children: [
                          TextSpan(text: 'Some selected managers are already assigned to other groups. Saving will automatically '),
                          TextSpan(text: 'remove', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: ' them from their previous assignments.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Managers List
            _isFetchingInitialData || staffState.isLoading
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : filteredManagers.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16.0), child: Text('No managers found matching criteria.'))
                    : ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredManagers.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final user = filteredManagers[index];
                            final isSelected = _selectedManagerIds.contains(user.id);
                            
                            final isUnassigned = user.groupName == null || user.groupName == '-' || user.groupName!.isEmpty;
                            final isCurrentManager = user.groupName == widget.groupName;
                            final showAssignedPill = !isUnassigned && !isCurrentManager;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedManagerIds.remove(user.id);
                                  } else {
                                    _selectedManagerIds.add(user.id);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A1C26) : Colors.white,
                                  border: Border.all(
                                    color: isSelected 
                                      ? (isDark ? Colors.white : Colors.black) 
                                      : Colors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                flex: 1,
                                                child: Text(
                                                  user.name, 
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              if (showAssignedPill) ...[
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  flex: 1,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFF3E0),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'Assigned: ${user.groupName}',
                                                      style: const TextStyle(
                                                        color: Color(0xFFF57C00),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ),
                                              ]
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user.email, 
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12)
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedManagerIds.add(user.id);
                                            } else {
                                              _selectedManagerIds.remove(user.id);
                                            }
                                          });
                                        },
                                        activeColor: isDark ? Colors.white : Colors.black,
                                        checkColor: isDark ? Colors.black : Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      ),
                                    ),
                                  ],
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
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: _isSaving ? null : () async {
            setState(() {
              _isSaving = true;
            });
            try {
              await ref.read(groupProvider.notifier).assignManagersToGroup(widget.groupId, _selectedManagerIds.toList());
              
              if (context.mounted) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Managers assigned successfully'), backgroundColor: Colors.green)
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isSaving = false;
                });
              }
            }
          },
          child: _isSaving 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
            : const Text('Save Assignments', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
