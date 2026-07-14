import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';
import '../providers/company_settings_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../data/models/company_settings_model.dart';
import '../../core/constants/permission_constants.dart';
import 'lead_autocomplete_dropdown.dart';
import '../screens/lead_profile_screen.dart';
import '../../data/models/lead_model.dart';

import '../../core/utils/date_utils.dart';

class InvoiceCreateDialog extends ConsumerStatefulWidget {
  final Invoice? invoice;
  final Lead? prefilledLead;

  const InvoiceCreateDialog({super.key, this.invoice, this.prefilledLead});

  @override
  ConsumerState<InvoiceCreateDialog> createState() => _InvoiceCreateDialogState();
}

class _InvoiceCreateDialogState extends ConsumerState<InvoiceCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _invoiceNumberController;
  late TextEditingController _subjectController;
  late TextEditingController _invoiceDateController;
  late TextEditingController _dueDateController;
  late TextEditingController _dealDateController;
  
  late TextEditingController _clientNameController;
  late TextEditingController _clientCompanyController;
  late TextEditingController _clientPhoneController;
  late TextEditingController _clientEmailController;
  
  late TextEditingController _billStreetController;
  late TextEditingController _billCityController;
  late TextEditingController _billStateController;
  late TextEditingController _billZipController;
  late TextEditingController _billCountryController;

  late TextEditingController _shipStreetController;
  late TextEditingController _shipCityController;
  late TextEditingController _shipStateController;
  late TextEditingController _shipZipController;
  late TextEditingController _shipCountryController;

  late TextEditingController _accOwnerController;
  late TextEditingController _bankNameController;
  late TextEditingController _accNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _upiController;

  late TextEditingController _termsController;
  late TextEditingController _descriptionController;
  late TextEditingController _adjustmentController;
  final ScrollController _itemsScrollController = ScrollController();
  final Map<int, FocusNode> _itemFocusNodes = {};
  final Map<int, TextEditingController> itemNameControllers = {};

  String _status = 'CREATED';
  List<InvoiceItem> _items = [];
  String? _selectedLeadId;

  bool _isLoading = false;
  String _selectedItemType = 'PRODUCT';
  BankAccount? _selectedPresetBank;

  bool _isObjectId(String? val) {
    if (val == null) return false;
    return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(val);
  }

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    
    _invoiceNumberController = TextEditingController(text: inv?.invoiceNumber ?? '');
    _subjectController = TextEditingController(text: inv?.subject ?? '');
    _invoiceDateController = TextEditingController(text: DateTimeUtils.formatSafe(inv?.invoiceDate ?? DateTimeUtils.toApiString(DateTime.now()), format: 'dd MMM yyyy'));
    _dueDateController = TextEditingController(text: DateTimeUtils.formatSafe(inv?.dueDate ?? DateTimeUtils.toApiString(DateTime.now().add(const Duration(days: 7))), format: 'dd MMM yyyy'));
    _dealDateController = TextEditingController(text: DateTimeUtils.formatSafe(inv?.dealDate));

    _clientNameController = TextEditingController(text: inv?.clientName ?? '');
    final initialCompany = inv?.clientCompany ?? '';
    _clientCompanyController = TextEditingController(text: _isObjectId(initialCompany) ? '' : initialCompany);
    _clientPhoneController = TextEditingController(text: inv?.clientPhoneNo ?? '');
    _clientEmailController = TextEditingController(text: inv?.clientEmail ?? '');

    _billStreetController = TextEditingController(text: inv?.billingAddress.street ?? '');
    _billCityController = TextEditingController(text: inv?.billingAddress.city ?? '');
    _billStateController = TextEditingController(text: inv?.billingAddress.state ?? '');
    _billZipController = TextEditingController(text: inv?.billingAddress.zip ?? '');
    _billCountryController = TextEditingController(text: inv?.billingAddress.country ?? 'India');

    _shipStreetController = TextEditingController(text: inv?.shippingAddress.street ?? '');
    _shipCityController = TextEditingController(text: inv?.shippingAddress.city ?? '');
    _shipStateController = TextEditingController(text: inv?.shippingAddress.state ?? '');
    _shipZipController = TextEditingController(text: inv?.shippingAddress.zip ?? '');
    _shipCountryController = TextEditingController(text: inv?.shippingAddress.country ?? 'India');

    _accOwnerController = TextEditingController(text: inv?.account.accountOwner ?? '');
    _bankNameController = TextEditingController(text: inv?.account.bankName ?? '');
    _accNumberController = TextEditingController(text: inv?.account.accountNumber ?? '');
    _ifscController = TextEditingController(text: inv?.account.bankIfsc ?? '');
    _upiController = TextEditingController(text: inv?.account.upiId ?? '');

    _termsController = TextEditingController(text: inv?.termsAndConditions ?? '');
    _descriptionController = TextEditingController(text: inv?.description ?? '');
    _adjustmentController = TextEditingController(text: inv?.adjustment.toString() ?? '0');

    _status = inv?.status ?? 'CREATED';
    _items = inv?.items != null ? List.from(inv!.items) : [];
    _selectedLeadId = inv?.leadId;

    if (widget.prefilledLead != null) {
      final lead = widget.prefilledLead!;
      _selectedLeadId = lead.id;
      _clientNameController.text = lead.name;
      _clientPhoneController.text = lead.phoneNo;
      _clientEmailController.text = lead.email;
      if (lead.company != null && lead.company!.isNotEmpty) {
        _clientCompanyController.text = _isObjectId(lead.company) ? '' : lead.company!;
      }
      if (lead.address != null) {
        _billStreetController.text = lead.address!.address1;
        _billCityController.text = lead.address!.city;
        _billStateController.text = lead.address!.state;
        _billZipController.text = lead.address!.pinCode;
        _billCountryController.text = lead.address!.country.isNotEmpty
            ? lead.address!.country
            : 'India';
        
        _shipStreetController.text = lead.address!.address1;
        _shipCityController.text = lead.address!.city;
        _shipStateController.text = lead.address!.state;
        _shipZipController.text = lead.address!.pinCode;
        _shipCountryController.text = lead.address!.country.isNotEmpty
            ? lead.address!.country
            : 'India';
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(companySettingsProvider);
      _loadInitialSettings();
    });
  }

  Future<void> _loadInitialSettings() async {
    try {
      final settings = await ref.read(companySettingsProvider.future);
      if (settings != null && mounted) {
        setState(() {
          if (_termsController.text.isEmpty) {
            _termsController.text = settings.invoiceDefaultTerms;
          }
          if (settings.bankAccounts.isNotEmpty && 
              _bankNameController.text.isEmpty && 
              _accNumberController.text.isEmpty) {
            final bank = settings.bankAccounts.firstWhere(
              (b) => b.isDefault,
              orElse: () => settings.bankAccounts.first,
            );
            _accOwnerController.text = bank.accountOwner;
            _bankNameController.text = bank.bankName;
            _accNumberController.text = bank.accountNumber;
            _ifscController.text = bank.bankIfsc;
            _upiController.text = bank.upiId;
            _selectedPresetBank = bank;
          }
        });
      }
    } catch (e) {
      debugPrint('Error prefilling settings: $e');
    }
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _subjectController.dispose();
    _invoiceDateController.dispose();
    _dueDateController.dispose();
    _dealDateController.dispose();
    _clientNameController.dispose();
    _clientCompanyController.dispose();
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    _billStreetController.dispose();
    _billCityController.dispose();
    _billStateController.dispose();
    _billZipController.dispose();
    _billCountryController.dispose();
    _shipStreetController.dispose();
    _shipCityController.dispose();
    _shipStateController.dispose();
    _shipZipController.dispose();
    _shipCountryController.dispose();
    _accOwnerController.dispose();
    _bankNameController.dispose();
    _accNumberController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    _termsController.dispose();
    _descriptionController.dispose();
    _adjustmentController.dispose();
    for (final node in _itemFocusNodes.values) {
      node.dispose();
    }
    _itemsScrollController.dispose();
    super.dispose();
  }

  double get _subTotal => _items.fold(0, (sum, item) => sum + item.amount);
  double get _taxTotal => _items.fold(0, (sum, item) => sum + item.tax);
  double get _discountTotal => _items.fold(0, (sum, item) => sum + item.discount);
  double get _grandTotal {
    final adj = double.tryParse(_adjustmentController.text) ?? 0;
    return _subTotal + _taxTotal - _discountTotal + adj;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
       showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text('Validation Error'),
           content: const Text('Add at least one item'),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(ctx),
               child: const Text('OK'),
             ),
           ],
         ),
       );
       return;
    }

    setState(() => _isLoading = true);

    try {
      final invoiceData = {
        "subject": _subjectController.text.trim(),
        "invoiceDate": DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_invoiceDateController.text)),
        "dueDate": DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_dueDateController.text)),
        if (_dealDateController.text.isNotEmpty) "dealDate": DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_dealDateController.text)),
        "status": _status,
        "clientCompany": _clientCompanyController.text.trim(),
        "clientName": _clientNameController.text.trim(),
        "clientPhoneNo": _clientPhoneController.text.trim(),
        "clientEmail": _clientEmailController.text.trim(),
        "lead": _selectedLeadId != null && _selectedLeadId!.isNotEmpty ? _selectedLeadId : null,
        "leadId": _selectedLeadId != null && _selectedLeadId!.isNotEmpty ? _selectedLeadId : null,
        "adjustment": double.tryParse(_adjustmentController.text.trim()) ?? 0,
        "items": _items.map((e) => e.toJson()).toList(),
        "billingAddress": {
          "street": _billStreetController.text.trim(),
          "city": _billCityController.text.trim(),
          "state": _billStateController.text.trim(),
          "zip": _billZipController.text.trim(),
          "country": _billCountryController.text.trim(),
        },
        "shippingAddress": {
          "street": _shipStreetController.text.trim(),
          "city": _shipCityController.text.trim(),
          "state": _shipStateController.text.trim(),
          "zip": _shipZipController.text.trim(),
          "country": _shipCountryController.text.trim(),
        },
        "account": {
          "accountOwner": _accOwnerController.text.trim(),
          "bankName": _bankNameController.text.trim(),
          "bankIfsc": _ifscController.text.trim(),
          "accountNumber": _accNumberController.text.trim(),
          "upiId": _upiController.text.trim(),
        },
        "termsAndConditions": _termsController.text.trim(),
        "description": _descriptionController.text.trim(),
      };

      if (widget.invoice != null) {
        await ref.read(invoicesProvider.notifier).updateInvoice(widget.invoice!.id, invoiceData);
      } else {
        await ref.read(invoicesProvider.notifier).createInvoice(invoiceData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isReadOnlyState {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    
    // 1. CANCELLED invoices are always read-only
    if (widget.invoice?.status == 'CANCELLED') return true;

    // 2. Check modular access
    if (!permissions.hasModule(PermissionModules.INVOICE)) return true;

    // 3. Check specific permission
    final requiredPermission = widget.invoice == null 
        ? PermissionModules.INVOICE_CREATE 
        : PermissionModules.INVOICE_UPDATE;
        
    return !permissions.hasPermission(requiredPermission, userRole: userRole);
  }

  bool hasPermission(String permission) {
    final permissions = ref.read(permissionsProvider);
    return permissions.hasPermission(permission, userRole: ref.read(loginProvider).user?.systemRole);
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = _isReadOnlyState;
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(companySettingsProvider);

    // Auto-fill terms from company settings when data arrives/reactively
    ref.listen(companySettingsProvider, (_, next) {
      if (!mounted) return;
      next.whenData((settings) {
        if (settings == null) return;
        if (_termsController.text.isEmpty && settings.invoiceDefaultTerms.isNotEmpty) {
          _termsController.text = settings.invoiceDefaultTerms;
        }
        if (settings.bankAccounts.isNotEmpty && 
            _bankNameController.text.isEmpty && 
            _accNumberController.text.isEmpty) {
          final bank = settings.bankAccounts.firstWhere(
            (b) => b.isDefault,
            orElse: () => settings.bankAccounts.first,
          );
          _accOwnerController.text = bank.accountOwner;
          _bankNameController.text = bank.bankName;
          _accNumberController.text = bank.accountNumber;
          _ifscController.text = bank.bankIfsc;
          _upiController.text = bank.upiId;
          _selectedPresetBank = bank;
        }
      });
    });

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
                                    ),
                                  )
                                : LeadAutocompleteDropdown(
                                    initialLead: widget.invoice?.leadId != null
                                        ? Lead(
                                            id: widget.invoice!.leadId!,
                                            leadId: widget.invoice!.leadReference ?? '',
                                            name: widget.invoice!.clientName,
                                            phoneNo: widget.invoice!.clientPhoneNo,
                                            email: widget.invoice!.clientEmail,
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
                                          _selectedLeadId = lead.id;
                                          _clientNameController.text = lead.name;
                                          _clientPhoneController.text = lead.phoneNo;
                                          _clientEmailController.text = lead.email;
                                          if (lead.company != null && lead.company!.isNotEmpty) {
                                            _clientCompanyController.text = _isObjectId(lead.company) ? '' : lead.company!;
                                          }
                                          if (lead.address != null) {
                                            _billStreetController.text = lead.address!.address1;
                                            _billCityController.text = lead.address!.city;
                                            _billStateController.text = lead.address!.state;
                                            _billZipController.text = lead.address!.pinCode;
                                            _billCountryController.text = lead.address!.country.isNotEmpty
                                                ? lead.address!.country
                                                : 'India';
                                            
                                            _shipStreetController.text = lead.address!.address1;
                                            _shipCityController.text = lead.address!.city;
                                            _shipStateController.text = lead.address!.state;
                                            _shipZipController.text = lead.address!.pinCode;
                                            _shipCountryController.text = lead.address!.country.isNotEmpty
                                                ? lead.address!.country
                                                : 'India';
                                          }
                                        } else {
                                          _selectedLeadId = null;
                                        }
                                      });
                                    },
                                  ),
                            if (_selectedLeadId != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
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
                              ),
                            _buildTextField("Invoice Subject", _subjectController, required: true, enabled: !isReadOnly),
                            _buildDatePicker("Invoice Date", _invoiceDateController, enabled: !isReadOnly),
                            _buildDatePicker("Due Date", _dueDateController, enabled: !isReadOnly),
                            _buildDatePicker("Deal Date", _dealDateController, enabled: !isReadOnly),
                            _buildDropdown(
                              "Status",
                              ['DRAFT', 'CREATED', 'SENT', 'PAID', 'CANCELLED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              isReadOnly ? null : (val) => setState(() => _status = val as String),
                              _status,
                            ),
                            _buildTextField("Client Company", _clientCompanyController, enabled: !isReadOnly),
                            _buildTextField("Client Name", _clientNameController, required: true, enabled: !isReadOnly),
                            _buildTextField("Client Phone", _clientPhoneController, keyboardType: TextInputType.phone, enabled: !isReadOnly),
                            _buildTextField("Client Email", _clientEmailController, keyboardType: TextInputType.emailAddress, enabled: !isReadOnly),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // 2. Addresses (Vertical layout to avoid overflow and for better readability)
                        _buildSection(
                          'Billing Address',
                          [
                            _buildAddressFields(
                              _billStreetController,
                              _billCityController,
                              _billStateController,
                              _billZipController,
                              _billCountryController,
                              enabled: !isReadOnly,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),

                        _buildSection(
                          'Shipping Address',
                          [
                            _buildAddressFields(
                              _shipStreetController,
                              _shipCityController,
                              _shipStateController,
                              _shipZipController,
                              _shipCountryController,
                              enabled: !isReadOnly,
                            ),
                          ],
                          trailing: !isReadOnly ? TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _shipStreetController.text = _billStreetController.text;
                                _shipCityController.text = _billCityController.text;
                                _shipStateController.text = _billStateController.text;
                                _shipZipController.text = _billZipController.text;
                                _shipCountryController.text = _billCountryController.text;
                              });
                            },
                            icon: const Icon(Icons.copy, size: 12, color: Colors.blue),
                            label: const Text(
                              'Same as Billing', 
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: Colors.blue.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ) : null,
                        ),

                        const SizedBox(height: 24),

                        // 3. Items
                        _buildSection(
                          'Items',
                          [
                            _buildItemsList(),
                            const SizedBox(height: 16),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: isReadOnly ? null : _addItem,
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

                        const SizedBox(height: 24),

                        // 4. Pricing Summary
                        _buildCalculationCard(theme),

                        const SizedBox(height: 24),

                        // 5. Bank Details
                      _buildSection(
                        'Bank Details',
                        [
                          settingsAsync.when(
                            data: (settings) {
                              final bankAccounts = settings?.bankAccounts ?? [];
                              if (bankAccounts.isEmpty) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "No preset bank accounts found",
                                            style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return InkWell(
                                onTap: isReadOnly ? null : () => _showPresetBankSelectorBottomSheet(context, bankAccounts),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Select Preset Bank Account",
                                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedPresetBank != null
                                                  ? '${_selectedPresetBank!.bankName} - ${_selectedPresetBank!.accountNumber}'
                                                  : (_bankNameController.text.isNotEmpty && _accNumberController.text.isNotEmpty)
                                                      ? '${_bankNameController.text} - ${_accNumberController.text}'
                                                      : 'Choose from your saved accounts',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Colors.black87),
                                    ],
                                  ),
                                ),
                              );
                            },
                            loading: () => Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                                  ),
                                  const SizedBox(width: 12),
                                  Text("Loading preset bank accounts...", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                            ),
                            error: (err, stack) => Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                              ),
                              child: Text('Error loading presets: $err', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTwoFieldRow(
                            _buildTextField("Account Owner", _accOwnerController, enabled: !isReadOnly),
                            _buildTextField("Bank Name", _bankNameController, enabled: !isReadOnly),
                          ),
                          _buildTwoFieldRow(
                            _buildTextField("Account Number", _accNumberController, enabled: !isReadOnly),
                            _buildTextField("IFSC Code", _ifscController, enabled: !isReadOnly),
                          ),
                          _buildTextField("UPI ID (Optional)", _upiController, enabled: !isReadOnly),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 6. Invoice Details
                      _buildSection(
                        'Invoice Details',
                        [
                          _buildTextField("Terms & Conditions", _termsController, maxLines: 3, enabled: !isReadOnly),
                          const SizedBox(height: 16),
                          _buildTextField("Description", _descriptionController, maxLines: 3, enabled: !isReadOnly),
                        ],
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.invoice == null ? 'Create Invoice' : 'Edit Invoice',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 20, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1.1)),
            if (trailing != null) trailing,
          ],
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

  Widget _buildAddressFields(TextEditingController street, TextEditingController city, TextEditingController state, TextEditingController zip, TextEditingController country, {bool enabled = true}) {
    return Column(
      children: [
        _buildTextField("Street", street, enabled: enabled),
        const SizedBox(height: 16),
        _buildTextField("City", city, enabled: enabled),
        const SizedBox(height: 16),
        _buildTextField("State", state, enabled: enabled),
        const SizedBox(height: 16),
        _buildTextField("Zip", zip, enabled: enabled),
        const SizedBox(height: 16),
        _buildTextField("Country", country, enabled: enabled),
      ],
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
            children: [
              _buildItemTypeButton('PRODUCT', 'Product', enabled: !_isReadOnlyState),
              const SizedBox(width: 8),
              _buildItemTypeButton('SERVICE', 'Service', enabled: !_isReadOnlyState),
            ],
          ),
        const SizedBox(height: 16),
        if (!_isReadOnlyState)
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Custom Item', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        const SizedBox(height: 16),
        // Table Header
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No items added yet', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
          ),
        ...List.generate(_items.length, (index) {
          final item = _items[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
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
                        enabled: !_isReadOnlyState,
                        onChanged: (val) => _updateItem(index, name: val),
                        focusNode: _itemFocusNodes[index],
                      ),
                    ),
                    if (!_isReadOnlyState) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => setState(() => _items.removeAt(index)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  "Description",
                  null,
                  initialValue: item.description,
                  enabled: !_isReadOnlyState,
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
                        enabled: !_isReadOnlyState,
                        onChanged: (val) => _updateItem(index, quantity: double.tryParse(val) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        "Rate",
                        null,
                        initialValue: item.unitPrice.toString(),
                        keyboardType: TextInputType.number,
                        enabled: !_isReadOnlyState,
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
                        "Disc",
                        null,
                        initialValue: item.discount.toString(),
                        keyboardType: TextInputType.number,
                        enabled: !_isReadOnlyState,
                        onChanged: (val) => _updateItem(index, discount: double.tryParse(val) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        "Tax",
                        null,
                        initialValue: item.tax.toString(),
                        keyboardType: TextInputType.number,
                        enabled: !_isReadOnlyState,
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
                      '₹${NumberFormat('#,##,###.##').format(item.total)}',
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

  Widget _buildItemTypeButton(String value, String label, {bool enabled = true}) {
    bool isSelected = _selectedItemType == value;
    return InkWell(
      onTap: !enabled ? null : () => setState(() => _selectedItemType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(color: isSelected ? Colors.black : Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _addItem() {
    final newIndex = _items.length;
    final focusNode = FocusNode();
    setState(() {
      _itemFocusNodes[newIndex] = focusNode;
      _items.add(InvoiceItem(
        itemType: _selectedItemType,
        name: '',
        description: '',
        quantity: 1,
        unitPrice: 0,
        amount: 0,
        total: 0,
        tax: 0,
        discount: 0,
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _itemsScrollController.animateTo(
        _itemsScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      focusNode.requestFocus();
    });
  }

  void _updateItem(int index, {double? quantity, double? unitPrice, double? tax, double? discount, String? name, String? description}) {
    final item = _items[index];
    final q = quantity ?? item.quantity;
    final p = unitPrice ?? item.unitPrice;
    final t = tax ?? item.tax;
    final d = discount ?? item.discount;
    
    final amount = q * p;
    final total = amount + t - d;

    setState(() {
      _items[index] = InvoiceItem(
        itemType: item.itemType,
        name: name ?? item.name,
        description: description ?? item.description,
        quantity: q,
        unitPrice: p,
        tax: t,
        discount: d,
        amount: amount,
        total: total,
      );
    });
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
                      enabled: !_isReadOnlyState,
                      onChanged: (val) => setState(() {}),
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
              onPressed: (_isReadOnlyState || _isLoading) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.invoice == null ? 'Create Invoice' : 'Update Invoice', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController? controller, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? initialValue,
    Function(String)? onChanged,
    bool enabled = true,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      focusNode: focusNode,
      controller: controller,
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      enabled: enabled,
      style: const TextStyle(fontSize: 14),
      validator: validator ?? (required ? (val) => val == null || val.isEmpty ? 'Required' : null : null),
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

  Widget _buildDatePicker(String label, TextEditingController controller, {bool enabled = true}) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
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

  Widget _buildDropdown(String label, List<DropdownMenuItem<dynamic>> items, Function(dynamic)? onChanged, dynamic value, {String? hint}) {
    return DropdownButtonFormField(
      initialValue: value,
      items: items,
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

  void _showPresetBankSelectorBottomSheet(BuildContext context, List<BankAccount> bankAccounts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setPickerState) {
                // Determine if we should support searching
          bankAccounts.length > 5;
                
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1D2A) : const Color(0xFFF8F9FA),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Preset Bank Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: bankAccounts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final bank = bankAccounts[index];
                            final isSelected = _selectedPresetBank?.id == bank.id || (_selectedPresetBank?.accountNumber == bank.accountNumber && _selectedPresetBank?.bankName == bank.bankName);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedPresetBank = bank;
                                  _accOwnerController.text = bank.accountOwner;
                                  _bankNameController.text = bank.bankName;
                                  _accNumberController.text = bank.accountNumber;
                                  _ifscController.text = bank.bankIfsc;
                                  _upiController.text = bank.upiId;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF222533) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? Colors.blue : Colors.black)
                                        : Colors.grey.withValues(alpha: 0.2),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.blue : Colors.black).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.account_balance,
                                        color: isDark ? Colors.blue.shade300 : Colors.black87,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bank.bankName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Owner: ${bank.accountOwner} | A/C: ${bank.accountNumber}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle, color: isDark ? Colors.blue : Colors.black),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

}
