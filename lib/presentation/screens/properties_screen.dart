import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/property_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../../data/models/property_model.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/project_create_dialog.dart';
import './all_properties_screen.dart';
import '../widgets/project_edit_dialog.dart';
import '../widgets/project_bulk_update_dialog.dart';
import '../widgets/project_quick_view_sheet.dart';
import '../../core/utils/date_utils.dart';
import '../widgets/project_share_dialog.dart';
import './public_view_screen.dart';
import '../widgets/access_denied_widget.dart';
import '../widgets/project_filters_bottom_sheet.dart';
import '../widgets/floating_dock_nav_bar.dart';

class PropertiesScreen extends ConsumerStatefulWidget {
  const PropertiesScreen({super.key});

  @override
  ConsumerState<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends ConsumerState<PropertiesScreen> {
  final Set<String> _selectedProjectIds = {};
  final ScrollController _scrollController = ScrollController();
  bool _isCardView = true;
  Set<String> _visibleColumns = {'Source', 'Status', 'Category', 'Properties', 'Possession Date', 'Last Updated'};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(propertyProvider.notifier).fetchProjects(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(propertyProvider.notifier).loadMoreProjects();
    }
  }

  void _toggleProjectSelection(String projectId) {
    setState(() {
      if (_selectedProjectIds.contains(projectId)) {
        _selectedProjectIds.remove(projectId);
      } else {
        _selectedProjectIds.add(projectId);
      }
    });
  }

