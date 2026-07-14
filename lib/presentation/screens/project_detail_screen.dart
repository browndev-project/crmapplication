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
    
    final createdDt = DateTimeUtils.parseSafe(prop.createdAt);
    final createdStr = createdDt != null 
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdDt).replaceAll('AM', 'am').replaceAll('PM', 'pm') 
        : prop.createdAt;

    final updatedDt = DateTimeUtils.parseSafe(prop.updatedAt);
    final updatedStr = updatedDt != null 
        ? DateFormat('dd MMM yyyy, hh:mm a').format(updatedDt).replaceAll('AM', 'am').replaceAll('PM', 'pm') 
        : prop.updatedAt;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PropertyDetailScreen(property: prop),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Title + Checkbox
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prop.name,
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Project: ${widget.project.name}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: _selectedPropertyIds.contains(prop.id),
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
                    activeColor: theme.primaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Specs Detail line
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(text: prop.propertyType.isEmpty ? "N/A" : prop.propertyTypeLabel),
                          const TextSpan(text: "  ·  "),
                          TextSpan(text: "${prop.area?.value.toInt() ?? 0} ${prop.area?.unit ?? 'sqft'}"),
                          if (prop.bedrooms != null && prop.bedrooms! > 0) ...[
                            const TextSpan(text: "  ·  "),
                            TextSpan(text: "${prop.bedrooms} BHK"),
                          ],
                          const TextSpan(text: "  ·  "),
                          TextSpan(
                            text: prop.listingType == 'rent'
                                ? "₹${NumberFormat('#,##,###').format(prop.price)} / month"
                                : "₹${NumberFormat('#,##,###').format(prop.price)}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Badges Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildListingTypeBadge(prop.listingType),
                  _buildStatusBadge(prop.status),
                  _buildCategoryBadge(prop.category),
                  if (prop.listingType == 'rent' &&
                      prop.allowedTenants != null &&
                      prop.allowedTenants!.isNotEmpty &&
                      prop.allowedTenants != 'any')
                    _buildTenantBadge(prop.allowedTenants!),
                ],
              ),
              const SizedBox(height: 12),

              // Location Pin + Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (prop.location?.address1.isNotEmpty == true) prop.location!.address1,
                        if (prop.location?.address2.isNotEmpty == true) prop.location!.address2,
                        if (prop.location?.city.isNotEmpty == true) prop.location!.city,
                        if (prop.location?.state.isNotEmpty == true) prop.location!.state,
                        if (prop.location?.pincode != null && prop.location!.pincode!.isNotEmpty) prop.location!.pincode,
                        if (prop.location?.country.isNotEmpty == true) prop.location!.country,
                      ].join(', '),
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
              const SizedBox(height: 12),

              // Dotted/Light Divider
              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? Colors.white10 : Colors.grey[300],
              ),
              const SizedBox(height: 12),

              // Owner Row: Icon + Name, Phone Icon + Number
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    prop.ownerName ?? 'N/A',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.phone_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    prop.ownerNumber ?? 'N/A',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Divider
              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? Colors.white10 : Colors.grey[300],
              ),
              const SizedBox(height: 8),

              // Left-aligned Action Icons Row
              Row(
                children: [
                  _buildActionIconButton(Icons.launch_outlined, "Public View", () {
                    PublicViewScreen.launchPublicView(context, ref, property: prop);
                  }, isAllowed: refPermissions.can(PermissionModules.PROPERTY, permission: PermissionModules.PROPERTY_VIEW, userRole: loginUser?.systemRole)),
                  _buildActionIconButton(Icons.share_outlined, "Share", () {
                    showDialog(
                      context: context,
                      builder: (context) => PropertyShareDialog(property: prop),
                    );
                  }, isAllowed: refPermissions.hasPermission(PermissionModules.PROPERTY_VIEW, userRole: loginUser?.systemRole)),
                  _buildActionIconButton(Icons.edit_outlined, "Edit", () {
                    showDialog(
                      context: context,
                      builder: (_) => PropertyCreateDialog(projectId: widget.project.id, property: prop),
                    );
                  }, isAllowed: refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name)),
                  _buildActionIconButton(Icons.delete_outline_rounded, "Delete", () {
                    _deleteProperty(context, prop);
                  }, isAllowed: refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name)),
                ],
              ),
              const SizedBox(height: 8),

              // Divider
              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? Colors.white10 : Colors.grey[300],
              ),
              const SizedBox(height: 12),

              // Creator / Updater footer
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Created by: ${prop.createdBy ?? 'Admin'}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        createdStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Updated by: ${prop.updatedBy ?? prop.createdBy ?? 'Admin'}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        updatedStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIconButton(IconData icon, String tooltip, VoidCallback onTap, {bool isAllowed = true}) {
    if (!isAllowed) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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

  Widget _buildListingTypeBadge(String type) {
    final isRent = type == 'rent';
    final textColor = isRent ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final bgColor = isRent ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final borderColor = isRent ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2);
    final label = isRent ? 'RENT' : 'SELL';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
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
      color = Colors.cyan;
    } else if (s == 'blocked') {
      color = Colors.red;
    } else if (s == 'rented') {
      color = Colors.indigo;
    } else if (s == 'notice period') {
      color = Colors.deepOrange;
    }

    final textColor = color;
    final bgColor = color.withValues(alpha: 0.08);
    final borderColor = color.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        Property.getDisplayLabel(status),
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
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

  Widget _buildTenantBadge(String tenants) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        "Tenants: ${Property.getDisplayLabel(tenants)}",
        style: const TextStyle(
          color: Color(0xFF616161),
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
