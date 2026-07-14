import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/r2_service.dart';
import '../../providers/whatsapp_provider.dart';
import 'whatsapp_permission_guard.dart';
import 'widgets/whatsapp_preview_bubble.dart';

class WhatsAppTemplateCreateDialog extends ConsumerStatefulWidget {
  const WhatsAppTemplateCreateDialog({super.key});

  @override
  ConsumerState<WhatsAppTemplateCreateDialog> createState() => _WhatsAppTemplateCreateDialogState();
}

class _WhatsAppTemplateCreateDialogState extends ConsumerState<WhatsAppTemplateCreateDialog> {
  final _formKey = GlobalKey<FormState>();

  // Basic Details
  final TextEditingController _nameController = TextEditingController();
  String _selectedCategory = 'MARKETING';
  final String _selectedLanguage = 'en_US';

  // Headers
  String _headerType = 'NONE'; // NONE, TEXT, IMAGE, DOCUMENT, VIDEO
  final TextEditingController _headerTextController = TextEditingController();
  final List<TextEditingController> _headerExampleControllers = [];
  String? _headerFileUrl;
  bool _isUploadingHeader = false;

  // Body
  final TextEditingController _bodyTextController = TextEditingController();
  final List<TextEditingController> _bodyExampleControllers = [];

  // Footer
  final TextEditingController _footerTextController = TextEditingController();

