import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/whatsapp_provider.dart';
import 'whatsapp_icon.dart';
import 'whatsapp_variable_selector.dart';
import 'whatsapp_preview_bubble.dart';

class WhatsAppSelectTemplateDialog extends ConsumerStatefulWidget {
  final String waId;
  const WhatsAppSelectTemplateDialog({super.key, required this.waId});

  @override
  ConsumerState<WhatsAppSelectTemplateDialog> createState() => _WhatsAppSelectTemplateDialogState();
}

class _WhatsAppSelectTemplateDialogState extends ConsumerState<WhatsAppSelectTemplateDialog> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedTemplate;
  final Map<int, String> _variableTypes = {};
  final Map<int, String> _customValues = {};
  bool _isSending = false;

  // Location header controllers
  final TextEditingController _sendLatitudeController = TextEditingController();
  final TextEditingController _sendLongitudeController = TextEditingController();
  final TextEditingController _sendPlaceNameController = TextEditingController();
  final TextEditingController _sendAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(whatsappTemplatesProvider.notifier).fetchTemplates();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sendLatitudeController.dispose();
    _sendLongitudeController.dispose();
    _sendPlaceNameController.dispose();
    _sendAddressController.dispose();
    super.dispose();
  }

  void _onTemplateSelected(Map<String, dynamic> template) {
    setState(() {
      _selectedTemplate = template;
      _variableTypes.clear();
      _customValues.clear();
      _sendLatitudeController.clear();
      _sendLongitudeController.clear();
      _sendPlaceNameController.clear();
      _sendAddressController.clear();

      final components = template['components'] as List?;
      final headerComp = components?.firstWhere((c) => c['type'] == 'HEADER', orElse: () => <String, dynamic>{});
      if (headerComp != null && headerComp['format'] == 'LOCATION') {
        _sendLatitudeController.text = (headerComp['latitude'] ?? '').toString();
        _sendLongitudeController.text = (headerComp['longitude'] ?? '').toString();
        _sendPlaceNameController.text = (headerComp['placeName'] ?? '').toString();
        _sendAddressController.text = (headerComp['address'] ?? '').toString();
      }

      // Initialize controllers for each variable
      final bodyText = _getBodyText(template);
      final varMatches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText);
      for (final match in varMatches) {
        final varNumber = int.tryParse(match.group(1) ?? '');
        if (varNumber != null && !_variableTypes.containsKey(varNumber)) {
          _variableTypes[varNumber] = 'custom';
        }
      }
    });
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

  String _getPreviewText() {
    if (_selectedTemplate == null) return '';
    String preview = _getBodyText(_selectedTemplate!);
    for (final entry in _variableTypes.entries) {
      final type = entry.value;
      String value = '';
      if (type == 'custom') {
        value = _customValues[entry.key] ?? '';
      } else {
        value = type;
      }
      if (value.isEmpty) value = '{{${entry.key}}}';
      preview = preview.replaceAll('{{${entry.key}}}', value);
    }
    return preview;
  }

  Map<String, dynamic>? getHeaderComponent() {
    final components = _selectedTemplate!['components'] as List?;
    if (components == null) return null;
    final header = components.cast<Map<String, dynamic>>().firstWhere(
      (c) => c['type'] == 'HEADER',
      orElse: () => <String, dynamic>{},
    );
    if (header.isEmpty) return null;
    final format = header['format'] as String?;
    if (format == 'IMAGE') {
      final example = _selectedTemplate!['example'] as Map?;
      final headerHandle = example?['header_handle'] as String?;
      if (headerHandle != null && headerHandle.isNotEmpty) {
        return {
          'type': 'HEADER',
          'parameters': [
            {
              'type': 'image',
              'image': {
                'link': headerHandle,
              },
            },
          ],
        };
      }
    }
    return null;
  }

  List<Map<String, dynamic>>? _getButtonsComponents() {
    final components = _selectedTemplate!['components'] as List?;
    if (components == null) return null;
    final buttonsComp = components.cast<Map<String, dynamic>>().firstWhere(
      (c) => c['type'] == 'BUTTONS',
      orElse: () => <String, dynamic>{},
    );
    if (buttonsComp.isEmpty) return null;
    final buttonsList = buttonsComp['buttons'] as List?;
    if (buttonsList == null) return null;

    final parameters = <Map<String, dynamic>>[];
    for (final btn in buttonsList) {
      final btnMap = btn as Map<String, dynamic>;
      final type = btnMap['type'] as String?;
      if (type == 'URL' && btnMap['url'] is String) {
        final url = btnMap['url'] as String;
        if (url.contains('{{')) {
          final match = RegExp(r'\{\{(\d+)\}\}').firstMatch(url);
          if (match != null) {
            final varNumber = int.parse(match.group(1)!);
            final text = _variableTypes[varNumber] == 'custom'
                ? _customValues[varNumber] ?? ''
                : (_variableTypes[varNumber] ?? '');
            parameters.add({
              'type': 'text',
              'text': text,
            });
          }
        }
      }
    }

    if (parameters.isEmpty) return null;

    return [
      {
        'type': 'button',
        'sub_type': 'url',
        'index': '0',
        'parameters': parameters,
      },
    ];
  }

  String? _getHeaderMediaUrl(Map<String, dynamic> headerComp) {
    final example = headerComp['example'] as Map?;
    if (example != null) {
      final handles = example['header_handle'];
      if (handles is List && handles.isNotEmpty) {
        return handles[0].toString();
      }
      if (handles is String && handles.isNotEmpty) {
        return handles;
      }
    }
    if (_selectedTemplate != null) {
      final topExample = _selectedTemplate!['example'] as Map?;
      if (topExample != null) {
        final handles = topExample['header_handle'];
        if (handles is List && handles.isNotEmpty) {
          return handles[0].toString();
        }
        if (handles is String && handles.isNotEmpty) {
          return handles;
        }
      }
    }
    return null;
  }

  Future<void> _sendTemplate() async {
    if (_selectedTemplate == null || _isSending) return;
    setState(() => _isSending = true);

    try {
      final components = <Map<String, dynamic>>[];

      // Extract Header if it's media (IMAGE, VIDEO, DOCUMENT) or LOCATION
      final headerComp = _selectedTemplate!['components']?.firstWhere(
        (c) => c['type'] == 'HEADER' || c['type'] == 'header',
        orElse: () => <String, dynamic>{},
      );
      if (headerComp != null) {
        final format = (headerComp['format'] ?? '').toString().toUpperCase();
        if (format == 'IMAGE' || format == 'VIDEO' || format == 'DOCUMENT') {
          final mediaUrl = _getHeaderMediaUrl(headerComp);
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            components.add({
              'type': 'header',
              'parameters': [
                {
                  'type': format.toLowerCase(),
                  format.toLowerCase(): {
                    'link': mediaUrl,
                  }
                }
              ]
            });
          }
        } else if (format == 'LOCATION') {
          components.add({
            'type': 'header',
            'parameters': [
              {
                'type': 'location',
                'location': {
                  'latitude': _sendLatitudeController.text.trim(),
                  'longitude': _sendLongitudeController.text.trim(),
                  'name': _sendPlaceNameController.text.trim().isNotEmpty 
                      ? _sendPlaceNameController.text.trim()
                      : 'Location',
                  'address': _sendAddressController.text.trim().isNotEmpty 
                      ? _sendAddressController.text.trim()
                      : 'Click to view',
                }
              }
            ]
          });
        }
      }

      // Build body component with parameters
      if (_variableTypes.isNotEmpty) {
        final parameters = _variableTypes.entries.map((e) {
          final type = e.value;
          final text = type == 'custom' ? _customValues[e.key] ?? '' : type;
          return {
            'type': 'text',
            'text': text,
          };
        }).toList();

        components.add({
          'type': 'body',
          'parameters': parameters,
        });
      }

      // Add BUTTONS component for dynamic URL buttons
      final buttonsComps = _getButtonsComponents();
      if (buttonsComps != null) {
        components.addAll(buttonsComps);
      }

      final payload = {
        'name': _selectedTemplate!['name'],
        'language': {
          'code': _selectedTemplate!['language'] ?? 'en_US',
        },
        if (components.isNotEmpty) 'components': components,
      };

      await ref.read(whatsappMessagesProvider.notifier).sendTemplateMessage(
        payload, 
        widget.waId,
        fullTemplate: _selectedTemplate,
        previewText: _getPreviewText(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            _buildHeader(isDark),
            const Divider(height: 1),
            Expanded(
              child: _selectedTemplate == null
                  ? _buildTemplateList(isDark)
                  : _buildVariableFiller(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF25D366),
            radius: 16,
            child: whatsAppIcon(size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WhatsApp Templates",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  "Select a template to send",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(bool isDark) {
    final state = ref.watch(whatsappTemplatesProvider);
    final templates = state.templates.where((t) {
      final name = (t['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchController.text.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search template...',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[500]),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => ref.read(whatsappTemplatesProvider.notifier).fetchTemplates(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: Text(
                  "REFRESH",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue.shade300 : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
                  ? Center(child: Text(state.error!))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: isDark ? const Color(0xFF2A2D3E) : Colors.white,
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: templates.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            return _buildTemplateCard(templates[index], isDark);
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template, bool isDark) {
    final String name = template['name'] ?? '';
    final String language = template['language'] ?? 'en_US';
    final String category = template['category'] ?? 'MARKETING';
    final bool isApproved = template['isApproved'] ?? false;
    final String status = (template['status'] ?? (isApproved ? 'APPROVED' : 'PENDING')).toString().toUpperCase();
    
    final bodyText = _getBodyText(template);
    final hasVariables = bodyText.contains('{{');
    final buttons = _getButtons(template);

    return InkWell(
      onTap: () => _onTemplateSelected(template),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: " - $status",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(Icons.description, size: 16, color: isDark ? Colors.white70 : Colors.black87),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPill(language, isDark),
                _buildPill(category, isDark),
                if (hasVariables) _buildPill("Has Variables", isDark),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              bodyText,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[800],
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildVariableFiller(bool isDark) {
    final name = _selectedTemplate!['name'] ?? '';
    final bodyText = _getBodyText(_selectedTemplate!);
    final varEntries = _variableTypes.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final headerComp = _selectedTemplate!['components']?.firstWhere(
      (c) => c['type'] == 'HEADER' || c['type'] == 'header',
      orElse: () => <String, dynamic>{},
    );
    final isLocationHeader = headerComp != null && headerComp['format'] == 'LOCATION';

    // Inject location coords/address into preview template representation
    final Map<String, dynamic> previewTpl = Map<String, dynamic>.from(_selectedTemplate!);
    if (isLocationHeader) {
      final comps = List<dynamic>.from(previewTpl['components'] ?? []);
      final headerIdx = comps.indexWhere((c) => c['type'] == 'HEADER' || c['type'] == 'header');
      if (headerIdx != -1) {
        final h = Map<String, dynamic>.from(comps[headerIdx]);
        h['placeName'] = _sendPlaceNameController.text;
        h['address'] = _sendAddressController.text;
        h['latitude'] = _sendLatitudeController.text;
        h['longitude'] = _sendLongitudeController.text;
        comps[headerIdx] = h;
      }
      previewTpl['components'] = comps;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button + template name
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        _selectedTemplate = null;
                        _variableTypes.clear();
                        _customValues.clear();
                      }),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_ios, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('Back', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                // Preview bubble
                WhatsAppPreviewBubble(
                  template: previewTpl,
                  bodyText: _getPreviewText().isNotEmpty ? _getPreviewText() : bodyText,
                  isDark: isDark,
                ),
                if (isLocationHeader) ...[
                  const SizedBox(height: 16),
                  Text('Location Header Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sendLatitudeController,
                          style: const TextStyle(fontSize: 13),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sendLongitudeController,
                          style: const TextStyle(fontSize: 13),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sendPlaceNameController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Place Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sendAddressController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
                if (varEntries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Fill Variables', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  ...varEntries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: WhatsAppVariableSelector(
                        mode: 'chat',
                        variableKey: e.key.toString(),
                        initialSource: _variableTypes[e.key] ?? 'recipient.name',
                        initialCustomValue: _customValues[e.key],
                        onChanged: (source, customValue) {
                          setState(() {
                            _variableTypes[e.key] = source;
                            if (customValue != null) {
                              _customValues[e.key] = customValue;
                            } else {
                              _customValues.remove(e.key);
                            }
                          });
                        },
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      "SEND TEMPLATE",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[300] : const Color(0xFF374151),
        ),
      ),
    );
  }
}
