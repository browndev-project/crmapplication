import 'package:flutter/material.dart';

class QuotationFilterBottomSheet extends StatefulWidget {
  final String? currentStatus;
  final Function(String?) onApply;

  const QuotationFilterBottomSheet({
    super.key,
    this.currentStatus,
    required this.onApply,
  });

  @override
  State<QuotationFilterBottomSheet> createState() => _QuotationFilterBottomSheetState();
}

class _QuotationFilterBottomSheetState extends State<QuotationFilterBottomSheet> {
  String? _selectedStatus;

  static const _statuses = ['ALL', 'DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'CANCELLED'];

  String _labelFor(String? value) {
    if (value == null || value == 'ALL') return 'All Statuses';
    return value[0] + value.substring(1).toLowerCase();
  }

  int? _indexFor(String? value) {
    if (value == null || value == 'ALL') return 0;
    return _statuses.indexOf(value);
  }

  @override
  void initState() {
    super.initState();
    final idx = _indexFor(widget.currentStatus);
    _selectedStatus = idx != null && idx > 0 ? _statuses[idx] : null;
  }

  void _reset() {
    setState(() => _selectedStatus = null);
  }

  void _apply() {
    widget.onApply(_selectedStatus);
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
            children: _statuses.map((status) {
              final isSelected = _selectedStatus == status || (status == 'ALL' && _selectedStatus == null);
              return ChoiceChip(
                label: Text(_labelFor(status)),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _selectedStatus = status == 'ALL' ? null : status);
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
