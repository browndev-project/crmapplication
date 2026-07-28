import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/lead_model.dart';
import '../../data/models/property_model.dart';
import '../../data/models/broker_model.dart';
import '../providers/booking_provider.dart';
import '../providers/whatsapp_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../core/utils/date_utils.dart';
import 'lead_autocomplete_dropdown.dart';

class BookingCreateDialog extends ConsumerStatefulWidget {
  final Booking? booking;
  final Lead? prefilledLead;

  const BookingCreateDialog({super.key, this.booking, this.prefilledLead});

  @override
  ConsumerState<BookingCreateDialog> createState() => _BookingCreateDialogState();
}

class _BookingCreateDialogState extends ConsumerState<BookingCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  List<PropertyName> _properties = [];
  List<Broker> _brokers = [];
  bool _isLoadingDropdowns = true;
  String? _dropdownLoadError;

  PropertyName? _selectedProperty;
  late TextEditingController _finalAmountController;
  late TextEditingController _bookingAmountController;

  bool _isBrokerageDeal = false;
  Broker? _selectedBroker;
  String _brokerageType = 'percentage';
  late TextEditingController _brokerageValueController;
  late TextEditingController _paidBrokerageController;

  // Installments list of maps
  // [{ 'name': TextEditingController, 'amount': TextEditingController, 'dueDate': DateTime, 'status': 'pending'|'paid', 'paidDate': DateTime? }]
  final List<Map<String, dynamic>> _installments = [];

  // WhatsApp reminder configuration states
  bool _sendReminders = true;
  int _reminderDaysBefore = 7;
  String _reminderTime = "10:00";
  Map<String, dynamic>? _selectedReminderTemplate;
  // Map of variable index (String) -> Map of source and custom value
  // e.g. { "1": { "source": "leadName", "custom": "" } }
  final Map<String, Map<String, String>> _reminderVarMappings = {};

  bool _sendOverdueReminders = true;
  int _overdueReminderDaysLimit = 7;
  String _overdueReminderTime = "10:00";
  Map<String, dynamic>? _selectedOverdueTemplate;
  final Map<String, Map<String, String>> _overdueVarMappings = {};

  bool _isSaving = false;
  Lead? _selectedLead;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;

    _selectedLead = widget.prefilledLead;
    if (_selectedLead == null && b != null && b.lead != null) {
      _selectedLead = Lead(
        id: b.lead!.id,
        leadId: b.lead!.id,
        source: '',
        status: '',
        pipeline: '',
        name: b.lead!.name,
        email: b.lead!.email,
        phoneNo: b.lead!.phoneNo,
        description: '',
        createdAt: '',
        updatedAt: '',
      );
    }

    _finalAmountController = TextEditingController(text: b != null ? b.finalAmount.toStringAsFixed(0) : '');
    _bookingAmountController = TextEditingController(text: b != null ? b.bookingAmount.toStringAsFixed(0) : '');

    _isBrokerageDeal = b?.isBrokerageDeal ?? false;
    _brokerageType = b != null && b.brokerageType != 'none' ? b.brokerageType : 'percentage';
    _brokerageValueController = TextEditingController(text: b != null ? b.brokerageValue.toStringAsFixed(0) : '0');
    _paidBrokerageController = TextEditingController(text: b != null ? b.paidBrokerageAmount.toStringAsFixed(0) : '0');

    _sendReminders = b?.sendReminders ?? true;
    _reminderDaysBefore = b?.reminderDaysBefore ?? 7;
    _reminderTime = b?.reminderTime ?? "10:00";

    _sendOverdueReminders = b?.sendOverdueReminders ?? true;
    _overdueReminderDaysLimit = b?.overdueReminderDaysLimit ?? 7;
    _overdueReminderTime = b?.overdueReminderTime ?? "10:00";

    // Prefill installments if editing
    if (b != null && b.paymentPlan.isNotEmpty) {
      for (var milestone in b.paymentPlan) {
        _installments.add({
          'name': TextEditingController(text: milestone.milestoneName),
          'amount': TextEditingController(text: milestone.amount.toStringAsFixed(0)),
          'dueDate': DateTimeUtils.parseSafe(milestone.dueDate) ?? DateTime.now(),
          'status': milestone.status,
          'paidDate': milestone.paidDate != null ? DateTimeUtils.parseSafe(milestone.paidDate) : null,
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDropdownData();
      }
    });
  }

  @override
  void dispose() {
    _finalAmountController.dispose();
    _bookingAmountController.dispose();
    _brokerageValueController.dispose();
    _paidBrokerageController.dispose();
    for (var inst in _installments) {
      (inst['name'] as TextEditingController).dispose();
      (inst['amount'] as TextEditingController).dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdownData() async {
    setState(() {
      _isLoadingDropdowns = true;
      _dropdownLoadError = null;
    });

    try {
      final service = ref.read(bookingServiceProvider);
      final propsFuture = service.fetchAvailableProperties();
      
      final permissions = ref.read(permissionsProvider);
      final userRole = ref.read(loginProvider).user?.systemRole;

      Future<List<Broker>> brokersFuture;
      if (permissions.hasModule("modules.broker", userRole: userRole) &&
          permissions.hasPermission("broker.view", userRole: userRole)) {
        brokersFuture = service.fetchActiveBrokers();
      } else {
        brokersFuture = Future.value(<Broker>[]);
      }

      final whatsappNotifier = ref.read(whatsappTemplatesProvider.notifier);
      final templatesFuture = whatsappNotifier.fetchTemplates();

      final results = await Future.wait([propsFuture, brokersFuture, templatesFuture]);
      
      _properties = results[0] as List<PropertyName>;
      _brokers = results[1] as List<Broker>;

      final b = widget.booking;
      if (b != null) {
        // Find selected property
        if (b.property != null) {
          _selectedProperty = _properties.firstWhere(
            (p) => p.id == b.property!.id,
            orElse: () => PropertyName(
              id: b.property!.id,
              name: b.property!.name,
              projectId: '',
              status: '',
              brokerageType: b.property!.brokerageType,
              brokerageValue: b.property!.brokerageValue,
            ),
          );
        }
        // Find selected broker
        if (b.broker != null) {
          _selectedBroker = _brokers.firstWhere(
            (br) => br.id == b.broker!.id,
            orElse: () => Broker(
              id: b.broker!.id,
              type: 'Broker',
              name: b.broker!.name,
              phoneNo: b.broker!.phoneNo,
              email: b.broker!.email,
              agencyName: b.broker!.agencyName,
              address: BrokerAddress(
                address1: '',
                address2: '',
                city: '',
                state: '',
                pinCode: '',
                country: '',
              ),
            ),
          );
        }

        // Setup template prefill if editing
        final templates = ref.read(whatsappTemplatesProvider).templates;
        if (b.reminderTemplate != null && b.reminderTemplate!.name != null) {
          final t = templates.firstWhere(
            (x) => x['name'] == b.reminderTemplate!.name,
            orElse: () => <String, dynamic>{},
          );
          if (t.isNotEmpty) {
            _selectedReminderTemplate = t;
            // Parse prefilled variable mappings
            for (var mapping in b.reminderVariableMappings) {
              _reminderVarMappings[mapping.key] = {
                'source': mapping.source,
                'custom': mapping.customValue,
              };
            }
          }
        }
        if (b.overdueReminderTemplate != null && b.overdueReminderTemplate!.name != null) {
          final t = templates.firstWhere(
            (x) => x['name'] == b.overdueReminderTemplate!.name,
            orElse: () => <String, dynamic>{},
          );
          if (t.isNotEmpty) {
            _selectedOverdueTemplate = t;
            // Parse prefilled variable mappings
            for (var mapping in b.overdueReminderVariableMappings) {
              _overdueVarMappings[mapping.key] = {
                'source': mapping.source,
                'custom': mapping.customValue,
              };
            }
          }
        }
      }

      setState(() {
        _isLoadingDropdowns = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDropdowns = false;
        _dropdownLoadError = 'Failed to load form data: $e';
      });
    }
  }

  double get _finalAmount => double.tryParse(_finalAmountController.text) ?? 0.0;
  double get _bookingAmount => double.tryParse(_bookingAmountController.text) ?? 0.0;
  double get _brokerageValue => double.tryParse(_brokerageValueController.text) ?? 0.0;

  double get _estimatedBrokerage {
    if (_brokerageType == 'percentage') {
      return (_finalAmount * _brokerageValue) / 100;
    } else if (_brokerageType == 'flat') {
      return _brokerageValue;
    }
    return 0.0;
  }

  double get _totalInstallments {
    double total = 0.0;
    for (var inst in _installments) {
      total += double.tryParse((inst['amount'] as TextEditingController).text) ?? 0.0;
    }
    return total;
  }

  void _addInstallment() {
    setState(() {
      final index = _installments.length + 1;
      _installments.add({
        'name': TextEditingController(text: 'Installment $index'),
        'amount': TextEditingController(text: ''),
        'dueDate': DateTime.now().add(Duration(days: 30 * index)),
        'status': 'pending',
        'paidDate': null,
      });
    });
  }

  void _removeInstallment(int index) {
    setState(() {
      final removed = _installments.removeAt(index);
      (removed['name'] as TextEditingController).dispose();
      (removed['amount'] as TextEditingController).dispose();
    });
  }

  List<String> _extractTemplateVariables(Map<String, dynamic>? template) {
    if (template == null) return [];
    final List<dynamic> components = template['components'] ?? [];
    final bodyComponent = components.firstWhere((c) => c['type'] == 'BODY', orElse: () => null);
    if (bodyComponent == null) return [];
    final String text = bodyComponent['text'] ?? '';
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(text);
    return matches.map((m) => m.group(1)!).toList();
  }

  String _getTemplatePreview(Map<String, dynamic>? template, Map<String, Map<String, String>> varMappings) {
    if (template == null) return 'Select a template to see preview';
    final List<dynamic> components = template['components'] ?? [];
    final bodyComponent = components.firstWhere((c) => c['type'] == 'BODY', orElse: () => null);
    if (bodyComponent == null) return 'No body component found in template';
    String text = bodyComponent['text'] ?? '';
    
    // Replace variable mappings in the preview text
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(text).toList();
    for (var match in matches) {
      final varIndex = match.group(1)!;
      final mapping = varMappings[varIndex];
      String displayVal = '{{$varIndex}}';
      if (mapping != null) {
        final source = mapping['source'];
        if (source == 'leadName') {
          displayVal = _selectedLead?.name ?? '';
        } else if (source == 'propertyName') {
          displayVal = _selectedProperty?.name ?? 'Villa 101';
        } else if (source == 'milestoneName') {
          displayVal = _installments.isNotEmpty 
              ? (_installments[0]['name'] as TextEditingController).text 
              : 'Installment 1';
        } else if (source == 'amount') {
          displayVal = _installments.isNotEmpty 
              ? '₹${(_installments[0]['amount'] as TextEditingController).text}' 
              : '₹1,00,000';
        } else if (source == 'dueDate') {
          displayVal = _installments.isNotEmpty 
              ? DateFormat('dd MMM yyyy').format(_installments[0]['dueDate'] as DateTime) 
              : '30 Sep 2026';
        } else if (source == 'custom') {
          displayVal = mapping['custom'] ?? '';
          if (displayVal.isEmpty) displayVal = '{{$varIndex}}';
        }
      }
      text = text.replaceAll('{{$varIndex}}', displayVal);
    }
    return text;
  }

  Future<void> _selectDate(BuildContext context, int index, {bool isPaidDate = false}) async {
    final inst = _installments[index];
    final DateTime initialDate = isPaidDate 
        ? (inst['paidDate'] as DateTime? ?? DateTime.now())
        : (inst['dueDate'] as DateTime? ?? DateTime.now());
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isPaidDate) {
          inst['paidDate'] = picked;
        } else {
          inst['dueDate'] = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLead == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a lead')),
      );
      return;
    }
    if (_selectedProperty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final leadObj = {
      '_id': _selectedLead!.id,
      'name': _selectedLead!.name,
      'email': _selectedLead!.email,
      'phoneNo': _selectedLead!.phoneNo,
    };

    final propertyObj = {
      '_id': _selectedProperty!.id,
      'name': _selectedProperty!.name,
      'brokerageType': _selectedProperty!.brokerageType,
      'brokerageValue': _selectedProperty!.brokerageValue,
    };

    final paymentPlan = _installments.map((inst) {
      return {
        'milestoneName': (inst['name'] as TextEditingController).text,
        'amount': double.tryParse((inst['amount'] as TextEditingController).text) ?? 0.0,
        'dueDate': DateTimeUtils.toApiString(inst['dueDate'] as DateTime?),
        'status': inst['status'],
        if (inst['status'] == 'paid' && inst['paidDate'] != null)
          'paidDate': DateTimeUtils.toApiString(inst['paidDate'] as DateTime?),
      };
    }).toList();

    // Map template variables to List format for API
    List<Map<String, dynamic>> buildVarMappings(
      Map<String, dynamic>? template,
      Map<String, Map<String, String>> mappings,
    ) {
      if (template == null) return [];
      final variables = _extractTemplateVariables(template);
      return variables.map((vIdx) {
        final map = mappings[vIdx] ?? {'source': 'custom', 'custom': ''};
        return {
          'key': vIdx,
          'section': 'body',
          'source': map['source'] ?? 'custom',
          'customValue': map['custom'] ?? '',
        };
      }).toList();
    }

    final Map<String, dynamic> payload = {
      'company': ref.read(loginProvider).user?.company ?? '',
      'lead': _selectedLead!.id,
      'leadId': _selectedLead!.id,
      'leadDetails': leadObj, // Fallback lead details object
      'property': _selectedProperty!.id,
      'propertyId': _selectedProperty!.id,
      'propertyDetails': propertyObj,
      'finalAmount': _finalAmount,
      'bookingAmount': _bookingAmount,
      'status': widget.booking?.status ?? 'active',
      'isBrokerageDeal': _isBrokerageDeal,
      'broker': _isBrokerageDeal ? _selectedBroker?.id : null,
      'brokerId': _isBrokerageDeal ? _selectedBroker?.id : null,
      'brokerageType': _isBrokerageDeal ? _brokerageType : 'none',
      'brokerageValue': _isBrokerageDeal ? _brokerageValue : 0.0,
      'brokerageAmount': _isBrokerageDeal ? _estimatedBrokerage : 0.0,
      'paidBrokerageAmount': _isBrokerageDeal ? double.tryParse(_paidBrokerageController.text) ?? 0.0 : 0.0,
      'paymentPlan': paymentPlan,
      'sendReminders': _sendReminders,
      'reminderDaysBefore': _reminderDaysBefore,
      'reminderTime': _reminderTime,
      'reminderTemplate': _selectedReminderTemplate != null
          ? {
              'name': _selectedReminderTemplate!['name'],
              'language': _selectedReminderTemplate!['language'] ?? 'en',
              'components': _selectedReminderTemplate!['components'] ?? [],
            }
          : null,
      'reminderVariableMappings': buildVarMappings(_selectedReminderTemplate, _reminderVarMappings),
      'sendOverdueReminders': _sendOverdueReminders,
      'overdueReminderDaysLimit': _overdueReminderDaysLimit,
      'overdueReminderTime': _overdueReminderTime,
      'overdueReminderTemplate': _selectedOverdueTemplate != null
          ? {
              'name': _selectedOverdueTemplate!['name'],
              'language': _selectedOverdueTemplate!['language'] ?? 'en',
              'components': _selectedOverdueTemplate!['components'] ?? [],
            }
          : null,
      'overdueReminderVariableMappings': buildVarMappings(_selectedOverdueTemplate, _overdueVarMappings),
    };

    try {
      if (widget.booking != null) {
        await ref.read(bookingsProvider.notifier).updateBooking(widget.booking!.id, payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking updated successfully')),
        );
      } else {
        await ref.read(bookingsProvider.notifier).createBooking(payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking created successfully')),
        );
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;
    final hasBrokerAccess = permissions.hasModule("modules.broker", userRole: userRole) &&
        permissions.hasPermission("broker.view", userRole: userRole);

    final templates = ref.watch(whatsappTemplatesProvider).templates;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.booking != null
              ? "Edit Booking"
              : (_selectedLead != null ? "Book Property for ${_selectedLead!.name}" : "Book Property"),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: _isLoadingDropdowns
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _dropdownLoadError != null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text(_dropdownLoadError!, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDropdownData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section 1: Booking Details Card
                              _buildFormCard(
                                title: "Booking Details",
                                child: Column(
                                  children: [
                                    if (widget.booking == null && widget.prefilledLead == null) ...[
                                      LeadAutocompleteDropdown(
                                        initialLead: _selectedLead,
                                        onLeadSelected: (lead) {
                                          setState(() {
                                            _selectedLead = lead;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    // Select Property Dropdown
                                    DropdownButtonFormField<PropertyName>(
                                      initialValue: _selectedProperty,
                                      isExpanded: true,
                                      hint: const Text("Select Property *"),
                                      decoration: _getInputDecoration(isDark),
                                      items: _properties.map((p) {
                                        return DropdownMenuItem<PropertyName>(
                                          value: p,
                                          child: Text(p.name),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedProperty = val;
                                          if (val != null && val.brokerageType != 'none') {
                                            _brokerageType = val.brokerageType;
                                            _brokerageValueController.text = val.brokerageValue.toStringAsFixed(0);
                                          }
                                        });
                                      },
                                      validator: (val) => val == null ? 'Property is required' : null,
                                    ),
                                    const SizedBox(height: 16),
                                    // Final Deal Amount
                                    TextFormField(
                                      controller: _finalAmountController,
                                      keyboardType: TextInputType.number,
                                      decoration: _getInputDecoration(isDark, labelText: "Final Deal Amount (₹) *"),
                                      onChanged: (_) => setState(() {}),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'Deal amount is required';
                                        if (double.tryParse(val) == null) return 'Must be a valid number';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Booking Amount Paid
                                    TextFormField(
                                      controller: _bookingAmountController,
                                      keyboardType: TextInputType.number,
                                      decoration: _getInputDecoration(isDark, labelText: "Booking Amount Paid (₹) *"),
                                      onChanged: (_) => setState(() {}),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'Booking deposit is required';
                                        if (double.tryParse(val) == null) return 'Must be a valid number';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Section 2: Brokerage Card (Conditional)
                              if (hasBrokerAccess)
                                _buildFormCard(
                                  title: "Brokerage & Partners",
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isBrokerageDeal = !_isBrokerageDeal;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: _isBrokerageDeal,
                                                activeColor: const Color(0xFF2563EB),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _isBrokerageDeal = val ?? false;
                                                  });
                                                },
                                              ),
                                              Text(
                                                "Is Brokerage Deal",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      AnimatedCrossFade(
                                        duration: const Duration(milliseconds: 200),
                                        crossFadeState: _isBrokerageDeal
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                        secondChild: const SizedBox.shrink(),
                                        firstChild: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            // Select Broker
                                            DropdownButtonFormField<Broker>(
                                              initialValue: _selectedBroker,
                                              isExpanded: true,
                                              hint: const Text("Select Broker/CP *"),
                                              decoration: _getInputDecoration(isDark),
                                              items: _brokers.map((b) {
                                                return DropdownMenuItem<Broker>(
                                                  value: b,
                                                  child: Text("${b.name} (${b.agencyName})"),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  _selectedBroker = val;
                                                });
                                              },
                                              validator: (val) => _isBrokerageDeal && val == null 
                                                  ? 'Broker is required' 
                                                  : null,
                                            ),
                                            const SizedBox(height: 16),
                                            DropdownButtonFormField<String>(
                                              initialValue: _brokerageType == 'none' ? 'percentage' : _brokerageType,
                                              isExpanded: true,
                                              decoration: _getInputDecoration(isDark, labelText: "Brokerage Type"),
                                              items: const [
                                                DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                                                DropdownMenuItem(value: 'flat', child: Text('Flat Amount (₹)')),
                                              ],
                                              onChanged: (val) {
                                                setState(() {
                                                  _brokerageType = val ?? 'percentage';
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: _brokerageValueController,
                                              keyboardType: TextInputType.number,
                                              decoration: _getInputDecoration(isDark, labelText: "Brokerage Value"),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                        const SizedBox(height: 16),
                                        // Paid Brokerage
                                        TextFormField(
                                          controller: _paidBrokerageController,
                                          keyboardType: TextInputType.number,
                                          decoration: _getInputDecoration(isDark, labelText: "Paid Brokerage (₹)"),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Estimated Total Brokerage:\n₹ ${_estimatedBrokerage.toStringAsFixed(0)}",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                              if (hasBrokerAccess) const SizedBox(height: 16),

                              // Section 3: Scheduled Payments (Payment Plan)
                              _buildFormCard(
                                title: "Scheduled Payments (${_installments.length})",
                                titleSuffix: TextButton.icon(
                                  onPressed: _addInstallment,
                                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
                                  label: Text(
                                    "Add Installment",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: Color(0xFF2563EB), width: 1),
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_installments.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 24),
                                        child: Center(
                                          child: Text(
                                            "No installments scheduled yet. Click \"Add Installment\" to begin.",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      )
                                    else
                                      ...List.generate(_installments.length, (index) {
                                        final inst = _installments[index];
                                        final nameCtrl = inst['name'] as TextEditingController;
                                        final amtCtrl = inst['amount'] as TextEditingController;
                                        final dueDate = inst['dueDate'] as DateTime;
                                        final status = inst['status'] as String;
                                        final paidDate = inst['paidDate'] as DateTime?;

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 16),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                          ),
                                          color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Card Header with Delete Button
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      "Installment ${index + 1}",
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () => _removeInstallment(index),
                                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                                      constraints: const BoxConstraints(),
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                // Milestone Name
                                                TextFormField(
                                                  controller: nameCtrl,
                                                  decoration: _getInputDecoration(isDark, labelText: "Installment Name"),
                                                  validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                                                ),
                                                const SizedBox(height: 12),
                                                // Amount
                                                TextFormField(
                                                  controller: amtCtrl,
                                                  keyboardType: TextInputType.number,
                                                  decoration: _getInputDecoration(isDark, labelText: "Amount (₹)"),
                                                  onChanged: (_) => setState(() {}),
                                                  validator: (val) {
                                                    if (val == null || val.trim().isEmpty) return 'Amount is required';
                                                    if (double.tryParse(val) == null) return 'Must be a valid number';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 12),
                                                // Due Date Pick Row
                                                InkWell(
                                                  onTap: () => _selectDate(context, index),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          DateFormat('dd/MM/yyyy').format(dueDate),
                                                          style: TextStyle(
                                                            color: isDark ? Colors.white : Colors.black87,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        Icon(Icons.calendar_today_outlined, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                // Status Dropdown
                                                DropdownButtonFormField<String>(
                                                  initialValue: status,
                                                  decoration: _getInputDecoration(isDark, labelText: "Status"),
                                                  items: const [
                                                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                                                  ],
                                                  onChanged: (val) {
                                                    setState(() {
                                                      inst['status'] = val ?? 'pending';
                                                      if (val == 'paid' && inst['paidDate'] == null) {
                                                        inst['paidDate'] = DateTime.now();
                                                      }
                                                    });
                                                  },
                                                ),
                                                if (status == 'paid') ...[
                                                  const SizedBox(height: 12),
                                                  // Paid Date Pick
                                                  InkWell(
                                                    onTap: () => _selectDate(context, index, isPaidDate: true),
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            paidDate != null 
                                                                ? DateFormat('dd/MM/yyyy').format(paidDate)
                                                                : 'Select Paid Date',
                                                            style: TextStyle(
                                                              color: isDark ? Colors.white : Colors.black87,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          Icon(Icons.calendar_today_outlined, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    
                                    // Bottom install summary banner
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Installments Total: ₹ ${_totalInstallments.toStringAsFixed(0)}",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                          (() {
                                            final matches = (_totalInstallments + _bookingAmount) == _finalAmount;
                                            if (matches) {
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "Matches Deal Amount",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                                                ],
                                              );
                                            } else {
                                              final rem = _finalAmount - (_totalInstallments + _bookingAmount);
                                              return Text(
                                                "Remaining: ₹ ${rem.toStringAsFixed(0)}",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: rem > 0 ? Colors.orange : Colors.red,
                                                ),
                                              );
                                            }
                                          })(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // WhatsApp Sections (Conditional on installments count)
                              if (_installments.isNotEmpty) ...[
                                // WhatsApp Payment Reminders Card
                                _buildFormCard(
                                  title: "WhatsApp Payment Reminders",
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _sendReminders = !_sendReminders;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: _sendReminders,
                                                activeColor: const Color(0xFF2563EB),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _sendReminders = val ?? false;
                                                  });
                                                },
                                              ),
                                              Text(
                                                "Enable Reminders",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      AnimatedCrossFade(
                                        duration: const Duration(milliseconds: 200),
                                        crossFadeState: _sendReminders
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                        secondChild: const SizedBox.shrink(),
                                        firstChild: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            DropdownButtonFormField<int>(
                                              initialValue: _reminderDaysBefore,
                                              isExpanded: true,
                                              decoration: _getInputDecoration(isDark, labelText: "Start Reminders"),
                                              items: List.generate(30, (i) => i + 1).map((days) {
                                                return DropdownMenuItem<int>(
                                                  value: days,
                                                  child: Text("$days days before"),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  _reminderDaysBefore = val ?? 7;
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            DropdownButtonFormField<String>(
                                              initialValue: _reminderTime,
                                              isExpanded: true,
                                              decoration: _getInputDecoration(isDark, labelText: "Reminder Time"),
                                              items: List.generate(13, (i) => i + 9).map((hour) {
                                                final timeStr = "${hour.toString().padLeft(2, '0')}:00";
                                                final ampm = hour >= 12 ? 'PM' : 'AM';
                                                final hr12 = hour > 12 ? hour - 12 : hour;
                                                return DropdownMenuItem<String>(
                                                  value: timeStr,
                                                  child: Text("$timeStr ($hr12 $ampm)"),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  _reminderTime = val ?? "10:00";
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            _buildTemplateMappingSection(
                                              isDark: isDark,
                                              templates: templates,
                                              selectedTemplate: _selectedReminderTemplate,
                                              mappings: _reminderVarMappings,
                                              onTemplateSelected: (t) {
                                                setState(() {
                                                  _selectedReminderTemplate = t;
                                                  _reminderVarMappings.clear();
                                                  if (t != null) {
                                                    final vars = _extractTemplateVariables(t);
                                                    final defaults = ['leadName', 'propertyName', 'milestoneName', 'amount', 'dueDate'];
                                                    for (int i = 0; i < vars.length; i++) {
                                                      _reminderVarMappings[vars[i]] = {
                                                        'source': i < defaults.length ? defaults[i] : 'custom',
                                                        'custom': '',
                                                      };
                                                    }
                                                  }
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // WhatsApp Overdue Reminders Card
                                _buildFormCard(
                                  title: "WhatsApp Overdue Reminders",
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _sendOverdueReminders = !_sendOverdueReminders;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: _sendOverdueReminders,
                                                activeColor: const Color(0xFF2563EB),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _sendOverdueReminders = val ?? false;
                                                  });
                                                },
                                              ),
                                              Text(
                                                "Enable Overdue Reminders",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      AnimatedCrossFade(
                                        duration: const Duration(milliseconds: 200),
                                        crossFadeState: _sendOverdueReminders
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                        secondChild: const SizedBox.shrink(),
                                        firstChild: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            DropdownButtonFormField<int>(
                                              initialValue: _overdueReminderDaysLimit,
                                              isExpanded: true,
                                              decoration: _getInputDecoration(isDark, labelText: "Stop Reminders After"),
                                              items: List.generate(15, (i) => i + 1).map((days) {
                                                return DropdownMenuItem<int>(
                                                  value: days,
                                                  child: Text("$days days overdue"),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  _overdueReminderDaysLimit = val ?? 7;
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            DropdownButtonFormField<String>(
                                              initialValue: _overdueReminderTime,
                                              isExpanded: true,
                                              decoration: _getInputDecoration(isDark, labelText: "Reminder Time"),
                                              items: List.generate(13, (i) => i + 9).map((hour) {
                                                final timeStr = "${hour.toString().padLeft(2, '0')}:00";
                                                final ampm = hour >= 12 ? 'PM' : 'AM';
                                                final hr12 = hour > 12 ? hour - 12 : hour;
                                                return DropdownMenuItem<String>(
                                                  value: timeStr,
                                                  child: Text("$timeStr ($hr12 $ampm)"),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  _overdueReminderTime = val ?? "10:00";
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            _buildTemplateMappingSection(
                                              isDark: isDark,
                                              templates: templates,
                                              selectedTemplate: _selectedOverdueTemplate,
                                              mappings: _overdueVarMappings,
                                              onTemplateSelected: (t) {
                                                setState(() {
                                                  _selectedOverdueTemplate = t;
                                                  _overdueVarMappings.clear();
                                                  if (t != null) {
                                                    final vars = _extractTemplateVariables(t);
                                                    final defaults = ['leadName', 'propertyName', 'milestoneName', 'amount', 'dueDate'];
                                                    for (int i = 0; i < vars.length; i++) {
                                                      _overdueVarMappings[vars[i]] = {
                                                        'source': i < defaults.length ? defaults[i] : 'custom',
                                                        'custom': '',
                                                      };
                                                    }
                                                  }
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Container(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                              child: Text(
                                "CANCEL",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isSaving || _isLoadingDropdowns ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      widget.booking != null ? "UPDATE BOOKING" : "CREATE BOOKING",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFormCard({
    required String title,
    Widget? titleSuffix,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (titleSuffix != null) titleSuffix,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateMappingSection({
    required bool isDark,
    required List<Map<String, dynamic>> templates,
    required Map<String, dynamic>? selectedTemplate,
    required Map<String, Map<String, String>> mappings,
    required Function(Map<String, dynamic>?) onTemplateSelected,
  }) {
    final selectedVariables = _extractTemplateVariables(selectedTemplate);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Reminder Message Template",
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          "Approved Templates",
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey),
        ),
        const SizedBox(height: 8),

        // Template Scroll List + Live Preview Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Templates List
            Expanded(
              flex: 4,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (context, idx) {
                    final t = templates[idx];
                    final name = t['name'] ?? '';
                    final isSelected = selectedTemplate?['name'] == name;

                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      title: Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        "MARKETING • ${(t['language'] ?? 'EN_US').toString().toUpperCase()}",
                        style: const TextStyle(fontSize: 8, color: Colors.grey),
                      ),
                      onTap: () => onTemplateSelected(t),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Right Column: Live Preview Card
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "LIVE PREVIEW",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white38 : Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 158,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _getTemplatePreview(selectedTemplate, mappings),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: selectedTemplate != null 
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.grey,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Variable Mappings Fields
        if (selectedVariables.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            "Variable Parameter Mappings",
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...selectedVariables.map((vIdx) {
            final map = mappings[vIdx] ?? {'source': 'custom', 'custom': ''};
            final source = map['source'] ?? 'custom';
            final customVal = map['custom'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: Text(
                      "{{$vIdx}}",
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: source,
                      isExpanded: true,
                      decoration: _getInputDecoration(isDark),
                      items: const [
                        DropdownMenuItem(value: 'leadName', child: Text('Lead Name')),
                        DropdownMenuItem(value: 'propertyName', child: Text('Property Name')),
                        DropdownMenuItem(value: 'milestoneName', child: Text('Milestone Name')),
                        DropdownMenuItem(value: 'amount', child: Text('Milestone Amount')),
                        DropdownMenuItem(value: 'dueDate', child: Text('Due Date')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom Value')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          mappings[vIdx] = {
                            'source': val ?? 'custom',
                            'custom': customVal,
                          };
                        });
                      },
                    ),
                  ),
                  if (source == 'custom') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: customVal,
                        decoration: _getInputDecoration(isDark, labelText: "Value"),
                        onChanged: (val) {
                          mappings[vIdx] = {
                            'source': source,
                            'custom': val,
                          };
                          // Force state update to re-render preview
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  InputDecoration _getInputDecoration(bool isDark, {String? labelText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
