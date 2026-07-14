import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/property_provider.dart';

import '../../data/models/property_model.dart';

class PropertyFiltersBottomSheet extends ConsumerStatefulWidget {
  final String projectId;

  const PropertyFiltersBottomSheet({super.key, required this.projectId});

  @override
  ConsumerState<PropertyFiltersBottomSheet> createState() => _PropertyFiltersBottomSheetState();
}

class _PropertyFiltersBottomSheetState extends ConsumerState<PropertyFiltersBottomSheet> {
  late String _listingType;
  String? _projectFilter;
  late String _city;
  late String _amenities;
  late String _status;
  late String _category;
  late String _propertyType;
  int? _bedrooms;
  late String _facing;
  late String _direction;
  late String _areaUnit;
  late String _sort;
  late String _builtUpFilter;
  String? _fromInventoryDate;
  String? _toInventoryDate;
  late String _allowedTenants;
  late String _preferredGender;
  late String _furnishingStatus;
  String? _availableBy;

  late TextEditingController _minAreaController;
  late TextEditingController _maxAreaController;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  late TextEditingController _fromInventoryDateController;
  late TextEditingController _toInventoryDateController;
  late TextEditingController _availableByController;
  bool _didInvalidateCities = false;

  @override
  void initState() {
    super.initState();
    final pid = widget.projectId;
    final state = pid.isEmpty
        ? ref.read(allPropertiesProvider)
        : ref.read(projectPropertiesProvider(pid));

    _listingType = state.listingType.isEmpty || state.listingType == 'all' ? 'all' : state.listingType;
    _projectFilter = state.projectFilter;
    _city = state.city.isEmpty || state.city == 'all_cities' ? 'all_cities' : state.city;
    _amenities = state.amenities;
    _status = state.status.isEmpty || state.status == 'all_properties' ? 'all_properties' : state.status;
    _category = state.category.isEmpty || state.category == 'all_categories' ? 'all_categories' : state.category;
    _propertyType = state.propertyType.isEmpty || state.propertyType == 'all_types' ? 'all_types' : state.propertyType;
    _bedrooms = state.bedrooms;
    _facing = state.facing.isEmpty || state.facing == 'all_facings' ? 'all_facings' : state.facing;
    _direction = state.direction.isEmpty || state.direction == 'all_directions' ? 'all_directions' : state.direction;
    _areaUnit = state.areaUnit.isEmpty || state.areaUnit == 'all' ? 'all' : state.areaUnit;
    _sort = state.sort;
    _builtUpFilter = state.builtUpFilter;
    _fromInventoryDate = state.fromInventoryDate;
    _toInventoryDate = state.toInventoryDate;
    _allowedTenants = state.allowedTenants.isEmpty || state.allowedTenants == 'any' ? 'any' : state.allowedTenants;
    _preferredGender = state.preferredGender.isEmpty || state.preferredGender == 'any' ? 'any' : state.preferredGender;
    _furnishingStatus = state.furnishingStatus.isEmpty || state.furnishingStatus == 'all' ? 'all' : state.furnishingStatus;
    _availableBy = state.availableBy;

    _minAreaController = TextEditingController(text: state.minArea?.toString() ?? '');
    _maxAreaController = TextEditingController(text: state.maxArea?.toString() ?? '');
    _minPriceController = TextEditingController(text: state.minPrice?.toString() ?? '');
    _maxPriceController = TextEditingController(text: state.maxPrice?.toString() ?? '');
    _fromInventoryDateController = TextEditingController(text: _fromInventoryDate ?? '');
    _toInventoryDateController = TextEditingController(text: _toInventoryDate ?? '');
    _availableByController = TextEditingController(text: _availableBy ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInvalidateCities) {
      _didInvalidateCities = true;
      ref.invalidate(citiesProvider);
    }
  }

  @override
  void dispose() {
    _minAreaController.dispose();
    _maxAreaController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _fromInventoryDateController.dispose();
    _toInventoryDateController.dispose();
    _availableByController.dispose();
    super.dispose();
  }

