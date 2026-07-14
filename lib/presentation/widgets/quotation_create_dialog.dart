import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/quotation_model.dart';
import '../providers/quotation_provider.dart';
import '../providers/itinerary_provider.dart';
import '../../data/models/itinerary_model.dart';
import '../providers/company_settings_provider.dart';
import 'lead_autocomplete_dropdown.dart';
import 'itinerary_selection_dialog.dart';
import '../../data/models/lead_model.dart';
import '../screens/lead_profile_screen.dart';

import '../../core/utils/date_utils.dart';

class QuotationCreateDialog extends ConsumerStatefulWidget {
  final Quotation? quotation;
  final ItineraryV2? prefilledItinerary;
  final Lead? prefilledLead;

  const QuotationCreateDialog({
    super.key,
    this.quotation,
    this.prefilledItinerary,
    this.prefilledLead,
  });

  @override
  ConsumerState<QuotationCreateDialog> createState() => _QuotationCreateDialogState();
}

class _QuotationCreateDialogState extends ConsumerState<QuotationCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _quoNoController.dispose();
    _dateController.dispose();
    _validUntilController.dispose();
    _subjectController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _clientCompanyController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _adjustmentController.dispose();
    _termsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  late TextEditingController _quoNoController;
  late TextEditingController _dateController;
  late TextEditingController _validUntilController;
  late TextEditingController _subjectController;
  late TextEditingController _clientNameController;
  late TextEditingController _clientEmailController;
  late TextEditingController _clientPhoneController;
  late TextEditingController _clientCompanyController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _countryController;
  late TextEditingController _adjustmentController;
  late TextEditingController _termsController;

  String _status = 'CREATED';
  List<QuotationItem> _items = [];
  double _subTotal = 0;
  double _discountTotal = 0;
  double _taxTotal = 0;
  double _grandTotal = 0;
  String? quoNoError;
  String? _selectedLeadId;
  String? _selectedItineraryId;
  String? _selectedItinerarySubject;
  String? _itineraryError;
  bool _termsExpanded = true;

  @override
  void initState() {
    super.initState();
    final q = widget.quotation;
    final it = widget.prefilledItinerary;
    final pl = widget.prefilledLead;

    _selectedLeadId = q?.leadId ?? it?.leadId ?? pl?.id;
    _selectedItineraryId = q?.itineraryId ?? it?.id;
    _selectedItinerarySubject = it?.subject;

    _quoNoController = TextEditingController(text: q?.quotationNumber ?? 'QUO-${DateFormat('yyyyMMdd').format(DateTime.now())}');
    _dateController = TextEditingController(text: DateTimeUtils.formatSafe(q?.quotationDate ?? DateTimeUtils.toApiString(DateTime.now()), format: 'dd MMM yyyy'));
    _validUntilController = TextEditingController(text: DateTimeUtils.formatSafe(q?.validUntil ?? DateTimeUtils.toApiString(DateTime.now().add(const Duration(days: 14))), format: 'dd MMM yyyy'));
    _subjectController = TextEditingController(text: q?.subject ?? it?.subject ?? '');

    // Auto-map itinerary fields to quotation
    _clientNameController = TextEditingController(text: q?.clientName ?? it?.clientName ?? pl?.name ?? '');
    _clientEmailController = TextEditingController(text: q?.clientEmail ?? it?.clientEmail ?? pl?.email ?? '');
    _clientPhoneController = TextEditingController(text: q?.clientPhoneNo ?? it?.clientPhoneNo ?? pl?.phoneNo ?? '');
    _clientCompanyController = TextEditingController(text: q?.clientCompany ?? it?.clientCompany ?? pl?.company ?? '');

    _streetController = TextEditingController(text: q?.billingAddress.street ?? pl?.address?.address1 ?? '');
    _cityController = TextEditingController(text: q?.billingAddress.city ?? pl?.address?.city ?? '');
    _stateController = TextEditingController(text: q?.billingAddress.state ?? pl?.address?.state ?? '');
    _zipController = TextEditingController(text: q?.billingAddress.zip ?? pl?.address?.pinCode ?? '');
    _countryController = TextEditingController(text: q?.billingAddress.country ?? pl?.address?.country ?? '');
    _adjustmentController = TextEditingController(text: q?.adjustment.toString() ?? '0');

    if (q != null) {
      _termsController = TextEditingController(text: q.termsAndConditions);
      _status = q.status;
      _items = List.from(q.items);
    } else if (it != null) {
      _termsController = TextEditingController(
        text: it.termsAndConditions.map((e) => '${e.title}: ${e.description}').join('\n'),
      );
      _status = 'CREATED';
      _items = [];
      for (var stay in it.stays) {
        _items.add(QuotationItem(
          itemId: stay.id.isNotEmpty ? stay.id : 'stay_${stay.name.hashCode}',
          name: 'Stay: ${stay.name}',
          description: '${stay.noOfNights} Nights',
          quantity: stay.noOfNights.toDouble(),
          unitPrice: stay.pricePerNight,
          amount: stay.pricePerNight * stay.noOfNights,
          totalAmount: stay.pricePerNight * stay.noOfNights,
        ));
      }
      for (var trans in it.transports) {
        _items.add(QuotationItem(
          itemId: trans.id.isNotEmpty ? trans.id : 'trans_${trans.details.hashCode}',
          name: 'Transport: ${trans.type} - ${trans.details}',
          description: trans.details,
          quantity: 1,
          unitPrice: trans.price,
          amount: trans.price,
          totalAmount: trans.price,
        ));
      }
      if (it.activitiesCost > 0) {
        _items.add(QuotationItem(
          itemId: 'activities',
          name: 'Activities Net Price',
          description: '${it.stays.length} Stays, ${it.transports.length} Transports',
          quantity: 1,
          unitPrice: it.activitiesCost,
          amount: it.activitiesCost,
          totalAmount: it.activitiesCost,
        ));
      }
    } else {
      _termsController = TextEditingController(text: '');
      _status = 'CREATED';
      _items = [];
    }

    _calculateTotals();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itineraryV2Provider.notifier).fetchItineraries(refresh: true);
      _loadInitialSettings();
    });
  }

  void _applyItinerary(ItineraryV2 it) {
    setState(() {
      _itineraryError = null;
      _selectedItineraryId = it.id;
      _selectedItinerarySubject = it.subject;
      _subjectController.text = it.subject;
      _clientNameController.text = it.clientName;
      _clientEmailController.text = it.clientEmail;
      _clientPhoneController.text = it.clientPhoneNo;
      _clientCompanyController.text = it.clientCompany;

      _termsController.text = it.termsAndConditions.map((e) => '${e.title}: ${e.description}').join('\n');
      _status = 'CREATED';
      _items = [];
      for (var stay in it.stays) {
        _items.add(QuotationItem(
          itemId: stay.id.isNotEmpty ? stay.id : 'stay_${stay.name.hashCode}',
          name: 'Stay: ${stay.name}',
          description: '${stay.noOfNights} Nights',
          quantity: stay.noOfNights.toDouble(),
          unitPrice: stay.pricePerNight,
          amount: stay.pricePerNight * stay.noOfNights,
          totalAmount: stay.pricePerNight * stay.noOfNights,
        ));
      }
      for (var trans in it.transports) {
        _items.add(QuotationItem(
          itemId: trans.id.isNotEmpty ? trans.id : 'trans_${trans.details.hashCode}',
          name: 'Transport: ${trans.type} - ${trans.details}',
          description: trans.details,
          quantity: 1,
          unitPrice: trans.price,
          amount: trans.price,
          totalAmount: trans.price,
        ));
      }
      if (it.activitiesCost > 0) {
        _items.add(QuotationItem(
          itemId: 'activities',
          name: 'Activities Net Price',
          description: '${it.stays.length} Stays, ${it.transports.length} Transports',
          quantity: 1,
          unitPrice: it.activitiesCost,
          amount: it.activitiesCost,
          totalAmount: it.activitiesCost,
        ));
      }
    });
    _calculateTotals();
  }

  void _clearItinerary() {
    setState(() {
      _itineraryError = null;
      _selectedItineraryId = null;
      _selectedItinerarySubject = null;
      _items = [];
      _termsController.text = '';
    });
    _calculateTotals();
  }

  void _calculateTotals() {
    double st = 0;
    double dt = 0;
    double tt = 0;
    for (var item in _items) {
      st += item.unitPrice * item.quantity;
      dt += item.discount;
      tt += item.tax;
    }
    double adj = double.tryParse(_adjustmentController.text) ?? 0;
    setState(() {
      _subTotal = st;
      _discountTotal = dt;
      _taxTotal = tt;
      _grandTotal = st - dt + tt + adj;
    });
  }

  Future<void> _loadInitialSettings() async {
    if (widget.quotation != null) return; // Don't prefill when editing

    try {
      final settings = await ref.read(companySettingsProvider.future);
      if (settings != null && mounted) {
        setState(() {
          if (_termsController.text.isEmpty) {
            _termsController.text = settings.invoiceDefaultTerms;
          }
        });
      }
    } catch (e) {
      debugPrint('Error prefilling settings: $e');
    }
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
    Widget? trailingHeader,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (trailingHeader != null) trailingHeader,
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: child,
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    setState(() {
      _items.add(QuotationItem(
        itemId: 'prod_${DateTime.now().millisecondsSinceEpoch}',
        name: '',
        description: '',
        quantity: 1,
        unitPrice: 0,
        amount: 0,
        totalAmount: 0,
        discount: 0,
        tax: 0,
      ));
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateItem(int index, {double? quantity, double? unitPrice, double? discount, double? tax, String? name, String? description}) {
    final item = _items[index];
    final q = quantity ?? item.quantity;
    final p = unitPrice ?? item.unitPrice;
    final d = discount ?? item.discount;
    final t = tax ?? item.tax;
    final amt = q * p;
    final total = amt - d + t;

    setState(() {
      _items[index] = QuotationItem(
        itemId: item.itemId,
        name: name ?? item.name,
        description: description ?? item.description,
        quantity: q,
        unitPrice: p,
        discount: d,
        tax: t,
        amount: amt,
        totalAmount: total,
      );
    });
    _calculateTotals();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. General Information
                        _buildSection(
                          'General Information',
                          [
                            widget.prefilledLead != null
                                ? TextFormField(
                                    initialValue: '${widget.prefilledLead!.name} (${widget.prefilledLead!.phoneNo})',
                                    readOnly: true,
                                    enabled: false,
                                    decoration: InputDecoration(
                                      labelText: 'Linked Lead (Locked)',
                                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      isDense: true,
                                      filled: true,
                                      fillColor: const Color(0xFFF1F3F4),
                                      prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  )
                                : LeadAutocompleteDropdown(
                                    initialLead: widget.quotation?.leadId != null
                                        ? Lead(
                                            id: widget.quotation!.leadId!,
                                            leadId: '',
                                            name: widget.quotation!.clientName,
                                            phoneNo: widget.quotation!.clientPhoneNo,
                                            email: widget.quotation!.clientEmail,
                                            source: '',
                                            status: '',
                                            pipeline: '',
                                            description: '',
                                            createdAt: '',
                                            updatedAt: '',
                                          )
                                        : widget.prefilledItinerary?.leadId != null
                                            ? Lead(
                                                id: widget.prefilledItinerary!.leadId!,
                                                leadId: '',
                                                name: widget.prefilledItinerary!.clientName,
                                                phoneNo: widget.prefilledItinerary!.clientPhoneNo,
                                                email: widget.prefilledItinerary!.clientEmail,
                                                source: '',
                                                status: '',
                                                pipeline: '',
                                                description: '',
                                                createdAt: '',
                                                updatedAt: '',
                                              )
                                            : null,
                                    onLeadSelected: (lead) {
                                      setState(() {
                                        if (lead != null) {
                                          if (_selectedLeadId != lead.id) {
                                            _clearItinerary();
                                          }
                                          _selectedLeadId = lead.id;
                                          _clientNameController.text = lead.name;
                                          _clientPhoneController.text = lead.phoneNo;
                                          _clientEmailController.text = lead.email;
                                          if (lead.company != null && lead.company!.isNotEmpty) {
                                            _clientCompanyController.text = lead.company!;
                                          }
                                          if (lead.address != null) {
                                            _streetController.text = lead.address!.address1;
                                            _cityController.text = lead.address!.city;
                                            _stateController.text = lead.address!.state;
                                            _zipController.text = lead.address!.pinCode;
                                            _countryController.text = lead.address!.country.isNotEmpty
                                                ? lead.address!.country
                                                : 'India';
                                          }
                                        } else {
                                          _selectedLeadId = null;
                                        }
                                      });
                                    },
                                  ),
                            if (_selectedLeadId != null) ...[
                              Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.contact_page_outlined, size: 16, color: Colors.blue),
                                    label: const Text('View Lead Profile Details', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => LeadProfileScreen(leadId: _selectedLeadId!)),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                                _selectedItineraryId == null
                                    ? GestureDetector(
                                        onTap: () async {
                                          final selected = await showDialog<ItineraryV2>(
                                            context: context,
                                            barrierDismissible: true,
                                            builder: (ctx) => ItinerarySelectionDialog(
                                              leadId: _selectedLeadId!,
                                              currentlySelectedItineraryId: _selectedItineraryId,
                                            ),
                                          );
                                          if (selected != null) {
                                            _applyItinerary(selected);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.map_outlined, color: Colors.teal, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Select Itinerary',
                                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Base this quotation on one of the active, unquoted itineraries',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFA5D6A7), width: 1),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Selected Itinerary: ${_selectedItinerarySubject ?? "Yes"}',
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                                  ),
                                                    const SizedBox(height: 1),
                                                    const Text(
                                                      'Quotation values mapped from selected itinerary',
                                                      style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (_itineraryError != null && widget.quotation == null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4, left: 4),
                                          child: Text(
                                            _itineraryError!,
                                            style: const TextStyle(color: Colors.red, fontSize: 12),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                            ],
                            const SizedBox(height: 12),
                            _buildTwoFieldRow(
                              _buildTextField("Quotation Number", _quoNoController, enabled: false),
                              _buildDropdown(
                                "Status",
                                ['DRAFT', 'CREATED', 'SENT', 'ACCEPTED', 'REJECTED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                (val) => setState(() => _status = val as String),
                                _status,
                              ),
                            ),
                            _buildTwoFieldRow(
                              _buildDatePicker("Quotation Date", _dateController, required: true),
                              _buildDatePicker("Valid Until", _validUntilController, required: true),
                            ),
                            _buildTextField("Subject", _subjectController, required: true),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // 2. Client Details
                        _buildSection(
                          'Customer Details',
                          [
                            _buildTextField("Client Name", _clientNameController, required: true),
                            _buildTextField("Email Address", _clientEmailController, keyboardType: TextInputType.emailAddress),
                            _buildTwoFieldRow(
                              _buildTextField("Phone No", _clientPhoneController, keyboardType: TextInputType.phone),
                              _buildTextField("Company", _clientCompanyController),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // 3. Billing Address
                        _buildSection(
                          'Billing Address',
                          [
                            _buildTextField("Street Address", _streetController),
                            _buildTwoFieldRow(
                              _buildTextField("City", _cityController),
                              _buildTextField("State", _stateController),
                            ),
                            _buildTwoFieldRow(
                              _buildTextField("Zip Code", _zipController),
                              _buildTextField("Country", _countryController),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // 4. Quotation Items
                        _buildSection(
                          'Quotation Items',
                          [
                            _buildItemsList(),
                            if (_items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  "At least one item is required",
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Item'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  foregroundColor: Colors.black,
                                  side: const BorderSide(color: Colors.black, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Final Calculations Card
                        _buildCalculationCard(theme),

                        const SizedBox(height: 32),

                        _buildCollapsibleSection(
                          title: 'Terms & Conditions',
                          icon: Icons.gavel_rounded,
                          isExpanded: _termsExpanded,
                          onToggle: () => setState(() => _termsExpanded = !_termsExpanded),
                          child: Column(
                            children: [
                              _buildTextField("Terms & Conditions", _termsController, maxLines: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Footer Actions
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.quotation == null ? 'Create New Quotation' : 'Edit Quotation',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1.1),
        ),
        const SizedBox(height: 16),
        Column(
          children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList(),
        ),
      ],
    );
  }

  Widget _buildTwoFieldRow(Widget first, Widget second) {
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No items added yet',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ...List.generate(_items.length, (index) {
          final item = _items[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildTextField(
                        "Item Name",
                        null,
                        initialValue: item.name,
                        required: true,
                        onChanged: (val) => _updateItem(index, name: val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => setState(() {
                        _items.removeAt(index);
                        _calculateTotals();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  "Description",
                  null,
                  initialValue: item.description,
                  onChanged: (val) => _updateItem(index, description: val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Qty",
                        null,
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _updateItem(index, quantity: double.tryParse(val) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        "Rate (₹)",
                        null,
                        initialValue: item.unitPrice.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _updateItem(index, unitPrice: double.tryParse(val) ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Discount (₹)",
                        null,
                        initialValue: item.discount.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _updateItem(index, discount: double.tryParse(val) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        "Tax (₹)",
                        null,
                        initialValue: item.tax.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _updateItem(index, tax: double.tryParse(val) ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(
                      '₹${NumberFormat('#,##,###.##').format(item.totalAmount)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCalculationCard(ThemeData theme) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            _buildSummaryRow('Sub Total (₹)', _subTotal),
            _buildSummaryRow('Discount (₹)', _discountTotal),
            _buildSummaryRow('Tax (₹)', _taxTotal),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Adjustment (₹)', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _adjustmentController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      onChanged: (val) {
                        _calculateTotals();
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
                      ),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '₹ ${NumberFormat('#,##,###.##').format(_grandTotal)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text('₹ ${NumberFormat('#,##,###.##').format(value)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : (widget.quotation == null && (_selectedItineraryId == null || _selectedItineraryId!.isEmpty) ? null : _submit),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.quotation == null ? 'Create Quotation' : 'Update Quotation', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController? controller, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? initialValue,
    Function(String)? onChanged,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      enabled: enabled,
      style: const TextStyle(fontSize: 14),
      validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller, {bool enabled = true, bool required = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
      validator: validator ?? (required ? (val) => val == null || val.isEmpty ? 'Required' : null : null),
      onTap: !enabled ? null : () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() {
            controller.text = DateTimeUtils.formatDayMonthYear(picked);
          });
        }
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        suffixIcon: const Icon(Icons.calendar_today, size: 16, color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<DropdownMenuItem<dynamic>> items,
    Function(dynamic)? onChanged,
    dynamic value, {
    String? hint,
  }) {
    final List<DropdownMenuItem<dynamic>> safeItems = List.from(items);
    if (value != null && !safeItems.any((item) => item.value == value)) {
      safeItems.add(DropdownMenuItem(
        value: value,
        child: Text(
          value.toString().length > 12 ? 'Selected (${value.toString().substring(0, 8)}...)' : value.toString(),
          style: const TextStyle(fontSize: 14),
        ),
      ));
    }

    return DropdownButtonFormField(
      initialValue: value,
      items: safeItems,
      onChanged: onChanged,
      isExpanded: true,
      hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 14, color: Colors.grey)) : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.quotation == null && (_selectedItineraryId == null || _selectedItineraryId!.isEmpty)) {
      setState(() {
        _itineraryError = 'Itinerary is required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final data = {
      'quotationNumber': _quoNoController.text,
      'quotationDate': DateFormat('yyyy-MM-dd').format(DateTimeUtils.parseSafe(_dateController.text) ?? DateTime.now()),
      'validUntil': DateFormat('yyyy-MM-dd').format(DateTimeUtils.parseSafe(_validUntilController.text) ?? DateTime.now().add(const Duration(days: 14))),
      'subject': _subjectController.text,
      'status': _status,
      'clientName': _clientNameController.text,
      'clientEmail': _clientEmailController.text,
      'clientPhoneNo': _clientPhoneController.text,
      'clientCompany': _clientCompanyController.text,
      'lead': _selectedLeadId != null && _selectedLeadId!.isNotEmpty ? _selectedLeadId : null,
      'itinerary': _selectedItineraryId != null && _selectedItineraryId!.isNotEmpty ? _selectedItineraryId : null,
      'billingAddress': {
        'street': _streetController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'zip': _zipController.text,
        'country': _countryController.text,
      },
      'items': _items.map((i) => i.toJson()).toList(),
      'subTotal': _subTotal,
      'discountTotal': _discountTotal,
      'taxTotal': _taxTotal,
      'adjustment': double.tryParse(_adjustmentController.text) ?? 0,
      'grandTotal': _grandTotal,
      'termsAndConditions': _termsController.text,
    };

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      if (widget.quotation == null) {
        await ref.read(quotationsProvider.notifier).createQuotation(data);
      } else {
        await ref.read(quotationsProvider.notifier).updateQuotation(widget.quotation!.id, data);
      }
      
      // Refresh itinerary list if this quotation was created from an itinerary
      if (_selectedItineraryId != null) {
        ref.read(itineraryV2Provider.notifier).fetchItineraries(refresh: true);
      }
      
      if (mounted) {
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error saving quotation: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
