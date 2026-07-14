import 'package:flutter/material.dart';

class SearchableCitySelector extends StatefulWidget {
  final List<String> allCities;
  final List<String> selectedCities;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final String placeholder;
  final bool closeOnSelect;

  const SearchableCitySelector({
    this.closeOnSelect = false,
    super.key,
    required this.allCities,
    required this.selectedCities,
    required this.onChanged,
    this.label = 'City',
    this.placeholder = 'All Cities',
  });

  @override
  State<SearchableCitySelector> createState() => _SearchableCitySelectorState();
}

class _SearchableCitySelectorState extends State<SearchableCitySelector> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedCities);
  }

  @override
  void didUpdateWidget(SearchableCitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCities != widget.selectedCities) {
      _selected = List.from(widget.selectedCities);
    }
  }

  String _getDisplayLabel(String value) {
    return value
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
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

    final sortedCities = _deduplicateAndSort(widget.allCities);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = searchQuery.isEmpty
              ? sortedCities
              : sortedCities
                  .where((c) => _getDisplayLabel(c).toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 560),
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
                        hintText: 'Search cities...',
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
                  if (tempSelected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      constraints: const BoxConstraints(maxHeight: 72),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: tempSelected.map((city) {
                            return Chip(
                              avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
                              label: Text(
                                _getDisplayLabel(city),
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                              deleteIcon: Icon(Icons.close, size: 16, color: Colors.white70),
                              onDeleted: () => setDialogState(() => tempSelected.remove(city)),
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
                                Icon(Icons.location_off, size: 44, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isEmpty ? 'No cities available' : 'No cities match "$searchQuery"',
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
                              final city = filtered[index];
                              final isChecked = tempSelected.contains(city);
                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    if (isChecked) {
                                      tempSelected.remove(city);
                                    } else {
                                      tempSelected.add(city);
                                    }
                                  });
                                  if (widget.closeOnSelect && tempSelected.isNotEmpty) {
                                    setState(() => _selected = List.from(tempSelected));
                                    widget.onChanged(List.from(tempSelected));
                                    Navigator.pop(ctx);
                                  }
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
                                          _getDisplayLabel(city),
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
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _showAddCityDialog(context, setDialogState, tempSelected);
                          },
                          icon: const Icon(Icons.add_location, size: 18),
                          label: const Text('Add New City', style: TextStyle(fontSize: 13)),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (!widget.closeOnSelect)
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

  void _showAddCityDialog(BuildContext context, void Function(void Function()) setDialogState, List<String> tempSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController newCityCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New City', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
        content: TextField(
          controller: newCityCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter city name',
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: isDark ? const Color(0xFF25293C) : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {
              final city = newCityCtrl.text.trim();
              if (city.isNotEmpty && !tempSelected.contains(city)) {
                setDialogState(() => tempSelected.add(city));
              }
              Navigator.pop(ctx);
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }
}