  void _resetLocalFilters() {
    setState(() {
      _listingType = 'all';
      _projectFilter = null;
      _city = 'all_cities';
      _amenities = '';
      _status = 'all_properties';
      _category = 'all_categories';
      _propertyType = 'all_types';
      _bedrooms = null;
      _facing = 'all_facings';
      _direction = 'all_directions';
      _areaUnit = 'all';
      _sort = 'created_desc';
      _builtUpFilter = '';
      _fromInventoryDate = null;
      _toInventoryDate = null;
      _allowedTenants = 'any';
      _preferredGender = 'any';
      _furnishingStatus = 'all';
      _availableBy = null;

      _minAreaController.clear();
      _maxAreaController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _fromInventoryDateController.clear();
      _toInventoryDateController.clear();
      _availableByController.clear();
    });
    _applyLocalFilters();
  }

  void _applyLocalFilters() {
    final minArea = double.tryParse(_minAreaController.text);
    final maxArea = double.tryParse(_maxAreaController.text);
    final minPrice = double.tryParse(_minPriceController.text);
    final maxPrice = double.tryParse(_maxPriceController.text);
    final pid = widget.projectId;
    final notifier = pid.isEmpty
        ? ref.read(allPropertiesProvider.notifier)
        : ref.read(projectPropertiesProvider(pid).notifier);
    final currentState = pid.isEmpty
        ? ref.read(allPropertiesProvider)
        : ref.read(projectPropertiesProvider(pid));

    notifier.applyFilters(
      status: _status,
      category: _category,
      propertyType: _propertyType == 'all_types' ? '' : _propertyType,
      facing: _facing,
      bedrooms: _bedrooms,
      bathrooms: currentState.bathrooms,
      listingType: _listingType,
      allowedTenants: _listingType == 'rent' ? _allowedTenants : 'any',
      city: _city == 'all_cities' ? '' : _city,
      furnishingStatus: _listingType == 'rent' ? _furnishingStatus : 'all',
      preferredGender: _listingType == 'rent' ? _preferredGender : 'any',
      amenities: _amenities,
      availableBy: _availableBy,
      minPrice: minPrice,
      maxPrice: maxPrice,
      areaUnit: _areaUnit,
      minArea: minArea,
      maxArea: maxArea,
      sort: _sort,
      direction: _direction == 'all_directions' ? '' : _direction,
      projectFilter: _projectFilter,
      builtUpFilter: _builtUpFilter,
      fromInventoryDate: _fromInventoryDate,
      toInventoryDate: _toInventoryDate,
    );
    Navigator.pop(context);
  }

  String _mapSortToDisplay(String value) {
    switch (value) {
      case 'created_asc':
        return 'Created (Oldest first)';
      case 'updated_desc':
        return 'Recently updated';
      case 'updated_asc':
        return 'Least recently updated';
      case 'created_desc':
      default:
        return 'Created (Newest first)';
    }
  }

  String _mapDisplayToSort(String display) {
    switch (display) {
      case 'Created (Oldest first)':
        return 'created_asc';
      case 'Recently updated':
        return 'updated_desc';
      case 'Least recently updated':
        return 'updated_asc';
      case 'Created (Newest first)':
      default:
        return 'created_desc';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAllProperties = widget.projectId.isEmpty;

    final dropdownBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50];
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final outlineColor = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300];

    // Providers
    final projectsAsync = isAllProperties ? ref.watch(propertyProvider) : null;
    final citiesAsync = ref.watch(citiesProvider);
    final amenitiesAsync = ref.watch(amenitiesProvider);

