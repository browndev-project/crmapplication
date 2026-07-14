import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/whatsapp_provider.dart';
import '../../../providers/lead_provider.dart';
import 'whatsapp_icon.dart';
import 'whatsapp_variable_selector.dart';
import 'whatsapp_preview_bubble.dart';
import '../../../../core/utils/formatters.dart';

class CreateStatusAutomationDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? editRule;
  const CreateStatusAutomationDialog({super.key, this.editRule});

  @override
  ConsumerState<CreateStatusAutomationDialog> createState() => _CreateStatusAutomationDialogState();
}

class _CreateStatusAutomationDialogState extends ConsumerState<CreateStatusAutomationDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _isActive = true;
  String? _selectedTemplateName;
  String? _targetStatus;
  final Map<String, String> _variableMappings = {};
  final Map<String, String> _customValues = {};

  // Lead status values matching CRM display names
  final List<String> validStatuses = [
    'new',
    'converted',
    'meeting scheduled',
    'attempted to contact',
    'contact in future',
    'contacted',
    'in negotiation',
    'junk lead',
    'lost',
    'visit scheduled',
  ];

  @override
  void initState() {
    super.initState();
    // Fetch statuses from API
    Future.microtask(() => ref.read(leadStatusProvider.notifier).fetchStatuses());
    if (widget.editRule != null) {
      _nameCtrl.text = widget.editRule!['name'] ?? '';
      _isActive = widget.editRule!['isActive'] ?? true;
      _selectedTemplateName = widget.editRule!['template']?['name'];
      _targetStatus = widget.editRule!['targetStatus'];
      // Load & sanitize variable mappings
      final mappings = widget.editRule!['variableMappings'] as List?;
      if (mappings != null) {
        for (var m in mappings) {
          final key = m['key'].toString();
          _variableMappings[key] = m['source'] as String? ?? 'lead.name';
          if (m['customValue'] != null) {
            _customValues[key] = m['customValue'].toString();
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _buildVariableMappings(Map<String, dynamic> template) {
    final bodyComp = (template['components'] as List?)?.firstWhere(
      (c) => c['type'] == 'BODY',
      orElse: () => <String, dynamic>{},
    );
    final bodyText = bodyComp?['text'] ?? '';
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText);
    if (matches.isEmpty) return [];
    return matches.map((m) {
      final key = m.group(1)!;
      return {
        'key': key, 
        'source': _variableMappings[key] ?? 'lead.name',
        if (_customValues[key] != null) 'customValue': _customValues[key],
      };
    }).toList();
  }

  Widget _buildVariablesSection(bool isDark, dynamic templatesState) {
    final idx = (templatesState.templates as List).indexWhere((t) => t['name'] == _selectedTemplateName);
    if (idx == -1) return const SizedBox.shrink();
    final t = templatesState.templates[idx] as Map<String, dynamic>;
    final bodyComp = (t['components'] as List?)?.firstWhere((c) => c['type'] == 'BODY', orElse: () => <String, dynamic>{});
    final bodyText = bodyComp?['text'] ?? '';
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText as String);
    if (matches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('BODY VARIABLES',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
        const SizedBox(height: 16),
        ...matches.map((m) {
          final key = m.group(1)!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WhatsAppVariableSelector(
              mode: 'status',
              variableKey: key,
              initialSource: _variableMappings[key] ?? 'lead.name',
              initialCustomValue: _customValues[key],
              onChanged: (source, customValue) {
                setState(() {
                  _variableMappings[key] = source;
                  if (customValue != null) {
                    _customValues[key] = customValue;
                  } else {
                    _customValues.remove(key);
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }

  String _getBodyText(Map<String, dynamic> template) {
    final components = template['components'] as List?;
    final bodyComp = components?.firstWhere((c) => c['type'] == 'BODY', orElse: () => <String, dynamic>{});
    return bodyComp?['text'] ?? '';
  }

  List<String> _getButtons(Map<String, dynamic> template) {
    final components = template['components'] as List?;
    final buttonsComp = components?.firstWhere((c) => c['type'] == 'BUTTONS', orElse: () => <String, dynamic>{});
    if (buttonsComp == null) return [];
    final buttonsList = buttonsComp['buttons'] as List?;
    if (buttonsList == null) return [];
    return buttonsList.map((b) => (b['text'] ?? '').toString()).toList();
  }

  String _getPreviewText(Map<String, dynamic>? template) {
    if (template == null) return '';
    String preview = _getBodyText(template);
    final mappings = _buildVariableMappings(template);
    for (var m in mappings) {
      preview = preview.replaceAll('{{${m['key']}}}', '${m['source']}');
    }
    return preview;
  }

  Widget _buildTemplateCard(Map<String, dynamic> t, bool isSelected, bool isDark) {
    final bText = _getBodyText(t);
    final buttons = _getButtons(t);
    final hasVariables = bText.contains(RegExp(r'\{\{\d+\}\}'));

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTemplateName = t['name'];
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2B22) : const Color(0xFFD9FDD3),
                    shape: BoxShape.circle,
                  ),
                  child: whatsAppIcon(size: 20, color: const Color(0xFF25D366)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${t['status'] ?? 'APPROVED'}".toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (t['status'] == 'APPROVED') ? Colors.green : Colors.orange,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.blue, size: 24),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t['language'] ?? 'en_US',
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF374151), fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (t['category'] ?? 'UTILITY').toUpperCase(),
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF374151), fontWeight: FontWeight.w500),
                  ),
                ),
                if (hasVariables)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Has Variables",
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            if (buttons.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: buttons.map((bText) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(16),
                      color: isDark ? Colors.white10 : Colors.transparent,
                    ),
                    child: Text(
                      bText,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templatesState = ref.watch(whatsappTemplatesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2130) : const Color(0xFFF8F9FA);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(context, isDark),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // General Settings Section
                      _buildSection(
                        'General Settings',
                        [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Automation Name',
                                    labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF25293C) : Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF25293C) : Colors.white,
                                  border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(_isActive ? "ACTIVE" : "INACTIVE", 
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _isActive ? Colors.green : Colors.grey)),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: _isActive,
                                      activeThumbColor: Colors.green,
                                      onChanged: (v) => setState(() => _isActive = v),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),

                      // Triggers Section
                      _buildSection(
                        'Trigger Conditions',
                        [
                          const Text("Target Lead Status", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _targetStatus,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF25293C) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                              hintText: "Select Target Status",
                              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                            items: ref.watch(leadStatusProvider).statuses
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(toTitleCase(s.name), style: const TextStyle(fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() { _targetStatus = val; });
                            },
                          ),
                          const SizedBox(height: 8),
                          Text("When a lead's status is changed to the selected status, this automation will fire.", 
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        ],
                      ),

                      const SizedBox(height: 32),
                      
                      // Message Configuration
                      _buildSection(
                        'Message Configuration',
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Template List
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Select Approved Template", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 350,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF25293C) : Colors.white,
                                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: templatesState.templates.length,
                                      itemBuilder: (context, index) {
                                        final t = templatesState.templates[index];
                                        final bool isSelected = _selectedTemplateName == t['name'];
                                        return _buildTemplateCard(t, isSelected, isDark);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              if (_selectedTemplateName != null)
                                _buildVariablesSection(isDark, templatesState),
                              // Live Preview Placeholder
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Live Preview", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    constraints: const BoxConstraints(minHeight: 120),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE4DDD6),
                                      borderRadius: BorderRadius.circular(8),
                                      image: const DecorationImage(
                                        image: NetworkImage('https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png'),
                                        repeat: ImageRepeat.repeat,
                                        opacity: 0.4,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: _selectedTemplateName == null 
                                        ? Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.smartphone, size: 32, color: Colors.green.shade400),
                                                const SizedBox(height: 12),
                                                Text("Select a template to view the preview", 
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                              ],
                                            ),
                                          )
                                        : WhatsAppPreviewBubble(
                                            template: templatesState.templates.firstWhere((t) => t['name'] == _selectedTemplateName),
                                            bodyText: _getPreviewText(templatesState.templates.firstWhere((t) => t['name'] == _selectedTemplateName)),
                                            isDark: isDark,
                                          ),
                                    ),
                                  ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer
            _buildFooter(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Create Status Automation",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            splashRadius: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
        color: isDark ? const Color(0xFF1A1D2D) : Colors.white,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              if (_nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an automation name.')));
                return;
              }
              if (_selectedTemplateName == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a template.')));
                return;
              }
              if (_targetStatus == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a target status.')));
                return;
              }
              
              final templatesState = ref.read(whatsappTemplatesProvider);
              Map<String, dynamic> matchedTemplate = templatesState.templates.firstWhere(
                (t) => t['name'] == _selectedTemplateName,
                orElse: () => <String, dynamic>{},
              );

              if (matchedTemplate.isEmpty && widget.editRule != null) {
                final editTpl = widget.editRule!['template'];
                if (editTpl is Map<String, dynamic>) {
                  matchedTemplate = editTpl;
                }
              }

              if (matchedTemplate.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected template not found.'), backgroundColor: Colors.red));
                return;
              }

              final bool isUpdate = widget.editRule != null;
              final String? ruleId = widget.editRule?['_id'] ?? widget.editRule?['id'];

              final body = {
                'name': _nameCtrl.text,
                'eventType': 'LEAD_STATUS_CHANGED',
                'targetStatus': _targetStatus,
                'template': {
                  'name': _selectedTemplateName,
                  'language': matchedTemplate['language'] ?? 'en',
                  'components': matchedTemplate['components'] ?? [],
                },
                'variableMappings': _buildVariableMappings(matchedTemplate),
                'isActive': _isActive,
              };

              try {
                if (isUpdate && ruleId != null) {
                  await ref.read(whatsappAutomationsProvider.notifier).updateEventRule(ruleId, body);
                } else {
                  await ref.read(whatsappAutomationsProvider.notifier).createEventRule(body);
                }
                navigator.pop();
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(SnackBar(
                    content: Text('Failed: ${e.toString().replaceAll(RegExp(r'^Failed:\s*\d+\s*-\s*'), '')}'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue : Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(widget.editRule != null ? "UPDATE" : "CREATE", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          )
        ],
      ),
    );
  }
}
