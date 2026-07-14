import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/voucher_model.dart';
import '../providers/voucher_provider.dart';
import '../../core/services/r2_service.dart';
import '../providers/company_settings_provider.dart';
import 'lead_autocomplete_dropdown.dart';
import '../../data/models/lead_model.dart';
import '../screens/lead_profile_screen.dart';

import '../../core/utils/date_utils.dart';

class GuestControllerGroup {
  final TextEditingController nameController;
  final TextEditingController ageController;
  String gender;
  String type;

  GuestControllerGroup({
    required String name,
    required int age,
    required this.gender,
    required this.type,
  })  : nameController = TextEditingController(text: name),
        ageController = TextEditingController(text: age.toString());

  void dispose() {
    nameController.dispose();
    ageController.dispose();
  }

  Guest toGuest() {
    return Guest(
      name: nameController.text,
      age: int.tryParse(ageController.text) ?? 0,
      gender: gender,
      type: type,
    );
  }
}

String _mapToBackendItemType(String type) {
  final t = type.trim().toUpperCase();
  if (t == 'TRAVEL') {
    return 'TRAVEL';
  }
  return 'ACCOMMODATION';
}

class ItemControllerGroup {
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final TextEditingController discountController;
  final TextEditingController taxController;
  String itemType;

  ItemControllerGroup({
    required String name,
    required String description,
    required double quantity,
    required double price,
    required double discount,
    required double tax,
    required this.itemType,
  })  : nameController = TextEditingController(text: name),
        descController = TextEditingController(text: description),
        qtyController = TextEditingController(text: quantity == 0 ? '' : quantity.toString()),
        priceController = TextEditingController(text: price == 0 ? '' : price.toString()),
        discountController = TextEditingController(text: discount == 0 ? '' : discount.toString()),
        taxController = TextEditingController(text: tax == 0 ? '' : tax.toString());

  void dispose() {
    nameController.dispose();
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
    taxController.dispose();
  }

  double get quantity => double.tryParse(qtyController.text) ?? 0;
  double get price => double.tryParse(priceController.text) ?? 0;
  double get discount => double.tryParse(discountController.text) ?? 0;
  double get tax => double.tryParse(taxController.text) ?? 0;
  double get amount => (quantity * price) - discount + tax;

  VoucherItem toVoucherItem() {
    return VoucherItem(
      itemType: _mapToBackendItemType(itemType),
      name: nameController.text,
      description: descController.text,
      quantity: quantity,
      price: price,
      discount: discount,
      tax: tax,
      amount: amount,
    );
  }
}

class VoucherCreateDialog extends ConsumerStatefulWidget {
  final Voucher? voucher;
  final Lead? prefilledLead;

  const VoucherCreateDialog({super.key, this.voucher, this.prefilledLead});

  @override
  ConsumerState<VoucherCreateDialog> createState() => _VoucherCreateDialogState();
}