    InputDecoration fieldDecoration(String hint, {String? label}) {
      return InputDecoration(
        hintText: hint,
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        floatingLabelBehavior: label != null ? FloatingLabelBehavior.always : FloatingLabelBehavior.never,
        hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        filled: true,
        fillColor: dropdownBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outlineColor!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white70 : Colors.black, width: 1.5),
        ),
      );
    }

    Widget buildDropdown({
      required String value,
      required List<DropdownMenuItem<String>> items,
      required ValueChanged<String?> onChanged,
      required String hint,
      String? label,
    }) {
      return DropdownButtonFormField<String>(
        initialValue: value,
        decoration: fieldDecoration(hint, label: label),
        dropdownColor: theme.cardColor,
        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
        items: items,
        onChanged: onChanged,
      );
    }

    Widget buildMultiSelectField({
      required String label,
      required List<String> selectedValues,
      required List<String> allOptions,
      required String placeholder,
      required ValueChanged<List<String>> onSelectedChanged,
      bool showSearch = false,
    }) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final displayText = selectedValues.isEmpty ? placeholder : selectedValues.map((e) => Property.getDisplayLabel(e)).join(', ');
      
      return InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) {
              List<String> tempSelected = List.from(selectedValues);
              String searchQuery = '';
              
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  final filteredOptions = showSearch && searchQuery.isNotEmpty
                      ? allOptions.where((opt) => opt.toLowerCase().contains(searchQuery.toLowerCase())).toList()
                      : allOptions;
                      
                  return AlertDialog(
                    title: Text('Select $label', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    content: SizedBox(
                      width: 400,
                      height: 400,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showSearch) ...[
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  searchQuery = val;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredOptions.length,
                              itemBuilder: (context, index) {
                                final opt = filteredOptions[index];
                                final isChecked = tempSelected.contains(opt);
                                return CheckboxListTile(
                                  title: Text(Property.getDisplayLabel(opt), style: const TextStyle(fontSize: 14)),
                                  value: isChecked,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: theme.primaryColor,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        tempSelected.add(opt);
                                      } else {
                                        tempSelected.remove(opt);
                                      }
                                    });
                                  },
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
                        child: const Text('CANCEL'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                        onPressed: () {
                          onSelectedChanged(tempSelected);
                          Navigator.pop(context);
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        child: InputDecorator(
          decoration: fieldDecoration(placeholder).copyWith(
            labelText: label,
            labelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 14,
                    color: selectedValues.isEmpty ? (isDark ? Colors.grey[400] : Colors.grey[600]) : theme.textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Property Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodyLarge?.color,
                        letterSpacing: 0.1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Filter Inputs
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Listing Type
                      buildDropdown(
                        value: _listingType,
                        hint: "All Listing Types",
                        label: "Property Visibility",
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Listing Types')),
                          const DropdownMenuItem(value: 'sell', child: Text('Sell / Sale')),
                          const DropdownMenuItem(value: 'rent', child: Text('Rent')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _listingType = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Project (only in All Properties view)
                      if (isAllProperties) ...[
                        buildDropdown(
                          value: _projectFilter ?? '',
                          hint: "All Projects",
                          label: "Project",
                          items: [
                            const DropdownMenuItem(value: '', child: Text('All Projects')),
                            if (projectsAsync != null)
                              ...projectsAsync.projects.map((p) =>
                                DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _projectFilter = val.isEmpty ? null : val);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. City
                      citiesAsync.when(
                        data: (cities) {
                          final selectedCities = _city == 'all_cities' || _city.isEmpty ? <String>[] : _city.split(',').where((e) => e.isNotEmpty).toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: labelColor, letterSpacing: 1.0)),
                              const SizedBox(height: 8),
                              if (selectedCities.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: selectedCities.map((c) => Chip(
                                    label: Text(c, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                    deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                                    onDeleted: () {
                                      setState(() {
                                        _city = selectedCities.where((x) => x != c).join(',');
                                      });
                                    },
                                    backgroundColor: Colors.teal.shade600,
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  )).toList(),
                                ),
                                const SizedBox(height: 8),
                              ],
                              InkWell(
                                onTap: () => _showCitySheet(cities, selectedCities),
                                child: InputDecorator(
                                  decoration: fieldDecoration('Tap to select cities').copyWith(
                                    labelText: 'City',
                                    labelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                                    floatingLabelBehavior: FloatingLabelBehavior.always,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedCities.isEmpty ? 'All Cities' : '${selectedCities.length} selected',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: selectedCities.isEmpty ? (isDark ? Colors.grey[400] : Colors.grey[600]) : theme.textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'City',
                            labelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: Text('Loading Cities...', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ),
                        error: (_, _) => InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'City',
                            labelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: Text('Error Loading Cities', style: TextStyle(fontSize: 14, color: Colors.red)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Amenities
                      amenitiesAsync.when(
                        data: (amenities) {
                          final selectedAmenities = _amenities.isEmpty ? <String>[] : _amenities.split(',').where((e) => e.isNotEmpty).toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AMENITIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: labelColor, letterSpacing: 1.0)),
                              const SizedBox(height: 8),
                              if (selectedAmenities.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: selectedAmenities.map((a) => Chip(
                                    label: Text(a, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                    deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                                    onDeleted: () {
                                      setState(() {
                                        _amenities = selectedAmenities.where((x) => x != a).join(',');
                                      });
                                    },
                                    backgroundColor: Colors.blue.shade600,
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  )).toList(),
                                ),
                                const SizedBox(height: 8),
                              ],
                              InkWell(
                                onTap: () => _showAmenitiesSheet(amenities, selectedAmenities),
                                child: InputDecorator(
                                  decoration: fieldDecoration('Tap to select amenities').copyWith(
                                    labelText: 'Amenities',
                                    labelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                                    floatingLabelBehavior: FloatingLabelBehavior.always,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedAmenities.isEmpty ? 'All Amenities' : '${selectedAmenities.length} selected',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: selectedAmenities.isEmpty ? (isDark ? Colors.grey[400] : Colors.grey[600]) : theme.textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Amenities',
                            labelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: Text('Loading Amenities...', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ),
                        error: (_, _) => InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Amenities',
                            labelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: Text('Error Loading Amenities', style: TextStyle(fontSize: 14, color: Colors.red)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Property Type
                      Builder(
                        builder: (context) {
                          final selectedTypes = _propertyType == 'all_types' || _propertyType.isEmpty ? <String>[] : _propertyType.split(',').where((e) => e.isNotEmpty).toList();
                          return buildMultiSelectField(
                            label: "Property Type",
                            selectedValues: selectedTypes,
                            allOptions: const [
                              'plot', 'flat', 'floor', 'room', 'farm_house', 'villa', 'duplex',
                              'shop', 'house', 'green_land', 'office', 'warehouse',
                              'coworking_space', 'studio_apartment', 'penthouse'
                            ],
                            placeholder: "All Property Types",
                            onSelectedChanged: (list) {
                              setState(() {
                                _propertyType = list.isEmpty ? 'all_types' : list.join(',');
                              });
                            },
                          );
                        }
                      ),
                      const SizedBox(height: 16),

                      // 5. Status
                      Builder(
                        builder: (context) {
                          final selectedStatuses = _status == 'all_properties' || _status.isEmpty ? <String>[] : _status.split(',').where((e) => e.isNotEmpty).toList();
                          return buildMultiSelectField(
                            label: "Status",
                            selectedValues: selectedStatuses,
                            allOptions: const ['available', 'on_hold', 'token_received', 'booked', 'sold', 'blocked', 'ready_to_move', 'rented', 'notice_period'],
                            placeholder: "All Properties",
                            onSelectedChanged: (list) {
                              setState(() {
                                _status = list.isEmpty ? 'all_properties' : list.join(',');
                              });
                            },
                          );
                        }
                      ),
                      const SizedBox(height: 16),

                      // 6. Category
                      Builder(
                        builder: (context) {
                          final selectedCategories = _category == 'all_categories' || _category.isEmpty ? <String>[] : _category.split(',').where((e) => e.isNotEmpty).toList();
                          return buildMultiSelectField(
                            label: "Category",
                            selectedValues: selectedCategories,
                            allOptions: const ['residential', 'commercial', 'industrial', 'land'],
                            placeholder: "All Categories",
                            onSelectedChanged: (list) {
                              setState(() {
                                _category = list.isEmpty ? 'all_categories' : list.join(',');
                              });
                            },
                          );
                        }
                      ),
                      const SizedBox(height: 16),

                      if (_listingType == 'rent') ...[
                        // Allowed Tenants
                        Text("Allowed Tenants", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
                        const SizedBox(height: 6),
                        buildDropdown(
                          value: _allowedTenants,
                          hint: "Allowed Tenants",
                          items: ['any', 'family', 'bachelors', 'company_lease']
                              .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e == 'any' ? 'Any' : Property.getDisplayLabel(e)),
                              ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _allowedTenants = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Preferred Gender
                        Text("Preferred Gender", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
                        const SizedBox(height: 6),
                        buildDropdown(
                          value: _preferredGender,
                          hint: "Preferred Gender",
                          items: ['any', 'male', 'female', 'other']
                              .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e == 'any' ? 'Any' : Property.getDisplayLabel(e)),
                              ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _preferredGender = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Furnishing Status
                        buildDropdown(
                          value: _furnishingStatus,
                          hint: "Any",
                          label: "Furnishing Status",
                          items: ['all', 'unfurnished', 'semi_furnished', 'fully_furnished']
                              .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e == 'all' ? 'Any' : Property.getDisplayLabel(e)),
                              ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _furnishingStatus = val);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 7. Bedrooms (BHK)
                      buildDropdown(
                        value: _bedrooms == null ? 'all_bedrooms' : '${_bedrooms}_bhk',
                        hint: "All Bedrooms",
                        label: "Bedrooms (BHK)",
                        items: ['all_bedrooms', '1_bhk', '2_bhk', '3_bhk', '4_bhk', '5_bhk']
                            .map((bed) => DropdownMenuItem(
                              value: bed,
                              child: Text(bed == 'all_bedrooms' ? 'All Bedrooms' : bed.replaceAll('_', ' ').toUpperCase()),
                            ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _bedrooms = val == 'all_bedrooms' ? null : int.parse(val.split('_')[0]);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 8. Facing (only facing styles)
                      buildDropdown(
                        value: _facing,
                        hint: "All Facings",
                        label: "Facing",
                        items: ['all_facings', 'park_facing', 'kothi_facing', 'dda_flat_facing', 'road_facing']
                            .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e == 'all_facings' ? 'All Facings' : Property.getDisplayLabel(e)),
                            ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _facing = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // 9. Direction
                      buildDropdown(
                        value: _direction,
                        hint: "All Directions",
                        label: "Direction",
                        items: ['all_directions', 'north', 'south', 'east', 'west', 'north_east', 'north_west', 'south_east', 'south_west']
                            .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e == 'all_directions' ? 'All Directions' : Property.getDisplayLabel(e)),
                            ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _direction = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // 10. Area Unit
                      buildDropdown(
                        value: _areaUnit,
                        hint: "All",
                        label: "Area Unit",
                        items: ['all', 'sqft', 'sqyd', 'acre', 'bigha']
                            .map((unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit == 'all' ? 'All' : unit),
                            ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _areaUnit = val);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Area Range Header
                      Text(
                        "AREA RANGE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Area Range Inputs Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minAreaController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: fieldDecoration("Min Area"),
                              style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _maxAreaController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: fieldDecoration("Max Area"),
                              style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Price Range Header
                      Text(
                        "PRICE RANGE (INR)",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price Range Inputs Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: fieldDecoration("Min Price"),
                              style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: fieldDecoration("Max Price"),
                              style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sort By Header
                      Text(
                        "Sort By",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Sort Dropdown
                      buildDropdown(
                        value: _mapSortToDisplay(_sort),
                        hint: "Sort By",
                        items: ['Created (Newest first)', 'Created (Oldest first)', 'Recently updated', 'Least recently updated']
                            .map((sortOption) => DropdownMenuItem(value: sortOption, child: Text(sortOption)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _sort = _mapDisplayToSort(val));
                        },
                      ),
                      const SizedBox(height: 16),

                      // Built Up Dropdown
                      buildDropdown(
                        value: _builtUpFilter == '' ? 'all_built_up' : (_builtUpFilter == 'true' ? 'built_up_only' : 'not_built_up'),
                        hint: "Built Up Status",
                        items: ['all_built_up', 'built_up_only', 'not_built_up']
                            .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e == 'all_built_up' ? 'All (Built Up)' :
                                e == 'built_up_only' ? 'Built Up Only' : 'Not Built Up',
                              ),
                            ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              if (val == 'all_built_up') {
                                _builtUpFilter = '';
                              } else if (val == 'built_up_only') {
                                _builtUpFilter = 'true';
                              } else {
                                _builtUpFilter = 'false';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Inventory Date Range Header
                      Text(
                        "INVENTORY DATE RANGE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _fromInventoryDate != null ? DateTime.parse(_fromInventoryDate!) : DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _fromInventoryDate = DateFormat('yyyy-MM-dd').format(picked);
                                    _fromInventoryDateController.text = _fromInventoryDate!;
                                  });
                                }
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: _fromInventoryDateController,
                                  decoration: fieldDecoration("From Date").copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16)),
                                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _toInventoryDate != null ? DateTime.parse(_toInventoryDate!) : DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _toInventoryDate = DateFormat('yyyy-MM-dd').format(picked);
                                    _toInventoryDateController.text = _toInventoryDate!;
                                  });
                                }
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: _toInventoryDateController,
                                  decoration: fieldDecoration("To Date").copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16)),
                                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Available By Date Picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _availableBy != null ? DateTime.parse(_availableBy!) : DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _availableBy = DateFormat('yyyy-MM-dd').format(picked);
                              _availableByController.text = _availableBy!;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _availableByController,
                            decoration: fieldDecoration("Available By").copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16)),
                            style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              // Sticky Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _resetLocalFilters,
                      child: Text(
                        "RESET FILTERS",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "CANCEL",
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyLocalFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text(
                        "APPLY",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
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

  void _showCitySheet(List<String> cities, List<String> selectedCities) {
    String searchQuery = '';
    List<String> tempSelected = List.from(selectedCities);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = searchQuery.isEmpty
                ? cities
                : cities.where((c) => c.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 32, height: 4,
                            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Cities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                            Text('${tempSelected.length} selected', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search cities...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) => setSheetState(() => searchQuery = val),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text('No cities found', style: TextStyle(color: Colors.grey[500])))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final city = filtered[index];
                              final checked = tempSelected.contains(city);
                              return CheckboxListTile(
                                title: Text(city, style: const TextStyle(fontSize: 14)),
                                value: checked,
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: theme.primaryColor,
                                dense: true,
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val == true) {
                                      tempSelected.add(city);
                                    } else {
                                      tempSelected.remove(city);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              setState(() {
                                _city = tempSelected.isEmpty ? 'all_cities' : tempSelected.join(',');
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAmenitiesSheet(List<String> allAmenities, List<String> selectedAmenities) {
    List<String> tempSelected = List.from(selectedAmenities);
    String searchQuery = '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = searchQuery.isEmpty
                ? allAmenities
                : allAmenities.where((a) => a.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 32, height: 4,
                            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Amenities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                            Text('${tempSelected.length} selected', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search amenities...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) => setSheetState(() => searchQuery = val),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text('No amenities found', style: TextStyle(color: Colors.grey[500])))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final amenity = filtered[index];
                              final checked = tempSelected.contains(amenity);
                              return CheckboxListTile(
                                title: Text(amenity, style: const TextStyle(fontSize: 14)),
                                value: checked,
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: theme.primaryColor,
                                dense: true,
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val == true) {
                                      tempSelected.add(amenity);
                                    } else {
                                      tempSelected.remove(amenity);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              setState(() {
                                _amenities = tempSelected.join(',');
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
