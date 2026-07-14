import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../providers/property_provider.dart';
import '../../core/services/r2_service.dart';
import 'location_picker_dialog.dart';
import '../../data/models/property_model.dart';
import 'amenities_tag_input.dart';
import 'city_search_field.dart';
import '../screens/assets/assets_library_screen.dart';

class PropertyCreateDialog extends ConsumerStatefulWidget {
  final String projectId;
  final Property? property;
  const PropertyCreateDialog({super.key, required this.projectId, this.property});

  @override
  ConsumerState<PropertyCreateDialog> createState() => _PropertyCreateDialogState();
}

class _PropertyCreateDialogState extends ConsumerState<PropertyCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic Info
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _internalNotesController = TextEditingController();
  
  // Pricing & Rent-specific
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _securityDepositController = TextEditingController();
  final TextEditingController _maintenanceChargesValueController = TextEditingController();
  final TextEditingController _lockInPeriodMonthsController = TextEditingController();
  final TextEditingController _noticePeriodMonthsController = TextEditingController();
  final TextEditingController _availabilityDateController = TextEditingController();
  final TextEditingController _policiesController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _basicController = TextEditingController();
  final TextEditingController _inventoryDateController = TextEditingController();
  
  // Dimensions
  final TextEditingController _areaValueController = TextEditingController();
  final TextEditingController _lengthValueController = TextEditingController();
  final TextEditingController _breadthValueController = TextEditingController();
  
  // Location
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  
  // New Fields
  final _r2Service = R2Service();
  final TextEditingController _brochureUrlController = TextEditingController();
  final TextEditingController _amenitiesController = TextEditingController();
  final TextEditingController _amenityInputController = TextEditingController(); // for tag input
  List<String> _amenities = []; // actual amenities list shown as chips
  String _selectedCity = ''; // selected city (from chip or custom)
  final TextEditingController _paymentPlanController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  
  // Owner & Unit Details
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerNumberController = TextEditingController();
  final TextEditingController _facingController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();

  // Site Facing — only structural/orientation facing types (NOT compass directions)
  static const List<String> _facingOptions = [
    'Park Facing',
    'Kothi Facing',
    'DDA Flat Facing',
    'Road Facing',
  ];

  // Direction — compass directions (separate field from facing)
  static const List<String> _directionOptions = [
    'North',
    'South',
    'East',
    'West',
    'North East',
    'North West',
    'South East',
    'South West',
  ];

  // Dropdowns
  String _selectedPropertyType = 'plot';
  String _selectedCategory = 'Residential';
  String _selectedStatus = 'available';
  String _selectedAreaUnit = 'sqft';
  String _selectedLengthUnit = 'feet';
  String _selectedBreadthUnit = 'feet';
  String? _selectedDirection; // compass: North / South / East etc.
  
  // Rent / Sell & Standalone configurations
  String _selectedListingType = 'Sell';
  String _selectedBillingCycle = 'included';
  String _selectedAllowedTenants = 'Any';
  String? _selectedPreferredGender;
  String _selectedFurnishingStatus = 'Unfurnished';
  bool _builtUp = false;
  String _selectedProjectId = '';
  
  bool _isLoading = false;
  List<String> _images = [];
  List<String> _videos = [];
  final bool _isUploadingBrochure = false;
  bool _isUploadingImages = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    if (widget.property != null) {
      final p = widget.property!;
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _internalNotesController.text = p.internalNotes ?? '';
      _priceController.text = p.price.toString();
      _tokenController.text = p.token.toString();
      
      _selectedListingType = p.listingType.toLowerCase() == 'rent' ? 'Rent' : 'Sell';
      _securityDepositController.text = p.securityDeposit.toString();
      if (p.maintenanceCharges != null) {
        _maintenanceChargesValueController.text = p.maintenanceCharges!.value.toString();
        final bc = p.maintenanceCharges!.billingCycle.toLowerCase();
        _selectedBillingCycle = ['included', 'monthly', 'quarterly', 'yearly'].contains(bc) ? bc : 'included';
      }
      _selectedAllowedTenants = ['Any', 'Family', 'Bachelors', 'Company Lease'].contains(p.allowedTenants) ? p.allowedTenants! : 'Any';
      _selectedPreferredGender = ['male', 'female', 'other', 'any'].contains(p.preferredGender) ? p.preferredGender : null;
      _lockInPeriodMonthsController.text = p.lockInPeriodMonths.toString();
      _noticePeriodMonthsController.text = p.noticePeriodMonths.toString();
      _policiesController.text = p.policies.join(', ');
      _availabilityDateController.text = _formatDate(p.availabilityDate ?? '');
      const furnishingMap = {
        'unfurnished': 'Unfurnished',
        'semi_furnished': 'Semi-Furnished',
        'fully_furnished': 'Fully Furnished',
      };
      _selectedFurnishingStatus = furnishingMap[p.furnishingStatus.toLowerCase()] ?? 'Unfurnished';
      _bathroomsController.text = p.bathrooms?.toString() ?? '';
      _builtUp = p.builtUp;
      _basicController.text = p.basic ?? '';
      _inventoryDateController.text = _formatDate(p.inventoryDate ?? '');
      _selectedProjectId = p.projectId;

      if (p.area != null) {
        _areaValueController.text = p.area!.value.toString();
        final u = _reverseMapUnit(p.area!.unit);
        _selectedAreaUnit = ['gaj', 'sqft', 'sqyd', 'acre'].contains(u) ? u : 'sqft';
      }
      if (p.length != null) {
        _lengthValueController.text = p.length!.value.toString();
        final u = _reverseMapUnit(p.length!.unit);
        _selectedLengthUnit = ['feet', 'yards', 'meters'].contains(u) ? u : 'feet';
      }
      if (p.breadth != null) {
        _breadthValueController.text = p.breadth!.value.toString();
        final u = _reverseMapUnit(p.breadth!.unit);
        _selectedBreadthUnit = ['feet', 'yards', 'meters'].contains(u) ? u : 'feet';
      }

      if (p.location != null) {
        _address1Controller.text = p.location!.address1;
        _address2Controller.text = p.location!.address2;
        _selectedCity = p.location!.city;
        _pincodeController.text = p.location!.pincode ?? '';
        _stateController.text = p.location!.state;
        _countryController.text = p.location!.country;
        if (p.location!.lat != null) _latController.text = p.location!.lat.toString();
        if (p.location!.lng != null) _lngController.text = p.location!.lng.toString();
      }

      // --- Property Type (snake_case from model -> dropdown value) ---
      final rawType = p.propertyType.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
      const validTypes = [
        'plot', 'flat', 'floor', 'room', 'farm_house', 'villa', 'duplex',
        'shop', 'house', 'green_land', 'office', 'warehouse',
        'coworking_space', 'studio_apartment', 'penthouse'
      ];
      _selectedPropertyType = validTypes.contains(rawType) ? rawType : 'plot';

      // --- Category (model is snake_case, dropdown uses Title case) ---
      final catLower = p.category.trim().toLowerCase().replaceAll('_', ' ');
      const catMap = {
        'residential': 'Residential', 'commercial': 'Commercial',
        'industrial': 'Industrial', 'land': 'Land',
      };
      _selectedCategory = catMap[catLower] ?? 'Residential';

      // --- Status (snake_case from model) ---
      final rawStat = p.status.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
      const validStatuses = [
        'available', 'on_hold', 'token_received', 'booked', 'sold', 'blocked',
        'ready_to_move', 'rented', 'notice_period'
      ];
      _selectedStatus = validStatuses.contains(rawStat) ? rawStat : 'available';

      // --- New fields ---
      _brochureUrlController.text = p.brochureUrl ?? '';
      debugPrint('===== DEBUG: p.amenities = ${p.amenities} (type: ${p.amenities.runtimeType}) =====');
      debugPrint('===== DEBUG: p.amenities.join = "${p.amenities.join(', ')}" =====');
      _amenities = List<String>.from(p.amenities.where((e) => e.isNotEmpty));
      debugPrint('===== DEBUG: _amenities = $_amenities =====');
      _images = p.images.where((e) => e.isNotEmpty).toList();
      _videos = p.videos.where((e) => e.isNotEmpty).toList();
      _ownerNameController.text = p.ownerName ?? '';
      _ownerNumberController.text = p.ownerNumber ?? '';

      // --- Site Facing (Park Facing / Kothi Facing / DDA Flat Facing / Road Facing) ---
      // Model stores as snake_case e.g. 'park_facing' -> display 'Park Facing'
      const facingSnakeToDisplay = {
        'park_facing': 'Park Facing',
        'kothi_facing': 'Kothi Facing',
        'dda_flat_facing': 'DDA Flat Facing',
        'road_facing': 'Road Facing',
      };
      if (p.facing != null && p.facing!.isNotEmpty) {
        final snake = Property.toSnakeCase(p.facing!);
        _facingController.text = facingSnakeToDisplay[snake] ?? '';
      } else {
        _facingController.text = '';
      }

      // --- Direction (North / South / East / West / diagonals) ---
      // Model stores as snake_case e.g. 'north_east' -> display 'North East'
      const dirSnakeToDisplay = {
        'north': 'North', 'south': 'South', 'east': 'East', 'west': 'West',
        'north_east': 'North East', 'north_west': 'North West',
        'south_east': 'South East', 'south_west': 'South West',
      };
      if (p.direction != null && p.direction!.isNotEmpty) {
        final snake = Property.toSnakeCase(p.direction!);
        _selectedDirection = dirSnakeToDisplay[snake];
      }

      // --- Bedrooms ---
      final beds = p.bedrooms;
      _bedroomsController.text = (beds != null && beds >= 1 && beds <= 6) ? beds.toString() : '';
    } else {
      _selectedProjectId = widget.projectId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _internalNotesController.dispose();
    _priceController.dispose();
    _tokenController.dispose();
    _securityDepositController.dispose();
    _maintenanceChargesValueController.dispose();
    _lockInPeriodMonthsController.dispose();
    _noticePeriodMonthsController.dispose();
    _availabilityDateController.dispose();
    _policiesController.dispose();
    _bathroomsController.dispose();
    _basicController.dispose();
    _inventoryDateController.dispose();
    _areaValueController.dispose();
    _lengthValueController.dispose();
    _breadthValueController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _brochureUrlController.dispose();
    _amenitiesController.dispose();
    _amenityInputController.dispose();
    _paymentPlanController.dispose();
    _videoUrlController.dispose();
    _ownerNameController.dispose();
    _ownerNumberController.dispose();
    _facingController.dispose();
    _bedroomsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Build payload — omit optional fields when empty to avoid backend null crash
      final payload = <String, dynamic>{
        "name": _nameController.text.trim(),
        "propertyType": _selectedPropertyType,
        "category": _selectedCategory,
        "status": _selectedStatus,
        "listingType": _selectedListingType,
        "price": double.tryParse(_priceController.text) ?? 0,
        "furnishingStatus": _selectedFurnishingStatus,
        "builtUp": _builtUp,
        if (_bathroomsController.text.isNotEmpty) "bathrooms": int.tryParse(_bathroomsController.text),
        if (_basicController.text.isNotEmpty) "basic": _basicController.text.trim(),
        if (_inventoryDateController.text.isNotEmpty) "inventoryDate": _inventoryDateController.text.trim(),
        "amenities": _amenities,
        "images": _images,
        "videos": _videos,
        "location": {
          "address1": _address1Controller.text.trim().isNotEmpty ? _address1Controller.text.trim() : null,
          "address2": _address2Controller.text.trim().isNotEmpty ? _address2Controller.text.trim() : null,
          "pincode": _pincodeController.text.trim().isNotEmpty ? _pincodeController.text.trim() : null,
          "city": _selectedCity.isNotEmpty ? _selectedCity : null,
          "state": _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : null,
          "country": _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : null,
          if (_latController.text.isNotEmpty && _lngController.text.isNotEmpty)
            "coordinates": {
              "lat": double.tryParse(_latController.text) ?? 0,
              "lng": double.tryParse(_lngController.text) ?? 0,
            },
        },
      };

      // projectId: set to null or omit to create a Standalone Property
      payload["projectId"] = _selectedProjectId.isNotEmpty ? _selectedProjectId : null;

      if (_selectedListingType == 'Sell') {
        payload["token"] = double.tryParse(_tokenController.text) ?? 0;
      } else {
        payload["token"] = 0;
        payload["securityDeposit"] = double.tryParse(_securityDepositController.text) ?? 0;
        payload["maintenanceCharges"] = {
          "value": double.tryParse(_maintenanceChargesValueController.text) ?? 0,
          "billingCycle": _selectedBillingCycle,
        };
        payload["allowedTenants"] = _selectedAllowedTenants;
        if (_selectedPreferredGender != null) payload["preferredGender"] = _selectedPreferredGender;
        payload["lockInPeriodMonths"] = int.tryParse(_lockInPeriodMonthsController.text) ?? 0;
        payload["noticePeriodMonths"] = int.tryParse(_noticePeriodMonthsController.text) ?? 1;
        if (_policiesController.text.trim().isNotEmpty) {
          payload["policies"] = _policiesController.text.trim().split(RegExp(r',\s*|\n')).where((e) => e.isNotEmpty).toList();
        } else {
          payload["policies"] = [];
        }
        if (_availabilityDateController.text.isNotEmpty) {
          payload["availabilityDate"] = _availabilityDateController.text.trim();
        }
      }

      // Optional fields — only include when they have values
      if (_descriptionController.text.trim().isNotEmpty) payload["description"] = _descriptionController.text.trim();
      if (_internalNotesController.text.trim().isNotEmpty) payload["internalNotes"] = _internalNotesController.text.trim();
      if (_brochureUrlController.text.trim().isNotEmpty) payload["brochureUrl"] = _brochureUrlController.text.trim();
      if (_paymentPlanController.text.trim().isNotEmpty) payload["paymentPlan"] = _paymentPlanController.text.trim();
      if (_ownerNameController.text.trim().isNotEmpty) payload["ownerName"] = _ownerNameController.text.trim();
      if (_ownerNumberController.text.trim().isNotEmpty) payload["ownerNumber"] = _ownerNumberController.text.trim();
      // Site Facing (Park Facing / Kothi Facing / DDA Flat Facing / Road Facing)
      if (_facingController.text.trim().isNotEmpty) payload["facing"] = _facingController.text.trim();
      // Direction (North / South / East / West / diagonals)
      if (_selectedDirection != null && _selectedDirection!.isNotEmpty) payload["direction"] = _selectedDirection;
      if (_bedroomsController.text.isNotEmpty) {
        final beds = int.tryParse(_bedroomsController.text);
        if (beds != null) payload["bedrooms"] = beds;
      }
      if (_areaValueController.text.isNotEmpty) {
        payload["area"] = {"value": double.tryParse(_areaValueController.text) ?? 0, "unit": _selectedAreaUnit};
      }
      if (_lengthValueController.text.isNotEmpty) {
        payload["length"] = {"value": double.tryParse(_lengthValueController.text) ?? 0, "unit": _selectedLengthUnit};
      }
      if (_breadthValueController.text.isNotEmpty) {
        payload["breadth"] = {"value": double.tryParse(_breadthValueController.text) ?? 0, "unit": _selectedBreadthUnit};
      }

      final String submitProjectId = widget.projectId.isNotEmpty ? widget.projectId : _selectedProjectId;
      if (widget.property == null) {
        await ref.read(projectPropertiesProvider(submitProjectId).notifier).createProperty(payload);
      } else {
        await ref.read(projectPropertiesProvider(submitProjectId).notifier).updateProperty(widget.property!.id, payload);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.property == null ? 'Property created successfully' : 'Property updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final citiesAsync = ref.watch(citiesProvider);
    
    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
       backgroundColor: Theme.of(context).cardColor,
       insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 500),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             // Fixed Header
             Padding(
               padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(widget.property == null ? "Create Property" : "Edit Property", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                   IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.05)),
                   )
                 ],
               ),
             ),
             const Divider(height: 32),
             
             // Scrollable Content
             Expanded(
               child: SingleChildScrollView(
                 padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
                 child: Form(
                   key: _formKey,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Listing Type at the very top
                       DropdownButtonFormField<String>(
                         initialValue: _selectedListingType,
                         decoration: _inputDecoration("Listing Type", isDark),
                         items: const [
                           DropdownMenuItem(value: 'Sell', child: Text('Sell', style: TextStyle(fontSize: 13))),
                           DropdownMenuItem(value: 'Rent', child: Text('Rent', style: TextStyle(fontSize: 13))),
                         ],
                         onChanged: (val) => setState(() => _selectedListingType = val!),
                       ),
                       const SizedBox(height: 16),

                       if (widget.projectId.isEmpty) ...[
                         DropdownButtonFormField<String>(
                           initialValue: _selectedProjectId.isNotEmpty ? _selectedProjectId : '',
                           decoration: _inputDecoration("Associated Project", isDark),
                           items: [
                             const DropdownMenuItem<String>(value: '', child: Text('None (Standalone Property)', style: TextStyle(fontSize: 13, color: Colors.grey))),
                             ...ref.watch(propertyProvider).projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: TextStyle(fontSize: 13)))),
                           ],
                           onChanged: (val) => setState(() => _selectedProjectId = val ?? ''),
                         ),
                         const SizedBox(height: 16),
                       ],
                       _buildTextField("Property Name", _nameController, isDark, required: true),
                       const SizedBox(height: 16),
                       
                       Row(
                         children: [
                           Expanded(
                             child: DropdownButtonFormField<String>(
                               initialValue: _selectedPropertyType,
                               decoration: _inputDecoration("Property Type", isDark),
                               items: [
                                 'Plot', 'Flat', 'Floor', 'Room', 'Farm House', 'Villa', 'Duplex',
                                 'Shop', 'House', 'Green Land', 'Office', 'Warehouse',
                                 'Coworking Space', 'Studio Apartment', 'Penthouse'
                               ].map((s) => DropdownMenuItem(value: s.toLowerCase().replaceAll(' ', '_'), child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                               onChanged: (val) => setState(() => _selectedPropertyType = val!),
                             ),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: DropdownButtonFormField<String>(
                               initialValue: _selectedCategory,
                               decoration: _inputDecoration("Category", isDark),
                               items: ['Residential', 'Commercial', 'Industrial', 'Land'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                               onChanged: (val) => setState(() => _selectedCategory = val!),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       
                       DropdownButtonFormField<String>(
                         initialValue: _selectedStatus,
                         decoration: _inputDecoration("Status", isDark),
                         items: [
                           'Available', 'On Hold', 'Token Received', 'Booked', 'Sold', 'Blocked',
                           'Ready to Move', 'Rented', 'Notice Period'
                         ].map((s) => DropdownMenuItem(value: s.toLowerCase().replaceAll(' ', '_'), child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                         onChanged: (val) => setState(() => _selectedStatus = val!),
                       ),
                       const SizedBox(height: 16),
                       _buildTextField("Description", _descriptionController, isDark, maxLines: 2),
                       const SizedBox(height: 16),

                        if (!_builtUp) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _bedroomsController.text.isNotEmpty ? _bedroomsController.text : null,
                            decoration: _inputDecoration("Number of Bedrooms", isDark),
                            items: ['1', '2', '3', '4', '5', '6']
                                .map((b) => DropdownMenuItem(value: b, child: Text('$b BHK', style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (val) => setState(() => _bedroomsController.text = val!),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Row(
                          children: [
                            Checkbox(
                              value: _builtUp,
                              onChanged: (val) {
                                setState(() {
                                  _builtUp = val ?? false;
                                  if (_builtUp) {
                                    _bedroomsController.clear();
                                  }
                                });
                              },
                            ),
                            const Text("Built Up Unit", style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Site Facing + Direction side by side
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _facingController.text.isNotEmpty ? _facingController.text : null,
                                decoration: _inputDecoration("Site Facing", isDark),
                                items: [
                                  const DropdownMenuItem<String>(value: '', child: Text('None', style: TextStyle(fontSize: 13, color: Colors.grey))),
                                  ..._facingOptions.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))),
                                ],
                                onChanged: (val) => setState(() => _facingController.text = val ?? ''),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedDirection,
                                decoration: _inputDecoration("Direction", isDark),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(fontSize: 13, color: Colors.grey))),
                                  ..._directionOptions.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))),
                                ],
                                onChanged: (val) => setState(() => _selectedDirection = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text("Layout & Details", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedFurnishingStatus,
                                decoration: _inputDecoration("Furnishing Status", isDark),
                                items: const [
                                  DropdownMenuItem(value: 'Unfurnished', child: Text('Unfurnished', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'Semi-Furnished', child: Text('Semi-Furnished', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'Fully Furnished', child: Text('Fully Furnished', style: TextStyle(fontSize: 13))),
                                ],
                                onChanged: (val) => setState(() => _selectedFurnishingStatus = val!),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField("Number of Bathrooms", _bathroomsController, isDark, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        InkWell(
                          onTap: () async {
                            final initialDate = _inventoryDateController.text.isNotEmpty
                                ? _parseDate(_inventoryDateController.text.trim())
                                : DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                _inventoryDateController.text = DateFormat('dd MMM yyyy').format(picked);
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: _buildTextField("Inventory Date", _inventoryDateController, isDark),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text("Transaction & Pricing", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),

                        if (_selectedListingType == 'Sell') ...[
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Price", _priceController, isDark, keyboardType: TextInputType.number)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField("Basic", _basicController, isDark)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField("Token Amount", _tokenController, isDark, keyboardType: TextInputType.number),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Rent amount per month", _priceController, isDark, keyboardType: TextInputType.number)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField("Basic", _basicController, isDark)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Security Deposit", _securityDepositController, isDark, keyboardType: TextInputType.number)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField("Maintenance Charges", _maintenanceChargesValueController, isDark, keyboardType: TextInputType.number)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedBillingCycle,
                                  decoration: _inputDecoration("Billing Cycle", isDark),
                                  items: const [
                                    DropdownMenuItem(value: 'included', child: Text('Included', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'monthly', child: Text('Monthly', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'quarterly', child: Text('Quarterly', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'yearly', child: Text('Yearly', style: TextStyle(fontSize: 13))),
                                  ],
                                  onChanged: (val) => setState(() => _selectedBillingCycle = val!),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedAllowedTenants,
                                  decoration: _inputDecoration("Allowed Tenants", isDark),
                                  items: const [
                                    DropdownMenuItem(value: 'Any', child: Text('Any', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'Family', child: Text('Family', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'Bachelors', child: Text('Bachelors', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'Company Lease', child: Text('Company Lease', style: TextStyle(fontSize: 13))),
                                  ],
                                  onChanged: (val) => setState(() => _selectedAllowedTenants = val!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedPreferredGender,
                                  decoration: _inputDecoration("Preferred Gender", isDark),
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('Any', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'male', child: Text('Male', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'female', child: Text('Female', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'other', child: Text('Other', style: TextStyle(fontSize: 13))),
                                  ],
                                  onChanged: (val) => setState(() => _selectedPreferredGender = val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Lock-in Period (Months)", _lockInPeriodMonthsController, isDark, keyboardType: TextInputType.number)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField("Notice Period (Months)", _noticePeriodMonthsController, isDark, keyboardType: TextInputType.number)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final initialDate = _availabilityDateController.text.isNotEmpty
                                  ? _parseDate(_availabilityDateController.text.trim())
                                  : DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _availabilityDateController.text = DateFormat('dd MMM yyyy').format(picked);
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: _buildTextField("Availability Date", _availabilityDateController, isDark),
                            ),
                          ),
                        ],
                       const SizedBox(height: 16),
                       
                       const Text("Dimensions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                       const SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(flex: 2, child: _buildTextField("Area", _areaValueController, isDark, keyboardType: TextInputType.number)),
                           const SizedBox(width: 12),
                           Expanded(
                             flex: 1,
                             child: DropdownButtonFormField<String>(
                               initialValue: _selectedAreaUnit,
                               decoration: _inputDecoration("Unit", isDark),
                               items: const [
                                 DropdownMenuItem(value: 'gaj', child: Text('Gaj', style: TextStyle(fontSize: 11))),
                                 DropdownMenuItem(value: 'sqft', child: Text('Sq Ft', style: TextStyle(fontSize: 11))),
                                 DropdownMenuItem(value: 'sqyd', child: Text('Sq Yd', style: TextStyle(fontSize: 11))),
                                 DropdownMenuItem(value: 'acre', child: Text('Acre', style: TextStyle(fontSize: 11))),
                               ],
                               onChanged: (val) => setState(() => _selectedAreaUnit = val!),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 12),
                       Row(
                         children: [
                           Expanded(flex: 2, child: _buildTextField("Length", _lengthValueController, isDark, keyboardType: TextInputType.number)),
                           const SizedBox(width: 12),
                           Expanded(
                             flex: 1,
                             child: DropdownButtonFormField<String>(
                               initialValue: _selectedLengthUnit,
                               decoration: _inputDecoration("Unit", isDark),
                               items: const [
                                 DropdownMenuItem(value: 'feet', child: Text('Feet', style: TextStyle(fontSize: 11))),
                                 DropdownMenuItem(value: 'yards', child: Text('Yards', style: TextStyle(fontSize: 11))),
                                 DropdownMenuItem(value: 'meters', child: Text('Meters', style: TextStyle(fontSize: 11))),
                               ],
                               onChanged: (val) => setState(() => _selectedLengthUnit = val!),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 12),
                       Row(
                         children: [
                           Expanded(flex: 2, child: _buildTextField("Breadth", _breadthValueController, isDark, keyboardType: TextInputType.number)),
                           const SizedBox(width: 12),
                           Expanded(
                             flex: 1,
                             child: DropdownButtonFormField<String>(
                               initialValue: _selectedBreadthUnit,
                               decoration: _inputDecoration("Unit", isDark),
                               items: const [
                                 DropdownMenuItem(value: 'feet', child: Text('Feet', style: TextStyle(fontSize: 11))),
                                 DropdownMenuItem(value: 'yards', child: Text('Yards', style: TextStyle(fontSize: 11))),
                                 DropdownMenuItem(value: 'meters', child: Text('Meters', style: TextStyle(fontSize: 11))),
                               ],
                               onChanged: (val) => setState(() => _selectedBreadthUnit = val!),
                             ),
                           ),
                         ],
                       ),
                        const SizedBox(height: 24),
                        
                         const Text("Owner Details", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                         const SizedBox(height: 8),
                         Row(
                           children: [
                             Expanded(child: _buildTextField("Owner Name", _ownerNameController, isDark)),
                             const SizedBox(width: 12),
                             Expanded(child: _buildTextField("Owner Number", _ownerNumberController, isDark, keyboardType: TextInputType.phone)),
                           ],
                         ),
                        const SizedBox(height: 24),

                       const Text("Location", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                       const SizedBox(height: 8),
                       _buildTextField("Address Line 1", _address1Controller, isDark),
                       const SizedBox(height: 8),
                        _buildTextField("Address Line 2", _address2Controller, isDark),
                        const SizedBox(height: 12),

                        // City
                        Text("City", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 1.0)),
                        const SizedBox(height: 8),
                        citiesAsync.when(
                          data: (cities) => CitySearchField(
                            allCities: cities,
                            selectedCity: _selectedCity.isNotEmpty ? _selectedCity : null,
                            onChanged: (city) {
                              setState(() {
                                _selectedCity = city ?? '';
                                _cityController.clear();
                              });
                            },
                          ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, _) => CitySearchField(
                            allCities: const [],
                            selectedCity: _selectedCity.isNotEmpty ? _selectedCity : null,
                            onChanged: (city) {
                              setState(() {
                                _selectedCity = city ?? '';
                                _cityController.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField("Pincode", _pincodeController, isDark),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildTextField("State", _stateController, isDark)),
                           const SizedBox(width: 12),
                           Expanded(child: _buildTextField("Country", _countryController, isDark)),
                         ],
                       ),
                       const SizedBox(height: 12),
                       
                       Row(
                         children: [
                           Expanded(child: _buildTextField("Latitude", _latController, isDark, keyboardType: TextInputType.number)),
                           const SizedBox(width: 12),
                           Expanded(child: _buildTextField("Longitude", _lngController, isDark, keyboardType: TextInputType.number)),
                         ],
                       ),
                       const SizedBox(height: 8),
                       Align(
                         alignment: Alignment.centerRight,
                         child: OutlinedButton.icon(
                           onPressed: _pickLocation,
                           icon: const Icon(Icons.map_outlined, size: 16),
                           label: const Text("Pick On Map", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                           style: OutlinedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           ),
                         ),
                       ),
                       const SizedBox(height: 16),

                       // Brochure URL & Select Brochure Button
                       Row(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           Expanded(
                             child: _buildTextField("Brochure URL", _brochureUrlController, isDark),
                           ),
                           const SizedBox(width: 12),
                           _isUploadingBrochure
                               ? const SizedBox(
                                   width: 32,
                                   height: 32,
                                   child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                                 )
                               : ElevatedButton.icon(
                                   onPressed: () async {
                                     final result = await Navigator.push(
                                       context,
                                       MaterialPageRoute(builder: (_) => const AssetsLibraryScreen(isSelectionMode: true)),
                                     );
                                     if (result != null && result is String) {
                                       setState(() {
                                         _brochureUrlController.text = result;
                                       });
                                     }
                                   },
                                   icon: const Icon(Icons.upload_file, size: 16),
                                   label: const Text("Select Brochure", style: TextStyle(fontSize: 11)),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.blue,
                                     foregroundColor: Colors.white,
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                   ),
                                 ),
                         ],
                       ),
                       const SizedBox(height: 16),

                         // Amenities tag input
                          AmenitiesTagInput(
                            selectedAmenities: _amenities,
                            onChanged: (list) => setState(() => _amenities = list),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 24),

                         // Policies & Rules placed right after Amenities
                        const Text("Policies & Rules", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        _buildTextField("Policies & Rules (comma/newline separated)", _policiesController, isDark, maxLines: 2),
                        const SizedBox(height: 24),

                       // Project Images
                       const Text("Property Images", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                       const SizedBox(height: 8),
                       if (_images.isNotEmpty)
                         Container(
                           height: 80,
                           margin: const EdgeInsets.only(bottom: 8),
                           child: ListView.builder(
                             scrollDirection: Axis.horizontal,
                             itemCount: _images.length,
                             itemBuilder: (context, index) {
                               return Stack(
                                 children: [
                                   Container(
                                     margin: const EdgeInsets.only(right: 8),
                                     width: 80,
                                     height: 80,
                                     decoration: BoxDecoration(
                                       borderRadius: BorderRadius.circular(6),
                                       border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                       image: DecorationImage(
                                         image: NetworkImage(_images[index]),
                                         fit: BoxFit.cover,
                                       ),
                                     ),
                                   ),
                                   Positioned(
                                     top: 2,
                                     right: 10,
                                     child: InkWell(
                                       onTap: () {
                                         setState(() {
                                           _images.removeAt(index);
                                         });
                                       },
                                       child: Container(
                                         decoration: const BoxDecoration(
                                           color: Colors.black54,
                                           shape: BoxShape.circle,
                                         ),
                                         child: const Icon(Icons.close, color: Colors.white, size: 16),
                                       ),
                                     ),
                                   ),
                                 ],
                               );
                             },
                           ),
                         ),
                       _isUploadingImages
                           ? const Row(
                               children: [
                                 SizedBox(
                                   width: 16,
                                   height: 16,
                                   child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                                 ),
                                 SizedBox(width: 8),
                                 Text("Uploading images to R2...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                               ],
                             )
                           : OutlinedButton.icon(
                               onPressed: () async {
                                 try {
                                   final result = await FilePicker.platform.pickFiles(
                                     type: FileType.image,
                                     allowMultiple: true,
                                   );
                                   if (result != null) {
                                     setState(() {
                                       _isUploadingImages = true;
                                       _uploadError = null;
                                     });
                                     for (var pickedFile in result.files) {
                                       Uint8List? bytes = pickedFile.bytes;
                                       if (bytes == null && pickedFile.path != null) {
                                         bytes = await File(pickedFile.path!).readAsBytes();
                                       }
                                       if (bytes == null) continue;
                                       final uniqueFileName = 'properties/images/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
                                       final r2Key = await _r2Service.uploadFile(
                                         bytes,
                                         uniqueFileName,
                                         'image/${pickedFile.extension ?? "jpeg"}',
                                       );
                                       if (r2Key != null) {
                                         setState(() {
                                           _images.add('${R2Service.publicBaseUrl}/$r2Key');
                                         });
                                       }
                                     }
                                   }
                                 } catch (e) {
                                   setState(() {
                                     _uploadError = e.toString();
                                   });
                                 } finally {
                                   setState(() {
                                     _isUploadingImages = false;
                                   });
                                 }
                               },
                               icon: const Icon(Icons.add_a_photo, size: 16),
                               label: const Text("Choose Images", style: TextStyle(fontSize: 11)),
                               style: OutlinedButton.styleFrom(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                               ),
                             ),
                       const SizedBox(height: 16),

                       // Property Videos
                       const Text("Property Videos", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                       const SizedBox(height: 8),
                       Row(
                         children: [
                           Expanded(
                             child: TextField(
                               controller: _videoUrlController,
                               style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13),
                               decoration: _inputDecoration("Paste video URL (YouTube, Vimeo...)", isDark),
                             ),
                           ),
                           const SizedBox(width: 8),
                           ElevatedButton(
                             onPressed: () {
                               final url = _videoUrlController.text.trim();
                               if (url.isNotEmpty) {
                                 setState(() {
                                   _videos.add(url);
                                   _videoUrlController.clear();
                                 });
                               }
                             },
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.black,
                               foregroundColor: Colors.white,
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                             ),
                             child: const Text("Add Link", style: TextStyle(fontSize: 11)),
                           ),
                         ],
                       ),
                       const SizedBox(height: 8),
                       if (_videos.isEmpty)
                         const Text(
                           "No video links added yet. Paste a link above and click 'Add Link'.",
                           style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                         )
                       else
                         Container(
                           constraints: const BoxConstraints(maxHeight: 120),
                           child: ListView.builder(
                             shrinkWrap: true,
                             itemCount: _videos.length,
                             itemBuilder: (context, index) {
                               return Card(
                                 margin: const EdgeInsets.only(bottom: 4),
                                 child: ListTile(
                                   dense: true,
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                   title: Text(_videos[index], style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                   trailing: IconButton(
                                     icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                     onPressed: () {
                                       setState(() {
                                         _videos.removeAt(index);
                                       });
                                     },
                                   ),
                                 ),
                               );
                             },
                           ),
                         ),
                       const SizedBox(height: 16),

                       // Payment Plan
                       _buildTextField("Payment Plan / Milestones", _paymentPlanController, isDark, maxLines: 3),
                       const SizedBox(height: 16),

                       if (_uploadError != null) ...[
                         Text(_uploadError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                         const SizedBox(height: 12),
                       ],
                       
                       _buildTextField("Internal Notes", _internalNotesController, isDark, maxLines: 2),
                       const SizedBox(height: 32),
                     ],
                   ),
                 ),
               ),
             ),
             
             // Fixed Footer
             const Divider(height: 1),
             Padding(
               padding: const EdgeInsets.all(24),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   TextButton(
                     onPressed: () => Navigator.pop(context),
                     style: TextButton.styleFrom(foregroundColor: Colors.grey),
                     child: const Text("CANCEL"),
                   ),
                   const SizedBox(width: 16),
                   ElevatedButton(
                     onPressed: _isLoading ? null : _submit,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.black,
                       foregroundColor: Colors.white,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                       elevation: 0
                     ),
                     child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.property == null ? "SAVE PROPERTY" : "UPDATE PROPERTY", style: const TextStyle(fontWeight: FontWeight.bold)),
                   )
                 ],
               ),
             )
           ],
         ),
       )
     );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, {
      bool required = false, 
      int maxLines = 1,
      TextInputType? keyboardType,
      Widget? suffixIcon,
  }) {
    return TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13),
        validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
        decoration: _inputDecoration(label, isDark).copyWith(suffixIcon: suffixIcon),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
      return InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: false,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          isDense: true,
      );
  }

  String mapUnit(String display) {
    switch (display) {
      case 'Sq Ft': return 'sqft';
      case 'Sq Yd': return 'sqyd';
      case 'Gaj': return 'gaj';
      case 'Acre': return 'acre';
      case 'Feet': return 'feet';
      case 'Yards': return 'yards';
      case 'Meters': return 'meters';
      default: return display.toLowerCase();
    }
  }

  String _reverseMapUnit(String value) {
    final s = value.toLowerCase().replaceAll(' ', '').replaceAll('.', '');
    switch (s) {
      case 'sqft':
      case 'sqfeet':
      case 'squarefeet':
        return 'sqft';
      case 'sqyd':
      case 'sqyards':
      case 'squareyards':
        return 'sqyd';
      case 'gaj':
        return 'gaj';
      case 'acre':
        return 'acre';
      case 'feet':
      case 'foot':
      case 'ft':
        return 'feet';
      case 'yards':
      case 'yard':
      case 'yd':
        return 'yards';
      case 'meters':
      case 'meter':
      case 'm':
        return 'meters';
      default:
        return s;
    }
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return DateFormat('dd MMM yyyy').format(dt);
  }

  DateTime _parseDate(String text) {
    return DateTime.tryParse(text) ?? DateFormat('dd MMM yyyy').tryParse(text) ?? DateTime.now();
  }

  Future<void> _pickLocation() async {
    double? initialLat = double.tryParse(_latController.text);
    double? initialLng = double.tryParse(_lngController.text);

    final LocationResult? result = await showDialog<LocationResult>(
      context: context,
      builder: (context) => LocationPickerDialog(
        initialLat: initialLat,
        initialLng: initialLng,
      ),
    );

    if (result != null) {
      setState(() {
        _latController.text = result.location.latitude.toString();
        _lngController.text = result.location.longitude.toString();
        
        _address1Controller.text = result.address;
        if (result.city != null) {
          _selectedCity = result.city!;
          _cityController.clear();
        }
        if (result.state != null) _stateController.text = result.state!;
        if (result.country != null) _countryController.text = result.country!;
        if (result.postcode != null) _pincodeController.text = result.postcode!;
      });
    }
  }
}
