import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/itinerary_service.dart';

class AiItineraryGenerateDialog extends StatefulWidget {
  const AiItineraryGenerateDialog({super.key});

  @override
  State<AiItineraryGenerateDialog> createState() => _AiItineraryGenerateDialogState();
}

class _AiItineraryGenerateDialogState extends State<AiItineraryGenerateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _startDateController = TextEditingController(text: DateFormat('MM/dd/yyyy').format(DateTime.now()));
  final _noOfDaysController = TextEditingController(text: '2');
  final _keyLocationsController = TextEditingController();
  final _adultsController = TextEditingController(text: '1');
  final _roomsController = TextEditingController(text: '1');
  
  bool _isLoading = false;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _startDateController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  void _onGenerate() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      
      // Parse the startDate back into standard yyyy-MM-dd format for the AI generator backend
      String formattedDate = '';
      try {
        final parsedDate = DateFormat('MM/dd/yyyy').parse(_startDateController.text.trim());
        formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (_) {
        formattedDate = _startDateController.text.trim();
      }

      final data = {
        'subject': _subjectController.text.trim(),
        'startDate': formattedDate,
        'noOfDays': int.tryParse(_noOfDaysController.text) ?? 2,
        'keyLocations': _keyLocationsController.text.split(',').map((e) => e.trim()).toList(),
        'adults': int.tryParse(_adultsController.text) ?? 1,
        'rooms': int.tryParse(_roomsController.text) ?? 1,
      };

      try {
        final generatedData = await ItineraryService().generateHybrid(data);
        if (!mounted) return;
        Navigator.pop(context, generatedData);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _startDateController.dispose();
    _noOfDaysController.dispose();
    _keyLocationsController.dispose();
    _adultsController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        width: double.maxFinite,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Auto-Generate Itinerary with AI',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 32),
                
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Itinerary Subject / Title',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startDateController,
                        decoration: InputDecoration(
                          labelText: 'Journey Start Date',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            onPressed: _selectDate,
                          ),
                        ),
                        readOnly: true,
                        onTap: _selectDate,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _noOfDaysController,
                        decoration: const InputDecoration(
                          labelText: 'Number of Days',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _keyLocationsController,
                  decoration: const InputDecoration(
                    labelText: 'Key Locations (Comma separated)',
                    hintText: 'E.g., Phuket, Bangkok',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _adultsController,
                        decoration: const InputDecoration(
                          labelText: 'Total Number of Adults',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _roomsController,
                        decoration: const InputDecoration(
                          labelText: 'Total Rooms Required',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 48),
                
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text('CANCEL', style: TextStyle(color: Colors.black)),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _onGenerate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: _isLoading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('GENERATE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