  // Location
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _placeNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Buttons
  final List<TextEditingController> _buttonControllers = [];
  final List<TextEditingController> _buttonSecondaryControllers = [];
  final List<TextEditingController> _buttonCountryCodeControllers = [];
  final List<String> _buttonActions = []; // QUICK_REPLY, URL, PHONE_NUMBER
  String _previousBodyText = '';
  String _previousHeaderText = '';
  Timer? _previewDebounce;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onTextChanged);
    _headerTextController.addListener(_onTextChanged);
    _bodyTextController.addListener(_onTextChanged);
    _footerTextController.addListener(_onTextChanged);
    _latitudeController.addListener(_onTextChanged);
    _longitudeController.addListener(_onTextChanged);
    _placeNameController.addListener(_onTextChanged);
    _addressController.addListener(_onTextChanged);
  }

  List<String> _getUniqueVariables(String text) {
    return RegExp(r'\{\{(\d+)\}\}')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toSet()
        .toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  }

  bool _areVariableListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onTextChanged() {
    final bodyVariables = _getUniqueVariables(_bodyTextController.text);
    final previousBodyVariables = _getUniqueVariables(_previousBodyText);
    final bodyChanged = !_areVariableListsEqual(previousBodyVariables, bodyVariables);

    if (bodyChanged) {
      final oldValues = <String, String>{};
      final oldVars = _getUniqueVariables(_previousBodyText);
      for (int i = 0; i < oldVars.length && i < _bodyExampleControllers.length; i++) {
        oldValues[oldVars[i]] = _bodyExampleControllers[i].text;
      }

      for (final ctrl in _bodyExampleControllers) {
        ctrl.dispose();
      }
      _bodyExampleControllers.clear();

      for (final varNum in bodyVariables) {
        final ctrl = TextEditingController(text: oldValues[varNum] ?? '');
        ctrl.addListener(() => setState(() {}));
        _bodyExampleControllers.add(ctrl);
      }
    }
    _previousBodyText = _bodyTextController.text;

    final headerVariables = _headerType == 'TEXT'
        ? _getUniqueVariables(_headerTextController.text)
        : <String>[];
    final previousHeaderVariables = _getUniqueVariables(_previousHeaderText);
    final headerChanged = !_areVariableListsEqual(previousHeaderVariables, headerVariables);

    if (headerChanged) {
      final oldValues = <String, String>{};
      final oldVars = _getUniqueVariables(_previousHeaderText);
      for (int i = 0; i < oldVars.length && i < _headerExampleControllers.length; i++) {
        oldValues[oldVars[i]] = _headerExampleControllers[i].text;
      }

      for (final ctrl in _headerExampleControllers) {
        ctrl.dispose();
      }
      _headerExampleControllers.clear();

      for (final varNum in headerVariables) {
        final ctrl = TextEditingController(text: oldValues[varNum] ?? '');
        ctrl.addListener(() => setState(() {}));
        _headerExampleControllers.add(ctrl);
      }
    }
    _previousHeaderText = _headerTextController.text;

    if (bodyChanged || headerChanged) {
      setState(() {});
    } else {
      _previewDebounce?.cancel();
      _previewDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _nameController.dispose();
    _headerTextController.dispose();
    _bodyTextController.dispose();
    _footerTextController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _placeNameController.dispose();
    _addressController.dispose();
    for (final ctrl in _buttonControllers) {
      ctrl.dispose();
    }
    for (final ctrl in _buttonSecondaryControllers) {
      ctrl.dispose();
    }
    for (final ctrl in _buttonCountryCodeControllers) {
      ctrl.dispose();
    }
    for (final ctrl in _headerExampleControllers) {
      ctrl.dispose();
    }
    for (final ctrl in _bodyExampleControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addButton() {
    if (_buttonControllers.length >= 10) return;
    setState(() {
      _buttonControllers.add(TextEditingController()..addListener(_onTextChanged));
      _buttonSecondaryControllers.add(TextEditingController()..addListener(_onTextChanged));
      _buttonCountryCodeControllers.add(TextEditingController(text: '91')..addListener(_onTextChanged));
      _buttonActions.add('QUICK_REPLY');
    });
  }

  void _removeButton(int index) {
    setState(() {
      _buttonControllers[index].dispose();
      _buttonControllers.removeAt(index);
      _buttonSecondaryControllers[index].dispose();
      _buttonSecondaryControllers.removeAt(index);
      _buttonCountryCodeControllers[index].dispose();
      _buttonCountryCodeControllers.removeAt(index);
      _buttonActions.removeAt(index);
    });
  }

  Future<void> _submitTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_headerType == 'IMAGE' || _headerType == 'DOCUMENT' || _headerType == 'VIDEO') && _headerFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a file for the header.'), backgroundColor: Colors.red),
      );
      return;
    }

    final List<Map<String, dynamic>> components = [];

    if (_headerType != 'NONE') {
      final Map<String, dynamic> header = {
        'type': 'HEADER',
        'format': _headerType,
      };
      if (_headerType == 'TEXT') {
        header['text'] = _headerTextController.text;
        if (_headerExampleControllers.isNotEmpty) {
          header['example'] = {
            'header_text': _headerExampleControllers.map((c) => c.text.isEmpty ? 'Sample' : c.text).toList()
          };
        }
      } else if (_headerType == 'LOCATION') {
        header['latitude'] = _latitudeController.text.trim();
        header['longitude'] = _longitudeController.text.trim();
        if (_placeNameController.text.trim().isNotEmpty) {
          header['placeName'] = _placeNameController.text.trim();
        }
        if (_addressController.text.trim().isNotEmpty) {
          header['address'] = _addressController.text.trim();
        }
      } else {
        header['example'] = {
          'header_handle': [_headerFileUrl ?? 'https://r2.cloudflare.com/assets/sample-template-media.png']
        };
      }
      components.add(header);
    }

    final Map<String, dynamic> body = {
      'type': 'BODY',
      'text': _bodyTextController.text,
    };
    if (_bodyExampleControllers.isNotEmpty) {
      body['example'] = {
         'body_text': [
           _bodyExampleControllers.map((c) => c.text.isEmpty ? 'Sample' : c.text).toList()
         ]
      };
    }
    components.add(body);

    if (_footerTextController.text.trim().isNotEmpty) {
      components.add({
        'type': 'FOOTER',
        'text': _footerTextController.text,
      });
    }

    if (_buttonControllers.isNotEmpty) {
      final List<Map<String, dynamic>> buttons = [];
      for (int i = 0; i < _buttonControllers.length; i++) {
        final actionType = _buttonActions[i];
        final Map<String, dynamic> btn = {
          'type': actionType,
          'text': _buttonControllers[i].text,
        };
        if (actionType == 'PHONE_NUMBER') {
          final code = _buttonCountryCodeControllers[i].text.replaceAll('+', '').trim();
          final phone = _buttonSecondaryControllers[i].text.trim();
          btn['phone_number'] = '+$code$phone';
        } else if (actionType == 'URL') {
          btn['url'] = _buttonSecondaryControllers[i].text.isNotEmpty
              ? _buttonSecondaryControllers[i].text
              : 'https://www.example.com';
        }
        buttons.add(btn);
      }
      components.add({
        'type': 'BUTTONS',
        'buttons': buttons,
      });
    }

    final payload = {
      'name': _nameController.text.toLowerCase().replaceAll(' ', '_'),
      'language': _selectedLanguage,
      'category': _selectedCategory,
      'components': components,
      'fullTemplateBody': _bodyTextController.text,
    };

    try {
      await ref.read(whatsappTemplatesProvider.notifier).createTemplate(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template submitted successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return WhatsAppPermissionGuard(
      requiredModules: const ['modules.integration', 'modules.whatsapp'],
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {},
          child: Container(
          width: isDesktop ? 1200 : size.width,
          height: isDesktop ? 800 : size.height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131520) : const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildHeader(context, isDark, isDesktop),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                                child: _buildFormContent(context, isDark),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: double.infinity,
                                color: isDark ? const Color(0xFF1E2130) : Colors.white,
                                padding: const EdgeInsets.all(24.0),
                                child: SingleChildScrollView(
                                  child: _buildLiveWhatsAppPreview(context, isDark),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            children: [
                              _buildFormContent(context, isDark),
                              const SizedBox(height: 24),
                              _buildLiveWhatsAppPreview(context, isDark),
                              const SizedBox(height: 48),
                            ],
                          ),
                        );
                      }
                    },
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

  Widget _buildHeader(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2D) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
            splashRadius: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: isDesktop ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Create Template",
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isDesktop) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Design and submit a new template for approval",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: isDesktop ? 16 : 8),
          ElevatedButton(
            onPressed: _submitTemplate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 16 : 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isDesktop ? "SUBMIT TO META" : "SUBMIT",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isDesktop ? 13 : 12, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // --- FORM BUILDERS ---

  Widget _buildFormContent(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          context,
          isDark,
          stepNumber: 1,
          title: "Basic Details",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('tpl_name_field'),
                controller: _nameController,
                style: const TextStyle(fontSize: 14),
                showCursor: true,
                enableInteractiveSelection: true,
                decoration: InputDecoration(
                  labelText: 'Template Name',
                  labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Template name required';
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Text(
                "Lowercase, numbers, and underscores only.",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MARKETING', child: Text('MARKETING')),
                      DropdownMenuItem(value: 'UTILITY', child: Text('UTILITY')),
                      DropdownMenuItem(value: 'AUTHENTICATION', child: Text('AUTHENTICATION')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  Positioned(
                    left: 12,
                    top: -6,
                    child: Container(
                      color: isDark ? const Color(0xFF1E2130) : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "Category",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        _buildSectionCard(
          context,
          isDark,
          stepNumber: 2,
          title: "Header (Optional)",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _headerType,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.grey.shade600),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                decoration: InputDecoration(
                  labelText: 'Header Type',
                  labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text('None')),
                  DropdownMenuItem(value: 'TEXT', child: Text('Text')),
                  DropdownMenuItem(value: 'IMAGE', child: Text('Image')),
                  DropdownMenuItem(value: 'DOCUMENT', child: Text('Document (PDF)')),
                  DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                  DropdownMenuItem(value: 'LOCATION', child: Text('Location')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _headerType = val);
                },
              ),
              if (_headerType == 'TEXT') ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('tpl_header_text_field'),
                  controller: _headerTextController,
                  style: const TextStyle(fontSize: 14),
                  showCursor: true,
                  enableInteractiveSelection: true,
                  decoration: InputDecoration(
                    labelText: 'Header Text',
                    labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                if (_headerExampleControllers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Example Data for Header Variables",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < _headerExampleControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextFormField(
                        controller: _headerExampleControllers[i],
                        style: const TextStyle(fontSize: 13),
                        showCursor: true,
                        enableInteractiveSelection: true,
                        decoration: InputDecoration(
                          hintText: 'Example for {{${i + 1}}}',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                ],
              ] else if (_headerType == 'LOCATION') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('tpl_lat_field'),
                        controller: _latitudeController,
                        style: const TextStyle(fontSize: 14),
                        showCursor: true,
                        enableInteractiveSelection: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (val) {
                          if (_headerType == 'LOCATION' && (val == null || val.trim().isEmpty)) return 'Latitude required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('tpl_lng_field'),
                        controller: _longitudeController,
                        style: const TextStyle(fontSize: 14),
                        showCursor: true,
                        enableInteractiveSelection: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (val) {
                          if (_headerType == 'LOCATION' && (val == null || val.trim().isEmpty)) return 'Longitude required';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('tpl_place_field'),
                        controller: _placeNameController,
                        style: const TextStyle(fontSize: 14),
                        showCursor: true,
                        enableInteractiveSelection: true,
                        decoration: InputDecoration(
                          labelText: 'Place Name',
                          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('tpl_address_field'),
                        controller: _addressController,
                        style: const TextStyle(fontSize: 14),
                        showCursor: true,
                        enableInteractiveSelection: true,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_headerType == 'IMAGE' || _headerType == 'DOCUMENT' || _headerType == 'VIDEO') ...[
                const SizedBox(height: 16),
                _buildHeaderFileUpload(context, isDark),
              ],
            ],
          ),
        ),

        _buildSectionCard(
          context,
          isDark,
          stepNumber: 3,
          title: "Message Body",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('tpl_body_text_field'),
                controller: _bodyTextController,
                maxLines: 5,
                style: const TextStyle(fontSize: 14),
                showCursor: true,
                enableInteractiveSelection: true,
                decoration: InputDecoration(
                  hintText: 'Enter your message body here... Use {{1}} for variables.',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Body content required';
                  return null;
                },
              ),
              if (_bodyExampleControllers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  "Example Data for Body Variables",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < _bodyExampleControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextFormField(
                        controller: _bodyExampleControllers[i],
                        style: const TextStyle(fontSize: 13),
                        showCursor: true,
                        enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        hintText: 'Example for {{${i + 1}}}',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),

        _buildSectionCard(
          context,
          isDark,
          stepNumber: 4,
          title: "Footer (Optional)",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('tpl_footer_text_field'),
                controller: _footerTextController,
                style: const TextStyle(fontSize: 14),
                showCursor: true,
                enableInteractiveSelection: true,
                decoration: InputDecoration(
                  labelText: 'Footer Text',
                  labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Interactive Buttons",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Add up to 10 buttons (Quick Replies, Website, or Phone).",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _addButton,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: isDark ? Colors.white : Colors.black87),
                        const SizedBox(width: 4),
                        Text(
                          "ADD\nBUTTON",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_buttonControllers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _buttonControllers.length,
                    itemBuilder: (context, idx) {
                      final actionType = _buttonActions[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2130) : Colors.white,
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Button #${idx + 1}",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  onPressed: () => _removeButton(idx),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Action Type dropdown & Button Text row
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 500;
                                final dropdownField = DropdownButtonFormField<String>(
                                  initialValue: actionType,
                                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Action Type',
                                    labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'QUICK_REPLY', child: Text('Quick Reply (Custom)')),
                                    DropdownMenuItem(value: 'URL', child: Text('Visit Website')),
                                    DropdownMenuItem(value: 'PHONE_NUMBER', child: Text('Call Phone Number')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _buttonActions[idx] = val);
                                    }
                                  },
                                );
                                final labelField = TextFormField(
                                  controller: _buttonControllers[idx],
                                  style: const TextStyle(fontSize: 14),
                                  showCursor: true,
                                  enableInteractiveSelection: true,
                                  decoration: InputDecoration(
                                    labelText: 'Button Text',
                                    labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                );
                                
                                return isWide 
                                    ? Row(
                                        children: [
                                          Expanded(flex: 4, child: dropdownField),
                                          const SizedBox(width: 12),
                                          Expanded(flex: 5, child: labelField),
                                        ],
                                      ) 
                                    : Column(
                                        children: [
                                          dropdownField,
                                          const SizedBox(height: 12),
                                          labelField,
                                        ],
                                      );
                              },
                            ),
                            if (actionType != 'QUICK_REPLY') ...[
                              const SizedBox(height: 12),
                              if (actionType == 'URL')
                                TextFormField(
                                  controller: _buttonSecondaryControllers[idx],
                                  style: const TextStyle(fontSize: 14),
                                  showCursor: true,
                                  enableInteractiveSelection: true,
                                  decoration: InputDecoration(
                                    labelText: 'Website URL',
                                    hintText: 'https://example.com',
                                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                                    labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              if (actionType == 'PHONE_NUMBER')
                                Row(
                                  children: [
                                    // Code
                                    SizedBox(
                                      width: 80,
                                      child: TextFormField(
                                        controller: _buttonCountryCodeControllers[idx],
                                        style: const TextStyle(fontSize: 14),
                                        showCursor: true,
                                        enableInteractiveSelection: true,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Code',
                                          hintText: '91',
                                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                                          labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Phone
                                    Expanded(
                                      child: TextFormField(
                                        controller: _buttonSecondaryControllers[idx],
                                        style: const TextStyle(fontSize: 14),
                                        showCursor: true,
                                        enableInteractiveSelection: true,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          labelText: 'Phone',
                                          hintText: '9211976541',
                                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                                          labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadHeaderFile() async {
    try {
      FileType fileType = FileType.any;
      if (_headerType == 'IMAGE') fileType = FileType.image;
      if (_headerType == 'VIDEO') fileType = FileType.video;
      if (_headerType == 'DOCUMENT') fileType = FileType.custom;

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: _headerType == 'DOCUMENT' ? ['pdf', 'doc', 'docx'] : null,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploadingHeader = true);
        
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final ext = result.files.single.extension ?? 'bin';
        final fileName = 'whatsapp-templates/${DateTime.now().millisecondsSinceEpoch}.$ext';
        
        final r2Service = R2Service();
        final contentType = _headerType == 'IMAGE' ? 'image/$ext' 
                          : _headerType == 'VIDEO' ? 'video/$ext' 
                          : 'application/pdf'; // simplified

        final uploadedUrl = await r2Service.uploadFile(bytes, fileName, contentType);
        
        setState(() {
          _isUploadingHeader = false;
          if (uploadedUrl != null) {
             _headerFileUrl = '${R2Service.publicBaseUrl}/$fileName';
          }
        });
      }
    } catch (e) {
      setState(() => _isUploadingHeader = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File upload failed: $e')));
      }
    }
  }

  Widget _buildHeaderFileUpload(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_headerFileUrl != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50,
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "File uploaded successfully and ready for template submission.",
                    style: TextStyle(fontSize: 13, color: Colors.green),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _headerFileUrl = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: _isUploadingHeader ? null : _pickAndUploadHeaderFile,
          icon: _isUploadingHeader
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file, size: 18),
          label: Text(_isUploadingHeader ? 'Uploading...' : 'Choose File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.blue.shade800 : Colors.blue.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Meta will review this media file when approving your template.",
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    bool isDark, {
    required int stepNumber,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withValues(alpha: 0.2) : const Color(0xFFE6F0FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue.shade200 : const Color(0xFF0066FF),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget buildMediaPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _headerType == 'IMAGE'
              ? Icons.image_outlined
              : _headerType == 'VIDEO'
                  ? Icons.play_circle_outline
                  : Icons.picture_as_pdf_outlined,
          size: 28,
          color: const Color(0xFF54656F),
        ),
        const SizedBox(height: 6),
        Text(
          _headerType == 'IMAGE'
              ? 'IMAGE HEADER'
              : _headerType == 'VIDEO'
                  ? 'VIDEO HEADER'
                  : 'DOCUMENT HEADER',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF54656F),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // --- LIVE PREVIEW BUBBLE ---

  Widget _buildLiveWhatsAppPreview(BuildContext context, bool isDark) {
    String bodyText = _bodyTextController.text.isEmpty
        ? 'Enter your message body here... Use {{1}} for variables.'
        : _bodyTextController.text;
    final bodyVariables = _getUniqueVariables(_bodyTextController.text);
    for (int i = 0; i < bodyVariables.length; i++) {
      final varNum = bodyVariables[i];
      final val = _bodyExampleControllers[i].text;
      bodyText = bodyText.replaceAll('{{$varNum}}', val.isEmpty ? 'Sample $varNum' : val);
    }
    
    String headerDisplayText = _headerTextController.text.isEmpty
        ? 'Header Text'
        : _headerTextController.text;
    final headerVariables = _getUniqueVariables(_headerTextController.text);
    for (int i = 0; i < headerVariables.length; i++) {
      final varNum = headerVariables[i];
      final val = _headerExampleControllers[i].text;
      headerDisplayText = headerDisplayText.replaceAll('{{$varNum}}', val.isEmpty ? 'Sample $varNum' : val);
    }

    final templateName = _nameController.text.isEmpty ? 'New Template' : _nameController.text;

    final List<Map<String, dynamic>> components = [];
    if (_headerType != 'NONE') {
      final Map<String, dynamic> header = {
        'type': 'HEADER',
        'format': _headerType,
      };
      if (_headerType == 'TEXT') {
        header['text'] = headerDisplayText;
      } else if (_headerType == 'LOCATION') {
        header['placeName'] = _placeNameController.text;
        header['address'] = _addressController.text;
        header['latitude'] = _latitudeController.text;
        header['longitude'] = _longitudeController.text;
      } else {
        header['example'] = {
          'header_handle': [_headerFileUrl ?? 'https://r2.cloudflare.com/assets/sample-template-media.png']
        };
      }
      components.add(header);
    }
    components.add({
      'type': 'BODY',
      'text': bodyText,
    });
    if (_footerTextController.text.trim().isNotEmpty) {
      components.add({
        'type': 'FOOTER',
        'text': _footerTextController.text,
      });
    }
    if (_buttonControllers.isNotEmpty) {
      final List<Map<String, dynamic>> buttons = [];
      for (int i = 0; i < _buttonControllers.length; i++) {
        final actionType = _buttonActions[i];
        final Map<String, dynamic> btn = {
          'type': actionType,
          'text': _buttonControllers[i].text.isEmpty ? 'Button' : _buttonControllers[i].text,
        };
        if (actionType == 'PHONE_NUMBER') {
          btn['phone_number'] = _buttonSecondaryControllers[i].text;
        } else if (actionType == 'URL') {
          btn['url'] = _buttonSecondaryControllers[i].text;
        }
        buttons.add(btn);
      }
      components.add({
        'type': 'BUTTONS',
        'buttons': buttons,
      });
    }

    final previewTemplateMap = {
      'name': templateName,
      'category': _selectedCategory,
      'components': components,
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEFECE5), // WhatsApp Web beige background
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "LIVE PREVIEW",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF7B8B95), // Dark gray
                ),
              ),
              Row(
                children: [
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFB5BAC0), shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFB5BAC0), shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFB5BAC0), shape: BoxShape.circle)),
                ],
              )
            ],
          ),
          const SizedBox(height: 120),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Unified Preview Bubble Component
              WhatsAppPreviewBubble(
                template: previewTemplateMap,
                bodyText: bodyText,
                isDark: false, // Live preview is always rendered in light mode inside beige simulator
              ),
            ],
          ),
          
          const SizedBox(height: 120),
          const Center(
            child: Text(
              "META BUSINESS API RENDERING",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Color(0xFF8696A0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
