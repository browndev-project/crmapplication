import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../core/utils/date_utils.dart';
import '../../core/constants/permission_constants.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/property_create_dialog.dart';
import '../widgets/project_edit_dialog.dart';
import '../widgets/property_bulk_update_dialog.dart';
import './property_detail_screen.dart';
import './public_view_screen.dart';

import '../widgets/access_denied_widget.dart';
import '../widgets/property_filters_bottom_sheet.dart';
import '../widgets/project_quick_view_sheet.dart';
import '../widgets/property_share_dialog.dart';
import 'all_properties_screen.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  final Set<String> _selectedPropertyIds = {};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectPropertiesProvider(widget.project.id).notifier).fetchProjectProperties(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(projectPropertiesProvider(widget.project.id).notifier).loadMoreProperties();
    }
  }

  void togglePropertySelection(String propertyId) {
    setState(() {
      if (_selectedPropertyIds.contains(propertyId)) {
        _selectedPropertyIds.remove(propertyId);
      } else {
        _selectedPropertyIds.add(propertyId);
      }
    });
  }

  Color getLetterBgColor(String letter, bool isDark) {
    if (letter.isEmpty) return Colors.blue.withValues(alpha: isDark ? 0.15 : 0.08);
    final code = letter.codeUnitAt(0);
    final list = [
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.blue,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];
    final color = list[code % list.length];
    return color.withValues(alpha: isDark ? 0.15 : 0.08);
  }

  Color getLetterTextColor(String letter) {
    if (letter.isEmpty) return Colors.blue;
    final code = letter.codeUnitAt(0);
    final list = [
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.blue,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];
    return list[code % list.length];
  }

  String formatPrice(double price) {
    if (price >= 10000000) {
      return "₹${(price / 10000000).toStringAsFixed(2)} Cr";
    } else if (price >= 100000) {
      return "₹${(price / 100000).toStringAsFixed(2)} L";
    } else {
      return "₹${NumberFormat('#,##,###').format(price)}";
    }
  }

  String getPricePerSqft(Property prop) {
    if (prop.area != null && prop.area!.value > 0) {
      final rate = prop.price / prop.area!.value;
      return "₹${NumberFormat('#,##,###').format(rate.round())} / ${prop.area!.unit}";
    }
    return "";
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 0.5,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildPropertyStatColumn({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          SizedBox(
            width: 65,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPropertyStatusColor(String status) {
    final s = status.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
    if (s == 'available' || s == 'active') {
      return Colors.green;
    } else if (s == 'blocked') {
      return const Color(0xFFC2410C);
    } else if (s == 'ready to move') {
      return Colors.teal;
    } else if (s == 'token received' || s == 'token') {
      return Colors.blue;
    } else if (s == 'on hold' || s == 'under construction' || s == 'upcoming') {
      return Colors.orange;
    }
    return Colors.grey;
  }

  Widget _buildTitleStatusBadge(String status) {
    final s = status.toLowerCase();
    final isActive = s == 'available' || s == 'active';
    final label = isActive ? 'Active' : Property.getDisplayLabel(status);
    final color = isActive ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRightStatusCardCompact(String status, bool isDark) {
    final s = status.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
    Color color = Colors.grey;
    String label = Property.getDisplayLabel(status);

    if (s == 'available' || s == 'active') {
      color = Colors.green;
    } else if (s == 'under construction' || s == 'upcoming' || s == 'on hold') {
      color = Colors.orange;
    } else if (s == 'ready to move') {
      color = Colors.teal;
    } else if (s == 'blocked') {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPropertyFiltersButton(BuildContext context, ProjectPropertiesState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int activeFiltersCount = 0;
    if (state.status != 'All Properties') activeFiltersCount++;
    if (state.category != 'All Categories') activeFiltersCount++;
    if (state.bedrooms != null) activeFiltersCount++;
    if (state.facing != 'All Facings') activeFiltersCount++;
    if (state.areaUnit != 'sqft') activeFiltersCount++;
    if (state.minArea != null || state.maxArea != null) activeFiltersCount++;
    if (state.minPrice != null || state.maxPrice != null) activeFiltersCount++;
    if (state.sort != 'updated_desc') activeFiltersCount++;

    final hasActiveFilters = activeFiltersCount > 0;

    return OutlinedButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PropertyFiltersBottomSheet(projectId: widget.project.id),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
        sectionName: "Project Details",
        showAppBar: true,
      );
    }

    final propertiesState = ref.watch(projectPropertiesProvider(widget.project.id));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredProperties = propertiesState.properties;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: GlobalAppBar(
        title: widget.project.name,
        showBackButton: true,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Breadcrumbs + Project Header Row + Action Buttons
          SliverToBoxAdapter(
            child: Container(
              color: theme.cardColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Breadcrumbs: Projects / Project Name
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          "Projects",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        "  /  ",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      Expanded(
                        child: Text(
                          widget.project.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. Title
                  Text(
                    widget.project.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // 3. Action Buttons Row (Edit, Add, Refresh)
                  Row(
                    children: [
                      if (permissions.hasPermission(PermissionModules.PROJECT_UPDATE, userRole: user?.systemRole))
                        _buildCompactActionButton(Icons.edit_outlined, () {
                          showDialog(context: context, builder: (_) => ProjectEditDialog(project: widget.project));
                        }, isDark: isDark),
                      if (permissions.hasPermission(PermissionModules.PROPERTY_CREATE, userRole: user?.systemRole)) ...[
                        const SizedBox(width: 8),
                        _buildCompactActionButton(Icons.add, () {
                          showDialog(context: context, builder: (context) => PropertyCreateDialog(projectId: widget.project.id));
                        }, isDark: isDark),
                      ],
                      const SizedBox(width: 8),
                      _buildCompactActionButton(Icons.refresh_rounded, () {
                        ref.read(projectPropertiesProvider(widget.project.id).notifier).fetchProjectProperties(isRefresh: true);
                      }, isDark: isDark),
                      const Spacer(),
                      // Reset Button in Header
                      if (propertiesState.status != 'All Properties' ||
                          propertiesState.category != 'All Categories' ||
                          propertiesState.bedrooms != null ||
                          propertiesState.facing != 'All Facings' ||
                          propertiesState.areaUnit != 'sqft' ||
                          propertiesState.minArea != null ||
                          propertiesState.maxArea != null ||
                          propertiesState.minPrice != null ||
                          propertiesState.maxPrice != null ||
                          propertiesState.sort != 'updated_desc' ||
                          propertiesState.direction != 'All Directions' ||
                          propertiesState.searchQuery.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            ref.read(projectPropertiesProvider(widget.project.id).notifier).resetFilters();
                            _searchController.clear();
                          },
                          icon: const Icon(Icons.filter_alt_off_outlined, size: 16, color: Colors.red),
                          label: const Text("Reset", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 4. Action buttons row: View Project Details + View All Properties
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => ProjectQuickViewSheet(project: widget.project),
                            );
                          },
                          icon: const Icon(Icons.info_outline_rounded, size: 16),
                          label: const Text("Project Details", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AllPropertiesScreen(projectId: widget.project.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.home_work_outlined, size: 16),
                          label: const Text("View Properties", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                              ref.read(projectPropertiesProvider(widget.project.id).notifier).setSearchQuery(val);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search properties by unit name...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.primaryColor),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPropertyFiltersButton(context, propertiesState),
                    ],
                  ),
                  if (filteredProperties.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildSelectionBar(filteredProperties),
                  ],
                ],
              ),
            ),
          ),

          // Properties List
          propertiesState.isLoading && filteredProperties.isEmpty
              ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())))
              : propertiesState.error != null && filteredProperties.isEmpty
                  ? SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Error: ${propertiesState.error}'))))
                  : filteredProperties.isEmpty
                      ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No properties found matching filters'))))
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildPropertyCard(filteredProperties[index], isDark),
                              childCount: filteredProperties.length,
                            ),
                          ),
                        ),
          if (propertiesState.isLoading && filteredProperties.isNotEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)), // Bottom spacing
        ],
      ),
      floatingActionButton: _selectedPropertyIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => PropertyBulkUpdateDialog(
                    projectId: widget.project.id,
                    propertyIds: _selectedPropertyIds.toList(),
                  ),
                ).then((_) {
                  setState(() {
                    _selectedPropertyIds.clear();
                  });
                });
              },
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text("Bulk Update"),
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              elevation: 2,
            )
          : null,
    );
  }

  Widget _buildPropertyCard(Property prop, bool isDark) {
    final theme = Theme.of(context);
    final refPermissions = ref.read(permissionsProvider);
    final loginUser = ref.read(loginProvider).user;
    
    final statusColor = _getPropertyStatusColor(prop.status);
    final projectLetter = prop.project?.name.isNotEmpty == true ? prop.project!.name[0].toUpperCase() : 'P';
    
    final projectAddress = prop.project?.location != null
        ? [
            if (prop.project!.location!.city.isNotEmpty) prop.project!.location!.city,
            if (prop.project!.location!.state.isNotEmpty) prop.project!.location!.state,
          ].join(', ')
        : (prop.location != null
            ? [
                if (prop.location!.city.isNotEmpty) prop.location!.city,
                if (prop.location!.state.isNotEmpty) prop.location!.state,
              ].join(', ')
            : 'Location not added');

    final String projectUrlId = prop.project?.id ?? prop.projectId;
    final isSelected = _selectedPropertyIds.contains(prop.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent border
              Container(
                width: 5,
                color: statusColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Separate top row for checkbox and menu button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: refPermissions.canUpdateProperty(
                                prop,
                                userRole: loginUser?.systemRole,
                                userName: loginUser?.name,
                              ) ? (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPropertyIds.add(prop.id);
                                  } else {
                                    _selectedPropertyIds.remove(prop.id);
                                  }
                                });
                              } : null,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (value) {
                              if (value == 'view') {
                                PublicViewScreen.launchPublicView(context, ref, property: prop);
                              } else if (value == 'share') {
                                showDialog(
                                  context: context,
                                  builder: (context) => PropertyShareDialog(property: prop),
                                );
                              } else if (value == 'edit') {
                                showDialog(
                                  context: context,
                                  builder: (_) => PropertyCreateDialog(projectId: projectUrlId, property: prop),
                                );
                              } else if (value == 'delete') {
                                _deleteProperty(context, prop);
                              }
                            },
                            itemBuilder: (context) => [
                              if (refPermissions.can(PermissionModules.PROPERTY, permission: PermissionModules.PROPERTY_VIEW, userRole: loginUser?.systemRole))
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.launch_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text("Public View"),
                                    ],
                                  ),
                                ),
                              if (refPermissions.hasPermission(PermissionModules.PROPERTY_VIEW, userRole: loginUser?.systemRole))
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text("Share"),
                                    ],
                                  ),
                                ),
                              if (refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name))
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text("Edit"),
                                    ],
                                  ),
                                ),
                              if (refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name))
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text("Delete", style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Column 1: Left Branding Column (Price & Sqft at bottom)
                          SizedBox(
                            width: 120,
                            child: Column(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: getLetterBgColor(projectLetter, isDark),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    projectLetter,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: getLetterTextColor(projectLetter),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (prop.project?.name ?? 'Standalone').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  projectAddress,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                _buildCategoryBadge(prop.category),
                                const SizedBox(height: 12),
                                // Price & Sqft valuation inside Left Column
                                Text(
                                  "Price",
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  formatPrice(prop.price),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (prop.area != null && prop.area!.value > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    getPricePerSqft(prop),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Column 2: Middle Details Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Statuses row at the top of the middle section
                                Row(
                                  children: [
                                    _buildTitleStatusBadge(prop.status),
                                    const SizedBox(width: 6),
                                    _buildRightStatusCardCompact(prop.status, isDark),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Property name below the status row
                                Text(
                                  prop.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                // Details rows
                                _buildDetailRow(Icons.business_center_outlined, "Project", prop.project?.name ?? 'Standalone', isDark),
                                _buildDetailRow(Icons.filter_list, "Type", prop.propertyTypeLabel, isDark),
                                _buildDetailRow(Icons.dashboard_outlined, "Built Up", "${prop.area?.value.toInt() ?? 0} ${Property.getDisplayLabel(prop.area?.unit ?? 'sqft')}", isDark),
                                _buildDetailRow(Icons.explore_outlined, "Facing", prop.facing ?? 'N/A', isDark),
                                _buildDetailRow(Icons.layers_outlined, "Furnishing", prop.furnishingStatus, isDark),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PropertyDetailScreen(property: prop),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      const Text(
                                        "+ 8 more details",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: const Color(0xFF2563EB)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                    // Bottom Stats Row (Horizontally Scrollable)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          _buildPropertyStatColumn(
                            icon: Icons.event_available_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            value: prop.visitsSummary.scheduled.toString().padLeft(2, '0'),
                            subtitle: "Visit Scheduled",
                            isDark: isDark,
                          ),
                          _buildStatDivider(isDark),
                          _buildPropertyStatColumn(
                            icon: Icons.date_range_outlined,
                            iconColor: const Color(0xFF22C55E),
                            value: prop.visitsSummary.completed.toString().padLeft(2, '0'),
                            subtitle: "Visit Completed",
                            isDark: isDark,
                          ),
                          _buildStatDivider(isDark),
                          _buildPropertyStatColumn(
                            icon: Icons.event_busy_outlined,
                            iconColor: const Color(0xFFF97316),
                            value: prop.visitsSummary.cancelled.toString().padLeft(2, '0'),
                            subtitle: "Visit Cancelled",
                            isDark: isDark,
                          ),
                          _buildStatDivider(isDark),
                          _buildPropertyStatColumn(
                            icon: Icons.people_outline_rounded,
                            iconColor: const Color(0xFF2563EB),
                            value: prop.leadsCount.toString().padLeft(2, '0'),
                            subtitle: "Leads Assigned",
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
    );
  }

  Widget _buildCategoryBadge(String category) {
    final textColor = const Color(0xFF7B1FA2);
    final bgColor = const Color(0xFFF3E5F5);
    final borderColor = const Color(0xFFE1BEE7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        Property.getDisplayLabel(category),
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }



  Widget buildReferenceBadge(String label, {required bool isStatus}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color textColor;
    Color bgColor;
    
    if (isStatus) {
      final s = label.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
      Color color = Colors.grey;
      if (s == 'available' || s == 'active') {
        color = Colors.green;
      } else if (s == 'booked' || s == 'pre launch' || s == 'pre-launch') {
        color = Colors.blue;
      } else if (s == 'under construction' || s == 'on hold') {
        color = Colors.orange;
      } else if (s == 'ready to move') {
        color = Colors.teal;
      } else if (s == 'sold' || s == 'sold out') {
        color = Colors.purple;
      } else if (s == 'token received' || s == 'token') {
        color = Colors.amber;
      } else if (s == 'blocked') {
        color = Colors.red;
      } else if (s == 'rented') {
        color = Colors.indigo;
      } else if (s == 'notice period') {
        color = Colors.deepOrange;
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
          Property.getDisplayLabel(label).toUpperCase(),
          style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _deleteProperty(BuildContext context, Property prop) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Property"),
        content: Text("Are you sure you want to delete property '${prop.name}'? This action cannot be undone."),
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
        final success = await ref.read(projectPropertiesProvider(widget.project.id).notifier).deleteProperty(prop.id);
        if (success && mounted) {
           scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Property deleted successfully")));
        } else if (mounted) {
           scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Failed to delete property")));
        }
      } catch (e) {
        if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget buildPropertyMetadataItem(String label, String user, String date, bool isDark) {
    DateTime? dt;
    dt = DateTimeUtils.parseSafe(date);

    final dateStr = dt != null ? DateFormat('dd MMM yyyy').format(dt) : date;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
        const SizedBox(height: 1),
        Text(user, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        Text(dateStr, style: TextStyle(fontSize: 7, color: Colors.grey[400])),
      ],
    );
  }

  Widget buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w500),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCompactActionButton(IconData icon, VoidCallback onTap, {bool isDark = false, Color? iconColor, String? label}) {
   Theme.of(context);
    final btn = Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: iconColor ?? (isDark ? Colors.white70 : Colors.black54)),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        tooltip: label,
      ),
    );
    if (label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn,
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ],
      );
    }
    return btn;
  }

  Widget buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget buildStatItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget buildSubStatItem(String text, Color color) {
    final parts = text.split(': ');
    if (parts.length < 2) return Text(text, style: TextStyle(color: color, fontSize: 11));
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: "${parts[0]}: ", style: TextStyle(color: color.withValues(alpha: 0.6))),
          TextSpan(text: parts[1], style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget buildRowStatCompact(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
      ],
    );
  }

  Widget buildBadge(String text, Color color, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(compact ? 4 : 8)),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: compact ? 8 : 10, fontWeight: FontWeight.bold)),
    );
  }

