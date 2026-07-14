import 'package:flutter/material.dart';

class SearchableAmenitiesSelector extends StatefulWidget {
  final List<String> allAmenities;
  final List<String> selectedAmenities;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final String placeholder;

  const SearchableAmenitiesSelector({
    super.key,
    required this.allAmenities,
    required this.selectedAmenities,
    required this.onChanged,
    this.label = 'Amenities',
    this.placeholder = 'All Amenities',
  });

  @override
  State<SearchableAmenitiesSelector> createState() => _SearchableAmenitiesSelectorState();
}

class _SearchableAmenitiesSelectorState extends State<SearchableAmenitiesSelector> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedAmenities);
  }

  @override
  void didUpdateWidget(SearchableAmenitiesSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAmenities != widget.selectedAmenities) {
      _selected = List.from(widget.selectedAmenities);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayText = _selected.isEmpty
        ? widget.placeholder
        : _selected.map(_getDisplayLabel).join(', ');

    return InkWell(
      onTap: () => _showSelector(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: const Icon(Icons.arrow_drop_down, size: 22),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 14,
            color: _selected.isEmpty
                ? (isDark ? Colors.grey[400] : Colors.grey[600])
                : theme.textTheme.bodyLarge?.color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _getDisplayLabel(String value) {
    return value
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  List<String> _getCategoryFilters(List<String> amenities) {
    final categories = <String>{};
    for (final a in amenities) {
      final words = a.split('_');
      if (words.length > 1) {
        categories.add(words[0].toLowerCase());
      }
    }
    final sorted = categories.toList()..sort();
    if (sorted.length > 1) {
      sorted.insert(0, 'all');
    }
    return sorted;
  }

  bool _matchesCategory(String amenity, String category) {
    if (category == 'all') return true;
    return amenity.toLowerCase().startsWith(category);
  }

  List<String> _deduplicateAndSort(List<String> items) {
    final unique = items.toSet().toList();
    unique.sort((a, b) => _getDisplayLabel(a).compareTo(_getDisplayLabel(b)));
    return unique;
  }

  void _showSelector(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    List<String> tempSelected = List.from(_selected);
    String searchQuery = '';
    String categoryFilter = 'all';

    final sortedAmenities = _deduplicateAndSort(widget.allAmenities);
    final categories = _getCategoryFilters(sortedAmenities);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          var filtered = sortedAmenities.where((a) {
            if (!_matchesCategory(a, categoryFilter)) return false;
            if (searchQuery.isNotEmpty && !_getDisplayLabel(a).toLowerCase().contains(searchQuery.toLowerCase())) return false;
            return true;
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 520,
              constraints: const BoxConstraints(maxHeight: 580),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2130) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select ${widget.label}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (tempSelected.isNotEmpty)
                          Text(
                            '${tempSelected.length} selected',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        if (tempSelected.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setDialogState(() => tempSelected.clear()),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('CLEAR ALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[400])),
                          ),
                        ],
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search amenities...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF25293C) : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                    ),
                  ),
                  if (categories.length > 1) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: categories.map((cat) {
                          final isActive = categoryFilter == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                cat == 'all' ? 'All' : _getDisplayLabel(cat),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                  color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                              selected: isActive,
                              selectedColor: Colors.blue.shade600,
                              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
                              side: BorderSide.none,
                              onSelected: (val) => setDialogState(() => categoryFilter = cat),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (tempSelected.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      constraints: const BoxConstraints(maxHeight: 72),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: tempSelected.map((amenity) {
                            return Chip(
                              avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
                              label: Text(
                                _getDisplayLabel(amenity),
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                              deleteIcon: Icon(Icons.close, size: 16, color: Colors.white70),
                              onDeleted: () => setDialogState(() => tempSelected.remove(amenity)),
                              backgroundColor: Colors.blue.shade600,
                              side: BorderSide.none,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 44, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isEmpty ? 'No amenities available' : 'No amenities match "$searchQuery"',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                ),
                                if (searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try a different search term',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final amenity = filtered[index];
                              final isChecked = tempSelected.contains(amenity);
                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    if (isChecked) {
                                      tempSelected.remove(amenity);
                                    } else {
                                      tempSelected.add(amenity);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? (isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.06))
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isChecked ? Colors.blue : (isDark ? Colors.grey[500]! : Colors.grey[400]!),
                                            width: isChecked ? 2 : 1.5,
                                          ),
                                          color: isChecked ? Colors.blue : Colors.transparent,
                                        ),
                                        child: isChecked
                                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          _getDisplayLabel(amenity),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                            fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (isChecked)
                                        Text(
                                          'Selected',
                                          style: TextStyle(fontSize: 11, color: Colors.blue[400]),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('CANCEL', style: TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() => _selected = List.from(tempSelected));
                            widget.onChanged(List.from(tempSelected));
                            Navigator.pop(ctx);
                          },
                          child: const Text('APPLY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
