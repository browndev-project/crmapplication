import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/lead_provider.dart';

class LeadBulkUploadDialog extends ConsumerStatefulWidget {
  const LeadBulkUploadDialog({super.key});

  @override
  ConsumerState<LeadBulkUploadDialog> createState() => _LeadBulkUploadDialogState();
}

class _LeadBulkUploadDialogState extends ConsumerState<LeadBulkUploadDialog> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  Map<String, dynamic>? _uploadSummary;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _downloadSample() async {
    const headers = "name, email, phoneNo, description, service_name, source, status, pipeline";
    const row = "John Doe, john@example.com, 1234567890, Sample Lead, Service A, Website, New, Hot";
    const content = "$headers\n$row";

    try {
      // In a real app, you might want to use a more user-accessible directory or share the file
      final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/leads_sample.csv');
      await file.writeAsString(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample saved to: ${file.path}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save sample: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadSummary = null; // Clear previous summary
    });
    
    try {
      final result = await ref.read(leadsProvider.notifier).bulkUploadLeads(_selectedFile!);
      
      if (mounted) {
        setState(() {
          _uploadSummary = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  List<Map<String, dynamic>> _getFailedRows() {
    if (_uploadSummary == null) return [];
    
    final results = _uploadSummary!['results'] as List? ?? [];
    return results
        .where((item) => item['success'] == false)
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
  Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text(
                    "Bulk Upload Leads",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
            ),
            const Divider(height: 1),

            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Action Buttons (Pick & Download)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildOutlineButton(
                            icon: Icons.note_add_outlined,
                            label: "CHOOSE CSV FILE",
                            onTap: _pickFile,
                          ),
                          _buildOutlineButton(
                            icon: Icons.download_outlined,
                            label: "DOWNLOAD SAMPLE",
                            onTap: _downloadSample,
                          ),
                          if (_selectedFile != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                _selectedFile!.name,
                                style: TextStyle(color: Colors.blue[700], fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            Text(
                              "No file chosen",
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Accepts CSV and Excel files (.csv, .xlsx, .xls)",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
            
                      const SizedBox(height: 24),
            
                      // Instructions Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // Light blue-grey
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Instructions",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            _buildInstructionItem("Do not do any design formatting in the sheet. Keep it plain text only"),
                            _buildInstructionItem("Do not change headings. Headings must match the sample file exactly"),
                            _buildInstructionItem("Ensure the service name is added in the Services section before you add it in the CSV file"),
                          ],
                        ),
                      ),
            
                      const SizedBox(height: 24),
            
                      // Required Headers
                      Text(
                        "Required CSV headers:",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          "name, email, phoneNo, description, service_name, source, status, pipeline",
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontFamily: 'Courier'),
                        ),
                      ),

                      // Upload Summary Section (shown after upload)
                      if (_uploadSummary != null) ...[
                        const SizedBox(height: 32),
                        
                        // Upload Summary Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Upload Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 12),
                              Text('Total Rows: ${(_uploadSummary!['summary'] as Map?)?['total'] ?? 0}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text('Success: ${(_uploadSummary!['summary'] as Map?)?['successCount'] ?? 0}', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Failed: ${(_uploadSummary!['summary'] as Map?)?['failCount'] ?? 0}', style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),

                        // Failed Rows Details
                        if (_getFailedRows().isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text('Failed Rows Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 12),
                          ..._getFailedRows().map((row) {
                            final rowNumber = row['row'] ?? 0;
                            final errors = row['errors'] as List? ?? [];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Row $rowNumber', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  ...errors.map((error) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(color: Colors.red)),
                                        Expanded(child: Text(error.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedFile == null || _isUploading ? null : _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedFile == null ? Colors.grey[300] : Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                    ),
                    child: _isUploading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("UPLOAD", style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOutlineButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(color: Color(0xFF1E293B), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
