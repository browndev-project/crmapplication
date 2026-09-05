import 'package:flutter/material.dart';
import 'common_shimmer_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/service_provider.dart';
import '../providers/team_provider.dart';
import '../../core/utils/date_utils.dart';
import '../providers/group_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/lead_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../providers/property_provider.dart';
import '../providers/constants_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../../data/models/staff_model.dart';

class LeadFilterBottomSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApply;

  const LeadFilterBottomSheet({
    super.key,
    required this.currentFilters,
    required this.onApply,
  });

  @override
  ConsumerState<LeadFilterBottomSheet> createState() => _LeadFilterBottomSheetState();
}

class _LeadFilterBottomSheetState extends ConsumerState<LeadFilterBottomSheet> {
  // State
  String _selectedCategory = 'Service'; // Default category

  // Multi-Select Filters
  List<String> _selectedServices = [];
  List<String> _selectedStatuses = [];
  List<String> _selectedSources = [];
  List<String> _selectedPipelines = [];
  List<String> _selectedAssignedTo = [];
  List<String> _selectedTeams = [];
  List<String> _selectedGroups = [];
  List<String> _selectedProjects = [];
  List<String> _selectedMetaCampaigns = [];
  List<String> _selectedMetaAdsets = [];
  List<String> _selectedMetaAds = [];
  List<String> _selectedMetaForms = [];

  List<_IdName> _metaCampaignsOptions = [];
  List<_IdName> _metaAdsetsOptions = [];
  List<_IdName> _metaAdsOptions = [];
  List<_IdName> _metaFormsOptions = [];
  bool _loadingMetaOptions = false;