Widget _buildSelectionBar(List<Property> filteredProperties) {
    final permissions = ref.read(permissionsProvider);
    final user = ref.read(loginProvider).user;
     Theme.of(context).brightness == Brightness.dark;
    
    // Properties that the user is allowed to update
    final eligibleProperties = filteredProperties.where((p) => permissions.canUpdateProperty(
      p, 
      userRole: user?.systemRole,
      userName: user?.name,
    )).toList();

    final allSelected = eligibleProperties.isNotEmpty && 
        eligibleProperties.every((p) => _selectedPropertyIds.contains(p.id));

    return Row(
      children: [
        const Spacer(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: allSelected,
                  tristate: eligibleProperties.isNotEmpty && 
                          eligibleProperties.any((p) => _selectedPropertyIds.contains(p.id)) && 
                          !allSelected,
                  onChanged: eligibleProperties.isEmpty ? null : (val) {
                    setState(() {
                      if (val == true) {
                        _selectedPropertyIds.addAll(eligibleProperties.map((p) => p.id));
                      } else {
                        for (var p in eligibleProperties) {
                          _selectedPropertyIds.remove(p.id);
                        }
                      }
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                allSelected ? "All selected" : "Select All",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              if (_selectedPropertyIds.isNotEmpty) const SizedBox(width: 4),
              if (_selectedPropertyIds.isNotEmpty)
                Text(
                  "${_selectedPropertyIds.length} selected",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }



  Color getPropStatusColor(String status) {
    final s = status.toLowerCase().replaceAll('_', ' ');
    if (s == 'available') return Colors.green;
    if (s == 'booked') return Colors.blue;
    if (s == 'sold') return Colors.purple;
    if (s == 'on hold') return Colors.orange;
    if (s == 'token received') return Colors.amber;
    if (s == 'blocked') return Colors.red;
    if (s == 'ready to move') return Colors.teal;
    if (s == 'rented') return Colors.indigo;
    if (s == 'notice period') return Colors.deepOrange;
    return Colors.grey;
  }
}
