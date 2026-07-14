import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../../core/services/asset_service.dart';

class AssetUploadDialog extends ConsumerStatefulWidget {
  const AssetUploadDialog({super.key});

  @override
  ConsumerState<AssetUploadDialog> createState() => _AssetUploadDialogState();
}

class _AssetUploadDialogState extends ConsumerState<AssetUploadDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          // Auto-fill name if empty
          if (_nameController.text.isEmpty) {
            _nameController.text = _selectedFile!.name;
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a file'), backgroundColor: Colors.red));
      return;
    }
    if (_nameController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an asset name'), backgroundColor: Colors.red));
       return;
    }

    setState(() => _isUploading = true);

    try {
      final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      debugPrint('Uploading asset: Name=${_nameController.text.trim()}, Tags=$tags');
      
      await ref.read(assetServiceProvider).uploadAsset(
        _selectedFile!, 
        name: _nameController.text.trim(), 
        tags: tags
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Upload Asset", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), padding: EdgeInsets.zero, constraints: const BoxConstraints())
              ],
            ),
            const Divider(height: 32),
            
            // Name Field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Asset Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            
            // Tags Field
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: 'Tags (comma separated)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            
            // File Upload Area
            GestureDetector(
              onTap: _pickFile,
              child: DottedBorder(
                child: Container(
                  width: double.infinity,
                  height: 150,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: _selectedFile == null 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text("Click to upload file", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 4),
                          Text("PDF DOC PPT XLS Images up to 20 MB", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(Icons.insert_drive_file, size: 40, color: Colors.blue.shade400),
                           const SizedBox(height: 8),
                           Text(_selectedFile!.name, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                           Text("Click to change", style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                        ],
                    ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  style: TextButton.styleFrom(foregroundColor: Colors.black87),
                  child: const Text("CANCEL")
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isUploading ? null : _handleUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueAccent : Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: _isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Upload"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
