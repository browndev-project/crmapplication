import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/property_provider.dart';
import '../../core/services/r2_service.dart';
import 'location_picker_dialog.dart';
import '../screens/assets/assets_library_screen.dart';

class ProjectCreateDialog extends ConsumerStatefulWidget {
  const ProjectCreateDialog({super.key});

  @override
  ConsumerState<ProjectCreateDialog> createState() => _ProjectCreateDialogState();
}

class _ProjectCreateDialogState extends ConsumerState<ProjectCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _developerNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _totalAreaValueController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  
  final _r2Service = R2Service();
  final TextEditingController _reraIdController = TextEditingController();
  final TextEditingController _possessionDateController = TextEditingController();
  final TextEditingController _brochureUrlController = TextEditingController();
  final TextEditingController _amenitiesController = TextEditingController();
  final TextEditingController _paymentPlanController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();

  String _selectedAreaUnit = 'sqft';
  String _selectedStatus = 'active';
  String _selectedCategory = 'Residential';
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _images = [];
  final List<String> _videos = [];
  final bool _isUploadingBrochure = false;
  bool _isUploadingImages = false;
  String? _uploadError;

  @override
  void dispose() {
    _nameController.dispose();
    _developerNameController.dispose();
    _descriptionController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _totalAreaValueController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _reraIdController.dispose();
    _possessionDateController.dispose();
    _brochureUrlController.dispose();
    _amenitiesController.dispose();
    _paymentPlanController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final payload = {
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "developerName": _developerNameController.text.trim().isNotEmpty ? _developerNameController.text.trim() : null,
        "location": {
            "address1": _address1Controller.text.trim().isNotEmpty ? _address1Controller.text.trim() : null,
            "address2": _address2Controller.text.trim().isNotEmpty ? _address2Controller.text.trim() : null,
            "pincode": _pincodeController.text.trim().isNotEmpty ? _pincodeController.text.trim() : null,
            "city": _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
            "state": _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : null,
            "country": _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : null,
            "coordinates": (_latController.text.isNotEmpty && _lngController.text.isNotEmpty)
                ? {
                    "lat": double.tryParse(_latController.text) ?? 0,
                    "lng": double.tryParse(_lngController.text) ?? 0
                  }
                : null
        },
        "totalArea": _totalAreaValueController.text.isNotEmpty 
            ? {
                "value": double.tryParse(_totalAreaValueController.text) ?? 0,
                "unit": _mapUnit(_selectedAreaUnit)
            }
            : null,
        "active": _isActive,
        "status": _selectedStatus,
        "category": _selectedCategory,
        "reraId": _reraIdController.text.trim().isNotEmpty ? _reraIdController.text.trim() : null,
        "possessionDate": _possessionDateController.text.trim().isNotEmpty ? _possessionDateController.text.trim() : null,
        "brochureUrl": _brochureUrlController.text.trim().isNotEmpty ? _brochureUrlController.text.trim() : null,
        "paymentPlan": _paymentPlanController.text.trim().isNotEmpty ? _paymentPlanController.text.trim() : null,
        "amenities": _amenitiesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        "images": _images,
        "videos": _videos,
      };

      await ref.read(propertyProvider.notifier).createProject(payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project created successfully'), backgroundColor: Colors.green),
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
    
    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
       backgroundColor: Theme.of(context).cardColor,
       insetPadding: const EdgeInsets.all(16),
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 500),
         child: SingleChildScrollView(
           child: Padding(
             padding: const EdgeInsets.all(24),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 // Header
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text("Create Project", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                     InkWell(
                       onTap: () => Navigator.pop(context),
                       borderRadius: BorderRadius.circular(20),
                       child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.close, size: 20, color: Theme.of(context).iconTheme.color),
                       ),
                     )
                   ],
                 ),
                 const Divider(height: 32),
                 
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category and Status at the top row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: _inputDecoration("Category", isDark),
                                items: ['Residential', 'Commercial', 'Industrial', 'Land'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (val) => setState(() => _selectedCategory = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedStatus,
                                isExpanded: true,
                                decoration: _inputDecoration("Status", isDark),
                                items: ['Pre-Launch', 'Active', 'Under Construction', 'Sold Out', 'Ready to Move', 'On Hold', 'Blocked'].map((s) => DropdownMenuItem(value: s.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_'), child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (val) => setState(() => _selectedStatus = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _buildTextField("Project Name", _nameController, isDark, required: true),
                        const SizedBox(height: 12),
                        
                        _buildTextField("Key Features / Description", _descriptionController, isDark, maxLines: 3),
                        const SizedBox(height: 16),
                        
                        const Text("Location", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        _buildTextField("Address Line 1", _address1Controller, isDark),
                        const SizedBox(height: 8),
                        _buildTextField("Address Line 2", _address2Controller, isDark),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Expanded(child: _buildTextField("City", _cityController, isDark)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField("Pincode", _pincodeController, isDark)),
                          ],
                        ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        const Text("Dimensions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildTextField("Total Area", _totalAreaValueController, isDark, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedAreaUnit,
                                decoration: _inputDecoration("Unit", isDark),
                                 items: const [
                                  DropdownMenuItem(value: 'gaj', child: Text('Gaj', style: TextStyle(fontSize: 11))),
                                  DropdownMenuItem(value: 'sqft', child: Text('Sq Ft', style: TextStyle(fontSize: 11))),
                                  DropdownMenuItem(value: 'sqyd', child: Text('Sq Yd', style: TextStyle(fontSize: 11))),
                                  DropdownMenuItem(value: 'acre', child: Text('Acre', style: TextStyle(fontSize: 11))),
                                  DropdownMenuItem(value: 'bigha', child: Text('Bigha', style: TextStyle(fontSize: 11))),
                                ],
                                onChanged: (val) => setState(() => _selectedAreaUnit = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // RERA ID and Possession Date
                        Row(
                          children: [
                            Expanded(child: _buildTextField("RERA ID", _reraIdController, isDark)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _possessionDateController.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                                child: AbsorbPointer(
                                  child: _buildTextField("Possession Date", _possessionDateController, isDark,
                                      suffixIcon: const Icon(Icons.calendar_today, size: 16)),
                                ),
                              ),
                            ),
                          ],
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

                        // Amenities (comma separated)
                        _buildTextField("Amenities (comma-separated)", _amenitiesController, isDark, maxLines: 2),
                        const SizedBox(height: 16),

                        // Project Images
                        const Text("Project Images", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                                        final uniqueFileName = 'projects/images/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
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

                        // Project Videos
                        const Text("Project Videos", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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

                        SwitchListTile(
                          title: const Text("Active"),
                          value: _isActive,
                          onChanged: (val) => setState(() => _isActive = val),
                          activeThumbColor: Colors.black,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
            
                  const SizedBox(height: 32),
            
                  // Footer
                  Row(
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
                                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                 elevation: 0
                             ),
                             child: _isLoading 
                                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                 : const Text("SAVE"),
                         )
                     ],
                  )
               ],
             ),
           ),
         ),
       ),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          isDense: true,
      );
  }

  String _mapUnit(String display) {
    switch (display) {
      case 'Sq Ft': return 'sqft';
      case 'Sq Yd': return 'sqyd';
      case 'Gaj': return 'gaj';
      case 'Acre': return 'acre';
      case 'Bigha': return 'bigha';
      case 'Feet': return 'feet';
      case 'Yards': return 'yards';
      case 'Meters': return 'meters';
      default: return display.toLowerCase();
    }
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
        if (result.city != null) _cityController.text = result.city!;
        if (result.state != null) _stateController.text = result.state!;
        if (result.country != null) _countryController.text = result.country!;
        if (result.postcode != null) _pincodeController.text = result.postcode!;
      });
    }
  }
}
