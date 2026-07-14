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
import '../widgets/property_bulk_update_dialog.dart';
import './property_detail_screen.dart';
import './public_view_screen.dart';
import '../widgets/access_denied_widget.dart';
import '../widgets/property_filters_bottom_sheet.dart';
import '../widgets/property_share_dialog.dart';
import '../widgets/floating_dock_nav_bar.dart';

class AllPropertiesScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const AllPropertiesScreen({super.key, this.projectId});

  @override
  ConsumerState<AllPropertiesScreen> createState() => _AllPropertiesScreenState();
}

class _AllPropertiesScreenState extends ConsumerState<AllPropertiesScreen> {
  final Set<String> _selectedPropertyIds = {};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _projectFilterController = TextEditingController();
  Timer? _searchDebounce;
  bool _isCardView = true;
  Set<String> _visibleColumns = {
    'Project',
    'Type',
    'Listing Type',
    'Category',
    'BHK',
    'Built Up',
    'Facing',
    'Direction',
    'Area',
    'Price',
    'Basic',
    'Inventory Date',
    'Allowed Tenants',
    'Location',
    'Owner Details',
    'Amenities',
    'Status',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.projectId != null) {
        ref.read(allPropertiesProvider.notifier).setProjectFilter(widget.projectId);
      } else {
        ref.read(allPropertiesProvider.notifier).resetFilters();
      }
      final projects = ref.read(propertyProvider).projects;
      if (projects.isEmpty) {
        ref.read(propertyProvider.notifier).fetchProjects(isRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _projectFilterController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(allPropertiesProvider.notifier).loadMoreProperties();
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
    if (state.minArea != null || state.maxArea != null) activeFiltersCount++;
    if (state.minPrice != null || state.maxPrice != null) activeFiltersCount++;
    if (state.sort != 'updated_desc') activeFiltersCount++;
    if (state.projectFilter != null && state.projectFilter!.isNotEmpty) activeFiltersCount++;

    final hasActiveFilters = activeFiltersCount > 0;

    return OutlinedButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const PropertyFiltersBottomSheet(projectId: ""),
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

  Widget _buildColumnsButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final columns = [
      'Project',
      'Type',
      'Listing Type',
      'Category',
      'BHK',
      'Built Up',
      'Facing',
      'Direction',
      'Area',
      'Price',
      'Basic',
      'Inventory Date',
      'Allowed Tenants',
      'Location',
      'Owner Details',
      'Amenities',
      'Status',
    ];

    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.cardColor,
      elevation: 8,
      onSelected: (value) {
        if (value == 'reset') {
          setState(() {
            _visibleColumns = Set.from(columns);
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
          value: 'Name',
          child: CheckboxListTile(
            value: true,
            onChanged: null,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        ...columns.map((col) => PopupMenuItem<String>(
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
        )),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'reset',
          child: const Text('Reset to default', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent)),
        ),
      ],
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

    final propertiesState = ref.watch(allPropertiesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredProperties = propertiesState.properties.where((prop) {
      // 1. Status Filter
      if (propertiesState.status != 'All Status' && propertiesState.status != 'all_properties') {
        final selectedStatuses = propertiesState.status.toLowerCase().split(',').map((e) => e.trim()).toSet();
        if (!selectedStatuses.contains(prop.status.toLowerCase())) {
          return false;
        }
      }
      // 2. Category Filter
      if (propertiesState.category != 'All Categories' && propertiesState.category != 'all_categories') {
        final selectedCategories = propertiesState.category.toLowerCase().split(',').map((e) => e.trim()).toSet();
        if (!selectedCategories.contains(prop.category.toLowerCase())) {
          return false;
        }
      }
      // 3. Facing Filter
      if (propertiesState.facing != 'All Facings' && propertiesState.facing != 'all_facings') {
        final selectedFacings = propertiesState.facing.toLowerCase().split(',').map((e) => e.trim()).toSet();
        if (prop.facing == null || !selectedFacings.contains(prop.facing!.toLowerCase())) {
          return false;
        }
      }
      // 4. Direction Filter
      if (propertiesState.direction != 'All Directions' && propertiesState.direction != 'all_directions' && propertiesState.direction.isNotEmpty) {
        final selectedDirections = propertiesState.direction.toLowerCase().split(',').map((e) => e.trim()).toSet();
        if (prop.direction == null || !selectedDirections.contains(prop.direction!.toLowerCase())) {
          return false;
        }
      }
      // 5. Allowed Tenants
      if (propertiesState.allowedTenants != 'any') {
        final selectedTenants = propertiesState.allowedTenants.toLowerCase().split(',').map((e) => e.trim()).toSet();
        if (prop.allowedTenants == null || !selectedTenants.contains(prop.allowedTenants!.toLowerCase())) {
          return false;
        }
      }
      // 6. City
      if (propertiesState.city != 'all_cities' && propertiesState.city.isNotEmpty) {
        final selectedCities = propertiesState.city.toLowerCase().split(',').map((e) => e.trim()).toSet();
        if (prop.location?.city == null || !selectedCities.contains(prop.location!.city.toLowerCase())) {
          return false;
        }
      }
      // 7. Amenities
      if (propertiesState.amenities.isNotEmpty) {
        final selectedAmenities = propertiesState.amenities.toLowerCase().split(',').map((e) => e.trim()).toList();
        for (final amenity in selectedAmenities) {
          if (!prop.amenities.map((e) => e.toLowerCase()).contains(amenity)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: GlobalAppBar(title: 'Properties', showBackButton: widget.projectId != null),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
            boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Title & Subtitle
                Text(
                  'All Properties',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage all Real Estate Property Units',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                // Row 2: Search & Add button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                            ref.read(allPropertiesProvider.notifier).setSearchQuery(val);
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search properties by unit name...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    if (permissions.hasPermission(PermissionModules.PROPERTY_CREATE, userRole: user?.systemRole))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          icon: Icon(Icons.add_box_rounded, color: isDark ? Colors.white : Colors.black, size: 28),
                          onPressed: () {
                            showDialog(context: context, builder: (context) => const PropertyCreateDialog(projectId: ''));
                          },
                          tooltip: 'Add Property',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 3: Grid toggle + Filters + Refresh + Reset
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildViewToggleButtons(isDark),
                      const SizedBox(width: 8),
                      _buildPropertyFiltersButton(context, propertiesState),
                      if (!_isCardView) ...[
                        const SizedBox(width: 8),
                        _buildColumnsButton(context),
                      ],
                      const SizedBox(width: 12),
                      _buildHeaderActionButton(
                        propertiesState.isLoading ? Icons.hourglass_empty : Icons.refresh_rounded,
                        'Refresh',
                        () {
                          if (!propertiesState.isLoading) {
                            setState(() {
                              _selectedPropertyIds.clear();
                            });
                            ref.read(allPropertiesProvider.notifier).fetchProjectProperties(isRefresh: true);
                          }
                        },
                        isDark: isDark,
                        isLoading: propertiesState.isLoading,
                      ),
                      const SizedBox(width: 6),
                      _buildHeaderActionButton(
                        Icons.filter_alt_off_outlined,
                        'Reset',
                        () {
                          ref.read(allPropertiesProvider.notifier).resetFilters();
                          _searchController.clear();
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Row 4: Project Filter Dropdown
                Consumer(
                  builder: (context, ref, _) {
                    final projectState = ref.watch(propertyProvider);
                    final projects = projectState.projects;
                    final currentFilter = propertiesState.projectFilter;

                    return DropdownButtonFormField<String?>(
                      initialValue: currentFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Project Filter',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      dropdownColor: theme.cardColor,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Projects'),
                        ),
                        ...projects.map((p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (val) {
                        ref.read(allPropertiesProvider.notifier).setProjectFilter(val);
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Selection Bar
          if (filteredProperties.isNotEmpty)
            _buildSelectionBar(filteredProperties),

          // Property List
          Expanded(
            child: propertiesState.isLoading && filteredProperties.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : propertiesState.error != null && filteredProperties.isEmpty
                    ? Center(child: Text('Error: ${propertiesState.error}'))
                    : filteredProperties.isEmpty
                        ? const Center(child: Text('No properties found'))
                        : !_isCardView
                            ? Builder(
                                builder: (context) {
                                  final eligibleProperties = filteredProperties.where((p) => permissions.canUpdateProperty(
                                    p, 
                                    userRole: user?.systemRole,
                                    userName: user?.name,
                                  )).toList();

                                  final allSelected = eligibleProperties.isNotEmpty && 
                                      eligibleProperties.every((p) => _selectedPropertyIds.contains(p.id));

                                  const double nameWidth = 160;
                                  const double projectWidth = 140;
                                  const double typeWidth = 100;
                                  const double listingTypeWidth = 100;
                                  const double categoryWidth = 120;
                                  const double bhkWidth = 80;
                                  const double builtUpWidth = 100;
                                  const double facingWidth = 100;
                                  const double directionWidth = 100;
                                  const double areaWidth = 100;
                                  const double priceWidth = 120;
                                  const double basicWidth = 120;
                                  const double inventoryDateWidth = 120;
                                  const double allowedTenantsWidth = 120;
                                  const double locationWidth = 200;
                                  const double ownerDetailsWidth = 180;
                                  const double amenitiesWidth = 180;
                                  const double statusWidth = 100;
                                  const double actionsWidth = 140;

                                  double tableWidth = 12 + 20 + 12 + nameWidth + actionsWidth;
                                  if (_visibleColumns.contains('Project')) tableWidth += projectWidth;
                                  if (_visibleColumns.contains('Type')) tableWidth += typeWidth;
                                  if (_visibleColumns.contains('Listing Type')) tableWidth += listingTypeWidth;
                                  if (_visibleColumns.contains('Category')) tableWidth += categoryWidth;
                                  if (_visibleColumns.contains('BHK')) tableWidth += bhkWidth;
                                  if (_visibleColumns.contains('Built Up')) tableWidth += builtUpWidth;
                                  if (_visibleColumns.contains('Facing')) tableWidth += facingWidth;
                                  if (_visibleColumns.contains('Direction')) tableWidth += directionWidth;
                                  if (_visibleColumns.contains('Area')) tableWidth += areaWidth;
                                  if (_visibleColumns.contains('Price')) tableWidth += priceWidth;
                                  if (_visibleColumns.contains('Basic')) tableWidth += basicWidth;
                                  if (_visibleColumns.contains('Inventory Date')) tableWidth += inventoryDateWidth;
                                  if (_visibleColumns.contains('Allowed Tenants')) tableWidth += allowedTenantsWidth;
                                  if (_visibleColumns.contains('Location')) tableWidth += locationWidth;
                                  if (_visibleColumns.contains('Owner Details')) tableWidth += ownerDetailsWidth;
                                  if (_visibleColumns.contains('Amenities')) tableWidth += amenitiesWidth;
                                  if (_visibleColumns.contains('Status')) tableWidth += statusWidth;

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
                                                        activeColor: theme.primaryColor,
                                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    const SizedBox(
                                                      width: nameWidth,
                                                      child: Text(
                                                        'Name',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                    if (_visibleColumns.contains('Project'))
                                                      const SizedBox(
                                                        width: projectWidth,
                                                        child: Text(
                                                          'Project',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Type'))
                                                      const SizedBox(
                                                        width: typeWidth,
                                                        child: Text(
                                                          'Type',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Listing Type'))
                                                      const SizedBox(
                                                        width: listingTypeWidth,
                                                        child: Text(
                                                          'Listing Type',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Category'))
                                                      const SizedBox(
                                                        width: categoryWidth,
                                                        child: Text(
                                                          'Category',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('BHK'))
                                                      const SizedBox(
                                                        width: bhkWidth,
                                                        child: Text(
                                                          'BHK',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Built Up'))
                                                      const SizedBox(
                                                        width: builtUpWidth,
                                                        child: Text(
                                                          'Built Up',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Facing'))
                                                      const SizedBox(
                                                        width: facingWidth,
                                                        child: Text(
                                                          'Facing',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Direction'))
                                                      const SizedBox(
                                                        width: directionWidth,
                                                        child: Text(
                                                          'Direction',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Area'))
                                                      const SizedBox(
                                                        width: areaWidth,
                                                        child: Text(
                                                          'Area',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Price'))
                                                      const SizedBox(
                                                        width: priceWidth,
                                                        child: Text(
                                                          'Price',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Basic'))
                                                      const SizedBox(
                                                        width: basicWidth,
                                                        child: Text(
                                                          'Basic',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Inventory Date'))
                                                      const SizedBox(
                                                        width: inventoryDateWidth,
                                                        child: Text(
                                                          'Inventory Date',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Allowed Tenants'))
                                                      const SizedBox(
                                                        width: allowedTenantsWidth,
                                                        child: Text(
                                                          'Allowed Tenants',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Location'))
                                                      const SizedBox(
                                                        width: locationWidth,
                                                        child: Text(
                                                          'Location',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Owner Details'))
                                                      const SizedBox(
                                                        width: ownerDetailsWidth,
                                                        child: Text(
                                                          'Owner Details',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Amenities'))
                                                      const SizedBox(
                                                        width: amenitiesWidth,
                                                        child: Text(
                                                          'Amenities',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    if (_visibleColumns.contains('Status'))
                                                      const SizedBox(
                                                        width: statusWidth,
                                                        child: Text(
                                                          'Status',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    const SizedBox(
                                                      width: actionsWidth,
                                                      child: Text(
                                                        'Actions',
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
                                                  padding: EdgeInsets.only(bottom: _selectedPropertyIds.isNotEmpty ? 100 : 0),
                                                  controller: _scrollController,
                                                  itemCount: filteredProperties.length + (propertiesState.isLoading ? 1 : 0),
                                                  separatorBuilder: (context, index) => Divider(
                                                    height: 1, 
                                                    color: theme.dividerColor.withValues(alpha: 0.15)
                                                  ),
                                                  itemBuilder: (context, index) {
                                                    if (index == filteredProperties.length) {
                                                      return const Center(
                                                        child: Padding(
                                                          padding: EdgeInsets.all(16.0),
                                                          child: CircularProgressIndicator(),
                                                        ),
                                                      );
                                                    }
                                                    
                                                    final prop = filteredProperties[index];
                                                    final isSelected = _selectedPropertyIds.contains(prop.id);
                                                    
                                                    final projectName = (prop.project?.name != null && prop.project!.name.isNotEmpty)
                                                        ? prop.project!.name
                                                        : "Standalone";
                                                        
                                                    final propType = prop.propertyType.isEmpty ? "N/A" : prop.propertyTypeLabel;

                                                    return Container(
                                                      color: isSelected 
                                                          ? theme.primaryColor.withValues(alpha: 0.03)
                                                          : (index % 2 == 1 && !isDark ? Colors.grey[50]?.withValues(alpha: 0.5) : null),
                                                      child: Row(
                                                        children: [
                                                          // Checkbox
                                                          Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                            child: SizedBox(
                                                              height: 20,
                                                              width: 20,
                                                              child: Checkbox(
                                                                value: isSelected,
                                                                activeColor: theme.primaryColor,
                                                                onChanged: permissions.canUpdateProperty(
                                                                  prop, 
                                                                  userRole: user?.systemRole,
                                                                  userName: user?.name,
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
                                                          ),
                                                          const SizedBox(width: 12),
                                                          // Columns content
                                                          GestureDetector(
                                                            onTap: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (context) => PropertyDetailScreen(property: prop),
                                                                ),
                                                              );
                                                            },
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                                              child: Row(
                                                                children: [
                                                                  SizedBox(
                                                                    width: nameWidth,
                                                                    child: Text(
                                                                      prop.name,
                                                                      style: TextStyle(
                                                                        fontWeight: FontWeight.bold,
                                                                        fontSize: 13,
                                                                        color: isDark ? Colors.white : Colors.black87,
                                                                      ),
                                                                      maxLines: 2,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                  if (_visibleColumns.contains('Project'))
                                                                    SizedBox(
                                                                      width: projectWidth,
                                                                      child: Text(
                                                                        projectName,
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 2,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Type'))
                                                                    SizedBox(
                                                                      width: typeWidth,
                                                                      child: Text(
                                                                        propType,
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Listing Type'))
                                                                    SizedBox(
                                                                      width: listingTypeWidth,
                                                                      child: Text(
                                                                        prop.listingTypeLabel.toUpperCase(),
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Category'))
                                                                    SizedBox(
                                                                      width: categoryWidth,
                                                                      child: Text(
                                                                        prop.categoryLabel,
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('BHK'))
                                                                    SizedBox(
                                                                      width: bhkWidth,
                                                                      child: Text(
                                                                        prop.builtUp ? "Built Up" : (prop.bedrooms != null && prop.bedrooms! > 0 ? "${prop.bedrooms} BHK" : "-"),
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Built Up'))
                                                                    SizedBox(
                                                                      width: builtUpWidth,
                                                                      child: Text(
                                                                        prop.builtUp ? "Yes" : "No",
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Facing'))
                                                                    SizedBox(
                                                                      width: facingWidth,
                                                                      child: Text(
                                                                        prop.facingLabel.isNotEmpty ? prop.facingLabel : "-",
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Direction'))
                                                                    SizedBox(
                                                                      width: directionWidth,
                                                                      child: Text(
                                                                        prop.directionLabel.isNotEmpty ? prop.directionLabel : "-",
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Area'))
                                                                    SizedBox(
                                                                      width: areaWidth,
                                                                      child: Text(
                                                                        prop.area != null ? "${prop.area!.value.toInt()} ${prop.area!.unit}" : "-",
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Price'))
                                                                    SizedBox(
                                                                      width: priceWidth,
                                                                      child: Text(
                                                                        prop.listingType.toLowerCase().contains('rent')
                                                                            ? "₹${NumberFormat('#,##,###').format(prop.price)}/mo"
                                                                            : "₹${NumberFormat('#,##,###').format(prop.price)}",
                                                                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Basic'))
                                                                    SizedBox(
                                                                      width: basicWidth,
                                                                      child: Text(
                                                                        prop.basic != null && prop.basic!.isNotEmpty ? prop.basic! : "-",
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Inventory Date'))
                                                                    SizedBox(
                                                                      width: inventoryDateWidth,
                                                                      child: Text(
                                                                        prop.inventoryDate != null
                                                                            ? DateTimeUtils.formatSafe(prop.inventoryDate, format: 'dd MMM yyyy')
                                                                            : "-",
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Allowed Tenants'))
                                                                    SizedBox(
                                                                      width: allowedTenantsWidth,
                                                                      child: Text(
                                                                        prop.allowedTenantsLabel.isNotEmpty ? prop.allowedTenantsLabel : "-",
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 2,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Location'))
                                                                    SizedBox(
                                                                      width: locationWidth,
                                                                      child: Text(
                                                                        [if (prop.location?.address1.isNotEmpty == true) prop.location!.address1, if (prop.location?.city.isNotEmpty == true) prop.location!.city].join(', '),
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 2,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Owner Details'))
                                                                    SizedBox(
                                                                      width: ownerDetailsWidth,
                                                                      child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        children: [
                                                                          Text(prop.ownerName ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                                          Text(prop.ownerNumber ?? '-', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Amenities'))
                                                                    SizedBox(
                                                                      width: amenitiesWidth,
                                                                      child: Text(
                                                                        prop.amenities.isEmpty ? "-" : prop.amenities.join(', '),
                                                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[750], fontWeight: FontWeight.w500),
                                                                        maxLines: 2,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  if (_visibleColumns.contains('Status'))
                                                                    SizedBox(
                                                                      width: statusWidth,
                                                                      child: Align(
                                                                        alignment: Alignment.centerLeft,
                                                                        child: _buildStatusBadge(prop.status),
                                                                      ),
                                                                    ),
                                                                  // Actions
                                                                  SizedBox(
                                                                    width: actionsWidth,
                                                                    child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        _buildActionIconButton(Icons.launch_outlined, "Public View", () {
                                                                          PublicViewScreen.launchPublicView(context, ref, property: prop);
                                                                        }, isAllowed: permissions.can(PermissionModules.PROPERTY, permission: PermissionModules.PROPERTY_VIEW, userRole: user?.systemRole)),
                                                                        _buildActionIconButton(Icons.share_outlined, "Share", () {
                                                                          showDialog(
                                                                            context: context,
                                                                            builder: (context) => PropertyShareDialog(property: prop),
                                                                          );
                                                                        }, isAllowed: permissions.hasPermission(PermissionModules.PROPERTY_VIEW, userRole: user?.systemRole)),
                                                                        _buildActionIconButton(Icons.edit_outlined, "Edit", () {
                                                                          showDialog(
                                                                            context: context,
                                                                            builder: (_) => PropertyCreateDialog(projectId: widget.projectId ?? '', property: prop),
                                                                          );
                                                                        }, isAllowed: permissions.canUpdateProperty(prop, userRole: user?.systemRole, userName: user?.name)),
                                                                        _buildActionIconButton(Icons.delete_outline_rounded, "Delete", () {
                                                                          _deleteProperty(context, prop);
                                                                        }, isAllowed: permissions.canUpdateProperty(prop, userRole: user?.systemRole, userName: user?.name)),
                                                                      ],
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
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(16, 16, 16, _selectedPropertyIds.isNotEmpty ? 100 : 16),
                                itemCount: filteredProperties.length + (propertiesState.isLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == filteredProperties.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  return _buildPropertyCard(filteredProperties[index], isDark);
                                },
                              ),
          ),
        ],
      ),
      floatingActionButton: _selectedPropertyIds.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(bottom: ref.watch(dockVisibilityProvider) ? 80 : 0),
              child: FloatingActionButton.extended(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => PropertyBulkUpdateDialog(
                      projectId: "",
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
              ),
            )
          : null,
    );
  }

  Widget _buildHeaderActionButton(IconData icon, String label, VoidCallback onTap, {required bool isDark, bool isPrimary = false, bool isLoading = false}) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading 
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading 
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.black87))
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: isDark ? Colors.white : Colors.black87,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
                          (prop.project?.name != null && prop.project!.name.isNotEmpty)
                              ? "Project: ${prop.project!.name}"
                              : "Standalone Property",
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
                          TextSpan(text: "${prop.area?.value.toInt() ?? 0} ${Property.getDisplayLabel(prop.area?.unit ?? 'sqft')}"),
                          if (prop.builtUp) ...[
                            const TextSpan(text: "  ·  "),
                            const TextSpan(text: "Built Up"),
                          ] else if (prop.bedrooms != null && prop.bedrooms! > 0) ...[
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
                  if (prop.listingType.toLowerCase().contains('rent') &&
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

              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? Colors.white10 : Colors.grey[300],
              ),
              const SizedBox(height: 12),

              // Owner Row
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

              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? Colors.white10 : Colors.grey[300],
              ),
              const SizedBox(height: 8),

              // Actions Row
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
                      builder: (_) => PropertyCreateDialog(projectId: prop.projectId, property: prop),
                    );
                  }, isAllowed: refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name)),
                  _buildActionIconButton(Icons.delete_outline_rounded, "Delete", () {
                    _deleteProperty(context, prop);
                  }, isAllowed: refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name)),
                ],
              ),
              const SizedBox(height: 8),

              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? Colors.white10 : Colors.grey[300],
              ),
              const SizedBox(height: 12),

              // Footer
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
    } else if (s == 'booked' || s == 'pre launch' || s == 'pre-launch') {color = Colors.blue;}
    else if (s == 'under construction' || s == 'on hold') {color = Colors.orange;}
    else if (s == 'ready to move') {color = Colors.teal;}
    else if (s == 'sold' || s == 'sold out'){ color = Colors.purple;}
    else if (s == 'token received' || s == 'token'){ color = Colors.cyan;}
    else if (s == 'blocked'){ color = Colors.red;}
    else if (s == 'rented'){ color = Colors.indigo;}
    else if (s == 'notice period'){ color = Colors.deepOrange;}

    final textColor = color;
    final bgColor = color.withValues(alpha: 0.08);
    final borderColor = color.withValues(alpha:0.2);

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
        final success = await ref.read(allPropertiesProvider.notifier).deleteProperty(prop.id);
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

  Widget _buildSelectionBar(List<Property> filteredProperties) {
    final permissions = ref.read(permissionsProvider);
    final user = ref.read(loginProvider).user;
    
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
}
