import 'package:flutter/material.dart';

class ItineraryFilterBottomSheet extends StatefulWidget {
  final bool? currentHasQuotation;
  final Function(bool?) onApply;

  const ItineraryFilterBottomSheet({
    super.key,
    required this.currentHasQuotation,
    required this.onApply,
  });

  @override
  State<ItineraryFilterBottomSheet> createState() => _ItineraryFilterBottomSheetState();
}

class _ItineraryFilterBottomSheetState extends State<ItineraryFilterBottomSheet> {
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    if (widget.currentHasQuotation == null) {
      _selectedFilter = 'All Plans';
    } else if (widget.currentHasQuotation == true) {
      _selectedFilter = 'Linked to Quote';
    } else {
      _selectedFilter = 'Without Quote';
    }
  }

  void _reset() {
    setState(() => _selectedFilter = 'Without Quote');
  }

  void _apply() {
    bool? val;
    if (_selectedFilter == 'Linked to Quote') {
      val = true;
    } else if (_selectedFilter == 'Without Quote') {
      val = false;
    } else {
      val = null;
    }
    
    widget.onApply(val);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 24),

          const Text('Plan Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['All Plans', 'Without Quote', 'Linked to Quote'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _selectedFilter = filter);
                },
                selectedColor: Colors.black,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _reset,
                  child: const Text('Reset', style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
