import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/r2_service.dart';
import '../../providers/lead_document_provider.dart';

class DocumentUploadDialog extends ConsumerStatefulWidget {
  final String leadId;
  const DocumentUploadDialog({super.key, required this.leadId});

  @override
  ConsumerState<DocumentUploadDialog> createState() => _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends ConsumerState<DocumentUploadDialog> {
  final _labelController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _error;

  final R2Service _r2Service = R2Service();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      if (result.files.single.size > 1024 * 1024) {
        setState(() => _error = 'File size must be less than 1MB');
        return;
      }
      setState(() {
        _selectedFile = result.files.single;
        _error = null;
        if (_labelController.text.isEmpty) {
          _labelController.text = _selectedFile!.name.split('.').first;
        }
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null || _labelController.text.isEmpty) {
      setState(() => _error = 'Please provide a label and select a file');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      Uint8List? bytes = _selectedFile!.bytes;
      if (bytes == null && _selectedFile!.path != null) {
        final file = File(_selectedFile!.path!);
        bytes = await file.readAsBytes();
      }
      
      if (bytes == null) throw 'Could not read file bytes';

      final uniqueFileName = 'leadDocs/${widget.leadId}/${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
      final r2Key = await _r2Service.uploadFile(bytes, uniqueFileName, _selectedFile!.extension ?? 'application/octet-stream');

      if (r2Key != null) {
        final success = await ref.read(leadDocumentServiceProvider).uploadDocumentMetadata(
              leadId: widget.leadId,
              label: _labelController.text,
              fileType: _selectedFile!.extension ?? '',
              size: _selectedFile!.size,
              r2Key: r2Key,
            );

        if (success) {
          ref.read(leadDocumentsProvider(widget.leadId).notifier).fetchDocuments();
          if (mounted) Navigator.of(context).pop();
        } else {
          throw 'Failed to save document metadata';
        }
      } else {
        throw 'Failed to upload file to storage';
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Upload Document', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: 'Document Label',
                hintText: 'e.g. Aadhaar Card',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickFile,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null ? _selectedFile!.name : 'Click to upload file',
                      style: TextStyle(color: _selectedFile != null ? Colors.blue : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text('Maximum 1 MB', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isUploading ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isUploading ? null : _handleUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isUploading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('UPLOAD'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