  // Single Select Filters
  String? _sort;
  DateTime? _startDate;
  DateTime? _endDate;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  String _toTitleCase(String text) {
    if (text.trim().isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.trim().isEmpty) return word;
      final lower = word.toLowerCase();
      if (lower == 'ivr') return 'IVR';
      if (lower == 'gmb') return 'GMB';
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  final List<String> categories = [
      'Service',
      'Status', 
      'Lead Stage', // Pipeline
      'Source',
      'Assigned To',
      'Project',
      'Team',
      'Group',
      'Sort By',
      'Date Range'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentFilters();
    
    // Set initial selected category based on permissions
    WidgetsBinding.instance.addPostFrameCallback((_) {
        final permissions = ref.read(permissionsProvider);
        final user = ref.read(loginProvider).user;
        
        if (!permissions.hasModule(PermissionModules.SERVICES, userRole: user?.systemRole)) {
            setState(() => _selectedCategory = 'Status');
        }
        
        ref.read(servicesProvider.notifier).fetchServices();
        ref.read(teamProvider.notifier).fetchTeams();
        ref.read(groupProvider.notifier).fetchGroups();
        ref.read(propertyProvider.notifier).fetchProjects();
        ref.read(staffProvider('admin').notifier).fetchUsers();
        ref.read(staffProvider('sales_executive').notifier).fetchUsers();
        ref.read(staffProvider('team_leader').notifier).fetchUsers();
        ref.read(staffProvider('sales_manager').notifier).fetchUsers();
        ref.read(leadStatusProvider.notifier).fetchStatuses();
        ref.read(constantsProvider.notifier).fetchConstants();
        _fetchMetaAttributionOptions();
    });
  }

  void _loadCurrentFilters() {
    final f = widget.currentFilters;
    
    _selectedServices = _parseList(f['service']);
    _selectedStatuses = _parseList(f['status']);
    _selectedSources = _parseList(f['source']);
    _selectedPipelines = _parseList(f['pipeline']);

    // Handle Assigned To mapping
    String? assignedToRaw = f['assignedToEmp'] ?? f['assignedTo'];
    _selectedAssignedTo = _parseList(assignedToRaw);

    _selectedTeams = _parseList(f['team']);
    _selectedGroups = _parseList(f['group']);
    _selectedProjects = _parseList(f['project']);
    _selectedMetaCampaigns = _parseList(f['metaCampaignId']);
    _selectedMetaAdsets = _parseList(f['metaAdsetId']);
    _selectedMetaAds = _parseList(f['metaAdId']);
    _selectedMetaForms = _parseList(f['metaFormId']);
    
    _sort = f['sort'] ?? 'updated_desc';
    
    String? startStr = f['from'] ?? f['startDate'];
    String? endStr = f['to'] ?? f['endDate'];

    if (startStr != null) {
      _startDate = DateTimeUtils.parseSafe(startStr);
    }
    if (endStr != null) {
      _endDate = DateTimeUtils.parseSafe(endStr);
    }
  }

  List<String> _parseList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String && value.isNotEmpty) return value.split(',');
      return [];
  }

  void _resetFilters() {
    setState(() {
      _selectedServices = [];
      _selectedStatuses = [];
      _selectedSources = [];
      _selectedPipelines = [];
      _selectedAssignedTo = [];
      _selectedTeams = [];
      _selectedGroups = [];
      _selectedProjects = [];
      _selectedMetaCampaigns = [];
      _selectedMetaAdsets = [];
      _selectedMetaAds = [];
      _selectedMetaForms = [];
      _sort = 'updated_desc';
      _startDate = null;
      _endDate = null;
    });
  }

  void _apply() {
    final Map<String, dynamic> filters = {};
    
    if (_selectedServices.isNotEmpty) filters['service'] = _selectedServices.join(',');
    if (_selectedStatuses.isNotEmpty) filters['status'] = _selectedStatuses.join(',');
    if (_selectedSources.isNotEmpty) filters['source'] = _selectedSources.join(',');
    if (_selectedPipelines.isNotEmpty) filters['pipeline'] = _selectedPipelines.join(',');
    if (_selectedAssignedTo.isNotEmpty) filters['assignedTo'] = _selectedAssignedTo.join(',');
    if (_selectedTeams.isNotEmpty) filters['team'] = _selectedTeams.join(',');
    if (_selectedGroups.isNotEmpty) filters['group'] = _selectedGroups.join(',');
    if (_selectedProjects.isNotEmpty) filters['project'] = _selectedProjects.join(',');
    if (_selectedMetaCampaigns.isNotEmpty) filters['metaCampaignId'] = _selectedMetaCampaigns.join(',');
    if (_selectedMetaAdsets.isNotEmpty) filters['metaAdsetId'] = _selectedMetaAdsets.join(',');
    if (_selectedMetaAds.isNotEmpty) filters['metaAdId'] = _selectedMetaAds.join(',');
    if (_selectedMetaForms.isNotEmpty) filters['metaFormId'] = _selectedMetaForms.join(',');
    
    if (_sort != null) filters['sort'] = _sort;
    if (_startDate != null) filters['startDate'] = _dateFormat.format(_startDate!);
    if (_endDate != null) filters['endDate'] = _dateFormat.format(_endDate!);

    widget.onApply(filters);
    Navigator.pop(context);
  }

  List<_IdName> _uniqueItems(List<_IdName> items) {
       final seen = <String>{};
       return items.where((e) => seen.add(e.id)).toList();
  }

  Future<void> _fetchMetaAttributionOptions() async {
    if (mounted) setState(() => _loadingMetaOptions = true);
    try {
      final options = await ref.read(leadServiceProvider).fetchMetaAttributionOptions();
      if (options != null && mounted) {
        final campaignsList = (options['campaigns'] as List?) ?? [];
        final adsetsList = (options['adsets'] as List?) ?? [];
        final adsList = (options['ads'] as List?) ?? [];
        final formsList = (options['forms'] as List?) ?? [];

        setState(() {
          _metaCampaignsOptions = campaignsList
              .map((e) => _IdName(e['campaignId']?.toString() ?? '', e['name']?.toString() ?? ''))
              .toList();
          _metaAdsetsOptions = adsetsList
              .map((e) => _IdName(e['adsetId']?.toString() ?? '', e['name']?.toString() ?? ''))
              .toList();
          _metaAdsOptions = adsList
              .map((e) => _IdName(e['adId']?.toString() ?? '', e['name']?.toString() ?? ''))
              .toList();
          _metaFormsOptions = formsList
              .map((e) => _IdName(e['formId']?.toString() ?? '', e['name']?.toString() ?? ''))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading meta options: $e');
    } finally {
      if (mounted) setState(() => _loadingMetaOptions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
    final bgColor = theme.cardColor;
    final sidebarBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50];
    final activeColor = isDark ? Colors.blueAccent : Colors.black;

    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;

    final isSalesExecutive = user?.systemRole == 'sales_executive';

    final List<String> filteredCategories = [
      if (permissions.hasModule(PermissionModules.SERVICES, userRole: user?.systemRole)) 'Service',
      'Status', 
      'Lead Stage', // Pipeline
      'Source',
      if (!isSalesExecutive) 'Assigned To',
      'Project',
      if (!isSalesExecutive && permissions.hasModule(PermissionModules.STAFF_TEAM, userRole: user?.systemRole)) 'Team',
      if (!isSalesExecutive && permissions.hasModule(PermissionModules.STAFF_GROUP, userRole: user?.systemRole)) 'Group',
      'Meta Campaign',
      'Meta Adset',
      'Meta Ad',
      'Meta Form',
      'Sort By',
      'Date Range'
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textColor),
                  onPressed: () => Navigator.pop(context),
                  tooltip: "Close",
                )
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),

          // Main Body (Split View)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Side: Categories
                SizedBox(
                  width: 130,
                  child: Container(
                    decoration: BoxDecoration(
                      color: sidebarBg,
                      border: Border(right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05))),
                    ),
                    child: ListView.builder(
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final cat = filteredCategories[index];
                        final isSelected = _selectedCategory == cat;
                        
                        bool hasFilter = false;
                        if (cat == 'Service' && _selectedServices.isNotEmpty) hasFilter = true;
                        if (cat == 'Status' && _selectedStatuses.isNotEmpty) hasFilter = true;
                        if (cat == 'Lead Stage' && _selectedPipelines.isNotEmpty) hasFilter = true;
                        if (cat == 'Source' && _selectedSources.isNotEmpty) hasFilter = true;
                        if (cat == 'Assigned To' && _selectedAssignedTo.isNotEmpty) hasFilter = true;
                        if (cat == 'Project' && _selectedProjects.isNotEmpty) hasFilter = true;
                        if (cat == 'Team' && _selectedTeams.isNotEmpty) hasFilter = true;
                        if (cat == 'Group' && _selectedGroups.isNotEmpty) hasFilter = true;
                        if (cat == 'Sort By' && _sort != null && _sort != 'updated_desc') hasFilter = true;
                        if (cat == 'Date Range' && (_startDate != null || _endDate != null)) hasFilter = true;

                        return InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            color: isSelected ? bgColor : Colors.transparent,
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 4,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: isSelected ? activeColor : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            cat,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              fontSize: 13,
                                              color: isSelected ? textColor : secondaryTextColor,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                        if (hasFilter)
                                           Container(
                                             width: 5, height: 5, 
                                             decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle)
                                           )
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Right Side: Options
                Expanded(
                  child: Container(
                     color: bgColor,
                     child: _buildRightSide(context),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          // Footer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _resetFilters,
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: const Text('Clear all', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRightSide(BuildContext context) {
      final theme = Theme.of(context);
      // Fetch Data
      final services = ref.watch(servicesProvider).services;
      final teams = ref.watch(teamProvider).teams;
      final groups = ref.watch(groupProvider).groups;
      final projects = ref.watch(propertyProvider).projects;
      
      final executives = ref.watch(staffProvider('sales_executive')).users;
      final leaders = ref.watch(staffProvider('team_leader')).users;
      final managers = ref.watch(staffProvider('sales_manager')).users;
      final admins = ref.watch(staffProvider('admin')).users;
      
      final currentUser = ref.watch(loginProvider).user;
      final allRaw = [...admins, ...managers, ...leaders, ...executives]
          .where((u) => u.status.toLowerCase() == 'active' && u.active == true)
          .toList();

      switch (_selectedCategory) {
          case 'Meta Campaign':
             if (_loadingMetaOptions) return const AppShimmerListSkeleton(itemCount: 4);
             return _buildCheckboxList(
                 context: context,
                 items: _metaCampaignsOptions,
                 selectedValues: _selectedMetaCampaigns,
                 onChanged: (v, selected) => setState(() => selected ? _selectedMetaCampaigns.add(v) : _selectedMetaCampaigns.remove(v)),
             );
          case 'Meta Adset':
             if (_loadingMetaOptions) return const AppShimmerListSkeleton(itemCount: 4);
             return _buildCheckboxList(
                 context: context,
                 items: _metaAdsetsOptions,
                 selectedValues: _selectedMetaAdsets,
                 onChanged: (v, selected) => setState(() => selected ? _selectedMetaAdsets.add(v) : _selectedMetaAdsets.remove(v)),
             );
          case 'Meta Ad':
             if (_loadingMetaOptions) return const AppShimmerListSkeleton(itemCount: 4);
             return _buildCheckboxList(
                 context: context,
                 items: _metaAdsOptions,
                 selectedValues: _selectedMetaAds,
                 onChanged: (v, selected) => setState(() => selected ? _selectedMetaAds.add(v) : _selectedMetaAds.remove(v)),
             );
          case 'Meta Form':
             if (_loadingMetaOptions) return const AppShimmerListSkeleton(itemCount: 4);
             return _buildCheckboxList(
                 context: context,
                 items: _metaFormsOptions,
                 selectedValues: _selectedMetaForms,
                 onChanged: (v, selected) => setState(() => selected ? _selectedMetaForms.add(v) : _selectedMetaForms.remove(v)),
             );
          case 'Service':
              final serviceItems = _uniqueItems(services.map((e) => _IdName(e.id, _toTitleCase(e.name))).toList());
              serviceItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              return _buildCheckboxList(
                  context: context,
                  items: serviceItems,
                  selectedValues: _selectedServices,
                  onChanged: (v, selected) {
                     setState(() {
                          if (selected) { _selectedServices.add(v); } 
                          else { _selectedServices.remove(v); }
                     });
                  },
              );
           case 'Status':
              final statusState = ref.watch(leadStatusProvider);
              final statuses = statusState.statuses.where((s) => s.isActive).toList();
              
              if (statusState.isLoading) return const AppShimmerListSkeleton(itemCount: 3);
              if (statusState.error != null) return Center(child: Text("Error: ${statusState.error}", style: const TextStyle(color: Colors.red)));
              
              final statusItems = statuses.map((e) => _IdName(e.id, _toTitleCase(e.name))).toList();
              statusItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              return _buildCheckboxList(
                  context: context,
                  items: statusItems,
                  selectedValues: _selectedStatuses,
                  onChanged: (v, selected) => setState(() => selected ? _selectedStatuses.add(v) : _selectedStatuses.remove(v)),
              );
            case 'Lead Stage':
               final constantsState = ref.watch(constantsProvider);
               final apiPipelines = constantsState.value?.leadPipeline ?? [];
               final pipelineItems = apiPipelines.map((e) => _IdName(e.value, _toTitleCase(e.label.isNotEmpty ? e.label : e.value))).toList();
               pipelineItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
               return _buildCheckboxList(
                   context: context,
                   items: pipelineItems,
                   selectedValues: _selectedPipelines,
                   onChanged: (v, selected) => setState(() => selected ? _selectedPipelines.add(v) : _selectedPipelines.remove(v)),
               );
            case 'Source':
               final constantsState = ref.watch(constantsProvider);
               final apiSources = constantsState.value?.leadSources ?? [];
               final sourceItems = apiSources.map((e) => _IdName(e.value, _toTitleCase(e.label.isNotEmpty ? e.label : e.value))).toList();
               sourceItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
               return _buildCheckboxList(
                   context: context,
                   items: sourceItems,
                   selectedValues: _selectedSources,
                   onChanged: (v, selected) => setState(() => selected ? _selectedSources.add(v) : _selectedSources.remove(v)),
               );
          case 'Assigned To':
             List<_IdName> staffList = [];
             
             // Map raw staff to _IdName with (Self) tag
             for (var s in allRaw) {
                 String displayName = s.name;
                 if (currentUser != null && s.id == currentUser.id) {
                     displayName = "${s.name} (Self)";
                 }
                 staffList.add(_IdName(s.id, displayName));
             }
             
             // Ensure current user is present if they have an ID
             if (currentUser != null && !staffList.any((s) => s.id == currentUser.id)) {
                 staffList.add(_IdName(currentUser.id, "${currentUser.name} (Self)"));
             }
             
             staffList = _uniqueItems(staffList);
             
             // Role weights for sorting
             final roleWeights = {
                 'admin': 1,
                 'sales_manager': 2,
                 'team_leader': 3,
                 'sales_executive': 4,
             };

             // Sort by role sequence: Self > admin > sales_manager > team_leader > sales_executive
             staffList.sort((a, b) {
                 // 1. Self always first
                 if (currentUser != null) {
                     if (a.id == currentUser.id) return -1;
                     if (b.id == currentUser.id) return 1;
                 }
                 
                 // 2. Find role for a and b to get weights
                 StaffUser? userA;
                 try { userA = allRaw.firstWhere((u) => u.id == a.id); } catch (_) {}
                 
                 StaffUser? userB;
                 try { userB = allRaw.firstWhere((u) => u.id == b.id); } catch (_) {}
                 
                 int weightA = roleWeights[userA?.systemRole ?? ''] ?? 5;
                 int weightB = roleWeights[userB?.systemRole ?? ''] ?? 5;
                 
                 if (weightA != weightB) {
                     return weightA.compareTo(weightB);
                 }
                 
                 // 3. Alphabetical fallback
                 return a.name.compareTo(b.name);
             });

             return _buildCheckboxList(
                 context: context,
                 items: staffList,
                 selectedValues: _selectedAssignedTo,
                 onChanged: (v, selected) => setState(() => selected ? _selectedAssignedTo.add(v) : _selectedAssignedTo.remove(v)),
             );
          case 'Project':
              final projectItems = _uniqueItems(projects.map((e) => _IdName(e.id, _toTitleCase(e.name))).toList());
              projectItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              return _buildCheckboxList(
                  context: context,
                  items: projectItems,
                  selectedValues: _selectedProjects,
                  onChanged: (v, selected) => setState(() => selected ? _selectedProjects.add(v) : _selectedProjects.remove(v)),
              );
           case 'Team':
              final teamItems = _uniqueItems(teams.map((e) => _IdName(e.id, _toTitleCase(e.name))).toList());
              teamItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              return _buildCheckboxList(
                  context: context,
                  items: teamItems,
                  selectedValues: _selectedTeams,
                  onChanged: (v, selected) => setState(() => selected ? _selectedTeams.add(v) : _selectedTeams.remove(v)),
              );
           case 'Group':
              final groupItems = _uniqueItems(groups.map((e) => _IdName(e.id, _toTitleCase(e.name))).toList());
              groupItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              return _buildCheckboxList(
                  context: context,
                  items: groupItems,
                  selectedValues: _selectedGroups,
                  onChanged: (v, selected) => setState(() => selected ? _selectedGroups.add(v) : _selectedGroups.remove(v)),
              );
          case 'Sort By':
             return _buildRadioList( 
                 context: context,
                 items: [
                     _IdName('updated_desc', 'Last Updated (Newest First)'),
                     _IdName('updated_asc', 'Last Updated (Oldest First)'),
                     _IdName('created_desc', 'Created Date (Newest First)'),
                     _IdName('created_asc', 'Created Date (Oldest First)'),
                 ],
                 groupValue: _sort,
                 onChanged: (v) => setState(() => _sort = v),
             );
          case 'Date Range':
             return Padding(
                 padding: const EdgeInsets.all(20),
                 child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                         Text('Select Date Range', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.textTheme.bodyLarge?.color)),
                         const SizedBox(height: 24),
                         _buildDateSelector(context, 'From', _startDate, (d) => setState(() => _startDate = d)),
                         const SizedBox(height: 16),
                         _buildDateSelector(context, 'To', _endDate, (d) => setState(() => _endDate = d)),
                     ],
                 ),
             );
          default:
             return const Center(child: Text('Select a category'));
      }
  }

  Widget _buildCheckboxList({
      required BuildContext context,
      required List<_IdName> items,
      required List<String> selectedValues,
      required Function(String, bool) onChanged,
  }) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      if (items.isEmpty) {
          return Center(child: Text("No items available", style: TextStyle(color: theme.textTheme.bodySmall?.color)));
      }
      return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (c, i) => Divider(height: 1, indent: 16, color: theme.dividerColor.withValues(alpha: 0.05)),
          itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = selectedValues.contains(item.id);
              
              return CheckboxListTile(
                  value: isSelected,
                  onChanged: (val) {
                      if (val != null) onChanged(item.id, val);
                  },
                  title: Text(item.name, style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                      color: isSelected ? theme.textTheme.bodyLarge?.color : theme.textTheme.bodyMedium?.color,
                  )),
                  activeColor: isDark ? Colors.blueAccent : Colors.black,
                  checkColor: isDark ? Colors.black : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  controlAffinity: ListTileControlAffinity.leading, 
                  visualDensity: VisualDensity.compact,
              );
          },
      );
  }

  Widget _buildRadioList({
      required BuildContext context,
      required List<_IdName> items,
      required String? groupValue,
      required Function(String?) onChanged,
  }) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return RadioGroup<String>(
          groupValue: groupValue,
          onChanged: onChanged,
          child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (c, i) => Divider(height: 1, indent: 16, color: theme.dividerColor.withValues(alpha: 0.05)),
              itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item.id == groupValue;
                  
                  return RadioListTile<String>(
                      value: item.id,
                      title: Text(item.name, style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                          color: isSelected ? theme.textTheme.bodyLarge?.color : theme.textTheme.bodyMedium?.color,
                      )),
                      activeColor: isDark ? Colors.blueAccent : Colors.black,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      controlAffinity: ListTileControlAffinity.trailing,
                      visualDensity: VisualDensity.compact,
                  );
              },
          ),
      );
  }

  Widget _buildDateSelector(BuildContext context, String label, DateTime? date, Function(DateTime) onSelect) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return InkWell(
          onTap: () async {
              final picked = await showDatePicker(
                  context: context,
                  initialDate: date ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                        data: Theme.of(context).copyWith(
                            colorScheme: isDark 
                              ? const ColorScheme.dark(primary: Colors.blueAccent, onPrimary: Colors.black, surface: Color(0xFF1E1E1E))
                              : const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white),
                        ),
                        child: child!
                    );
                }
              );
              if (picked != null) onSelect(picked);
          },
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      Text(
                        date != null ? _dateFormat.format(date) : label, 
                        style: TextStyle(
                          color: date != null ? theme.textTheme.bodyLarge?.color : theme.textTheme.bodySmall?.color,
                          fontWeight: date != null ? FontWeight.w700 : FontWeight.w400,
                        )
                      ),
                      Icon(Icons.calendar_today_rounded, size: 18, color: theme.iconTheme.color?.withValues(alpha: 0.5))
                  ],
              ),
          ),
      );
  }
}

class _IdName {
  final String id;
  final String name;
  _IdName(this.id, this.name);
}
