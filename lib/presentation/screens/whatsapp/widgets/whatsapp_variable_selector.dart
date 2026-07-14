import 'package:flutter/material.dart';
import '../../../../core/constants/whatsapp_constants.dart';

class WhatsAppVariableSelector extends StatefulWidget {
  final String mode; // 'lead', 'meeting', 'visit', 'status', 'marketing'
  final String variableKey;
  final String initialSource;
  final String? initialCustomValue;
  final Function(String source, String? customValue) onChanged;

  const WhatsAppVariableSelector({
    super.key,
    required this.mode,
    required this.variableKey,
    required this.initialSource,
    this.initialCustomValue,
    required this.onChanged,
  });

  @override
  State<WhatsAppVariableSelector> createState() =>
      _WhatsAppVariableSelectorState();
}

class _WhatsAppVariableSelectorState extends State<WhatsAppVariableSelector> {
  late String _selectedSource;
  late TextEditingController _customValueCtrl;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.initialSource;
    _customValueCtrl = TextEditingController(text: widget.initialCustomValue);
  }

  @override
  void dispose() {
    _customValueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sources = WhatsAppVariableSources.getSourcesForMode(widget.mode);
    final fallbackSource = sources.containsValue(_selectedSource)
        ? _selectedSource
        : sources.values.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Variable {{${widget.variableKey}}}',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
            borderRadius: BorderRadius.circular(4),
            color: isDark ? const Color(0xFF25293C) : Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: fallbackSource,
              isExpanded: true,
              items: sources.entries.map((e) {
                return DropdownMenuItem<String>(
                  value: e.value,
                  child: Text(e.key, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSource = val);
                  widget.onChanged(
                    _selectedSource,
                    _selectedSource == 'custom' ? _customValueCtrl.text : null,
                  );
                }
              },
            ),
          ),
        ),
        if (_selectedSource == 'custom') ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _customValueCtrl,
            decoration: InputDecoration(
              labelText: 'Custom Value',
              hintText: 'Enter static text for this variable',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (val) {
              widget.onChanged(_selectedSource, val);
            },
          ),
        ],
      ],
    );
  }
}
