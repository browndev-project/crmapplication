import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/property_provider.dart';
import '../../data/models/property_model.dart';

class PropertyBulkUpdateDialog extends ConsumerStatefulWidget {
  final String projectId;
  final List<String> propertyIds;

  const PropertyBulkUpdateDialog({
    super.key,
    required this.projectId,
    required this.propertyIds,
  });

  @override
  ConsumerState<PropertyBulkUpdateDialog> createState() => _PropertyBulkUpdateDialogState();
}

class _PropertyBulkUpdateDialogState extends ConsumerState<PropertyBulkUpdateDialog> {
  String? _selectedStatus;
  String? _selectedCategory;
  String? _selectedPropertyType;
  String? _selectedListingType;
  bool _isUpdating = false;

  final List<String> _statuses = ['available', 'on_hold', 'token_received', 'booked', 'sold', 'blocked', 'ready_to_move', 'rented', 'notice_period'];
  final List<String> _categories = ['residential', 'commercial', 'industrial', 'land'];
  final List<String> _propertyTypes = [
    'plot', 'flat', 'floor', 'room', 'farm_house', 'villa', 'duplex',
    'shop', 'house', 'green_land', 'office', 'warehouse',
    'coworking_space', 'studio_apartment', 'penthouse'
  ];
  final List<String> _listingTypes = ['sell', 'rent'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.cardColor,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 24),
                _buildContent(isDark),
                const SizedBox(height: 32),
                _buildActions(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.edit_note_rounded, color: Colors.blue, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bulk Update Properties",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${widget.propertyIds.length} properties selected",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdown(
          label: "Status",
          value: _selectedStatus,
          items: _statuses,
          onChanged: (val) => setState(() => _selectedStatus = val),
          hint: "Select new status",
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildDropdown(
          label: "Category",
          value: _selectedCategory,
          items: _categories,
          onChanged: (val) => setState(() => _selectedCategory = val),
          hint: "Select new category",
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildDropdown(
          label: "Unit Type",
          value: _selectedPropertyType,
          items: _propertyTypes,
          onChanged: (val) => setState(() => _selectedPropertyType = val),
          hint: "Select new unit type",
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildDropdown(
          label: "Listing Type",
          value: _selectedListingType,
          items: _listingTypes,
          onChanged: (val) => setState(() => _selectedListingType = val),
          hint: "Select new listing type",
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Text(
          "Leave blank to keep existing values",
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF25293C) : Colors.grey[50],
          ),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(Property.getDisplayLabel(e), style: const TextStyle(fontSize: 14)),
          )).toList(),
          onChanged: onChanged,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ],
    );
  }

  Widget _buildActions(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            "Cancel",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _isUpdating || (_selectedStatus == null && _selectedCategory == null && _selectedPropertyType == null && _selectedListingType == null) ? null : _handleUpdate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: _isUpdating
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text("Updating...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Text(
                        "Update All",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleUpdate() async {
    setState(() => _isUpdating = true);

    final updates = <String, dynamic>{};
    if (_selectedStatus != null) {
      updates['status'] = _selectedStatus;
    }
    if (_selectedCategory != null) {
      updates['category'] = _selectedCategory;
    }
    if (_selectedPropertyType != null) {
      updates['propertyType'] = _selectedPropertyType;
    }
    if (_selectedListingType != null) {
      updates['listingType'] = _selectedListingType;
    }

    try {
      final notifier = widget.projectId.isEmpty
          ? ref.read(allPropertiesProvider.notifier)
          : ref.read(projectPropertiesProvider(widget.projectId).notifier);

      final success = await notifier.bulkUpdateProperties(widget.propertyIds, updates);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text("Properties updated successfully"),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to update properties"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}