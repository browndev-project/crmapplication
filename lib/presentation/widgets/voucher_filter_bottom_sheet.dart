import 'package:flutter/material.dart';

class VoucherFilterBottomSheet extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApply;

  const VoucherFilterBottomSheet({
    super.key,
    required this.currentFilters,
    required this.onApply,
  });

  @override
  State<VoucherFilterBottomSheet> createState() => _VoucherFilterBottomSheetState();
}

class _VoucherFilterBottomSheetState extends State<VoucherFilterBottomSheet> {
  late String _selectedStatus;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    final f = widget.currentFilters;
    _selectedStatus = f['status'] ?? 'All Statuses';
    _selectedType = f['type'] ?? 'All Types';
  }

  void _reset() {
    setState(() {
      _selectedStatus = 'All Statuses';
      _selectedType = 'All Types';
    });
  }

  void _apply() {
    widget.onApply({
      'status': _selectedStatus,
      'type': _selectedType,
      'search': widget.currentFilters['search'],
    });
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

          const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              'All Statuses', 'Draft', 'Created', 'Sent', 'Paid', 'Cancelled'
            ].map((status) {
              final isSelected = _selectedStatus == status;
              return ChoiceChip(
                label: Text(status),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _selectedStatus = status);
                },
                selectedColor: Colors.black,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          const Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              'All Types', 'Receipt', 'Payment'
            ].map((type) {
              final isSelected = _selectedType == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _selectedType = type);
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