class _VoucherCreateDialogState extends ConsumerState<VoucherCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final R2Service _r2Service = R2Service();
  bool _isUploadingImage = false;
  String? _uploadError;

  final ScrollController _mainScrollController = ScrollController();
  
  late TextEditingController _voucherNoController;
  late TextEditingController _voucherDateController;
  late TextEditingController _clientNameController;
  late TextEditingController _clientPhoneController;
  late TextEditingController _clientEmailController;
  late TextEditingController _clientAddressController;

  // Hotel fields
  late TextEditingController _checkInController;
  late TextEditingController _checkOutController;
  late TextEditingController _noOfRoomsController;
  late TextEditingController _hotelNameController;
  late TextEditingController _hotelContactController;
  late TextEditingController _hotelAddressController;
  late TextEditingController _hotelGstController;
  late TextEditingController _hotelImageUrlController;

  // Travel fields
  late TextEditingController _travelStartController;
  late TextEditingController _travelEndController;
  late TextEditingController _travelKmsController;

  late TextEditingController _termsController;
  late TextEditingController _inclusionsController;
  late TextEditingController _advancePaidController;

  String _voucherType = 'HOTEL';
  List<ItemControllerGroup> _itemGroups = [];
  List<GuestControllerGroup> _guestGroups = [];
  bool _isLoading = false;
  bool _isKmsOverridden = false;
  String? _selectedLeadId;

  bool _generalExpanded = true;
  bool _detailsExpanded = true;
  bool _guestsExpanded = true;
  bool _itemsExpanded = true;
  bool _termsExpanded = true;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;
    final pl = widget.prefilledLead;
    
    _selectedLeadId = v?.leadId ?? pl?.id;
    _voucherType = v?.voucherType ?? 'HOTEL';
    _voucherNoController = TextEditingController(
      text: v?.voucherNo ?? 'VR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    _voucherDateController = TextEditingController(text: DateTimeUtils.formatSafe(v?.voucherDate ?? DateTimeUtils.toApiString(DateTime.now()), format: 'dd MMM yyyy'));
    
    String initialAddress = v?.clientAddress ?? '';
    if (v == null && pl?.address != null) {
      initialAddress = '${pl!.address!.address1}, ${pl.address!.city}, ${pl.address!.state} - ${pl.address!.pinCode}';
    }

    _clientNameController = TextEditingController(text: v?.clientName ?? pl?.name ?? '');
    _clientPhoneController = TextEditingController(text: v?.clientPhone ?? pl?.phoneNo ?? '');
    _clientEmailController = TextEditingController(text: v?.clientEmail ?? pl?.email ?? '');
    _clientAddressController = TextEditingController(text: initialAddress);

    _checkInController = TextEditingController(text: DateTimeUtils.formatSafe(v?.checkIn, format: 'dd MMM yyyy'));
    _checkOutController = TextEditingController(text: DateTimeUtils.formatSafe(v?.checkOut, format: 'dd MMM yyyy'));
    _noOfRoomsController = TextEditingController(text: v?.noOfRooms?.toString() ?? '1');
    _hotelNameController = TextEditingController(text: v?.hotelDetails?.name ?? '');
    _hotelContactController = TextEditingController(text: v?.hotelDetails?.contact ?? '');
    _hotelAddressController = TextEditingController(text: v?.hotelDetails?.address ?? '');
    _hotelGstController = TextEditingController(text: v?.hotelDetails?.gstNo ?? '');
    _hotelImageUrlController = TextEditingController(text: v?.hotelDetails?.imageUrl ?? '');

    _travelStartController = TextEditingController(text: DateTimeUtils.formatSafe(v?.travelStartDate, format: 'dd MMM yyyy'));
    _travelEndController = TextEditingController(text: DateTimeUtils.formatSafe(v?.travelEndDate, format: 'dd MMM yyyy'));
    _travelKmsController = TextEditingController(text: v?.travelTotalKms?.toString() ?? '0');
    double initialKms = 0;
    if (v?.items != null) {
      for (var item in v!.items) {
        if (_normalizeItemType(item.itemType) == 'Travel') {
          initialKms += item.quantity;
        }
      }
    }
    if (v?.travelTotalKms != null && v!.travelTotalKms! > 0 && v.travelTotalKms != initialKms) {
      _isKmsOverridden = true;
    } else {
      _isKmsOverridden = false;
    }

    _termsController = TextEditingController(text: v?.termsAndConditions ?? '');
    _inclusionsController = TextEditingController(text: v?.inclusions ?? '');
    _advancePaidController = TextEditingController(text: v?.financials.advancePaid.toString() ?? '0');

    if (v?.items != null) {
      _itemGroups = v!.items.map((item) => ItemControllerGroup(
        name: item.name,
        description: item.description,
        quantity: item.quantity,
        price: item.price,
        discount: item.discount,
        tax: item.tax,
        itemType: _normalizeItemType(item.itemType),
      )).toList();
    } else {
      _itemGroups = [];
    }

    if (v?.guestList != null) {
      _guestGroups = v!.guestList.map((g) => GuestControllerGroup(
        name: g.name,
        age: g.age,
        gender: g.gender,
        type: g.type,
      )).toList();
    } else {
      _guestGroups = [];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialSettings();
    });
  }

  String _normalizeItemType(String type) {
    final t = type.trim().toUpperCase();
    if (['TRANSPORT', 'FLIGHT', 'TRAIN', 'BUS', 'TRAVEL'].contains(t)) {
      return 'Travel';
    }
    return 'Accommodation';
  }

  Future<void> _loadInitialSettings() async {
    if (widget.voucher != null) return; // Don't prefill when editing

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

    if (mounted) {
      setState(() {
        if (_termsController.text.isEmpty) {
          _termsController.text = 'All booking must be made in advance.\nBooking made with vouchers is not refundable in cash.';
        }
        if (_inclusionsController.text.isEmpty) {
          _inclusionsController.text = 'WiFi, Breakfast, Housekeeping, Pool access, Air conditioning';
        }
      });
    }
  }

  @override
  void dispose() {
    _voucherNoController.dispose();
    _voucherDateController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    _clientAddressController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _noOfRoomsController.dispose();
    _hotelNameController.dispose();
    _hotelContactController.dispose();
    _hotelAddressController.dispose();
    _hotelGstController.dispose();
    _hotelImageUrlController.dispose();
    _travelStartController.dispose();
    _travelEndController.dispose();
    _travelKmsController.dispose();
    _termsController.dispose();
    _inclusionsController.dispose();
    _advancePaidController.dispose();
    _mainScrollController.dispose();
    for (var group in _itemGroups) {
      group.dispose();
    }
    for (var group in _guestGroups) {
      group.dispose();
    }
    super.dispose();
  }

  VoucherFinancials get _calculatedFinancials {
    double subTotal = 0;
    double discountTotal = 0;
    double taxTotal = 0;
    
    for (var group in _itemGroups) {
      subTotal += group.price * group.quantity;
      discountTotal += group.discount;
      taxTotal += group.tax;
    }

    double totalAmount = subTotal - discountTotal + taxTotal;
    double advancePaid = double.tryParse(_advancePaidController.text) ?? 0;
    double balanceAmount = totalAmount - advancePaid;

    return VoucherFinancials(
      subTotal: subTotal,
      discountTotal: discountTotal,
      taxTotal: taxTotal,
      totalAmount: totalAmount,
      advancePaid: advancePaid,
      balanceAmount: balanceAmount,
    );
  }

  void _updateTotals() {
    setState(() {
      if (!_isKmsOverridden) {
        double kms = 0;
        for (var group in _itemGroups) {
          if (group.itemType == 'Travel') {
            kms += group.quantity;
          }
        }
        _travelKmsController.text = kms.toStringAsFixed(0);
      }
    });
  }

  void _addItem() {
    setState(() {
      _itemGroups.add(ItemControllerGroup(
        name: '',
        description: '',
        quantity: 1,
        price: 0,
        discount: 0,
        tax: 0,
        itemType: _voucherType == 'HOTEL' ? 'Accommodation' : 'Travel',
      ));
      _itemsExpanded = true;
    });
    _updateTotals();
    _scrollToBottom();
  }

  void _addGuest() {
    setState(() {
      _guestGroups.add(GuestControllerGroup(
        name: '',
        age: 25,
        gender: 'Male',
        type: 'Adult',
      ));
      _guestsExpanded = true;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_mainScrollController.hasClients) {
        _mainScrollController.animateTo(
          _mainScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_itemGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one item is required'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final financials = _calculatedFinancials;
    final data = {
      'lead': _selectedLeadId != null && _selectedLeadId!.isNotEmpty ? _selectedLeadId : null,
      'voucherType': _voucherType,
      'voucherNo': _voucherNoController.text,
      'voucherDate': DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_voucherDateController.text)),
      'clientName': _clientNameController.text,
      'clientPhone': _clientPhoneController.text,
      'clientEmail': _clientEmailController.text,
      'clientAddress': _clientAddressController.text,
      if (_voucherType == 'HOTEL') ...{
        'checkIn': DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_checkInController.text)),
        'checkOut': DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_checkOutController.text)),
        'noOfRooms': int.tryParse(_noOfRoomsController.text) ?? 1,
        'hotelDetails': {
          'name': _hotelNameController.text,
          'contact': _hotelContactController.text,
          'address': _hotelAddressController.text,
          'gstNo': _hotelGstController.text,
          'imageUrl': _hotelImageUrlController.text,
        },
      },
      if (_voucherType == 'TRAVEL' || _voucherType == 'FLIGHT' || _voucherType == 'TRANSPORT') ...{
        'travelStartDate': DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_travelStartController.text)),
        'travelEndDate': DateTimeUtils.toApiString(DateTimeUtils.parseSafe(_travelEndController.text)),
        'travelTotalKms': double.tryParse(_travelKmsController.text) ?? 0,
      },
      'items': _itemGroups.map((e) => e.toVoucherItem().toJson()).toList(),
      'guestList': _voucherType == 'HOTEL' ? _guestGroups.map((e) => e.toGuest().toJson()).toList() : [],
      'financials': financials.toJson(),
      'termsAndConditions': _voucherType == 'HOTEL' ? _termsController.text : '',
      'inclusions': _voucherType == 'HOTEL' ? _inclusionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [],
    };

    try {
      if (widget.voucher == null) {
        await ref.read(vouchersProvider.notifier).createVoucher(data);
      } else {
        await ref.read(vouchersProvider.notifier).updateVoucher(widget.voucher!.id, data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 800),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: SingleChildScrollView(
                    controller: _mainScrollController,
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           _buildCollapsibleSection(
                            title: 'General Information',
                            icon: Icons.info_outline_rounded,
                            isExpanded: _generalExpanded,
                            onToggle: () => setState(() => _generalExpanded = !_generalExpanded),
                            child: Column(
                              children: [
                                widget.prefilledLead != null
                                    ? Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: TextFormField(
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
                                        ),
                                      )
                                    : LeadAutocompleteDropdown(
                                        initialLead: widget.voucher?.leadId != null
                                            ? Lead(
                                                id: widget.voucher!.leadId!,
                                                leadId: '',
                                                name: widget.voucher!.clientName,
                                                phoneNo: widget.voucher!.clientPhone,
                                                email: widget.voucher!.clientEmail,
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
                                              if (lead.address != null) {
                                                _clientAddressController.text = '${lead.address!.address1}, ${lead.address!.city}, ${lead.address!.state} - ${lead.address!.pinCode}';
                                              }
                                            } else {
                                              _selectedLeadId = null;
                                            }
                                          });
                                        },
                                      ),
                                if (_selectedLeadId != null) ...[
                                  const SizedBox(height: 8),
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
                                ],
                                const SizedBox(height: 12),
                                 _buildDropdown(
                                   "Voucher Type",
                                   ['HOTEL', 'TRAVEL'].map((s) {
                                     String label = s;
                                     if (s == 'HOTEL') label = 'Hotel Voucher';
                                     if (s == 'TRAVEL') label = 'Travel Voucher';
                                     return DropdownMenuItem(value: s, child: Text(label));
                                   }).toList(),
                                  (val) {
                                    setState(() {
                                      _voucherType = val as String;
                                      for (var group in _itemGroups) {
                                        if (_voucherType == 'HOTEL') {
                                          group.itemType = 'Accommodation';
                                        } else {
                                          group.itemType = 'Travel';
                                        }
                                      }
                                    });
                                    _updateTotals();
                                  },
                                  _voucherType,
                                ),
                                const SizedBox(height: 12),
                                _buildTwoFieldRow(
                                  _buildTextField(
                                    "Voucher Number", 
                                    _voucherNoController,
                                    validator: (val) => val == null || val.isEmpty ? 'Voucher Number is required' : null,
                                  ),
                                  _buildDatePicker("Voucher Date", _voucherDateController),
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  "Client Name", 
                                  _clientNameController,
                                  validator: (val) => val == null || val.isEmpty ? 'Client Name is required' : null,
                                ),
                                const SizedBox(height: 12),
                                _buildTwoFieldRow(
                                  _buildTextField(
                                    "Client Phone", 
                                    _clientPhoneController,
                                    keyboardType: TextInputType.phone,
                                    validator: _validatePhone,
                                  ),
                                  _buildTextField(
                                    "Client Email", 
                                    _clientEmailController,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (val) => val != null && val.isNotEmpty && !val.contains('@') ? 'Invalid email format' : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildTextField("Client Address", _clientAddressController, maxLines: 2),
                              ],
                            ),
                          ),

                          _buildCollapsibleSection(
                            title: _voucherType == 'HOTEL' ? 'Hotel Details' : 'Travel Details',
                            icon: _voucherType == 'HOTEL' ? Icons.hotel_outlined : Icons.map_outlined,
                            isExpanded: _detailsExpanded,
                            onToggle: () => setState(() => _detailsExpanded = !_detailsExpanded),
                            child: _voucherType == 'HOTEL' 
                                ? Column(
                                    children: [
                                      _buildTwoFieldRow(
                                        _buildDatePicker("Check In", _checkInController, validator: _validateCheckIn),
                                        _buildDatePicker("Check Out", _checkOutController, validator: _validateCheckOut),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField(
                                        "Number of Rooms", 
                                        _noOfRoomsController, 
                                        keyboardType: TextInputType.number,
                                        validator: (val) => int.tryParse(val ?? '') == null || int.parse(val!) <= 0 ? 'Enter valid room count' : null,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField("Hotel Name", _hotelNameController),
                                      const SizedBox(height: 12),
                                      _buildTwoFieldRow(
                                        _buildTextField("Hotel Contact", _hotelContactController, keyboardType: TextInputType.phone),
                                        _buildTextField("Hotel GST", _hotelGstController),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField("Hotel Address", _hotelAddressController, maxLines: 2),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildTwoFieldRow(
                                        _buildDatePicker("Travel Start Date", _travelStartController, validator: _validateTravelStart),
                                        _buildDatePicker("Travel End Date", _travelEndController, validator: _validateTravelEnd),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _travelKmsController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (val) => _isKmsOverridden = true,
                                        style: const TextStyle(fontSize: 14),
                                        decoration: InputDecoration(
                                          labelText: "Total Travel (KMs)",
                                          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                                          helperText: _isKmsOverridden ? "Manual Override Enabled" : "Auto-calculated from items",
                                          helperStyle: TextStyle(color: _isKmsOverridden ? Colors.orange[700] : Colors.green[700], fontSize: 11, fontWeight: FontWeight.bold),
                                          filled: true,
                                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                                          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),

                          if (_voucherType == 'HOTEL')
                            _buildCollapsibleSection(
                              title: 'Guest List (${_guestGroups.length})',
                              icon: Icons.people_outline_rounded,
                              isExpanded: _guestsExpanded,
                              onToggle: () => setState(() => _guestsExpanded = !_guestsExpanded),
                              trailingHeader: _buildAddButton('Add Guest', _addGuest),
                              child: _buildGuestList(),
                            ),
                          _buildCollapsibleSection(
                            title: 'Voucher Items (${_itemGroups.length})',
                            icon: Icons.list_alt_rounded,
                            isExpanded: _itemsExpanded,
                            onToggle: () => setState(() => _itemsExpanded = !_itemsExpanded),
                            trailingHeader: _buildAddButton('Add Item', _addItem),
                            child: _buildItemsList(),
                          ),
                          const SizedBox(height: 16),
                          _buildCalculationCard(theme),
                          if (_voucherType == 'HOTEL')
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _buildCollapsibleSection(
                                title: 'Terms & Inclusions',
                                icon: Icons.gavel_rounded,
                                isExpanded: _termsExpanded,
                                onToggle: () => setState(() => _termsExpanded = !_termsExpanded),
                                child: Column(
                                  children: [
                                    _buildTextField("Terms & Conditions", _termsController, maxLines: 4),
                                    const SizedBox(height: 12),
                                    _buildTextField("Inclusions (comma separated)", _inclusionsController, maxLines: 3),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.voucher == null ? 'Create Voucher' : 'Edit Voucher',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
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

  Widget _buildTwoFieldRow(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 450) {
          return Column(
            children: [
              first,
              const SizedBox(height: 12),
              second,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: Colors.blue),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          if (_guestGroups.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
              ),
              child: const Center(
                child: Text(
                  'No guests added. Click "Add Guest" to start.',
                  style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            );
          }

          return Column(
            children: List.generate(_guestGroups.length, (index) {
              final group = _guestGroups[index];
              return Container(
                key: ValueKey(group),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Guest Details',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() {
                              _guestGroups.removeAt(index);
                            });
                            group.dispose();
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: group.nameController,
                      style: const TextStyle(fontSize: 13),
                      validator: (val) => val == null || val.isEmpty ? 'Guest Name is required' : null,
                      decoration: InputDecoration(
                        labelText: "Guest Name",
                        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.white,
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.2), borderRadius: BorderRadius.circular(4)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: group.ageController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13),
                            validator: (val) => val == null || val.isEmpty ? 'Age' : null,
                            decoration: InputDecoration(
                              labelText: "Age",
                              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.white,
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.2), borderRadius: BorderRadius.circular(4)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: _buildCompactDropdown(
                            ['Male', 'Female', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            (val) => setState(() => group.gender = val as String),
                            group.gender,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: _buildCompactDropdown(
                            ['Adult', 'Child'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            (val) => setState(() => group.type = val as String),
                            group.type,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          );
        }

        // Desktop / Tablet layout (headers always visible)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header (Always Visible on Desktop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    flex: 5,
                    child: Text(
                      'Guest Name',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 55,
                    child: Text(
                      'Age',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 95,
                    child: Text(
                      'Gender',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 95,
                    child: Text(
                      'Type',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 32), // Spacer for delete button
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 8),
            
            if (_guestGroups.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                ),
                child: const Center(
                  child: Text(
                    'No guests added. Click "Add Guest" to start.',
                    style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ...List.generate(_guestGroups.length, (index) {
                final group = _guestGroups[index];
                return Padding(
                  key: ValueKey(group),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: group.nameController,
                          style: const TextStyle(fontSize: 13),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          decoration: InputDecoration(
                            hintText: "Guest Name",
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.2), borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 55,
                        child: TextFormField(
                          controller: group.ageController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          validator: (val) => val == null || val.isEmpty ? 'Age' : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.2), borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 95,
                        child: _buildCompactDropdown(
                          ['Male', 'Female', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          (val) => setState(() => group.gender = val as String),
                          group.gender,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 95,
                        child: _buildCompactDropdown(
                          ['Adult', 'Child'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          (val) => setState(() => group.type = val as String),
                          group.type,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () {
                          setState(() {
                            _guestGroups.removeAt(index);
                          });
                          group.dispose();
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildItemsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_itemGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.list_alt_outlined, size: 36, color: Colors.grey[400]),
              const SizedBox(height: 8),
              const Text('No items added yet', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: List.generate(_itemGroups.length, (index) {
        final group = _itemGroups[index];
        return Container(
          key: ValueKey(group),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ITEM #${index + 1}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                  ),
                  Row(
                    children: [
                      Text(
                        'Total: ₹${NumberFormat('#,##,###.##').format(group.amount)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        onPressed: () {
                          setState(() {
                            _itemGroups.removeAt(index);
                          });
                          group.dispose();
                          _updateTotals();
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              (() {
                List<String> itemTypes = ['Accommodation', 'Travel'];
                if (_voucherType == 'HOTEL') {
                  itemTypes = ['Accommodation'];
                } else if (_voucherType == 'TRAVEL') {
                  itemTypes = ['Travel'];
                }
                return _buildDropdown(
                  "Type",
                  itemTypes
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  (val) {
                    setState(() => group.itemType = val as String);
                    _updateTotals();
                  },
                  group.itemType,
                );
              })(),
              const SizedBox(height: 8),
              TextFormField(
                controller: group.descController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Description",
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.white,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = (constraints.maxWidth - 24) / 4;
                  return Row(
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: group.qtyController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateTotals(),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "Qty",
                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                            filled: true,
                            fillColor: isDark ? Colors.black26 : Colors.white,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: group.priceController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateTotals(),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "Price",
                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                            filled: true,
                            fillColor: isDark ? Colors.black26 : Colors.white,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: group.discountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateTotals(),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "Disc",
                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                            filled: true,
                            fillColor: isDark ? Colors.black26 : Colors.white,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: group.taxController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateTotals(),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "Tax",
                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                            filled: true,
                            fillColor: isDark ? Colors.black26 : Colors.white,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCalculationCard(ThemeData theme) {
    final financials = _calculatedFinancials;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161924) : Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "FINANCIAL SUMMARY",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          _buildCalcRow("Sub Total", financials.subTotal, isDark: isDark),
          _buildCalcRow("Discount Total", financials.discountTotal, isDark: isDark, isNegative: true),
          _buildCalcRow("Tax Total", financials.taxTotal, isDark: isDark),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: isDark ? Colors.white10 : Colors.grey[300], height: 1),
          ),
          _buildCalcRow("Total Amount", financials.totalAmount, isDark: isDark, isBold: true, fontSize: 15),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: const Text("Advance Paid", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: TextFormField(
                  controller: _advancePaidController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setState(() {}),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.white,
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCalcRow(
            "Balance Amount", 
            financials.balanceAmount, 
            isDark: isDark, 
            isBold: true, 
            fontSize: 16, 
            color: financials.balanceAmount > 0 ? Colors.orange[700] : Colors.green[700],
          ),
        ],
      ),
    );
  }

  Widget _buildCalcRow(String label, double value, {required bool isDark, bool isBold = false, double fontSize = 13, Color? color, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontSize: fontSize)),
          Text(
            '${isNegative ? "- " : ""}₹${NumberFormat('#,##,###.##').format(value)}',
            style: TextStyle(
              color: color ?? (isDark ? Colors.white : Colors.black),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label, 
    TextEditingController? controller, {
    int maxLines = 1, 
    TextInputType? keyboardType, 
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator ?? (val) => (val == null || val.isEmpty) && label.contains('*') ? 'Required' : null,
    );
  }

  Widget _buildDropdown(String label, List<DropdownMenuItem<dynamic>> items, Function(dynamic)? onChanged, dynamic value, {String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 13, color: Colors.grey)) : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
    );
  }

  Widget _buildCompactDropdown(List<DropdownMenuItem<dynamic>> items, Function(dynamic)? onChanged, dynamic value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.2), borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller, {String? Function(String?)? validator}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTimeUtils.parseSafe(controller.text) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          controller.text = DateTimeUtils.formatDayMonthYear(date);
          _updateTotals();
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            suffixIcon: const Icon(Icons.calendar_today, size: 16),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Cancel', style: TextStyle(color: Colors.black, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              elevation: 0,
            ),
            child: _isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.voucher == null ? 'Create Voucher' : 'Update Voucher', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }



  void showImageSourceDialog() {
    final urlController = TextEditingController(text: _hotelImageUrlController.text);
    _uploadError = null;
    _isUploadingImage = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              title: const Text('Set Hotel Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upload via Cloudflare R2:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isUploadingImage
                            ? null
                            : () async {
                                try {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.image,
                                  );

                                  if (result != null) {
                                    dialogSetState(() {
                                      _isUploadingImage = true;
                                      _uploadError = null;
                                    });

                                    final pickedFile = result.files.single;
                                    Uint8List? bytes = pickedFile.bytes;
                                    if (bytes == null && pickedFile.path != null) {
                                      final file = File(pickedFile.path!);
                                      bytes = await file.readAsBytes();
                                    }

                                    if (bytes == null) throw 'Could not read file bytes';

                                    final uniqueFileName = 'hotelImages/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
                                    final r2Key = await _r2Service.uploadFile(
                                      bytes,
                                      uniqueFileName,
                                      pickedFile.extension ?? 'image/jpeg',
                                    );

                                    if (r2Key != null) {
                                      final publicUrl = '${R2Service.publicBaseUrl}/$r2Key';
                                      urlController.text = publicUrl;
                                      dialogSetState(() {});
                                    } else {
                                      throw 'Cloudflare R2 Upload failed';
                                    }
                                  }
                                } catch (e) {
                                  dialogSetState(() {
                                    _uploadError = e.toString();
                                  });
                                } finally {
                                  dialogSetState(() {
                                    _isUploadingImage = false;
                                  });
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isUploadingImage) ...[
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                ),
                                const SizedBox(width: 8),
                                const Text('Uploading to R2...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ] else ...[
                                const Icon(Icons.cloud_upload_outlined, color: Colors.black54, size: 18),
                                const SizedBox(width: 6),
                                const Text('Choose File & Upload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                              ]
                            ],
                          ),
                        ),
                      ),
                      if (_uploadError != null) ...[
                        const SizedBox(height: 6),
                        Text(_uploadError!, style: const TextStyle(color: Colors.red, fontSize: 10)),
                      ],
                      const SizedBox(height: 16),
                      const Text('Or Enter Custom Image URL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: urlController,
                        onChanged: (v) => dialogSetState(() {}),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'https://images.unsplash.com/...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Or Pick a Premium Preset:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.5,
                        children: [
                          _buildPresetCard(
                            'Luxury Resort',
                            'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&auto=format&fit=crop',
                            urlController,
                            dialogSetState,
                          ),
                          _buildPresetCard(
                            'Boutique Hotel',
                            'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=600&auto=format&fit=crop',
                            urlController,
                            dialogSetState,
                          ),
                          _buildPresetCard(
                            'Beachside Villa',
                            'https://images.unsplash.com/photo-1540541338287-41700207dee6?w=600&auto=format&fit=crop',
                            urlController,
                            dialogSetState,
                          ),
                          _buildPresetCard(
                            'Mountain Lodge',
                            'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=600&auto=format&fit=crop',
                            urlController,
                            dialogSetState,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.black, fontSize: 13)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hotelImageUrlController.text = urlController.text;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 13)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetCard(String name, String url, TextEditingController controller, StateSetter dialogSetState) {
    return InkWell(
      onTap: () {
        dialogSetState(() {
          controller.text = url;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(url, fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.3)),
            Center(
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePhone(String? val) {
    if (val == null || val.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(val.replaceAll(' ', '').replaceAll('-', ''))) {
      return 'Invalid phone number format';
    }
    return null;
  }



  String? _validateCheckIn(String? val) {
    if (val == null || val.isEmpty) return 'Check-in date is required';
    return null;
  }

  String? _validateCheckOut(String? val) {
    if (val == null || val.isEmpty) return 'Check-out date is required';
    final start = DateTimeUtils.parseSafe(_checkInController.text);
    final end = DateTimeUtils.parseSafe(val);
    if (start != null && end != null && end.isBefore(start)) {
      return 'Check-out must be after check-in';
    }
    return null;
  }

  String? _validateTravelStart(String? val) {
    if (val == null || val.isEmpty) return 'Start date is required';
    return null;
  }

  String? _validateTravelEnd(String? val) {
    if (val == null || val.isEmpty) return 'End date is required';
    final start = DateTimeUtils.parseSafe(_travelStartController.text);
    final end = DateTimeUtils.parseSafe(val);
    if (start != null && end != null && end.isBefore(start)) {
      return 'End date must be after start date';
    }
    return null;
  }
}