  Widget _buildFiltersButton(BuildContext context, PropertyState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int activeFiltersCount = 0;
    if (state.status != 'All Status') activeFiltersCount++;
    if (state.projectCategory != 'All Projects') activeFiltersCount++;
    if (state.propertyCategory != 'All Properties') activeFiltersCount++;
    if (state.from != null || state.to != null) activeFiltersCount++;
    if (state.sort != 'updated_desc') activeFiltersCount++;

    final hasActiveFilters = activeFiltersCount > 0;

    return OutlinedButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const ProjectFiltersBottomSheet(),
        );
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.tune_rounded,
            size: 18,
            color: hasActiveFilters
                ? (isDark ? Colors.blueAccent : Colors.black)
                : (isDark ? Colors.white70 : Colors.black54),
          ),
          if (hasActiveFilters)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 12,
                  minHeight: 12,
                ),
                child: Text(
                  '$activeFiltersCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: Text(
        "Filters",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: hasActiveFilters
              ? (isDark ? Colors.blueAccent : Colors.black)
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(
          color: hasActiveFilters
              ? (isDark ? Colors.blueAccent : Colors.black)
              : (isDark ? Colors.white24 : Colors.grey[350]!),
          width: hasActiveFilters ? 1.5 : 1.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildColumnsButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.cardColor,
      elevation: 8,
      onSelected: (value) {
        if (value == 'reset') {
          setState(() {
            _visibleColumns = {'Source', 'Status', 'Category', 'Properties', 'Possession Date', 'Last Updated'};
          });
        }
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_column_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black54),
            const SizedBox(width: 4),
            Text(
              'Columns',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text('SHOW/HIDE COLUMNS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 0.5)),
        ),
        PopupMenuItem<String>(
          value: 'Project',
          child: CheckboxListTile(
            value: true,
            onChanged: null,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Project', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        for (final col in ['Source', 'Status', 'Category', 'Properties', 'Possession Date', 'Last Updated'])
          PopupMenuItem<String>(
            value: col,
            child: CheckboxListTile(
              value: _visibleColumns.contains(col),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _visibleColumns.add(col);
                  } else {
                    _visibleColumns.remove(col);
                  }
                });
                Navigator.pop(context);
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(col, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black)),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'reset',
          child: Text('Reset to default', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent)),
        ),
      ],
    );
  }

  Widget _buildViewToggleButtons(bool isDark) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isCardView = false),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: !_isCardView ? const Color(0xFF2563EB) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.list_rounded,
                size: 18,
                color: !_isCardView 
                    ? Colors.white 
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _isCardView = true),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _isCardView ? const Color(0xFF2563EB) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: _isCardView 
                    ? Colors.white 
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;

    // Completely restrict access if the PROPERTY module or PROJECT_VIEW permission is disabled
    if (!permissions.hasModule(PermissionModules.PROPERTY, userRole: user?.systemRole) ||
        !permissions.hasPermission(PermissionModules.PROJECT_VIEW, userRole: user?.systemRole)) {
      return const AccessDeniedWidget(
        sectionName: "Properties",
        showAppBar: true,
      );
    }

    final state = ref.watch(propertyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final filteredProjects = state.projects;

    ref.listen<PropertyState>(propertyProvider, (previous, next) {
      if (next.error != null && next.projects.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(currentRoute: 'Projects'),
      appBar: const GlobalAppBar(title: 'Projects'),
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onSubmitted: (val) => ref.read(propertyProvider.notifier).setSearchQuery(val),
                        decoration: InputDecoration(
                          hintText: 'Search projects by name...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[500], size: 20),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                    ),
                    if (permissions.hasPermission(PermissionModules.PROJECT_CREATE, userRole: user?.systemRole))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () => showDialog(context: context, builder: (context) => const ProjectCreateDialog()),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.add, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildViewToggleButtons(isDark),
                    const SizedBox(width: 8),
                    _buildFiltersButton(context, state),
                    if (!_isCardView) ...[
                      const SizedBox(width: 8),
                      _buildColumnsButton(context),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Selection Bar
          if (filteredProjects.isNotEmpty)
            _buildSelectionBar(filteredProjects),

          // Project List
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(propertyProvider);
                final filteredProjects = state.projects;

                if (state.isLoading && state.projects.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.error != null && state.projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 16),
                        Text(state.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        TextButton(
                          onPressed: () => ref.read(propertyProvider.notifier).fetchProjects(isRefresh: true),
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  );
                }

                if (filteredProjects.isEmpty) {
                  return const Center(child: Text('No projects found'));
                }

                if (!_isCardView) {
                  final eligibleProjects = filteredProjects.where((p) => permissions.hasPermission(
                    PermissionModules.PROJECT_UPDATE, 
                    userRole: user?.systemRole,
                  )).toList();

                  final allSelected = eligibleProjects.isNotEmpty && 
                      eligibleProjects.every((p) => _selectedProjectIds.contains(p.id));

                  const double projectColWidth = 180;
                  const double sourceColWidth = 120;
                  const double statusColWidth = 100;
                  const double categoryColWidth = 110;
                  const double propertiesColWidth = 90;
                  const double possessionDateColWidth = 110;
                  const double lastUpdatedColWidth = 110;
                  const double actionsColWidth = 140;

                  const double pinnedWidth = 12 + 20 + 12 + projectColWidth;
                  double scrollableWidth = 0;
                  if (_visibleColumns.contains('Source')) scrollableWidth += sourceColWidth;
                  if (_visibleColumns.contains('Status')) scrollableWidth += statusColWidth;
                  if (_visibleColumns.contains('Category')) scrollableWidth += categoryColWidth;
                  if (_visibleColumns.contains('Properties')) scrollableWidth += propertiesColWidth;
                  if (_visibleColumns.contains('Possession Date')) scrollableWidth += possessionDateColWidth;
                  if (_visibleColumns.contains('Last Updated')) scrollableWidth += lastUpdatedColWidth;
                  scrollableWidth += actionsColWidth;

                  final double tableWidth = pinnedWidth + scrollableWidth;

                  return Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  children: [
                                    // Table Header
                                    Container(
                                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                                      height: 48,
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: Checkbox(
                                              value: allSelected,
                                              tristate: eligibleProjects.isNotEmpty && 
                                                        eligibleProjects.any((p) => _selectedProjectIds.contains(p.id)) && 
                                                        !allSelected,
                                              onChanged: eligibleProjects.isEmpty ? null : (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedProjectIds.addAll(eligibleProjects.map((p) => p.id));
                                                  } else {
                                                    for (var p in eligibleProjects) {
                                                      _selectedProjectIds.remove(p.id);
                                                    }
                                                  }
                                                });
                                              },
                                              activeColor: theme.primaryColor,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const SizedBox(
                                            width: projectColWidth,
                                            child: Text(
                                              'PROJECT',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.grey,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          if (_visibleColumns.contains('Source'))
                                            const SizedBox(
                                              width: sourceColWidth,
                                              child: Text(
                                                'SOURCE',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 0.5),
                                              ),
                                            ),
                                          if (_visibleColumns.contains('Status'))
                                            const SizedBox(
                                              width: statusColWidth,
                                              child: Text(
                                                'STATUS',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 0.5),
                                              ),
                                            ),
                                          if (_visibleColumns.contains('Category'))
                                            const SizedBox(
                                              width: categoryColWidth,
                                              child: Text(
                                                'CATEGORY',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 0.5),
                                              ),
                                            ),
                                          if (_visibleColumns.contains('Properties'))
                                            const SizedBox(
                                              width: propertiesColWidth,
                                              child: Text(
                                                'PROPS',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 0.5),
                                              ),
                                            ),
                                          if (_visibleColumns.contains('Possession Date'))
                                            const SizedBox(
                                              width: possessionDateColWidth,
                                              child: Text(
                                                'POSSESSION',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 0.5),
                                              ),
                                            ),
                                          if (_visibleColumns.contains('Last Updated'))
                                            const SizedBox(
                                              width: lastUpdatedColWidth,
                                              child: Text(
                                                'UPDATED',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 0.5),
                                              ),
                                            ),
                                          const SizedBox(
                                            width: actionsColWidth,
                                            child: Text(
                                              'ACTIONS',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.15)),

                                    // Table Rows
                                    ...List.generate(filteredProjects.length, (index) {
                                      final project = filteredProjects[index];
                                      final isSelected = _selectedProjectIds.contains(project.id);
                                      
                                      return Container(
                                        height: 85,
                                        color: isSelected 
                                            ? theme.primaryColor.withValues(alpha: 0.03) 
                                            : (index % 2 == 1 && !isDark ? Colors.grey[50]?.withValues(alpha: 0.5) : null),
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: Checkbox(
                                                      value: isSelected,
                                                      activeColor: theme.primaryColor,
                                                      onChanged: (_) => _toggleProjectSelection(project.id),
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      visualDensity: VisualDensity.compact,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    width: projectColWidth,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        final hasPropertyViewPermission = permissions.hasModule(PermissionModules.PROPERTY, userRole: user?.systemRole) &&
                                                            permissions.hasPermission(PermissionModules.PROPERTY_VIEW, userRole: user?.systemRole);
                                                        if (hasPropertyViewPermission) {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => AllPropertiesScreen(projectId: project.id),
                                                            ),
                                                          );
                                                        } else {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text("Access Denied: You do not have permission to view properties of this project"),
                                                              backgroundColor: Colors.red,
                                                            ),
                                                          );
                                                        }
                                                      },
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            "#${index + 1} ${project.name}",
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 13.5,
                                                              color: isDark ? Colors.white : Colors.black87,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            project.location != null
                                                                ? [
                                                                    if (project.location!.address1.isNotEmpty) project.location!.address1,
                                                                    if (project.location!.city.isNotEmpty) project.location!.city,
                                                                    if (project.location!.state.isNotEmpty) project.location!.state,
                                                                  ].join(', ')
                                                                : 'No address',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  if (_visibleColumns.contains('Source'))
                                                    SizedBox(
                                                      width: sourceColWidth,
                                                      child: Align(
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          project.source != null && project.source!.isNotEmpty ? project.source! : 'system',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: isDark ? Colors.white70 : Colors.black87,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  if (_visibleColumns.contains('Status'))
                                                    SizedBox(
                                                      width: statusColWidth,
                                                      child: Align(
                                                        alignment: Alignment.center,
                                                        child: _buildReferenceBadge(project.status, isStatus: true),
                                                      ),
                                                    ),
                                                  if (_visibleColumns.contains('Category'))
                                                    SizedBox(
                                                      width: categoryColWidth,
                                                      child: Align(
                                                        alignment: Alignment.center,
                                                        child: _buildReferenceBadge(project.category, isStatus: false),
                                                      ),
                                                    ),
                                                  if (_visibleColumns.contains('Properties'))
                                                    SizedBox(
                                                      width: propertiesColWidth,
                                                      child: Align(
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          '${project.propertiesCount}',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                            color: isDark ? Colors.white : Colors.black87,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_visibleColumns.contains('Possession Date'))
                                                    SizedBox(
                                                      width: possessionDateColWidth,
                                                      child: Align(
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          project.possessionDate != null
                                                              ? DateTimeUtils.formatSafe(project.possessionDate!, format: 'dd/MM/yy')
                                                              : 'N/A',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_visibleColumns.contains('Last Updated'))
                                                    SizedBox(
                                                      width: lastUpdatedColWidth,
                                                      child: Align(
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          DateTimeUtils.formatSafe(project.updatedAt, format: 'dd/MM/yy'),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  SizedBox(
                                                    width: actionsColWidth,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        _buildTableActionButton(
                                                          icon: Icons.remove_red_eye_outlined,
                                                          onTap: () {
                                                            showModalBottomSheet(
                                                              context: context,
                                                              isScrollControlled: true,
                                                              backgroundColor: Colors.transparent,
                                                              builder: (context) => ProjectQuickViewSheet(project: project),
                                                            );
                                                          },
                                                          tooltip: 'Quick View',
                                                          isDark: isDark,
                                                        ),
                                                        const SizedBox(width: 12),
                                                        _buildTableActionButton(
                                                          icon: Icons.edit_outlined,
                                                          onTap: permissions.hasPermission(PermissionModules.PROJECT_UPDATE, userRole: user?.systemRole)
                                                              ? () {
                                                                  showDialog(
                                                                    context: context,
                                                                    builder: (context) => ProjectEditDialog(project: project),
                                                                  );
                                                                }
                                                              : null,
                                                          tooltip: 'Edit',
                                                          isDark: isDark,
                                                        ),
                                                        if (user?.systemRole == 'company_admin') ...[
                                                          const SizedBox(width: 12),
                                                          _buildTableActionButton(
                                                            icon: Icons.delete_outline_rounded,
                                                            onTap: permissions.hasPermission(PermissionModules.PROJECT_UPDATE, userRole: user?.systemRole)
                                                                ? () => _deleteProject(context, project)
                                                                : null,
                                                            tooltip: 'Delete',
                                                            iconColor: Colors.red,
                                                            isDark: isDark,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.15)),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            if (state.isLoading)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProjects.length + (state.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filteredProjects.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return _buildProjectCard(filteredProjects[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedProjectIds.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(bottom: ref.watch(dockVisibilityProvider) ? 80 : 0),
              child: FloatingActionButton.extended(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ProjectBulkUpdateDialog(
                      projectIds: _selectedProjectIds.toList(),
                    ),
                  ).then((_) {
                    setState(() {
                      _selectedProjectIds.clear();
                    });
                  });
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text("Bulk Update"),
                backgroundColor: Theme.of(context).primaryColor,
              ),
            )
          : null,
    );
  }

  Widget buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[500]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              iconSize: 16,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
              items: items.map((e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar(List<Project> filteredProjects) {
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    
    final eligibleProjects = filteredProjects.where((p) => permissions.hasPermission(
      PermissionModules.PROJECT_UPDATE, 
      userRole: user?.systemRole,
    )).toList();

    final allSelected = eligibleProjects.isNotEmpty && 
        eligibleProjects.every((p) => _selectedProjectIds.contains(p.id));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF1E293B) 
            : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: Checkbox(
              value: allSelected,
              tristate: eligibleProjects.isNotEmpty && 
                        eligibleProjects.any((p) => _selectedProjectIds.contains(p.id)) && 
                        !allSelected,
              onChanged: eligibleProjects.isEmpty ? null : (val) {
                setState(() {
                  if (val == true) {
                    _selectedProjectIds.addAll(eligibleProjects.map((p) => p.id));
                  } else {
                    for (var p in eligibleProjects) {
                      _selectedProjectIds.remove(p.id);
                    }
                  }
                });
              },
              activeColor: const Color(0xFF2563EB),
              side: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade600, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            allSelected ? "All eligible selected" : "Select all eligible on page",
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0369A1),
            ),
          ),
          const Spacer(),
          if (_selectedProjectIds.isNotEmpty)
            Text(
              "${_selectedProjectIds.length} selected",
              style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final projectId = project.id;
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;

    int getCategoryCount(String categoryName) {
      if (project.propertyCategoryCounts.isEmpty) return 0;
      for (var c in project.propertyCategoryCounts) {
        if (c.id.toLowerCase() == categoryName.toLowerCase()) {
          return c.count;
        }
      }
      return 0;
    }


    final address = project.location != null
        ? [
            if (project.location!.address1.isNotEmpty) project.location!.address1,
            if (project.location!.address2.isNotEmpty) project.location!.address2,
            if (project.location!.city.isNotEmpty) project.location!.city,
            if (project.location!.state.isNotEmpty) project.location!.state,
            if (project.location!.pincode != null && project.location!.pincode!.isNotEmpty) project.location!.pincode,
            if (project.location!.country.isNotEmpty) project.location!.country,
          ].join(', ')
        : 'Location not added';

    final statusColor = _getProjectStatusColor(project.status);

    final hasPropertyViewPermission = permissions.hasModule(PermissionModules.PROPERTY, userRole: user?.systemRole) &&
        permissions.hasPermission(PermissionModules.PROPERTY_VIEW, userRole: user?.systemRole);

    return GestureDetector(
      onTap: () {
        if (hasPropertyViewPermission) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllPropertiesScreen(projectId: project.id),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Access Denied: You do not have permission to view properties of this project"),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
          width: 1.0,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Edge Status bar
              Container(
                width: 5,
                color: statusColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Image Section with properties count badge overlaid
                          _buildProjectImage(project, isDark),
                          const SizedBox(width: 14),
                          // Right Details Section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            project.name.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              letterSpacing: -0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'source: ${project.source != null && project.source!.isNotEmpty ? project.source! : "system"}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: Checkbox(
                                            value: _selectedProjectIds.contains(projectId),
                                            activeColor: const Color(0xFF2563EB),
                                            onChanged: (_) => _toggleProjectSelection(projectId),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Metadata chips Row
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildReferenceBadge(project.status, isStatus: true),
                                    _buildReferenceBadge(project.category, isStatus: false),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Address text
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 12,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        address.isNotEmpty ? address : 'Location not added',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Action Button Row
                                Row(
                                  children: [
                                    _buildModernSquareButton(
                                      icon: Icons.remove_red_eye_outlined,
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => ProjectQuickViewSheet(project: project),
                                        );
                                      },
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildModernSquareButton(
                                      icon: Icons.edit_outlined,
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => ProjectEditDialog(project: project),
                                        );
                                      },
                                      isDark: isDark,
                                      isAllowed: permissions.hasPermission(
                                        PermissionModules.PROJECT_UPDATE,
                                        userRole: user?.systemRole,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildModernSquareButton(
                                      icon: Icons.reply_outlined,
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => ProjectShareDialog(project: project),
                                        );
                                      },
                                      isDark: isDark,
                                      isAllowed: permissions.hasPermission(
                                        PermissionModules.PROJECT_VIEW,
                                        userRole: user?.systemRole,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildModernSquareButton(
                                      icon: Icons.launch_outlined,
                                      onTap: () {
                                        PublicViewScreen.launchPublicView(context, ref, project: project);
                                      },
                                      isDark: isDark,
                                      isAllowed: permissions.can(
                                        PermissionModules.PROPERTY,
                                        permission: PermissionModules.PROJECT_VIEW,
                                        userRole: user?.systemRole,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (user?.systemRole == 'company_admin')
                                      _buildModernSquareButton(
                                        icon: Icons.delete_outline_rounded,
                                        onTap: () => _deleteProject(context, project),
                                        isDark: isDark,
                                        isRed: true,
                                        isAllowed: permissions.hasPermission(
                                          PermissionModules.PROJECT_UPDATE,
                                          userRole: user?.systemRole,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                    // Bottom Stats Grid Section
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          _buildStatColumn(
                            icon: Icons.home_outlined,
                            iconColor: const Color(0xFF22C55E),
                            title: "Residential",
                            value: getCategoryCount("Residential").toString().padLeft(2, '0'),
                            subtitle: "Properties",
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: 0.5,
                            height: 32,
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 14),
                          _buildStatColumn(
                            icon: Icons.business_outlined,
                            iconColor: const Color(0xFF2563EB),
                            title: "Commercial",
                            value: getCategoryCount("Commercial").toString().padLeft(2, '0'),
                            subtitle: "Properties",
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: 0.5,
                            height: 32,
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 14),
                          _buildStatColumn(
                            icon: Icons.factory_outlined,
                            iconColor: const Color(0xFFF97316),
                            title: "Industrial",
                            value: getCategoryCount("Industrial").toString().padLeft(2, '0'),
                            subtitle: "Properties",
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: 0.5,
                            height: 32,
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 14),
                          _buildStatColumn(
                            icon: Icons.landscape_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            title: "Land",
                            value: getCategoryCount("Land").toString().padLeft(2, '0'),
                            subtitle: "Properties",
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ],
    ),
  ),
),
),
);
}

  Widget _buildProjectImage(Project project, bool isDark) {
    final hasImage = project.images.isNotEmpty && project.images.first.isNotEmpty;
    
    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hasImage
                ? Image.network(
                    project.images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(isDark),
                  )
                : _buildImagePlaceholder(isDark),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.business_outlined,
                  size: 9,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                Text(
                  "${project.propertiesCount} Properties",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.domain_outlined,
        size: 28,
        color: isDark ? Colors.grey[500] : Colors.grey[400],
      ),
    );
  }



  Widget _buildModernSquareButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool isRed = false,
    bool isAllowed = true,
  }) {
    if (!isAllowed) return const SizedBox();
    final color = isRed
        ? Colors.red
        : (isDark ? Colors.grey[400]! : const Color(0xFF475569));
    final borderColor = isRed
        ? Colors.red.withValues(alpha: 0.3)
        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0));
    final bgColor = isRed
        ? Colors.red.withValues(alpha: 0.05)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.0),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTableActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
    Color? iconColor,
    required bool isDark,
  }) {
    final disabled = onTap == null;
    final color = disabled
        ? (isDark ? Colors.grey[700] : Colors.grey[400])
        : (iconColor ?? (isDark ? Colors.grey[300] : const Color(0xFF475569)));

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Color _getProjectStatusColor(String status) {
    final s = status.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
    if (s == 'active') {
      return Colors.green;
    } else if (s == 'pre launch' || s == 'pre-launch') {
      return Colors.blue;
    } else if (s == 'under construction') {
      return Colors.orange;
    } else if (s == 'ready to move') {
      return Colors.teal;
    } else if (s == 'sold out') {
      return Colors.purple;
    } else if (s == 'on hold') {
      return Colors.amber;
    } else if (s == 'blocked') {
      return Colors.red;
    }
    return Colors.grey;
  }



  Widget _buildReferenceBadge(String label, {required bool isStatus}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color textColor;
    Color bgColor;
    bool outline = false;
    
    if (isStatus) {
      final s = label.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
      Color color = Colors.grey;
      if (s == 'active') {
        color = Colors.green;
      } else if (s == 'pre launch' || s == 'pre-launch') {
        color = Colors.blue;
        outline = true;
      } else if (s == 'under construction') {
        color = Colors.orange;
      } else if (s == 'ready to move') {
        color = Colors.teal;
      } else if (s == 'sold out') {
        color = Colors.purple;
      } else if (s == 'on hold') {
        color = Colors.amber;
      } else if (s == 'blocked') {
        color = Colors.red;
      }
      
      textColor = color;
      bgColor = outline ? color.withValues(alpha: 0.03) : color.withValues(alpha: 0.12);
    } else {
      textColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
      bgColor = isDark ? Colors.white10 : const Color(0xFFF1F5F9);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStatus 
              ? (outline ? textColor : textColor.withValues(alpha: 0.2))
              : Colors.transparent,
          width: 1.0,
        ),
      ),
      child: Text(
        _toTitleCase(label.replaceAll('_', ' ').replaceAll('-', ' ')),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  void _deleteProject(BuildContext context, Project project) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Project"),
        content: Text("Are you sure you want to delete project '${project.name}'? This action cannot be undone and will delete all associated properties."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete")
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await ref.read(propertyProvider.notifier).deleteProject(project.id);
        if (success && mounted) {
           scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Project deleted successfully")));
        } else if (mounted) {
           scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Failed to delete project")));
        }
      } catch (e) {
        if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}
