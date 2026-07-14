import 'package:dotted_border/dotted_border.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/whatsapp_provider.dart';
import '../../providers/lead_provider.dart';
import '../../../data/models/lead_model.dart';
import '../../widgets/global_app_bar.dart';
import 'whatsapp_permission_guard.dart';
import '../../../core/constants/whatsapp_constants.dart';
import 'widgets/whatsapp_variable_selector.dart';
import 'widgets/whatsapp_preview_bubble.dart';

class WhatsAppCampaignCreateScreen extends ConsumerStatefulWidget {
  const WhatsAppCampaignCreateScreen({super.key});

  @override
  ConsumerState<WhatsAppCampaignCreateScreen> createState() => _WhatsAppCampaignCreateScreenState();
}

class _WhatsAppCampaignCreateScreenState extends ConsumerState<WhatsAppCampaignCreateScreen> {
  int _currentStep = 0;
// ... (code omitted to match exactly since we have to specify TargetContent)

  // Step 1: Details
  final TextEditingController _campaignNameController = TextEditingController();
  String? _selectedTemplateName;
  Map<String, dynamic>? _selectedTemplate;

  // Step 2: Target Audience
  String _audienceSource = 'EXCEL'; // LEADS, EXCEL
  File? _excelFile;
  String? _excelFileName;
  final List<String> _selectedLeadIds = [];

  // Location header controllers
  final TextEditingController _locationLatitudeController = TextEditingController();
  final TextEditingController _locationLongitudeController = TextEditingController();
  final TextEditingController _locationPlaceNameController = TextEditingController();
  final TextEditingController _locationAddressController = TextEditingController();
  String _leadsSearchQuery = '';

  // Pagination & Search State
  final List<Lead> _searchedLeads = [];
  bool _isLoadingLeads = false;
  int _currentLeadPage = 1;
  bool _hasMoreLeads = true;
  Timer? _searchTimer;
  final ScrollController _scrollController = ScrollController();
  // Step 3: Variables Mapping (dropdown-based like select template dialog)
  final Map<int, String> _variableSources = {}; // index -> source key
  final Map<int, String> _customValues = {};
  DateTime? _scheduledAt;

