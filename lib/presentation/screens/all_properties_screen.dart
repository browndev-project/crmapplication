import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
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
  bool _showScrollToTop = false;
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
    final showBtn = _scrollController.offset > 250;
    if (showBtn != _showScrollToTop) {
      setState(() {
        _showScrollToTop = showBtn;
      });
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

  Widget _buildSquareFilterButton(BuildContext context, ProjectPropertiesState state, bool isDark) {
    int activeFiltersCount = 0;
    if (state.status != 'All Properties' && state.status != 'All Status') activeFiltersCount++;
    if (state.category != 'All Categories') activeFiltersCount++;
    if (state.bedrooms != null) activeFiltersCount++;
    if (state.facing != 'All Facings') activeFiltersCount++;
    if (state.minArea != null || state.maxArea != null) activeFiltersCount++;
    if (state.minPrice != null || state.maxPrice != null) activeFiltersCount++;
    if (state.sort != 'updated_desc') activeFiltersCount++;
    if (state.projectFilter != null && state.projectFilter!.isNotEmpty) activeFiltersCount++;

    final hasActiveFilters = activeFiltersCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              size: 20,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const PropertyFiltersBottomSheet(projectId: ""),
              );
            },
            tooltip: 'Filters',
          ),
          if (hasActiveFilters)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
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

  // ignore: unused_element
  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 0.5,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
    );
  }

  // ignore: unused_element
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
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
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
                                  'Properties',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                // const SizedBox(height: 4),
                                // Text(
                                //   'Manage and track all your property listings.',
                                //   style: TextStyle(
                                //     fontSize: 13,
                                //     color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: propertiesState.isLoading
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.black87),
                                        )
                                      : Icon(Icons.refresh_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
                                  onPressed: () {
                                    if (!propertiesState.isLoading) {
                                      setState(() {
                                        _selectedPropertyIds.clear();
                                      });
                                      ref.read(allPropertiesProvider.notifier).fetchProjectProperties(isRefresh: true);
                                    }
                                  },
                                  tooltip: 'Refresh',
                                ),
                              ),
                              if (permissions.hasPermission(PermissionModules.PROPERTY_CREATE, userRole: user?.systemRole)) ...[
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => const PropertyCreateDialog(projectId: ''),
                                      );
                                    },
                                    tooltip: 'Add Property',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                                hintText: 'Search by name, project, type or location...',
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
                          const SizedBox(width: 8),
                          _buildSquareFilterButton(context, propertiesState, isDark),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildViewToggleButtons(isDark),
                          if (!_isCardView) ...[
                            const SizedBox(width: 8),
                            _buildColumnsButton(context),
                          ],
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 12),
                      // Consumer(
                      //   builder: (context, ref, _) {
                      //     final projectState = ref.watch(propertyProvider);
                      //     final projects = projectState.projects;
                      //     final currentFilter = propertiesState.projectFilter;
                      //
                      //     return DropdownButtonFormField<String?>(
                      //       initialValue: currentFilter,
                      //       isExpanded: true,
                      //       decoration: InputDecoration(
                      //         labelText: 'Project Filter',
                      //         floatingLabelBehavior: FloatingLabelBehavior.always,
                      //         isDense: true,
                      //         filled: true,
                      //         fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                      //         border: OutlineInputBorder(
                      //           borderRadius: BorderRadius.circular(12),
                      //           borderSide: BorderSide.none,
                      //         ),
                      //         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      //       ),
                      //       dropdownColor: theme.cardColor,
                      //       items: [
                      //         const DropdownMenuItem<String?>(
                      //           value: null,
                      //           child: Text('All Projects'),
                      //         ),
                      //         ...projects.map((p) => DropdownMenuItem<String?>(
                      //           value: p.id,
                      //           child: Text(p.name, overflow: TextOverflow.ellipsis),
                      //         )),
                      //       ],
                      //       onChanged: (val) {
                      //         ref.read(allPropertiesProvider.notifier).setProjectFilter(val);
                      //       },
                      //     );
                      //   },
                      // ),
                    ],
                  ),
                ),
              ),
              // Selection Bar
              if (filteredProperties.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildSelectionBar(filteredProperties),
                ),
              if (propertiesState.isLoading && filteredProperties.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (propertiesState.error != null && filteredProperties.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Text('Error: ${propertiesState.error}')),
                )
              else if (filteredProperties.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No properties found')),
                )
              else if (!_isCardView)
                SliverToBoxAdapter(
                  child: Builder(
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
                      const double actionsWidth = 180;

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
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                          ),
                                        ),
                                        if (_visibleColumns.contains('Project'))
                                          const SizedBox(
                                            width: projectWidth,
                                            child: Text('Project', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Type'))
                                          const SizedBox(
                                            width: typeWidth,
                                            child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Listing Type'))
                                          const SizedBox(
                                            width: listingTypeWidth,
                                            child: Text('Listing Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Category'))
                                          const SizedBox(
                                            width: categoryWidth,
                                            child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('BHK'))
                                          const SizedBox(
                                            width: bhkWidth,
                                            child: Text('BHK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Built Up'))
                                          const SizedBox(
                                            width: builtUpWidth,
                                            child: Text('Built Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Facing'))
                                          const SizedBox(
                                            width: facingWidth,
                                            child: Text('Facing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Direction'))
                                          const SizedBox(
                                            width: directionWidth,
                                            child: Text('Direction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Area'))
                                          const SizedBox(
                                            width: areaWidth,
                                            child: Text('Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Price'))
                                          const SizedBox(
                                            width: priceWidth,
                                            child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Basic'))
                                          const SizedBox(
                                            width: basicWidth,
                                            child: Text('Basic Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Inventory Date'))
                                          const SizedBox(
                                            width: inventoryDateWidth,
                                            child: Text('Inventory Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Allowed Tenants'))
                                          const SizedBox(
                                            width: allowedTenantsWidth,
                                            child: Text('Allowed Tenants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Location'))
                                          const SizedBox(
                                            width: locationWidth,
                                            child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Owner Details'))
                                          const SizedBox(
                                            width: ownerDetailsWidth,
                                            child: Text('Owner Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Amenities'))
                                          const SizedBox(
                                            width: amenitiesWidth,
                                            child: Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        if (_visibleColumns.contains('Status'))
                                          const SizedBox(
                                            width: statusWidth,
                                            child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                          ),
                                        const SizedBox(
                                          width: actionsWidth,
                                          child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 0.5),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredProperties.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                                    itemBuilder: (context, index) {
                                      final prop = filteredProperties[index];
                                      final isSelected = _selectedPropertyIds.contains(prop.id);
                                      final refPermissions = ref.read(permissionsProvider);
                                      final loginUser = ref.read(loginProvider).user;
                                      final projectUrlId = prop.project?.id ?? prop.projectId;
                                      return Container(
                                        color: isSelected ? theme.primaryColor.withValues(alpha: 0.05) : null,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 12),
                                            SizedBox(
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
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: nameWidth,
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (context) => PropertyDetailScreen(property: prop)),
                                                  );
                                                },
                                                child: Text(
                                                  prop.name,
                                                  style: TextStyle(
                                                    color: theme.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            if (_visibleColumns.contains('Project'))
                                              SizedBox(
                                                width: projectWidth,
                                                child: Text(prop.project?.name ?? '-', overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Type'))
                                              SizedBox(
                                                width: typeWidth,
                                                child: Text(prop.propertyTypeLabel, overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Listing Type'))
                                              SizedBox(
                                                width: listingTypeWidth,
                                                child: Text(prop.listingType.toUpperCase(), overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Category'))
                                              SizedBox(
                                                width: categoryWidth,
                                                child: Text(prop.category, overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('BHK'))
                                              SizedBox(
                                                width: bhkWidth,
                                                child: Text(prop.bedrooms != null ? "${prop.bedrooms} BHK" : '-', overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Built Up'))
                                              SizedBox(
                                                width: builtUpWidth,
                                                child: Text(prop.builtUp ? "Yes" : "No", overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Facing'))
                                              SizedBox(
                                                width: facingWidth,
                                                child: Text(prop.facing ?? '-', overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Direction'))
                                              SizedBox(
                                                width: directionWidth,
                                                child: Text(prop.direction ?? '-', overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Area'))
                                              SizedBox(
                                                width: areaWidth,
                                                child: Text(
                                                  prop.area != null ? "${prop.area!.value.toInt()} ${prop.area!.unit}" : "-",
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            if (_visibleColumns.contains('Price'))
                                              SizedBox(
                                                width: priceWidth,
                                                child: Text(formatPrice(prop.price), overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Basic'))
                                              SizedBox(
                                                width: basicWidth,
                                                child: Text(
                                                  [
                                                    if (prop.bathrooms != null) "${prop.bathrooms} Baths",
                                                  ].join(', '),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            if (_visibleColumns.contains('Inventory Date'))
                                              SizedBox(
                                                width: inventoryDateWidth,
                                                child: Text(prop.inventoryDate ?? '-', overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Allowed Tenants'))
                                              SizedBox(
                                                width: allowedTenantsWidth,
                                                child: Text(prop.allowedTenants ?? '-', overflow: TextOverflow.ellipsis),
                                              ),
                                            if (_visibleColumns.contains('Location'))
                                              SizedBox(
                                                width: locationWidth,
                                                child: Text(
                                                  [
                                                    if (prop.location?.address1.isNotEmpty == true) prop.location!.address1,
                                                    if (prop.location?.address2.isNotEmpty == true) prop.location!.address2,
                                                    if (prop.location?.city.isNotEmpty == true) prop.location!.city,
                                                  ].join(', '),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            if (_visibleColumns.contains('Owner Details'))
                                              SizedBox(
                                                width: ownerDetailsWidth,
                                                child: Text(
                                                  [
                                                    if (prop.ownerName != null && prop.ownerName!.isNotEmpty) prop.ownerName,
                                                    if (prop.ownerNumber != null && prop.ownerNumber!.isNotEmpty) prop.ownerNumber,
                                                  ].join(', '),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            if (_visibleColumns.contains('Amenities'))
                                              SizedBox(
                                                width: amenitiesWidth,
                                                child: Text(prop.amenities.join(', '), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                              ),
                                            if (_visibleColumns.contains('Status'))
                                              SizedBox(
                                                width: statusWidth,
                                                child: Text(prop.statusLabel, overflow: TextOverflow.ellipsis),
                                              ),
                                            SizedBox(
                                              width: actionsWidth,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _buildTableActionButton(
                                                    icon: Icons.edit_outlined,
                                                    onTap: refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name)
                                                        ? () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (_) => PropertyCreateDialog(projectId: projectUrlId, property: prop),
                                                            );
                                                          }
                                                        : null,
                                                    tooltip: 'Edit',
                                                    isDark: isDark,
                                                  ),
                                                  if (loginUser?.systemRole == 'company_admin') ...[
                                                    const SizedBox(width: 12),
                                                    _buildTableActionButton(
                                                      icon: Icons.delete_outline_rounded,
                                                      onTap: refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name)
                                                          ? () => _deleteProperty(context, prop)
                                                          : null,
                                                      tooltip: 'Delete',
                                                      iconColor: Colors.red,
                                                      isDark: isDark,
                                                    ),
                                                  ],
                                                  const SizedBox(width: 12),
                                                  _buildTableActionButton(
                                                    icon: Icons.share_outlined,
                                                    onTap: refPermissions.hasPermission(PermissionModules.PROPERTY_VIEW, userRole: loginUser?.systemRole)
                                                        ? () {
                                                            showDialog(context: context, builder: (context) => PropertyShareDialog(property: prop));
                                                          }
                                                        : null,
                                                    tooltip: 'Share',
                                                    isDark: isDark,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  _buildTableActionButton(
                                                    icon: Icons.public,
                                                    onTap: () {
                                                      PublicViewScreen.launchPublicView(context, ref, property: prop);
                                                    },
                                                    tooltip: 'Public View',
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildPropertyCard(filteredProperties[index], isDark);
                      },
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
              ],
            ],
          ),
          if (_showScrollToTop)
            Positioned(
              bottom: ref.watch(dockVisibilityProvider) ? 96 : 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
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
                    // Redesigned Top Row with Checkbox, Avatar, Name, Badges, Price and Menu button
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Checkbox on the left
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: SizedBox(
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
                          ),
                          const SizedBox(width: 10),

                          // 2. Project Letter Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: getLetterBgColor(projectLetter, isDark),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              projectLetter,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: getLetterTextColor(projectLetter),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 3. Title, Badges & Location Section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prop.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.home_outlined,
                                      size: 13,
                                      color: isDark ? Colors.purple[300] : const Color(0xFF7E22CE),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildCategoryBadge(prop.category),
                                    const SizedBox(width: 6),
                                    _buildRightStatusCardCompact(prop.status, isDark),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        projectAddress.isNotEmpty ? projectAddress : 'Location not added',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 4. Right Price Column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(height: 10),
                              Text(
                                formatPrice(prop.price),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                "Price",
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Redesigned specs row (2 columns with vertical divider)
                    const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Specs Column
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  _buildDetailRow(Icons.business_center_outlined, "Project", prop.project?.name ?? 'Standalone', isDark),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.local_offer_outlined, "Type", prop.propertyTypeLabel, isDark),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.grid_view_rounded,
                                    "Area",
                                    prop.area?.value != null
                                        ? "${NumberFormat('#,##,###').format(prop.area!.value)} ${Property.getDisplayLabel(prop.area!.unit)}"
                                        : "N/A",
                                    isDark,
                                  ),
                                ],
                              ),
                            ),
                            // Vertical Divider Line in the middle
                            VerticalDivider(
                              width: 24,
                              thickness: 0.5,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            // Right Specs Column
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  _buildDetailRow(Icons.explore_outlined, "Facing", _formatDisplayValue(prop.facingLabel), isDark),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.layers_outlined, "Furnishing", _formatDisplayValue(prop.furnishingStatusLabel), isDark),
                                  if (prop.direction != null && prop.direction!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildDetailRow(Icons.navigation_outlined, "Direction", _formatDisplayValue(prop.directionLabel), isDark),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dropdown "+ More Details"
                    const Divider(height: 1, thickness: 0.5, color: Colors.black12),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              "+ 8 More Details",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    ),


                    const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                    // Bottom Actions Row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCardActionButton(
                              icon: const Icon(Icons.visibility_outlined),
                              label: "View",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PropertyDetailScreen(property: prop),
                                  ),
                                );
                              },
                              isDark: isDark,
                            ),
                          ),
                          _buildVerticalDivider(isDark),
                          Expanded(
                            child: _buildCardActionButton(
                              icon: const Icon(Icons.edit_outlined),
                              label: "Edit",
                              onTap: refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name)
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => PropertyCreateDialog(projectId: projectUrlId, property: prop),
                                      );
                                    }
                                  : null,
                              isDark: isDark,
                            ),
                          ),
                          _buildVerticalDivider(isDark),
                          Expanded(
                            child: _buildCardActionButton(
                              icon: Transform.scale(
                                scaleX: -1,
                                child: const Icon(Icons.reply, size: 16),
                              ),
                              label: "Share",
                              onTap: refPermissions.hasPermission(PermissionModules.PROPERTY_VIEW, userRole: loginUser?.systemRole)
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => PropertyShareDialog(property: prop),
                                      );
                                    }
                                  : null,
                              isDark: isDark,
                            ),
                          ),
                          _buildVerticalDivider(isDark),
                          Expanded(
                            child: _buildCardMoreButton(
                              prop: prop,
                              loginUser: loginUser,
                              refPermissions: refPermissions,
                              isDark: isDark,
                            ),
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

  String _formatDisplayValue(String? value) {
    if (value == null || value.trim().isEmpty || value.toLowerCase() == 'n/a' || value.toLowerCase() == 'null') {
      return 'N/A';
    }
    return value;
  }

  Widget _buildCardActionButton({
    required Widget icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final disabled = onTap == null;
    final color = disabled
        ? Colors.grey.shade400
        : const Color(0xFF2563EB); // Blue-600

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon is Icon
                ? Icon(
                    icon.icon,
                    size: 16,
                    color: color,
                  )
                : icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
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

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      width: 0.5,
      height: 20,
      color: isDark ? Colors.white10 : Colors.black12,
    );
  }

  Widget _buildCardMoreButton({
    required Property prop,
    required dynamic loginUser,
    required dynamic refPermissions,
    required bool isDark,
  }) {
    final isAdmin = loginUser?.systemRole == 'company_admin';
    final canDelete = refPermissions.canUpdateProperty(prop, userRole: loginUser?.systemRole, userName: loginUser?.name) && isAdmin;

    final color = const Color(0xFF2563EB);

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'delete') {
          _deleteProperty(context, prop);
        } else if (value == 'public_view') {
          PublicViewScreen.launchPublicView(context, ref, property: prop);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.more_horiz, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              "More",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'public_view',
          child: Row(
            children: [
              Icon(
                Icons.public,
                size: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 8),
              const Text("Public View"),
            ],
          ),
        ),
        if (isAdmin)
          PopupMenuItem(
            value: 'delete',
            enabled: canDelete,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: canDelete ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  "Delete",
                  style: TextStyle(color: canDelete ? Colors.red : Colors.grey),
                ),
              ],
            ),
          ),
      ],
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
                  activeColor: const Color(0xFF2563EB),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Select all eligible on page",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          if (_selectedPropertyIds.isNotEmpty)
            Text(
              "${_selectedPropertyIds.length} selected",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
              ),
            ),
        ],
      ),
    );
  }
}
