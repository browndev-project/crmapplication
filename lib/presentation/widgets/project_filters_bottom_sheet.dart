import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/property_provider.dart';

class ProjectFiltersBottomSheet extends ConsumerStatefulWidget {
  const ProjectFiltersBottomSheet({super.key});

  @override
  ConsumerState<ProjectFiltersBottomSheet> createState() => _ProjectFiltersBottomSheetState();
}

class _ProjectFiltersBottomSheetState extends ConsumerState<ProjectFiltersBottomSheet> {
  Set<String> _statuses = {};
  Set<String> _projectCategories = {};
  Set<String> _propertyCategories = {};
  String? _from;
  String? _to;
  late String _sort;

  static const List<String> statusOptions = [
    'Active', 'Pre-Launch', 'Under Construction', 'Ready to Move', 'Sold Out', 'On Hold', 'Blocked'
  ];

  static const List<String> projectCategoryOptions = [
    'Residential', 'Commercial', 'Industrial', 'Land'
  ];

  static const List<String> propertyCategoryOptions = [
    'Residential', 'Commercial', 'Industrial', 'Land'
  ];

  @override
  void initState() {
    super.initState();
    final state = ref.read(propertyProvider);
    _statuses = _parseFilterSet(state.status);
    _projectCategories = _parseFilterSet(state.projectCategory);
    _propertyCategories = _parseFilterSet(state.propertyCategory);
    _from = state.from;
    _to = state.to;
    _sort = state.sort;
  }

  Set<String> _parseFilterSet(String filterValue) {
    if (filterValue == 'All Status' || filterValue == 'All Projects' || filterValue == 'All Properties') {
      return {};
    }
    return filterValue.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  String _joinFilterSet(Set<String> values, String defaultValue) {
    if (values.isEmpty) return defaultValue;
    return values.join(', ');
  }

  String _getStatusDisplay() {
    if (_statuses.isEmpty) return 'All Status';
    return _statuses.join(', ');
  }

  String _getProjectCategoryDisplay() {
    if (_projectCategories.isEmpty) return 'All Projects';
    return _projectCategories.join(', ');
  }

  String _getPropertyCategoryDisplay() {
    if (_propertyCategories.isEmpty) return 'All Properties';
    return _propertyCategories.join(', ');
  }

  void _resetLocalFilters() {
    setState(() {
      _statuses = {};
      _projectCategories = {};
      _propertyCategories = {};
      _from = null;
      _to = null;
      _sort = 'updated_desc';
    });
  }

  void _applyLocalFilters() {
    ref.read(propertyProvider.notifier).applyFilters(
      status: _joinFilterSet(_statuses, 'All Status'),
      projectCategory: _joinFilterSet(_projectCategories, 'All Projects'),
      propertyCategory: _joinFilterSet(_propertyCategories, 'All Properties'),
      from: _from,
      to: _to,
      sort: _sort,
    );
    Navigator.pop(context);
  }

  String _mapSortToDisplay(String value) {
    switch (value) {
      case 'created_asc':
        return 'Created (Oldest First)';
      case 'updated_asc':
        return 'Updated (Oldest First)';
      case 'created_desc':
        return 'Created (Newest First)';
      case 'updated_desc':
      default:
        return 'Updated (Newest First)';
    }
  }

  String _mapDisplayToSort(String display) {
    switch (display) {
      case 'Created (Oldest First)':
        return 'created_asc';
      case 'Updated (Oldest First)':
        return 'updated_asc';
      case 'Created (Newest First)':
        return 'created_desc';
      case 'Updated (Newest First)':
      default:
        return 'updated_desc';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dropdownBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50];
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final outlineColor = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300];

    InputDecoration fieldDecoration(String hint) {
      return InputDecoration(
        hintText: hint,
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
                      'Project Filters',
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
                      // Status Multi-Select Dropdown
                      Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMultiSelectDropdown(
                        displayText: _getStatusDisplay(),
                        hint: 'All Status',
                        options: statusOptions,
                        selected: _statuses,
                        onChanged: (val) => setState(() => _statuses = val),
                      ),
                      const SizedBox(height: 16),

                      // Project Category Multi-Select Dropdown
                      Text(
                        'PROJECT CATEGORY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMultiSelectDropdown(
                        displayText: _getProjectCategoryDisplay(),
                        hint: 'All Projects',
                        options: projectCategoryOptions,
                        selected: _projectCategories,
                        onChanged: (val) => setState(() => _projectCategories = val),
                      ),
                      const SizedBox(height: 16),

                      // Properties Category Multi-Select Dropdown
                      Text(
                        'PROPERTIES CATEGORY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMultiSelectDropdown(
                        displayText: _getPropertyCategoryDisplay(),
                        hint: 'All Properties',
                        options: propertyCategoryOptions,
                        selected: _propertyCategories,
                        onChanged: (val) => setState(() => _propertyCategories = val),
                      ),
                      const SizedBox(height: 20),

                      // Date Range Picker Header
                      Text(
                        "DATE RANGE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Date Fields Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePickerField("From", _from, (date) => setState(() => _from = date)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDatePickerField("To", _to, (date) => setState(() => _to = date)),
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
                      DropdownButtonFormField<String>(
                        initialValue: _mapSortToDisplay(_sort),
                        decoration: fieldDecoration("Sort By"),
                        dropdownColor: theme.cardColor,
                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                        items: ['Created (Newest First)', 'Created (Oldest First)', 'Updated (Newest First)', 'Updated (Oldest First)']
                            .map((sortOption) => DropdownMenuItem(
                                  value: sortOption,
                                  child: Text(sortOption),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _sort = _mapDisplayToSort(val));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              // Sticky Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetLocalFilters,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: isDark ? Colors.white38 : Colors.grey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          "Reset All",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _applyLocalFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          "Apply Filters",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
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

  Widget _buildMultiSelectDropdown({
    required String displayText,
    required String hint,
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<Set<String>> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final result = await showModalBottomSheet<Set<String>>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _MultiSelectSheet(
            title: hint,
            options: options,
            selected: Set.from(selected),
          ),
        );
        if (result != null) {
          onChanged(result);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 14,
                  color: selected.isNotEmpty
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  fontWeight: selected.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_drop_down_rounded, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerField(String hint, String? value, Function(String?) onDateSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final initialDate = value != null ? DateTime.parse(value) : DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? const ColorScheme.dark(primary: Colors.blueAccent, onPrimary: Colors.black, surface: Color(0xFF1E1E1E))
                    : const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          onDateSelected(formatted);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value ?? hint,
              style: TextStyle(
                fontSize: 14,
                color: value != null ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;

  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _selected.clear());
                        },
                        child: const Text('Clear', style: TextStyle(fontSize: 13)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: widget.options.map((option) {
                    final isSelected = _selected.contains(option);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(option);
                          } else {
                            _selected.add(option);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              size: 22,
                              color: isSelected
                                  ? (isDark ? Colors.blueAccent : Colors.black)
                                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              option,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    "Apply",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
