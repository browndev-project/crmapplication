import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/property_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../../data/models/property_model.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/project_create_dialog.dart';
import './project_detail_screen.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isCardView = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: !_isCardView 
                    ? (isDark ? Colors.white24 : Colors.grey[300]) 
                    : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
              ),
              height: double.infinity,
              child: Icon(
                Icons.list_rounded,
                size: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Container(
            width: 1,
            color: isDark ? Colors.white12 : Colors.grey[300]!,
            height: double.infinity,
          ),
          GestureDetector(
            onTap: () => setState(() => _isCardView = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _isCardView 
                    ? (isDark ? Colors.white24 : Colors.grey[300]) 
                    : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
              ),
              height: double.infinity,
              child: Icon(
                Icons.grid_view_rounded,
                size: 20,
                color: isDark ? Colors.white : Colors.black87,
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
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),
                    if (permissions.hasPermission(PermissionModules.PROJECT_CREATE, userRole: user?.systemRole))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          icon: Icon(Icons.add_box_rounded, color: isDark ? Colors.white : Colors.black, size: 28),
                          onPressed: () => showDialog(context: context, builder: (context) => const ProjectCreateDialog()),
                          tooltip: 'Create Project',
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

                  double tableWidth = 12 + 20 + 12 + projectColWidth;
                  if (_visibleColumns.contains('Source')) tableWidth += sourceColWidth;
                  if (_visibleColumns.contains('Status')) tableWidth += statusColWidth;
                  if (_visibleColumns.contains('Category')) tableWidth += categoryColWidth;
                  if (_visibleColumns.contains('Properties')) tableWidth += propertiesColWidth;
                  if (_visibleColumns.contains('Possession Date')) tableWidth += possessionDateColWidth;
                  if (_visibleColumns.contains('Last Updated')) tableWidth += lastUpdatedColWidth;

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
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                                padding: const EdgeInsets.symmetric(vertical: 10),
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
                                        'Project',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    if (_visibleColumns.contains('Source'))
                                      const SizedBox(
                                        width: sourceColWidth,
                                        child: Text(
                                          'Source',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                        ),
                                      ),
                                    if (_visibleColumns.contains('Status'))
                                      const SizedBox(
                                        width: statusColWidth,
                                        child: Text(
                                          'Status',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                        ),
                                      ),
                                    if (_visibleColumns.contains('Category'))
                                      const SizedBox(
                                        width: categoryColWidth,
                                        child: Text(
                                          'Category',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                        ),
                                      ),
                                    if (_visibleColumns.contains('Properties'))
                                      const SizedBox(
                                        width: propertiesColWidth,
                                        child: Text(
                                          'Props',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                        ),
                                      ),
                                    if (_visibleColumns.contains('Possession Date'))
                                      const SizedBox(
                                        width: possessionDateColWidth,
                                        child: Text(
                                          'Possession',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                                        ),
                                      ),
                                    if (_visibleColumns.contains('Last Updated'))
                                      const SizedBox(
                                        width: lastUpdatedColWidth,
                                        child: Text(
                                          'Updated',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.15)),
                              // Table Rows
                              Expanded(
                                child: ListView.separated(
                                  controller: _scrollController,
                                  itemCount: filteredProjects.length + (state.isLoading ? 1 : 0),
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1, 
                                    color: theme.dividerColor.withValues(alpha: 0.15)
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index == filteredProjects.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    
                                    final project = filteredProjects[index];
                                    final isSelected = _selectedProjectIds.contains(project.id);
                                    
                                    final address = project.location != null
                                        ? [
                                            if (project.location!.address1.isNotEmpty) project.location!.address1,
                                            if (project.location!.city.isNotEmpty) project.location!.city,
                                            if (project.location!.state.isNotEmpty) project.location!.state,
                                          ].join(', ')
                                        : 'No address';

                                    return Container(
                                      color: isSelected 
                                          ? theme.primaryColor.withValues(alpha: 0.03) 
                                          : (index % 2 == 1 && !isDark ? Colors.grey[50]?.withValues(alpha: 0.5) : null),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            child: SizedBox(
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
                                          ),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ProjectDetailScreen(project: project),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: projectColWidth,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              '#${index + 1} ',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 13.5,
                                                                color: Colors.grey,
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                project.name,
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 13.5,
                                                                  color: isDark ? Colors.white : Colors.black87,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          address,
                                                          style: TextStyle(
                                                            fontSize: 11.5,
                                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (_visibleColumns.contains('Source'))
                                                    SizedBox(
                                                      width: sourceColWidth,
                                                      child: Align(
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          project.developerName.isNotEmpty ? project.developerName : (project.source ?? 'N/A'),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
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
                                                            fontSize: 11,
                                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                                                            fontSize: 11,
                                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                          ),
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
                                  },
                                ),
                              ),
                            ],
                          ),
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
    
    // Projects that the user is allowed to update
    final eligibleProjects = filteredProjects.where((p) => permissions.hasPermission(
      PermissionModules.PROJECT_UPDATE, 
      userRole: user?.systemRole,
    )).toList();

    final allSelected = eligibleProjects.isNotEmpty && 
        eligibleProjects.every((p) => _selectedProjectIds.contains(p.id));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Checkbox(
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
            activeColor: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            allSelected ? "All eligible selected" : "Select All eligible on page",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_selectedProjectIds.isNotEmpty)
            Text(
              "${_selectedProjectIds.length} selected",
              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
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

    final address = project.location != null
        ? [
            if (project.location!.address1.isNotEmpty) project.location!.address1,
            if (project.location!.address2.isNotEmpty) project.location!.address2,
            if (project.location!.city.isNotEmpty) project.location!.city,
            if (project.location!.state.isNotEmpty) project.location!.state,
            if (project.location!.pincode != null && project.location!.pincode!.isNotEmpty) project.location!.pincode,
            if (project.location!.country.isNotEmpty) project.location!.country,
          ].join(', ')
        : 'No address';

    final createdDt = DateTimeUtils.parseSafe(project.createdAt);
    final createdStr = createdDt != null ? DateFormat('dd MMM yyyy').format(createdDt) : project.createdAt;
    final updatedDt = DateTimeUtils.parseSafe(project.updatedAt);
    final updatedStr = updatedDt != null ? DateFormat('dd MMM yyyy').format(updatedDt) : project.updatedAt;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(project: project),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Checkbox + Name / Index
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "#${project.id.length > 2 ? project.id.substring(project.id.length - 2) : project.id} ${project.name}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Properties: ${project.propertiesCount}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (project.developerName.isNotEmpty || (project.source != null && project.source!.isNotEmpty)) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Source: ${project.developerName.isNotEmpty ? project.developerName : project.source}",
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[300] : Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Checkbox(
                    value: _selectedProjectIds.contains(projectId),
                    activeColor: theme.primaryColor,
                    onChanged: (_) => _toggleProjectSelection(projectId),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Badges Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildReferenceBadge(project.status, isStatus: true),
                  const SizedBox(width: 8),
                  _buildReferenceBadge(project.category, isStatus: false),
                ],
              ),
            ),

            // Address Location Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[750],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 16, thickness: 0.5, indent: 16, endIndent: 16),

            // Actions Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _buildActionIconButton(Icons.visibility_outlined, "View", () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ProjectQuickViewSheet(project: project),
                    );
                  }),
                  _buildActionIconButton(Icons.edit_outlined, "Edit", () {
                    showDialog(context: context, builder: (context) => ProjectEditDialog(project: project));
                  }, isAllowed: permissions.hasPermission(PermissionModules.PROJECT_UPDATE, userRole: user?.systemRole)),
                  _buildActionIconButton(Icons.share_outlined, "Share", () {
                    showDialog(context: context, builder: (context) => ProjectShareDialog(project: project));
                  }, isAllowed: permissions.hasPermission(PermissionModules.PROJECT_VIEW, userRole: user?.systemRole)),
                  _buildActionIconButton(Icons.launch_outlined, "Public", () {
                    PublicViewScreen.launchPublicView(context, ref, project: project);
                  }, isAllowed: permissions.can(PermissionModules.PROPERTY, permission: PermissionModules.PROJECT_VIEW, userRole: user?.systemRole)),
                  _buildActionIconButton(Icons.delete_outline_rounded, "Delete", () {
                    _deleteProject(context, project);
                  }, isAllowed: permissions.hasPermission(PermissionModules.PROJECT_UPDATE, userRole: user?.systemRole)),
                ],
              ),
            ),

            const Divider(height: 16, thickness: 0.5, indent: 16, endIndent: 16),

            // Footer: Creator & Updater Details
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Created by: ${project.createdBy ?? 'Admin'}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                      Text(
                        createdStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[750],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Updated by: ${project.updatedBy ?? project.createdBy ?? 'Admin'}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                      Text(
                        updatedStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[750],
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
    );
  }

  Widget _buildReferenceBadge(String label, {required bool isStatus}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color textColor;
    Color bgColor;
    
    if (isStatus) {
      final s = label.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
      Color color = Colors.grey;
      if (s == 'active') {
        color = Colors.green;
      } else if (s == 'pre launch' || s == 'pre-launch') {
        color = Colors.blue;
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
      bgColor = color.withValues(alpha: 0.12);
    } else {
      // Category: purple-blue shade like in mockup
      textColor = isDark ? Colors.indigoAccent : const Color(0xFF5C6BC0);
      bgColor = isDark ? Colors.indigoAccent.withValues(alpha: 0.12) : const Color(0xFFE8EAF6);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionIconButton(IconData icon, String tooltip, VoidCallback onTap, {bool isAllowed = true}) {
    if (!isAllowed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
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
