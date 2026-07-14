import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/utils/date_utils.dart';

class InvoiceFilterBottomSheet extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApply;

  const InvoiceFilterBottomSheet({
    super.key,
    required this.currentFilters,
    required this.onApply,
  });

  @override
  State<InvoiceFilterBottomSheet> createState() => _InvoiceFilterBottomSheetState();
}

class _InvoiceFilterBottomSheetState extends State<InvoiceFilterBottomSheet> {
  String _selectedStatus = 'All Statuses';
  DateTime? _startDate;
  DateTime? _endDate;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  void _loadFilters() {
    final f = widget.currentFilters;
    _selectedStatus = f['status'] ?? 'All Statuses';
    if (f['startDate'] != null) _startDate = DateTimeUtils.parseSafe(f['startDate']);
    if (f['endDate'] != null) _endDate = DateTimeUtils.parseSafe(f['endDate']);
  }

  void _reset() {
    setState(() {
      _selectedStatus = 'All Statuses';
      _startDate = null;
      _endDate = null;
    });
  }

  void _apply() {
    widget.onApply({
      'status': _selectedStatus,
      'startDate': _startDate != null ? _dateFormat.format(_startDate!) : null,
      'endDate': _endDate != null ? _dateFormat.format(_endDate!) : null,
      'search': widget.currentFilters['search'], // Keep search
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
 theme.brightness == Brightness.dark;

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

          // Status Filter
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

          // Date Range
          const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDateField('From', _startDate, (d) => setState(() => _startDate = d))),
              const SizedBox(width: 12),
              Expanded(child: _buildDateField('To', _endDate, (d) => setState(() => _endDate = d))),
            ],
          ),
          const SizedBox(height: 32),

          // Actions
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

  Widget _buildDateField(String label, DateTime? date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null ? DateFormat('dd MMM yyyy').format(date) : label,
              style: TextStyle(
                color: date != null ? null : Colors.grey,
                fontSize: 13,
              ),
            ),
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
