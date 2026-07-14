import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/status_model.dart';
import '../../../providers/lead_provider.dart';

class LeadStatusConfigView extends ConsumerStatefulWidget {
  const LeadStatusConfigView({super.key});

  @override
  ConsumerState<LeadStatusConfigView> createState() => _LeadStatusConfigViewState();
}

class _LeadStatusConfigViewState extends ConsumerState<LeadStatusConfigView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Create Form State
  final _nameController = TextEditingController();
  String _selectedColorKey = 'blue'; // internal key
  bool _isCreating = false;

  // Map for UI rendering and Backend Payload
  final Map<String, Map<String, dynamic>> _colorPalette = {
    'blue': {
      'bg': 'bg-blue-100', 'text': 'text-blue-700', 
      'bgColor': Colors.blue.shade100, 'textColor': Colors.blue.shade700
    },
    'green': {
      'bg': 'bg-green-100', 'text': 'text-green-700', 
      'bgColor': Colors.green.shade100, 'textColor': Colors.green.shade700
    },
    'purple': {
      'bg': 'bg-purple-100', 'text': 'text-purple-700', 
      'bgColor': Colors.purple.shade100, 'textColor': Colors.purple.shade700
    },
    'orange': {
      'bg': 'bg-orange-100', 'text': 'text-orange-700', 
      'bgColor': Colors.orange.shade100, 'textColor': Colors.orange.shade700
    },
    'red': {
      'bg': 'bg-red-100', 'text': 'text-red-700', 
      'bgColor': Colors.red.shade100, 'textColor': Colors.red.shade700
    },
    'grey': {
      'bg': 'bg-gray-100', 'text': 'text-gray-700', 
      'bgColor': Colors.grey.shade300, 'textColor': Colors.grey.shade700
    },
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
       ref.read(leadStatusProvider.notifier).fetchStatuses();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a status name')));
        return;
    }
    
    setState(() { _isCreating = true; });
    
    try {
        final palette = _colorPalette[_selectedColorKey]!;
        await ref.read(leadServiceProvider).createLeadStatus(
            name: name,
            backgroundColor: palette['bg'],
            color: palette['text']
        );
        
        // Success
        _nameController.clear();
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status created successfully')));
            // Refresh list
            ref.read(leadStatusProvider.notifier).refreshStatuses();
        }
    } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
        if (mounted) setState(() { _isCreating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadStatusProvider);
    final allStatuses = state.statuses;
    
    final systemStatuses = allStatuses.where((s) => s.isDefault).toList();
    final companyStatuses = allStatuses.where((s) => !s.isDefault).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text("Lead Status Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
         const SizedBox(height: 16),
         
         // Visual Tab Bar (Segmented Look)
         _buildTabs(),
         const SizedBox(height: 20),
        
        // Content
        if (state.isLoading && allStatuses.isEmpty)
           const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else
           AnimatedBuilder(
               animation: _tabController,
               builder: (context, _) {
                   if (_tabController.index == 0) {
                      return _buildStatusList(systemStatuses, readOnly: true);
                   } else {
                      return Column(
                          children: [
                              _buildCreateForm(),
                              const SizedBox(height: 24),
                              _buildStatusList(companyStatuses, readOnly: false)
                          ],
                      );
                   }
               }
           )
      ],
    );
  }
  
   Widget _buildTabs() {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return Container(
       height: 48,
       padding: const EdgeInsets.all(4),
       decoration: BoxDecoration(
         color: isDark ? const Color(0xFF1E2130) : Colors.grey[100],
         borderRadius: BorderRadius.circular(8),
       ),
       child: TabBar(
         controller: _tabController,
         indicatorSize: TabBarIndicatorSize.tab,
         labelColor: isDark ? Colors.white : Colors.black,
         unselectedLabelColor: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.grey[500],
         labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
         unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
         indicator: BoxDecoration(
           color: isDark ? const Color(0xFF2D324A) : Colors.white,
           borderRadius: BorderRadius.circular(8),
           boxShadow: [
             if (!isDark)
               BoxShadow(
                 color: Colors.black.withValues(alpha: 0.05),
                 blurRadius: 4,
                 offset: const Offset(0, 2),
               ),
           ],
         ),
         tabs: const [
           Tab(text: 'DEFAULT STATUS'),
           Tab(text: 'COMPANY CREATED'),
         ],
         overlayColor: WidgetStateProperty.all(Colors.transparent),
         dividerColor: Colors.transparent, 
       ),
     );
   }

  // ... _buildCreateForm remains mostly the same, ensuring it looks good ...
  Widget _buildCreateForm() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text("Add New Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                      decoration: InputDecoration(
                          hintText: 'e.g., Interested, Follow Up',
                          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey[400], fontSize: 14),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.blue : Colors.black)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                      ),
                  ),
                  const SizedBox(height: 16),
                  Text("Select Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white38 : Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                      children: [
                         ..._colorPalette.keys.map((key) {
                             final isSelected = _selectedColorKey == key;
                             final color = _colorPalette[key]!['bgColor'] as Color;
                             return GestureDetector(
                                 onTap: () => setState(() => _selectedColorKey = key),
                                 child: Container(
                                     margin: const EdgeInsets.only(right: 12),
                                     width: 32, height: 32,
                                     decoration: BoxDecoration(
                                         color: color,
                                         shape: BoxShape.circle,
                                         border: isSelected ? Border.all(color: Colors.black, width: 2) : Border.all(color: Colors.transparent),
                                         boxShadow: [if(isSelected) BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                                     ),
                                     child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black54) : null,
                                 ),
                             );
                         })
                      ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                      children: [
                          Expanded(
                            child: ElevatedButton(
                                onPressed: _isCreating ? null : _handleCreate,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.blue : Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 0
                                ),
                                child: _isCreating 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('SAVE STATUS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                            ),
                          ),
                      ],
                  )
              ],
          ),
      );
  }

  Widget _buildStatusList(List<LeadStatus> statuses, {required bool readOnly}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (statuses.isEmpty) { 
          return Center(
             child: Padding(
                padding: const EdgeInsets.all(40), 
                child: Column(
                  children: [
                    Icon(Icons.layers_clear, size: 48, color: isDark ? Colors.white10 : Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No statuses found', style: TextStyle(color: isDark ? Colors.white24 : Colors.grey[500])),
                  ],
                )
             )
          );
      }
      
      return Container(
           decoration: BoxDecoration(
               color: Theme.of(context).cardColor,
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
           ),
          child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: statuses.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
              itemBuilder: (context, index) {
                  final status = statuses[index];
                  
                  // IMPROVED COLOR LOGIC
                  Color bgColor;
                  Color txtColor;
                  
                  // 1. Try to match by backend payload string (exact match)
                  final matchedKey = _colorPalette.keys.firstWhere(
                      (k) => _colorPalette[k]!['bg'] == status.backgroundColor, 
                      orElse: () => ''
                  );
                  
                  if (matchedKey.isNotEmpty) {
                      bgColor = _colorPalette[matchedKey]!['bgColor'];
                      txtColor = _colorPalette[matchedKey]!['textColor'];
                  } else {
                      // 2. Fallback: Intelligent string matching (like Lead Profile)
                      final lower = status.name.toLowerCase();
                      if (lower.contains('new')) {
                          bgColor = Colors.blue.shade100; txtColor = Colors.blue.shade700;
                      } else if (lower.contains('contact') || lower.contains('connect')) {
                          bgColor = Colors.green.shade100; txtColor = Colors.green.shade700;
                      } else if (lower.contains('negotiat')) {
                          bgColor = Colors.purple.shade100; txtColor = Colors.purple.shade700;
                      } else if (lower.contains('lost') || lower.contains('fail')) {
                          bgColor = Colors.red.shade100; txtColor = Colors.red.shade700;
                      } else if (lower.contains('won') || lower.contains('convert')) {
                          bgColor = Colors.teal.shade100; txtColor = Colors.teal.shade700;
                      } else if (lower.contains('junk')) {
                          bgColor = Colors.grey.shade300; txtColor = Colors.grey.shade700;
                      } else if (lower.contains('future') || lower.contains('attempt')) {
                          bgColor = Colors.orange.shade100; txtColor = Colors.orange.shade700;
                      } else {
                           // 3. Hash Fallback
                           final paletteKeys = _colorPalette.keys.toList();
                           final key = paletteKeys[status.name.hashCode.abs() % paletteKeys.length];
                           bgColor = _colorPalette[key]!['bgColor'];
                           txtColor = _colorPalette[key]!['textColor'];
                      }
                  }

                  return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                          children: [
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                   decoration: BoxDecoration(
                                       color: bgColor,
                                       borderRadius: BorderRadius.circular(8)
                                   ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          status.name, 
                                          style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 13)
                                      ),
                                      if (readOnly) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.lock, size: 12, color: txtColor.withValues(alpha: 0.6))
                                      ]
                                    ],
                                  ),
                              ),
                              const Spacer(),
                              IgnorePointer(
                                ignoring: readOnly,
                                child: Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                      value: status.isActive,
                                      onChanged: (val) {
                                         ref.read(leadStatusProvider.notifier).updateStatusActiveState(status.id, val);
                                      },
                                      activeThumbColor: isDark ? Colors.blue : Colors.black,
                                      inactiveThumbColor: Colors.grey,
                                      trackColor: WidgetStateProperty.resolveWith((states) {
                                         if (states.contains(WidgetState.selected)) return (isDark ? Colors.blue : Colors.black).withValues(alpha: 0.5);
                                         return isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200];
                                      }),
                                      thumbColor: WidgetStateProperty.resolveWith((states) {
                                          if (readOnly && states.contains(WidgetState.selected)) return Colors.grey[400];
                                          return Colors.white;
                                      }),
                                  ),
                                ),
                              )
                          ],
                      ),
                  );
              },
          ),
      );
  }
}