  String _bodyText = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        _fetchLeads();
      }
    });
    Future.microtask(() {
      ref.read(whatsappTemplatesProvider.notifier).fetchTemplates();
      _fetchLeads(refresh: true);
    });
  }

  Future<void> _fetchLeads({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentLeadPage = 1;
        _searchedLeads.clear();
        _hasMoreLeads = true;
      });
    }
    if (!_hasMoreLeads || _isLoadingLeads) return;

    setState(() => _isLoadingLeads = true);

    try {
      final service = ref.read(leadServiceProvider);
      final response = await service.fetchLeads(
        page: _currentLeadPage,
        limit: 20,
        search: _leadsSearchQuery,
      );

      setState(() {
        final seenIds = <String>{};
        for (final l in _searchedLeads) {
          seenIds.add(l.id);
        }
        for (final l in response.leads) {
          if (!seenIds.contains(l.id)) {
            _searchedLeads.add(l);
            seenIds.add(l.id);
          }
        }
        _hasMoreLeads = _currentLeadPage < response.totalPages;
        if (_hasMoreLeads) _currentLeadPage++;
        _isLoadingLeads = false;
      });
    } catch (e) {
      setState(() => _isLoadingLeads = false);
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _scrollController.dispose();
    _campaignNameController.dispose();
    _locationLatitudeController.dispose();
    _locationLongitudeController.dispose();
    _locationPlaceNameController.dispose();
    _locationAddressController.dispose();
    super.dispose();
  }

  void _onTemplateSelected(String name, List<Map<String, dynamic>> templates) {
    final matched = templates.firstWhere((t) => t['name'] == name);
    final components = matched['components'] as List?;
    final bodyComp = components?.firstWhere((c) => c['type'] == 'BODY', orElse: () => <String, dynamic>{});
    final String bodyText = bodyComp?['text'] ?? '';

    final uniqueVarNumbers = RegExp(r'\{\{(\d+)\}\}')
        .allMatches(bodyText)
        .map((m) => m.group(1)!)
        .toSet()
        .toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    _customValues.clear();
    _variableSources.clear();

    for (int i = 0; i < uniqueVarNumbers.length; i++) {
      _variableSources[i] = 'recipient.name';
    }

    _locationLatitudeController.clear();
    _locationLongitudeController.clear();
    _locationPlaceNameController.clear();
    _locationAddressController.clear();

    final headerComp = components?.firstWhere((c) => c['type'] == 'HEADER', orElse: () => <String, dynamic>{});
    if (headerComp != null && headerComp['format'] == 'LOCATION') {
      _locationLatitudeController.text = (headerComp['latitude'] ?? '').toString();
      _locationLongitudeController.text = (headerComp['longitude'] ?? '').toString();
      _locationPlaceNameController.text = (headerComp['placeName'] ?? '').toString();
      _locationAddressController.text = (headerComp['address'] ?? '').toString();
    }

    setState(() {
      _selectedTemplateName = name;
      _selectedTemplate = matched;
      _bodyText = bodyText;
    });
  }

  String _getPreviewText() {
    if (_bodyText.isEmpty) return '';
    var preview = _bodyText;
    for (final entry in _variableSources.entries) {
      final sourceKey = entry.value;
      final label = WhatsAppVariableSources.getLabelForValue(sourceKey);
      final value = sourceKey == 'custom' && _customValues.containsKey(entry.key)
          ? _customValues[entry.key]!
          : label;
      preview = preview.replaceAll('{{${entry.key + 1}}}', value.isNotEmpty ? value : '?');
    }
    return preview;
  }

  Future<void> _pickExcelFile() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );
      if (result == null || result.files.single.path == null) return;
      setState(() {
        _excelFile = File(result.files.single.path!);
        _excelFileName = result.files.single.name;
      });
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('File pick error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _validateStep() {
    if (_currentStep == 0) {
      if (_campaignNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a campaign name'), backgroundColor: Colors.red),
        );
        return false;
      }
      return true;
    }
    if (_currentStep == 1) {
      if (_audienceSource == 'LEADS' && _selectedLeadIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one lead'), backgroundColor: Colors.red),
        );
        return false;
      }
      if (_audienceSource == 'EXCEL' && _excelFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload an Excel/CSV file'), backgroundColor: Colors.red),
        );
        return false;
      }
      return true;
    }
    if (_currentStep == 2) {
      if (_selectedTemplateName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a template'), backgroundColor: Colors.red),
        );
        return false;
      }
      return true;
    }
    return true;
  }

  Future<void> _submitCampaign() async {
    if (_campaignNameController.text.trim().isEmpty) return;
    if (_selectedTemplateName == null) return;

    final templatesState = ref.read(whatsappTemplatesProvider);
    final matched = templatesState.templates.cast<Map<String, dynamic>?>().firstWhere(
      (t) => t?['name'] == _selectedTemplateName,
      orElse: () => <String, dynamic>{},
    );
    if (matched == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected template not found. Please re-select.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final List<Map<String, dynamic>> variablesPayload = [];
    for (final entry in _variableSources.entries) {
      final source = entry.value;
      final customVal = source == 'custom' && _customValues.containsKey(entry.key)
          ? _customValues[entry.key]!
          : null;
      variablesPayload.add({
        'key': '${entry.key + 1}',
        'source': source,
        if (customVal != null && customVal.isNotEmpty) 'customValue': customVal,
      });
    }

    final List<dynamic> matchedComponents = List.from(matched['components'] ?? []);
    final headerComp = matchedComponents.firstWhere((c) => c['type'] == 'HEADER', orElse: () => <String, dynamic>{});
    final isLocationHeader = headerComp != null && headerComp['format'] == 'LOCATION';
    if (isLocationHeader) {
      for (int i = 0; i < matchedComponents.length; i++) {
        if (matchedComponents[i]['type'] == 'HEADER') {
          final h = Map<String, dynamic>.from(matchedComponents[i]);
          h['placeName'] = _locationPlaceNameController.text.trim();
          h['address'] = _locationAddressController.text.trim();
          h['latitude'] = _locationLatitudeController.text.trim();
          h['longitude'] = _locationLongitudeController.text.trim();
          matchedComponents[i] = h;
          break;
        }
      }
    }

    final recipientSrc = _audienceSource == 'LEADS' ? 'leads' : 'excel';
    debugPrint('[CampaignCreate] Submitting campaign: recipientSource=$recipientSrc, leadIds=$_selectedLeadIds, file=${_excelFile?.path}');

    final fields = {
      'name': _campaignNameController.text,
      'templateName': _selectedTemplateName,
      'templateLanguage': matched['language'] ?? 'en',
      'templateComponents': jsonEncode(matchedComponents),
      'variableMappings': jsonEncode(variablesPayload),
      'recipientSource': recipientSrc,
      'scheduledAt': _scheduledAt?.toUtc().toIso8601String(),
    };

    try {
      await ref.read(whatsappCampaignsProvider.notifier).createCampaign(
            fields,
            file: _audienceSource != 'LEADS' ? _excelFile : null,
            leadIds: _audienceSource == 'LEADS' ? _selectedLeadIds : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to build campaign: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templatesState = ref.watch(whatsappTemplatesProvider);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return WhatsAppPermissionGuard(
      requiredModules: const ['modules.integration', 'modules.whatsapp'],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const GlobalAppBar(title: 'WhatsApp Marketing'),

        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32.0 : 16.0, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.keyboard_backspace, size: 16),
                    SizedBox(width: 8),
                    Text("BACK TO CAMPAIGNS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text("Create New Campaign", style: TextStyle(fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Set up your bulk WhatsApp marketing campaign in just a few steps.", style: TextStyle(color: Colors.grey.shade600, fontSize: isDesktop ? 14 : 12)),
              const SizedBox(height: 32),

              // Wizard Content
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2130) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                padding: EdgeInsets.all(isDesktop ? 40 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCustomStepper(isDesktop, isDark),
                    SizedBox(height: isDesktop ? 48 : 32),

                    if (_currentStep == 0) _buildStep1(isDark)
                    else if (_currentStep == 1) _buildStep2(_searchedLeads, isDark)
                    else _buildStep3(templatesState.templates, isDark, isDesktop),

                    SizedBox(height: isDesktop ? 48 : 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(color: _currentStep > 0 ? (isDark ? Colors.white : Colors.black) : Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text("BACK", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (!_validateStep()) return;
                              if (_currentStep < 2) {
                                setState(() => _currentStep++);
                              } else {
                                _submitCampaign();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.blue : Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Text(_currentStep == 2 ? "LAUNCH" : "NEXT", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    ),
    );
  }

  Widget _buildCustomStepper(bool isDesktop, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepIndicator(0, "Basic Details", isDesktop, isDark),
        _buildLine(isDesktop),
        _buildStepIndicator(1, "Recipients", isDesktop, isDark),
        _buildLine(isDesktop),
        _buildStepIndicator(2, isDesktop ? "Template & Schedule" : "Template\n& Schedule", isDesktop, isDark),
      ],
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title, bool isDesktop, bool isDark) {
    bool isActive = _currentStep == stepIndex;
    bool isCompleted = _currentStep > stepIndex;
    Color color = isActive || isCompleted ? (isDark ? Colors.blue : Colors.black) : Colors.grey.shade400;
    Color textColor = isActive ? (isDark ? Colors.white : Colors.black) : Colors.grey.shade600;

    return Column(
      children: [
        Container(
          width: isDesktop ? 24 : 20,
          height: isDesktop ? 24 : 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            "${stepIndex + 1}",
            style: TextStyle(color: Colors.white, fontSize: isDesktop ? 12 : 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: isDesktop ? 11 : 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        )
      ],
    );
  }

  Widget _buildLine(bool isDesktop) {
    return Container(
      width: isDesktop ? 100 : 30,
      height: 1,
      color: Colors.grey.shade300,
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 8, vertical: 12),
    );
  }

  Widget _buildStep1(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Name your campaign", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        TextField(
          controller: _campaignNameController,
          decoration: InputDecoration(
            hintText: 'Campaign Name',
            border: const OutlineInputBorder(),
            fillColor: isDark ? const Color(0xFF25293C) : Colors.white,
            filled: true,
          ),
        )
      ],
    );
  }

  Widget _buildStep2(List<dynamic> leadsList, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Choose Recipients", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        RadioGroup<String>(
          groupValue: _audienceSource,
          onChanged: (val) {
            if (val != null) {
              setState(() => _audienceSource = val);
            }
          },
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'EXCEL',
                title: const Text("Upload Excel Sheet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                activeColor: isDark ? Colors.blue : Colors.black,
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                value: 'LEADS',
                title: const Text("Select Existing Leads", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                activeColor: isDark ? Colors.blue : Colors.black,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_audienceSource == 'LEADS') ...[
          TextField(
            onChanged: (val) {
              _leadsSearchQuery = val;
              _searchTimer?.cancel();
              _searchTimer = Timer(const Duration(milliseconds: 500), () {
                _fetchLeads(refresh: true);
              });
            },
            decoration: InputDecoration(
              hintText: 'Search system leads...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              fillColor: isDark ? const Color(0xFF25293C) : Colors.white,
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text("${_selectedLeadIds.length} selected", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600])),
              const Spacer(),
              TextButton(
                onPressed: leadsList.isEmpty ? null : () {
                  final uniqueLeadsCount = leadsList.map((l) => l.id).toSet().length;
                  setState(() {
                    if (_selectedLeadIds.length >= uniqueLeadsCount) {
                      _selectedLeadIds.clear();
                    } else {
                      _selectedLeadIds.clear();
                      final added = <String>{};
                      for (final l in leadsList) {
                        if (l.id != null && added.add(l.id!)) {
                          _selectedLeadIds.add(l.id!);
                        }
                      }
                    }
                  });
                },
                child: Text(
                  _selectedLeadIds.length >= leadsList.map((l) => l.id).toSet().length && leadsList.isNotEmpty ? "DESELECT ALL" : "SELECT ALL",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
            ),
            child: leadsList.isEmpty && !_isLoadingLeads
                ? const Center(child: Text("No leads found"))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: leadsList.length + (_hasMoreLeads ? 1 : 0),
                    itemBuilder: (context, idx) {
                      if (idx >= leadsList.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                        );
                      }
                      final lead = leadsList[idx];
                      final isChecked = _selectedLeadIds.contains(lead.id);
                      return CheckboxListTile(
                        value: isChecked,
                        title: Text(lead.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(lead.phoneNo ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedLeadIds.add(lead.id!);
                            } else {
                              _selectedLeadIds.remove(lead.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ] else ...[
          DottedBorder(
            options: RoundedRectDottedBorderOptions(
              radius: const Radius.circular(8),
              color: isDark ? Colors.white30 : Colors.grey.shade400,
              strokeWidth: 1.5,
              dashPattern: const [6, 4],
              padding: EdgeInsets.zero,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF25293C) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Upload your Excel (.xlsx, .xls) file here",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Required columns: Phone (Required), Name (Optional)",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_excelFileName == null)
                    ElevatedButton(
                      onPressed: _pickExcelFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.blue : Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text("CHOOSE FILE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_drive_file, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _excelFileName!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => setState(() {
                            _excelFile = null;
                            _excelFileName = null;
                          }),
                        )
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3(List<Map<String, dynamic>> templates, bool isDark, bool isDesktop) {
    final uniqueTemplates = <String, Map<String, dynamic>>{};
    for (final t in templates) {
      final name = (t['name'] ?? '').toString();
      if (name.isNotEmpty && !uniqueTemplates.containsKey(name)) {
        uniqueTemplates[name] = t;
      }
    }
    final templateEntries = uniqueTemplates.entries.toList();
    final validSelectedName = _selectedTemplateName != null && templateEntries.any((e) => e.key == _selectedTemplateName)
        ? _selectedTemplateName
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Template", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: validSelectedName,
          decoration: InputDecoration(
            labelText: 'Dispatch Meta Template',
            border: const OutlineInputBorder(),
            fillColor: isDark ? const Color(0xFF25293C) : Colors.white,
            filled: true,
          ),
          items: templateEntries.map((e) {
            return DropdownMenuItem(value: e.key, child: Text(e.key));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              _onTemplateSelected(val, templates);
            }
          },
        ),

        // Template Preview + Variable Mappings
        if (_selectedTemplate != null) ...[
          const SizedBox(height: 24),
          const Text("Message Preview", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),

          // Extract location format
          () {
            final components = _selectedTemplate?['components'] as List?;
            final headerComp = components?.firstWhere((c) => c['type'] == 'HEADER', orElse: () => <String, dynamic>{});
            final isLocationHeader = headerComp != null && headerComp['format'] == 'LOCATION';

            final previewTpl = Map<String, dynamic>.from(_selectedTemplate!);
            if (isLocationHeader) {
              final newComps = (previewTpl['components'] as List).map((comp) {
                if (comp['type'] == 'HEADER') {
                  final c = Map<String, dynamic>.from(comp);
                  c['placeName'] = _locationPlaceNameController.text;
                  c['address'] = _locationAddressController.text;
                  c['latitude'] = _locationLatitudeController.text;
                  c['longitude'] = _locationLongitudeController.text;
                  return c;
                }
                return comp;
              }).toList();
              previewTpl['components'] = newComps;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2C27) : const Color(0xFFEFECE5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: WhatsAppPreviewBubble(
                    template: previewTpl,
                    bodyText: _getPreviewText().isNotEmpty ? _getPreviewText() : _bodyText,
                    isDark: isDark,
                  ),
                ),
                if (isLocationHeader) ...[
                  const SizedBox(height: 24),
                  const Text("Location Header Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _locationLatitudeController,
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
                          controller: _locationLongitudeController,
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
                          controller: _locationPlaceNameController,
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
                          controller: _locationAddressController,
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
              ],
            );
          }(),

          // Variable mapping dropdowns
          if (_variableSources.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text("Map Template Variables", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            ..._variableSources.entries.map((entry) {
              final int variableIndex = entry.key; // 0-based index
              final String variableKey = (variableIndex + 1).toString(); // 1-based string key for selector display
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: WhatsAppVariableSelector(
                  mode: 'marketing',
                  variableKey: variableKey,
                  initialSource: _variableSources[variableIndex] ?? 'recipient.name',
                  initialCustomValue: _customValues[variableIndex],
                  onChanged: (source, customValue) {
                    setState(() {
                      _variableSources[variableIndex] = source;
                      if (customValue != null) {
                        _customValues[variableIndex] = customValue;
                      } else {
                        _customValues.remove(variableIndex);
                      }
                    });
                  },
                ),
              );
            }),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Campaign Summary
          const Text("Campaign Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
              color: isDark ? const Color(0xFF25293C) : Colors.grey.shade50,
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.description_outlined, 'Template',
                  _selectedTemplateName ?? '-', isDark,
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  Icons.people_outline, 'Recipients',
                  _audienceSource == 'LEADS'
                      ? '${_selectedLeadIds.length} CRM leads selected'
                      : 'Excel file: ${_excelFileName ?? '-'}',
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  Icons.schedule, 'Schedule',
                  _scheduledAt == null ? 'Send immediately' : 'Scheduled for ${_scheduledAt!.toLocal().toString().substring(0, 16)}',
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  Icons.data_array_outlined, 'Variables',
                  '${_variableSources.length} mapped',
                  isDark,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        const Text("Schedule Campaign", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: isDark ? const Color(0xFF1E2130) : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _scheduledAt == null
                      ? "Send Immediately"
                      : "Scheduled for:\n${_scheduledAt!.toLocal().toString().substring(0, 16)}",
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null && mounted) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (time != null && mounted) {
                      setState(() {
                        _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text("SET", style: TextStyle(fontSize: 12)),
              ),
              if (_scheduledAt != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                  onPressed: () => setState(() => _scheduledAt = null),
                  tooltip: 'Clear schedule',
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
