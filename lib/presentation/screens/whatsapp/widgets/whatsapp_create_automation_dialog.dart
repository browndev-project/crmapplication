import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../providers/whatsapp_provider.dart';
import 'whatsapp_icon.dart';
import 'whatsapp_variable_selector.dart';
import '../../../providers/login_provider.dart';
import '../../../providers/dashboard_provider.dart';
import 'whatsapp_preview_bubble.dart';

class CreateAutomationDialog extends ConsumerStatefulWidget {
  final String triggerMode; // 'lead', 'meeting', 'visit'
  final Map<String, dynamic>? editRule;
  const CreateAutomationDialog({
    super.key,
    required this.triggerMode,
    this.editRule,
  });

  @override
  ConsumerState<CreateAutomationDialog> createState() =>
      _CreateAutomationDialogState();
}

class _CreateAutomationDialogState
    extends ConsumerState<CreateAutomationDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _metaFormIdCtrl = TextEditingController();
  bool _isActive = true;
  String? _selectedTemplateName;
  String _activeTab = 'default';

  // Location header controllers
  final TextEditingController _locationLatitudeCtrl = TextEditingController();
  final TextEditingController _locationLongitudeCtrl = TextEditingController();
  final TextEditingController _locationPlaceNameCtrl = TextEditingController();
  final TextEditingController _locationAddressCtrl = TextEditingController();

  /// Returns a canonical key (lowercased, trimmed, underscored/hyphens replaced with spaces)
  /// for case-insensitive source name comparison.
  static String _sourceKey(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-\s]+'), ' ');
  }

  /// Normalizes a source name to its display form, handling common case/spelling variants.
  static String _normalizeSourceName(String name) {
    switch (_sourceKey(name)) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'meta ads' || 'meta':
        return 'Meta Ads';
      case 'website':
        return 'Website';
      case 'ivr':
        return 'IVR';
      case 'referral':
        return 'Referral';
      case 'justdial':
        return 'Justdial';
      case 'tradeindia':
        return 'Tradeindia';
      case 'sulekha':
        return 'Sulekha';
      default:
        return name;
    }
  }

  // For Incoming Leads
  List<String> get _allSources {
    final dashState = ref.read(dashboardProvider);
    final unique = <String>{};
    void addSource(String name) {
      final normalized = _normalizeSourceName(name);
      // Use canonical key for dedup
      final key = _sourceKey(normalized);
      unique.removeWhere((s) => _sourceKey(s) == key);
      unique.add(normalized);
    }

    if (dashState.data?.leadSources?.sources case final sources?) {
      for (final key in sources.keys) {
        addSource(key.toString());
      }
    }
    for (final name in [
      'Website',
      'Meta Ads',
      'WhatsApp',
      'IVR',
      'Referral',
      'Justdial',
      'Tradeindia',
      'Sulekha',
      'Other',
    ]) {
      addSource(name);
    }
    return unique.toList()..sort();
  }

  /// Returns canonical keys (lowercased) of sources assigned to other automations.
  Set<String> get _sourcesInOtherRules {
    final rules = ref.read(whatsappAutomationsProvider).incomingLeadsRules;
    final set = <String>{};
    final currentId =
        widget.editRule?['_id'] ?? widget.editRule?['id'];
    for (final rule in rules) {
      if (currentId != null &&
          (rule['_id'] == currentId ||
              rule['id'] == currentId)) {
        continue;
      }
      final sources = rule['leadSources'] as List?;
      if (sources != null) {
        for (var s in sources) {
          set.add(_sourceKey(s.toString()));
        }
      }
    }
    // Fallback to cache when backend data is empty
    if (set.isEmpty) {
      for (final mapping in _cachedMappings) {
        final mid = mapping['automationId']?.toString() ?? '';
        if (currentId != null && mid == currentId.toString()) continue;
        final sources = mapping['sources'] as List?;
        if (sources != null) {
          for (var s in sources) {
            set.add(_sourceKey(s.toString()));
          }
        }
      }
    }
    return set;
  }

  /// Cached automation-to-source mappings loaded from Hive.
  List<Map<String, dynamic>> _cachedMappings = [];

  /// Loads automation source mappings from Hive cache.
  void _loadMappingsCache() {
    try {
      if (Hive.isBoxOpen('authBox')) {
        final data = Hive.box('authBox').get('automationSourceMappings');
        if (data is String && data.isNotEmpty) {
          final list = jsonDecode(data) as List;
          _cachedMappings =
              list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
  }

  /// Returns display names following the filtering logic:
  /// - Always show sources belonging to the current automation (edit mode).
  /// - Never show sources assigned to other automations.
  /// - Show all unassigned sources.
  List<String> get _displaySources {
    final currentSourceKeys = <String>{};
    if (widget.editRule != null) {
      final sources = widget.editRule!['leadSources'] as List?;
      if (sources != null) {
        for (var s in sources) {
          currentSourceKeys.add(_sourceKey(s.toString()));
        }
      }
    }

    final otherKeys = _sourcesInOtherRules;

    return _allSources.where((source) {
      final key = _sourceKey(source);
      if (currentSourceKeys.contains(key)) return true;
      if (otherKeys.contains(key)) return false;
      return true;
    }).toList();
  }

  final Set<String> _selectedSources = {};

  // For Meetings
  String? _selectedEvent;

  final Map<String, String> _variableMappings = {};
  final Map<String, String> _customValues = {};

  // Form Overrides
  final List<Map<String, dynamic>> _formOverrides = [];
  bool _isLoadingForms = false;

  List<dynamic> _metaPages = [];
  final List<dynamic> _metaForms = [];
  List<dynamic> _websiteForms = [];

  String get _defaultVariableSource =>
      widget.triggerMode == 'marketing' ? 'recipient.name' : 'lead.name';

  /// Returns the allowed variable source prefix for the current trigger mode
  String get _allowedVariablePrefix {
    switch (widget.triggerMode) {
      case 'meeting':
        return 'meeting.';
      case 'visit':
        return 'visit.';
      case 'lead':
      case 'status':
      default:
        return 'lead.';
    }
  }

  /// Ensure the source remains a backend-supported automation value.
  String _normalizeVariableSource(String source) {
    if (source == 'custom') return 'custom';
    if (source.startsWith('lead.')) return source;
    if (source.startsWith(_allowedVariablePrefix)) return source;
    return _defaultVariableSource;
  }

  String _componentType(dynamic component) => component is Map
      ? (component['type'] ?? '').toString().toUpperCase()
      : '';

  bool _isWebsiteFormId(String? id) {
    final value = id?.trim() ?? '';
    return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(value);
  }

  String _resolveOverrideType(Map<String, dynamic> override) {
    final explicitType = (override['type']?.toString() ?? '').toUpperCase();
    if (explicitType == 'META' || explicitType == 'WEBSITE') {
      return explicitType;
    }

    final source = (override['source']?.toString() ?? '').toLowerCase();
    if (source.contains('meta')) {
      return 'META';
    }
    if (source.contains('website')) {
      return 'WEBSITE';
    }

    if (override.containsKey('pageId') && override['pageId'] != null) {
      return 'META';
    }

    if (override.containsKey('formId') && override['formId'] != null) {
      return _isWebsiteFormId(override['formId'].toString())
          ? 'WEBSITE'
          : 'META';
    }

    return 'META';
  }

  String _defaultSourceForOverrideType(String type) {
    return type == 'WEBSITE' ? 'Website' : 'Meta Ads';
  }

  @override
  void initState() {
    super.initState();

    // Load cached automation source mappings from Hive
    _loadMappingsCache();

    if (widget.editRule != null) {
      _nameCtrl.text = widget.editRule!['name'] ?? '';
      _isActive = widget.editRule!['isActive'] ?? true;
      _selectedTemplateName = widget.editRule!['template']?['name'];
      _activeTab = 'default';

      if (widget.triggerMode != 'lead') {
        _selectedEvent = widget.editRule!['eventType'];
      } else {
        final sources = widget.editRule!['leadSources'] as List?;
        if (sources != null) {
          _selectedSources.addAll(sources.map((e) => _normalizeSourceName(e.toString())));
        }

        final overrides = widget.editRule!['formOverrides'] as List?;
        if (overrides != null) {
          try {
            _formOverrides.addAll(
              overrides.map((e) {
                final map = Map<String, dynamic>.from(e);
                final inferredType = _resolveOverrideType(map);
                map['type'] = inferredType;
                map['source'] = (map['source']?.toString() ?? '').isNotEmpty
                    ? map['source'].toString()
                    : _defaultSourceForOverrideType(inferredType);
                map['isExpanded'] = map['isExpanded'] ?? true;
                if (map['variableMappings'] != null) {
                  map['variableMappings'] = List<Map<String, dynamic>>.from(
                    (map['variableMappings'] as List).map(
                      (m) => Map<String, dynamic>.from(m),
                    ),
                  );
                } else {
                  map['variableMappings'] = <Map<String, dynamic>>[];
                }
                return map;
              }),
            );
          } catch (e) {
            debugPrint(
              '[CreateAutomationDialog] Error loading form overrides: $e',
            );
          }
        }
      }

      final mappings = widget.editRule!['variableMappings'] as List?;
      if (mappings != null) {
        for (var m in mappings) {
          final key = m['key'].toString();
          _variableMappings[key] = _normalizeVariableSource(
              m['source'] as String? ?? _defaultVariableSource);
          if (m['customValue'] != null) {
            _customValues[key] = m['customValue'].toString();
          }
        }
      }

      final templateMap = widget.editRule!['template'];
      if (templateMap != null && templateMap['components'] != null) {
        final comps = templateMap['components'] as List;
        final headerComp = comps.firstWhere(
          (c) => _componentType(c) == 'HEADER',
          orElse: () => <String, dynamic>{},
        );
        if (headerComp != null && headerComp['format'] == 'LOCATION') {
          _locationLatitudeCtrl.text = (headerComp['latitude'] ?? '')
              .toString();
          _locationLongitudeCtrl.text = (headerComp['longitude'] ?? '')
              .toString();
          _locationPlaceNameCtrl.text = (headerComp['placeName'] ?? '')
              .toString();
          _locationAddressCtrl.text = (headerComp['address'] ?? '').toString();
        }
      }
    }

    if (widget.triggerMode == 'lead') {
      _fetchInitialFormData();
    }
  }

  Future<void> _fetchInitialFormData() async {
    setState(() => _isLoadingForms = true);
    try {
      final service = ref.read(whatsappServiceProvider);
      final automationsNotifier = ref.read(whatsappAutomationsProvider.notifier);

      // Load existing rules so _sourcesInOtherRules is populated
      await automationsNotifier.fetchIncomingLeadsRules();
      // Cache is automatically persisted by the provider after fetch.
      // Reload into dialog state for instant filtering.
      _loadMappingsCache();

      final user = ref.read(loginProvider).user;
      final companyId = user?.company;

      if (companyId != null) {
        final metaStatus = await service.fetchMetaIntegrationStatus(companyId);
        if (metaStatus['success'] == true) {
          _metaPages = metaStatus['data']?['connectedPages'] ?? [];

          _metaForms.clear();

          final futures = _metaPages.map((page) async {
            final pageId = page['pageId'].toString();
            try {
              final res = await service.fetchMetaPageForms(pageId);
              if (res['success'] == true) {
                final forms = res['forms'] as List? ?? [];
                return forms
                    .map(
                      (f) => {
                        ...Map<String, dynamic>.from(f),
                        'pageId': pageId,
                        'pageName': page['pageName'] ?? 'Unnamed Page',
                      },
                    )
                    .toList();
              }
            } catch (e) {
              debugPrint('Error fetching forms for page $pageId: $e');
            }
            return <Map<String, dynamic>>[];
          });

          final results = await Future.wait(futures);
          for (var list in results) {
            _metaForms.addAll(list);
          }
        }
      }

      final webForms = await service.fetchWebsiteIntegrationForms();
      if (webForms['success'] == true) {
        _websiteForms = webForms['data']?['forms'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching forms for overrides: $e');
    } finally {
      if (mounted) setState(() => _isLoadingForms = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _metaFormIdCtrl.dispose();
    _locationLatitudeCtrl.dispose();
    _locationLongitudeCtrl.dispose();
    _locationPlaceNameCtrl.dispose();
    _locationAddressCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildVariableMappings(
    Map<String, dynamic> template,
  ) {
    final bodyComp = (template['components'] as List?)?.firstWhere(
      (c) => _componentType(c) == 'BODY',
      orElse: () => <String, dynamic>{},
    );
    final bodyText = (bodyComp is Map && bodyComp.isNotEmpty)
        ? (bodyComp['text'] ?? '')
        : '';
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText as String);
    if (matches.isEmpty) return [];
    return matches.map((m) {
      final key = m.group(1)!;
      final source = _variableMappings[key] ?? _defaultVariableSource;
      return {
        'key': key,
        'source': source,
        if (_customValues[key] != null) 'customValue': _customValues[key],
      };
    }).toList();
  }

  String _getBodyText(Map<String, dynamic> template) {
    final components = template['components'] as List?;
    final bodyComp = components?.firstWhere(
      (c) => _componentType(c) == 'BODY',
      orElse: () => <String, dynamic>{},
    );
    return (bodyComp is Map && bodyComp.isNotEmpty)
        ? (bodyComp['text'] ?? '')
        : '';
  }

  List<String> _getButtons(Map<String, dynamic> template) {
    final components = template['components'] as List?;
    final buttonsComp = components?.firstWhere(
      (c) => _componentType(c) == 'BUTTONS',
      orElse: () => <String, dynamic>{},
    );
    if (buttonsComp == null || (buttonsComp is Map && buttonsComp.isEmpty)) {
      return [];
    }
    final buttonsList = buttonsComp['buttons'] as List?;
    if (buttonsList == null) return [];
    return buttonsList.map((b) => (b['text'] ?? '').toString()).toList();
  }

  String _getPreviewText(Map<String, dynamic>? template) {
    if (template == null) return '';
    String preview = _getBodyText(template);
    final mappings = _buildVariableMappings(template);

    String getDisplayValue(String source) {
      switch (source) {
        case 'recipient.name':
          return 'Recipient Name';
        case 'recipient.phone':
          return 'Recipient Phone';
        default:
          return source;
      }
    }

    for (var m in mappings) {
      preview = preview.replaceAll(
        '{{${m['key']}}}',
        getDisplayValue(m['source']),
      );
    }
    return preview;
  }

  Widget _buildTemplateCard(
    Map<String, dynamic> t,
    bool isSelected,
    bool isDark,
  ) {
    final bText = _getBodyText(t);
    final buttons = _getButtons(t);
    final hasVariables = bText.contains(RegExp(r'\{\{\d+\}\}'));

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTemplateName = t['name'];
          _locationLatitudeCtrl.clear();
          _locationLongitudeCtrl.clear();
          _locationPlaceNameCtrl.clear();
          _locationAddressCtrl.clear();

          final components = t['components'] as List?;
          final headerComp = components?.firstWhere(
            (c) => _componentType(c) == 'HEADER',
            orElse: () => <String, dynamic>{},
          );
          if (headerComp != null && headerComp['format'] == 'LOCATION') {
            _locationLatitudeCtrl.text = (headerComp['latitude'] ?? '')
                .toString();
            _locationLongitudeCtrl.text = (headerComp['longitude'] ?? '')
                .toString();
            _locationPlaceNameCtrl.text = (headerComp['placeName'] ?? '')
                .toString();
            _locationAddressCtrl.text = (headerComp['address'] ?? '')
                .toString();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
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
                    color: isDark
                        ? const Color(0xFF1E2B22)
                        : const Color(0xFFD9FDD3),
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
                          color: (t['status'] == 'APPROVED')
                              ? Colors.green
                              : Colors.orange,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t['language'] ?? 'en_US',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (t['category'] ?? 'UTILITY').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (hasVariables)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Has Variables",
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
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
        constraints: const BoxConstraints(maxWidth: 900),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
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
                      if (widget.triggerMode == 'lead') ...[
                        // TOP TRIGGER SECTION
                        _buildTopTriggerSection(isDark),
                        const SizedBox(height: 16),
                        _buildTabBar(isDark, [
                          {'id': 'default', 'label': 'DEFAULT CONFIGURATION'},
                          if (_selectedSources.contains('Meta Ads') ||
                              _formOverrides.any(
                                (o) => _resolveOverrideType(o) == 'META',
                              ))
                            {'id': 'meta', 'label': 'META FORM OVERRIDES'},
                          if (_selectedSources.contains('Website') ||
                              _formOverrides.any(
                                (o) => _resolveOverrideType(o) == 'WEBSITE',
                              ))
                            {
                              'id': 'website',
                              'label': 'WEBSITE FORM OVERRIDES',
                            },
                          if (_formOverrides.isNotEmpty &&
                              !_selectedSources.contains('Meta Ads') &&
                              !_selectedSources.contains('Website') &&
                              _formOverrides.every((o) {
                                final t = _resolveOverrideType(o);
                                return t != 'META' && t != 'WEBSITE';
                              }))
                            {'id': 'overrides', 'label': 'FORM OVERRIDES'},
                        ]),
                        const SizedBox(height: 24),

                        // TAB CONTENT
                        if (_activeTab == 'default') ...[
                          // Alert Box
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.05),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: "Important: ",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              "Setting a default template is mandatory. This template will be used for all selected lead sources (use the override tabs for Meta or Website form specific automations).",
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_formOverrides.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.blue.withValues(alpha: 0.08)
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.blue.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 16,
                                    color: isDark
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_formOverrides.length} form override${_formOverrides.length == 1 ? '' : 's'} configured. Switch to the override tab${_formOverrides.where((o) => o['type'] == 'WEBSITE').isNotEmpty && _formOverrides.where((o) => o['type'] == 'META').isNotEmpty ? 's' : ''} above to edit them.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.blue.shade200
                                            : Colors.blue.shade800,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 650) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _buildDefaultConfigLeft(
                                        isDark,
                                        templatesState,
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      flex: 4,
                                      child: _buildLivePreviewRightColumn(
                                        isDark,
                                        templatesState,
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    _buildDefaultConfigLeft(
                                      isDark,
                                      templatesState,
                                    ),
                                    const SizedBox(height: 32),
                                    _buildLivePreviewRightColumn(
                                      isDark,
                                      templatesState,
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ] else if (_activeTab == 'meta') ...[
                          _buildOverridesTabContent(
                            'META',
                            isDark,
                            templatesState,
                          ),
                        ] else if (_activeTab == 'website') ...[
                          _buildOverridesTabContent(
                            'WEBSITE',
                            isDark,
                            templatesState,
                          ),
                        ] else if (_activeTab == 'overrides') ...[
                          _buildCombinedOverridesTab(isDark, templatesState),
                        ],
                      ] else ...[
                        // ORIGINAL LAYOUT FOR NON-LEAD
                        _buildTopTriggerSection(isDark),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Divider(color: Colors.grey, height: 1),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 600) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _buildConfigLeftColumn(
                                      isDark,
                                      templatesState,
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    flex: 4,
                                    child: _buildLivePreviewRightColumn(
                                      isDark,
                                      templatesState,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  _buildConfigLeftColumn(
                                    isDark,
                                    templatesState,
                                  ),
                                  const SizedBox(height: 32),
                                  _buildLivePreviewRightColumn(
                                    isDark,
                                    templatesState,
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ],
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

  Widget _buildTopTriggerSection(bool isDark) {
    if (widget.triggerMode == 'meeting' || widget.triggerMode == 'visit') {
      List<DropdownMenuItem<String>> eventItems =
          widget.triggerMode == 'meeting'
          ? const [
              DropdownMenuItem(
                value: 'MEETING_CREATED',
                child: Text('Meeting Created', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'MEETING_RESCHEDULED',
                child: Text(
                  'Meeting Rescheduled',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              DropdownMenuItem(
                value: 'MEETING_COMPLETED',
                child: Text(
                  'Meeting Completed',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              DropdownMenuItem(
                value: 'MEETING_CANCELLED',
                child: Text(
                  'Meeting Cancelled',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              DropdownMenuItem(
                value: 'MEETING_REMINDER_30_MIN',
                child: Text(
                  'Reminder 30 Minutes before meeting',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              DropdownMenuItem(
                value: 'MEETING_REMINDER_15_MIN',
                child: Text(
                  'Reminder 15 Minutes before meeting',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ]
          : const [
              DropdownMenuItem(
                value: 'VISIT_CREATED',
                child: Text('Visit Created', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'VISIT_RESCHEDULED',
                child: Text(
                  'Visit Rescheduled',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              DropdownMenuItem(
                value: 'VISIT_CANCELLED',
                child: Text('Visit Cancelled', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'VISIT_COMPLETED',
                child: Text('Visit Completed', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'VISIT_REMINDER_DAY_BEFORE',
                child: Text(
                  'Day Before Reminder (8:00 PM)',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              DropdownMenuItem(
                value: 'VISIT_REMINDER_MORNING',
                child: Text(
                  'Visit Day Reminder (9:30 AM)',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              DropdownMenuItem(
                value: 'VISIT_REMINDER_1_HOUR',
                child: Text(
                  'Reminder 1 Hour Before Visit',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ];

      return _buildSection('Trigger Event Type', [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
            borderRadius: BorderRadius.circular(4),
            color: isDark ? const Color(0xFF25293C) : Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEvent,
                    isExpanded: true,
                    hint: Text(
                      "Select Event Type",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    items: eventItems,
                    onChanged: (val) {
                      setState(() {
                        _selectedEvent = val;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.triggerMode == 'meeting'
              ? "Only one active automation is recommended per event type. Messages send only when a meeting has \"Send on WhatsApp\" enabled."
              : "Only one active automation is recommended per event type. Messages send when visit events occur.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ]);
    } else {
      return _buildSection('Trigger Conditions', [
        Row(
          children: [
            const Text(
              "Target Lead Sources",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                "Multiple Select",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF25293C) : Colors.white,
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            children: _displaySources.map((source) {
              final sourceKey = _sourceKey(source);
              final isAssignedElsewhere = _sourcesInOtherRules.contains(sourceKey);
              final isChecked = _selectedSources.any((s) => _sourceKey(s) == sourceKey);
              final bool disabled = isAssignedElsewhere && !isChecked;
              return Opacity(
                opacity: disabled ? 0.5 : 1.0,
                child: SizedBox(
                  width: 160,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: Colors.black,
                          onChanged: disabled
                              ? null
                              : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedSources.add(source);
                                    } else {
                                      _selectedSources.remove(source);
                                      if (source == 'Website' &&
                                          _activeTab == 'website') {
                                        _activeTab = 'default';
                                      } else if (source == 'Meta Ads' &&
                                          _activeTab == 'meta') {
                                        _activeTab = 'default';
                                      }
                                    }
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source,
                              style: TextStyle(
                                fontSize: 12,
                                color: disabled
                                    ? Colors.grey
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                decoration: disabled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isAssignedElsewhere)
                              Text(
                                isChecked
                                    ? 'Currently assigned here'
                                    : 'This source is already assigned to another automation.',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isChecked
                                      ? Colors.green.shade400
                                      : Colors.red.shade400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "This automation will only trigger for leads coming from the selected sources.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ]);
    }
  }

  Widget _buildConfigLeftColumn(bool isDark, dynamic templatesState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Automation Configuration', [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Automation Name',
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF25293C) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade400,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade400,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF25293C) : Colors.white,
                  border: Border.all(
                    color: _isActive ? Colors.green : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Text(
                      _isActive ? "ACTIVE" : "INACTIVE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 24,
                      width: 40,
                      child: Switch(
                        value: _isActive,
                        activeThumbColor: Colors.green,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 24),
        if (widget.triggerMode == 'lead') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      children: const [
                        TextSpan(
                          text: "Important: ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        TextSpan(
                          text:
                              "Setting a default template is mandatory. This template will be used for all selected lead sources (in case of Meta Ads, use the Form-Specific Overrides tab for Meta forms specific automations).",
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 24),
        _buildSection('Approved Templates', [
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF25293C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(
              builder: (context) {
                final filteredTemplates = (templatesState.templates as List)
                    .where((t) => t['status'] != 'REJECTED')
                    .toList();
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filteredTemplates.length,
                  itemBuilder: (context, index) {
                    final t = filteredTemplates[index];
                    final bool isSelected = _selectedTemplateName == t['name'];
                    return _buildTemplateCard(t, isSelected, isDark);
                  },
                );
              },
            ),
          ),
        ]),
        if (_selectedTemplateName != null) ...[
          const SizedBox(height: 24),
          _buildLocationHeaderSection(isDark, templatesState),
          const SizedBox(height: 24),
          _buildVariablesSection(isDark, templatesState),
        ],
      ],
    );
  }

  Widget _buildLocationHeaderSection(bool isDark, dynamic templatesState) {
    final idx = (templatesState.templates as List).indexWhere(
      (t) => t['name'] == _selectedTemplateName,
    );
    if (idx == -1) return const SizedBox.shrink();
    final t = templatesState.templates[idx] as Map<String, dynamic>;

    final components = t['components'] as List?;
    final headerComp = components?.firstWhere(
      (c) => _componentType(c) == 'HEADER',
      orElse: () => <String, dynamic>{},
    );
    final isLocationHeader =
        headerComp != null && headerComp['format'] == 'LOCATION';
    if (!isLocationHeader) return const SizedBox.shrink();

    return _buildSection('LOCATION HEADER DETAILS', [
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _locationLatitudeCtrl,
              style: const TextStyle(fontSize: 13),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _locationLongitudeCtrl,
              style: const TextStyle(fontSize: 13),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
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
              controller: _locationPlaceNameCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Place Name',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _locationAddressCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _buildVariablesSection(bool isDark, dynamic templatesState) {
    final idx = (templatesState.templates as List).indexWhere(
      (t) => t['name'] == _selectedTemplateName,
    );
    if (idx == -1) return const SizedBox.shrink();
    final t = templatesState.templates[idx] as Map<String, dynamic>;

    final components = t['components'] as List?;
    final bodyComp = components?.firstWhere(
      (c) => _componentType(c) == 'BODY',
      orElse: () => <String, dynamic>{},
    );
    final bodyText = (bodyComp is Map) ? (bodyComp['text'] ?? '') : '';
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText as String);
    if (matches.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      'BODY VARIABLES',
      matches.map((m) {
        final key = m.group(1)!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: WhatsAppVariableSelector(
            mode: widget.triggerMode,
            variableKey: key,
            initialSource: _variableMappings[key] ?? _defaultVariableSource,
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
      }).toList(),
    );
  }

  Widget _buildLivePreviewRightColumn(bool isDark, dynamic templatesState) {
    Map<String, dynamic>? previewTpl;
    if (_selectedTemplateName != null) {
      final matched = (templatesState.templates as List).firstWhere(
        (t) => t['name'] == _selectedTemplateName,
        orElse: () => <String, dynamic>{},
      );
      if (matched != null) {
        previewTpl = Map<String, dynamic>.from(matched);
        final components = previewTpl['components'] as List?;
        final headerComp = components?.firstWhere(
          (c) => _componentType(c) == 'HEADER',
          orElse: () => <String, dynamic>{},
        );
        final isLocationHeader =
            headerComp != null && headerComp['format'] == 'LOCATION';
        if (isLocationHeader) {
          final newComps = (previewTpl['components'] as List).map((comp) {
            if (_componentType(comp) == 'HEADER') {
              final c = Map<String, dynamic>.from(comp);
              c['placeName'] = _locationPlaceNameCtrl.text;
              c['address'] = _locationAddressCtrl.text;
              c['latitude'] = _locationLatitudeCtrl.text;
              c['longitude'] = _locationLongitudeCtrl.text;
              return c;
            }
            return comp;
          }).toList();
          previewTpl['components'] = newComps;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "LIVE PREVIEW",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 400),
          decoration: BoxDecoration(
            color: const Color(0xFFE4DDD6),
            borderRadius: BorderRadius.circular(12),
            image: const DecorationImage(
              image: NetworkImage(
                'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
              ),
              repeat: ImageRepeat.repeat,
              opacity: 0.4,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _selectedTemplateName == null || previewTpl == null
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.smartphone,
                          size: 32,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Select a template to view the preview",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : WhatsAppPreviewBubble(
                    template: previewTpl,
                    bodyText: _getPreviewText(previewTpl),
                    isDark: isDark,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.triggerMode == 'meeting'
                ? "Create Meeting Automation"
                : widget.triggerMode == 'visit'
                ? "Create Visit Automation"
                : "Create Automation",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
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
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        color: isDark ? const Color(0xFF1A1D2D) : Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
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
            child: Text(
              "CANCEL",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              if (_nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an automation name.'),
                  ),
                );
                return;
              }
              if (_selectedTemplateName == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a template.')),
                );
                return;
              }

              final templatesState = ref.read(whatsappTemplatesProvider);
              Map<String, dynamic> matchedTemplate = templatesState.templates
                  .firstWhere(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selected template not found.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final bool isUpdate = widget.editRule != null;
              final String? ruleId =
                  widget.editRule?['_id'] ?? widget.editRule?['id'];

              final List<dynamic> matchedComponents = List.from(
                matchedTemplate['components'] ?? [],
              );
              final headerComp = matchedComponents.firstWhere(
                (c) => _componentType(c) == 'HEADER',
                orElse: () => <String, dynamic>{},
              );
              final isLocationHeader =
                  headerComp != null && headerComp['format'] == 'LOCATION';
              if (isLocationHeader) {
                for (int i = 0; i < matchedComponents.length; i++) {
                  if (_componentType(matchedComponents[i]) == 'HEADER') {
                    final h = Map<String, dynamic>.from(matchedComponents[i]);
                    h['placeName'] = _locationPlaceNameCtrl.text.trim();
                    h['address'] = _locationAddressCtrl.text.trim();
                    h['latitude'] = _locationLatitudeCtrl.text.trim();
                    h['longitude'] = _locationLongitudeCtrl.text.trim();
                    matchedComponents[i] = h;
                    break;
                  }
                }
              }

              try {
                if (widget.triggerMode != 'lead') {
                  if (_selectedEvent == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a trigger event.'),
                      ),
                    );
                    return;
                  }
                  final body = {
                    'name': _nameCtrl.text,
                    'eventType': _selectedEvent,
                    'template': {
                      'name': _selectedTemplateName,
                      'language': matchedTemplate['language'] ?? 'en',
                      'components': matchedComponents,
                    },
                    'variableMappings': _buildVariableMappings(matchedTemplate),
                    'isActive': _isActive,
                  };
                  if (isUpdate && ruleId != null) {
                    await ref
                        .read(whatsappAutomationsProvider.notifier)
                        .updateEventRule(ruleId, body);
                  } else {
                    await ref
                        .read(whatsappAutomationsProvider.notifier)
                        .createEventRule(body);
                  }
                } else {
                  if (_selectedSources.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please select at least one lead source.',
                        ),
                      ),
                    );
                    return;
                  }
                  final body = {
                    'name': _nameCtrl.text,
                    'leadSources': _selectedSources.toList(),
                    if (_selectedSources.contains('Meta Ads') &&
                        _metaFormIdCtrl.text.trim().isNotEmpty)
                      'metaFormId': _metaFormIdCtrl.text.trim(),
                    'formOverrides': _formOverrides.map((o) {
                      final copy = Map<String, dynamic>.from(o);
                      final resolvedType = _resolveOverrideType(copy);
                      copy['type'] = resolvedType;
                      copy['source'] =
                          (copy['source']?.toString() ?? '').isNotEmpty
                          ? copy['source'].toString()
                          : _defaultSourceForOverrideType(resolvedType);
                      if (copy['variableMappings'] is List) {
                        copy['variableMappings'] = (copy['variableMappings'] as List)
                            .map((m) => Map<String, dynamic>.from(m))
                            .map((m) => {
                                  'key': m['key'].toString(),
                                  'source': _normalizeVariableSource(
                                      m['source'] as String? ?? _defaultVariableSource),
                                  if (m['customValue'] != null)
                                    'customValue': m['customValue'].toString(),
                                })
                            .toList();
                      }
                      copy.remove('isExpanded');
                      return copy;
                    }).toList(),
                    'template': {
                      'name': _selectedTemplateName,
                      'language': matchedTemplate['language'] ?? 'en',
                      'components': matchedComponents,
                    },
                    'variableMappings': _buildVariableMappings(matchedTemplate),
                    'isActive': _isActive,
                  };
                  if (isUpdate && ruleId != null) {
                    await ref
                        .read(whatsappAutomationsProvider.notifier)
                        .updateIncomingLeadsRule(ruleId, body);
                  } else {
                    await ref
                        .read(whatsappAutomationsProvider.notifier)
                        .createIncomingLeadsRule(body);
                  }
                  // Cache is automatically refreshed by the provider after the
                }
                navigator.pop();
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed: ${e.toString().replaceAll(RegExp(r'^Failed:\s*\d+\s*-\s*'), '')}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              widget.editRule != null ? "UPDATE" : "CREATE",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultConfigLeft(bool isDark, dynamic templatesState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "DEFAULT MESSAGE SETTINGS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 16),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF25293C) : Colors.white,
                border: Border.all(
                  color: _isActive ? Colors.green : Colors.grey.shade400,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    _isActive ? "ACTIVE" : "INACTIVE",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 24,
                    width: 40,
                    child: Switch(
                      value: _isActive,
                      activeThumbColor: Colors.green,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection('Approved Templates', [
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF25293C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
            child: Builder(
              builder: (context) {
                final filteredTemplates = (templatesState.templates as List)
                    .where((t) => t['status'] != 'REJECTED')
                    .toList();
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filteredTemplates.length,
                  itemBuilder: (context, index) {
                    final t = filteredTemplates[index];
                    final bool isSelected = _selectedTemplateName == t['name'];
                    return _buildTemplateCard(t, isSelected, isDark);
                  },
                );
              },
            ),
          ),
        ]),
        if (_selectedTemplateName != null) ...[
          const SizedBox(height: 24),
          _buildLocationHeaderSection(isDark, templatesState),
          const SizedBox(height: 24),
          _buildVariablesSection(isDark, templatesState),
        ],
      ],
    );
  }

  Widget _buildTabBar(bool isDark, List<Map<String, String>> tabs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _activeTab == tab['id'];
            return InkWell(
              onTap: () => setState(() => _activeTab = tab['id']!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Text(
                  tab['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.grey[500],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOverridesTabContent(
    String type,
    bool isDark,
    dynamic templatesState,
  ) {
    final title = type == 'META'
        ? 'META Ads FORM-SPECIFIC OVERRIDES'
        : 'WEBSITE FORM-SPECIFIC OVERRIDES';
    final addBtnLabel = type == 'META'
        ? 'ADD FORM-SPECIFIC OVERRIDE'
        : 'ADD WEBSITE FORM OVERRIDE';
    final subtitle = type == 'META'
        ? 'Overrides allow you to send a different message for specific forms. Forms not listed here will use the default template above.'
        : 'Overrides allow you to send a different message for specific website forms. Forms not listed here will use the default template above.';

    final typeOverrides = _formOverrides
        .where((o) => _resolveOverrideType(o) == type)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        if (typeOverrides.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF25293C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.alt_route, color: Colors.grey.shade400, size: 32),
                const SizedBox(height: 12),
                Text(
                  type == 'META'
                      ? "No Meta Ads overrides configured. Click the button below to add one."
                      : "No Website overrides configured. Click the button below to add one.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ...typeOverrides.asMap().entries.map((entry) {
            final override = entry.value;
            final mainIdx = _formOverrides.indexOf(override);
            return _buildInlineOverrideCard(
              mainIdx,
              override,
              isDark,
              templatesState,
            );
          }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _formOverrides.add({
                  'type': type,
                  'source': _defaultSourceForOverrideType(type),
                  'pageId': null,
                  'formId': null,
                  'formName': null,
                  'template': null,
                  'variableMappings': <Map<String, dynamic>>[],
                  'isActive': true,
                  'isExpanded': true,
                });
              });
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              addBtnLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black87,
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedOverridesTab(bool isDark, dynamic templatesState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FORM OVERRIDES',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        ..._formOverrides.asMap().entries.map((entry) {
          final mainIdx = entry.key;
          final override = entry.value;
          return _buildInlineOverrideCard(
            mainIdx,
            override,
            isDark,
            templatesState,
          );
        }),
        const SizedBox(height: 16),
        Text(
          'Overrides allow you to send a different message for specific forms. Forms not listed here will use the default template above.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineOverrideCard(
    int mainIdx,
    Map<String, dynamic> override,
    bool isDark,
    dynamic templatesState,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF25293C) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, cardConstraints) {
          final isExpanded = override['isExpanded'] == true;
          final type = _resolveOverrideType(override);
          final formName = override['formName'] as String? ?? 'Select a Form';
          final isActive = override['isActive'] != false;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    override['isExpanded'] = !isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Choose which form this template triggers for",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cardConstraints.maxWidth > 420) ...[
                            Text(
                              isActive ? "Active" : "Inactive",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          SizedBox(
                            height: 20,
                            width: 36,
                            child: Switch(
                              value: isActive,
                              activeThumbColor: Colors.green,
                              onChanged: (v) {
                                setState(() {
                                  override['isActive'] = v;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              int targetIdx = -1;
                              for (int i = 0; i < _formOverrides.length; i++) {
                                if (identical(_formOverrides[i], override)) {
                                  targetIdx = i;
                                  break;
                                }
                              }
                              if (targetIdx != -1) {
                                setState(() {
                                  _formOverrides.removeAt(targetIdx);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isExpanded) ...[
                const Divider(height: 1, thickness: 0.5),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (type == 'META') ...[
                        _buildInlineLabel("Target Meta Form", isDark),
                        _buildInlineDropdown(
                          value: override['formId']?.toString(),
                          hint: _isLoadingForms
                              ? "Loading forms..."
                              : "Target Meta Form",
                          isDark: isDark,
                          items: () {
                            final hasCurrent = _metaForms.any(
                              (f) =>
                                  f['id'].toString() ==
                                  override['formId']?.toString(),
                            );
                            final list = _metaForms
                                .map<DropdownMenuItem<String>>((f) {
                                  final displayName = f['pageName'] != null
                                      ? "${f['name']} (${f['pageName']})"
                                      : "${f['name']}";
                                  return DropdownMenuItem(
                                    value: f['id'].toString(),
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                                .toList();

                            if (!hasCurrent && override['formId'] != null) {
                              list.add(
                                DropdownMenuItem(
                                  value: override['formId'].toString(),
                                  child: Text(
                                    override['formName'] ?? 'Unknown Form',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }
                            return list;
                          }(),
                          onChanged: (val) {
                            final form = _metaForms.firstWhere(
                              (f) => f['id'].toString() == val,
                              orElse: () => <String, dynamic>{},
                            );
                            setState(() {
                              override['type'] = type;
                              override['source'] =
                                  _defaultSourceForOverrideType(type);
                              override['formId'] = val;
                              override['formName'] = form?['name'];
                              override['pageId'] = form?['pageId'];
                            });
                          },
                        ),
                      ] else ...[
                        _buildInlineLabel("Target Website Form", isDark),
                        _buildInlineDropdown(
                          value: override['formId']?.toString(),
                          hint: "Target Website Form",
                          isDark: isDark,
                          items: () {
                            final hasCurrent = _websiteForms.any(
                              (f) =>
                                  f['_id'].toString() ==
                                  override['formId']?.toString(),
                            );
                            final list = _websiteForms
                                .map<DropdownMenuItem<String>>((f) {
                                  return DropdownMenuItem(
                                    value: f['_id'].toString(),
                                    child: Text(
                                      f['formName'] ?? 'Unnamed Form',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                                .toList();

                            if (!hasCurrent && override['formId'] != null) {
                              list.add(
                                DropdownMenuItem(
                                  value: override['formId'].toString(),
                                  child: Text(
                                    override['formName'] ?? 'Unknown Form',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }
                            return list;
                          }(),
                          onChanged: (val) {
                            final form = _websiteForms.firstWhere(
                              (f) => f['_id'].toString() == val,
                              orElse: () => <String, dynamic>{},
                            );
                            setState(() {
                              override['type'] = type;
                              override['source'] =
                                  _defaultSourceForOverrideType(type);
                              override['formId'] = val;
                              override['formName'] = form?['formName'];
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      LayoutBuilder(
                        builder: (context, cardContentConstraints) {
                          final selectedTName =
                              override['template']?['name'] as String?;

                          final templateListWidget = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInlineLabel("Override Template", isDark),
                              Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E2130)
                                      : const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final filteredTemplates =
                                        (templatesState.templates as List)
                                            .where(
                                              (t) => t['status'] != 'REJECTED',
                                            )
                                            .toList();
                                    return ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: filteredTemplates.length,
                                      itemBuilder: (context, index) {
                                        final t = filteredTemplates[index];
                                        final bool isSelected =
                                            selectedTName == t['name'];
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              override['template'] = {
                                                'name': t['name'],
                                                'language': t['language'],
                                                'components': t['components'],
                                              };
                                              override['variableMappings'] =
                                                  _buildVariableMappings(t);
                                            });
                                          },
                                          child: _buildCompactTemplateRow(
                                            t,
                                            isSelected,
                                            isDark,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );

                          final previewWidget = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInlineLabel("Live Preview", isDark),
                              Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(
                                  minHeight: 220,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE4DDD6),
                                  borderRadius: BorderRadius.circular(6),
                                  image: const DecorationImage(
                                    image: NetworkImage(
                                      'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
                                    ),
                                    repeat: ImageRepeat.repeat,
                                    opacity: 0.4,
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: selectedTName == null
                                      ? Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 
                                                  0.05,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.smartphone,
                                                size: 24,
                                                color: Colors.green.shade400,
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                "Select a template to view preview",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : WhatsAppPreviewBubble(
                                          template: override['template'],
                                          bodyText: _getPreviewText(
                                            override['template'],
                                          ),
                                          isDark: isDark,
                                        ),
                                ),
                              ),
                            ],
                          );

                          if (cardContentConstraints.maxWidth > 650) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: templateListWidget),
                                const SizedBox(width: 16),
                                Expanded(flex: 4, child: previewWidget),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                templateListWidget,
                                const SizedBox(height: 16),
                                previewWidget,
                              ],
                            );
                          }
                        },
                      ),

                      if (override['template'] != null) ...[
                        const SizedBox(height: 16),
                        _buildInlineOverrideVariables(override, isDark),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactTemplateRow(dynamic t, bool isSelected, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.message_outlined,
            size: 16,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t['name'] ?? '',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: Colors.blue, size: 18),
        ],
      ),
    );
  }

  Widget _buildInlineLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildInlineDropdown({
    required String? value,
    required String hint,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(4),
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          dropdownColor: isDark ? const Color(0xFF1E2130) : Colors.white,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInlineOverrideVariables(
    Map<String, dynamic> override,
    bool isDark,
  ) {
    final template = override['template'] as Map<String, dynamic>;
    final components = template['components'] as List?;
    final bodyComp = components?.firstWhere(
      (c) => _componentType(c) == 'BODY',
      orElse: () => <String, dynamic>{},
    );
    final bodyText = (bodyComp is Map) ? (bodyComp['text'] ?? '') : '';
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText as String);
    if (matches.isEmpty) return const SizedBox.shrink();

    final mappingsList = override['variableMappings'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        _buildInlineLabel("BODY VARIABLES MAPPING", isDark),
        const SizedBox(height: 8),
        ...matches.map((m) {
          final key = m.group(1)!;

          Map<String, dynamic>? mapping = mappingsList
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (item) => item?['key'] == key,
                orElse: () => <String, dynamic>{},
              );

          if (mapping == null) {
            mapping = {'key': key, 'source': _defaultVariableSource};
            mappingsList.add(mapping);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WhatsAppVariableSelector(
              mode: 'lead',
              variableKey: key,
              initialSource: mapping['source'] ?? _defaultVariableSource,
              initialCustomValue: mapping['customValue'],
              onChanged: (source, customValue) {
                setState(() {
                  mapping!['source'] = source;
                  if (customValue != null) {
                    mapping['customValue'] = customValue;
                  } else {
                    mapping.remove('customValue');
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }
}
