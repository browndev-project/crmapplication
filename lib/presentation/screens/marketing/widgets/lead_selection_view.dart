import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/lead_provider.dart';
import '../../../../core/constants/permission_constants.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/login_provider.dart';
import 'send_email_dialog.dart';


import '../../../../core/utils/formatters.dart';

class LeadSelectionView extends ConsumerStatefulWidget {
  const LeadSelectionView({super.key});

  @override
  ConsumerState<LeadSelectionView> createState() => _LeadSelectionViewState();
}

class _LeadSelectionViewState extends ConsumerState<LeadSelectionView> {
  final Set<String> _selectedLeadIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch leads if not already loaded or stale
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final hasPermission = ref.read(permissionsProvider).hasModule(PermissionModules.LEADS, userRole: ref.read(loginProvider).user?.systemRole);
       if (hasPermission) {
          ref.read(leadsProvider.notifier).fetchLeads();
       }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedLeadIds.contains(id)) {
        _selectedLeadIds.remove(id);
      } else {
        _selectedLeadIds.add(id);
      }
    });
  }

  void _selectAll(List<String> allIds) {
    setState(() {
      if (_selectedLeadIds.length == allIds.length) {
        _selectedLeadIds.clear();
      } else {
        _selectedLeadIds.addAll(allIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leadsState = ref.watch(leadsProvider);
    final leads = leadsState.leads;
    final allIds = leads.map((e) => e.id).toList();
    final isAllSelected = leads.isNotEmpty && _selectedLeadIds.length == leads.length;

    final hasLeadsModule = ref.watch(permissionsProvider).hasModule(PermissionModules.LEADS, userRole: ref.read(loginProvider).user?.systemRole);

    if (!hasLeadsModule) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("Access Restricted", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text("You do not have permission to view leads.", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Selection Banner (Floating Style)
        if (_selectedLeadIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedLeadIds.length} Recipients Selected',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                    ),
                    
                    if (ref.watch(permissionsProvider).hasPermission(PermissionModules.MARKETING_MAIL, userRole: ref.watch(loginProvider).user?.systemRole) &&
                        ref.watch(permissionsProvider).hasModule(PermissionModules.TOOLS, userRole: ref.watch(loginProvider).user?.systemRole))
                       ElevatedButton(
                          onPressed: () {
                              final selectedLeads = leads.where((l) => _selectedLeadIds.contains(l.id)).toList();
                              showDialog(
                                context: context,
                                builder: (_) => SendEmailDialog(recipients: selectedLeads),
                              );
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.blue : Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: const Size(0, 36)
                          ),
                          child: const Text('MAIL NOW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                       )
                  ],
                ),
                const SizedBox(height: 12),
                
                // Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _selectedLeadIds.map((id) {
                      final lead = leads.firstWhere((l) => l.id == id, orElse: () => leads[0]); 
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          label: Text(
                            lead.email.isNotEmpty ? lead.email : 'No Email',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.blueGrey[800]),
                          ),
                          deleteIcon: Icon(Icons.close, size: 14, color: isDark ? Colors.white38 : Colors.blueGrey[400]),
                          onDeleted: () => _toggleSelection(id),
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blueGrey.shade50,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _selectedLeadIds.clear()),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text("Clear Selection", style: TextStyle(fontSize: 12)),
                  ),
                )
              ],
            ),
          ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search leads...',
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.white38 : Colors.grey[400], size: 20),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) {
                ref.read(leadsProvider.notifier).applyFilters({'search': val});
            },
          ),
        ),

        // Header Row (Visual Only)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
               InkWell(
                 onTap: () => _selectAll(allIds),
                 child: Container(
                   width: 20, height: 20,
                   decoration: BoxDecoration(
                     color: isAllSelected ? (isDark ? Colors.blue : Colors.black) : Colors.transparent,
                     border: Border.all(color: isAllSelected ? (isDark ? Colors.blue : Colors.black) : Colors.grey.shade400),
                     borderRadius: BorderRadius.circular(6),
                   ),
                   child: isAllSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                 ),
               ),
               const SizedBox(width: 16),
               Text("Select All", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
        ),

        // List
        Expanded(
          child: leadsState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: leads.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final lead = leads[index];
                    final isSelected = _selectedLeadIds.contains(lead.id);

                    return InkWell(
                      onTap: () => _toggleSelection(lead.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? (isDark ? Colors.blue : Colors.black) : Theme.of(context).dividerColor.withValues(alpha: 0.1), width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Checkbox Area
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected ? (isDark ? Colors.blue : Colors.black) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                                  border: Border.all(color: isSelected ? (isDark ? Colors.blue : Colors.black) : (isDark ? Colors.white10 : Colors.grey.shade300)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Info Area
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(lead.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(lead.status).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          toTitleCase(lead.status), 
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(lead.status)),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(lead.email, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 12, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(lead.phoneNo, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                                      const SizedBox(width: 12),
                                      Icon(Icons.work_outline, size: 12, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(lead.service?.name ?? 'No Service', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new': return Colors.blue;
      case 'contacted': return Colors.orange;
      case 'converted': return Colors.green;
      case 'lost': return Colors.red;
      default: return Colors.grey;
    }
  }
}
