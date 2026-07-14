import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/itinerary_model.dart';
import '../providers/itinerary_provider.dart';
import 'itinerary_template_gallery_dialog.dart';
import '../../core/services/r2_service.dart';
import '../../core/services/ai_service.dart';
import 'ai_itinerary_generate_dialog.dart';
import 'lead_autocomplete_dropdown.dart';
import '../../data/models/lead_model.dart';

class ImageUploadWidget extends StatefulWidget {
  final String? imageUrl;
  final String? Function(String) onImageChanged;
  final String label;
  final double height;
  final double? width;
  final bool required;

  const ImageUploadWidget({
    super.key,
    this.imageUrl,
    required this.onImageChanged,
    this.label = 'Upload Image',
    this.height = 120,
    this.width,
    this.required = false,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  bool _isUploading = false;
  String? _error;
  String? _previewUrl;

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.imageUrl;
  }

  @override
  void didUpdateWidget(ImageUploadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _previewUrl = widget.imageUrl;
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isUploading = true;
          _error = null;
        });

        final file = File(result.files.first.path!);
        final bytes = await file.readAsBytes();
        final extension = result.files.first.extension ?? 'jpg';
        final fileName = 'itinerary_${DateTime.now().millisecondsSinceEpoch}.$extension';

        final r2Service = R2Service();
        final key = await r2Service.uploadFile(
          bytes,
          'images/$fileName',
          'image/$extension',
        );

        if (key != null) {
          final uploadedUrl = '${R2Service.publicBaseUrl}/images/$fileName';
          setState(() {
            _previewUrl = uploadedUrl;
            _isUploading = false;
          });
          widget.onImageChanged(uploadedUrl);
        } else {
          setState(() {
            _error = 'Upload failed. Please try again.';
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isUploading = false;
      });
    }
  }

  void _showUrlInputDialog() {
    final controller = TextEditingController(text: _previewUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter ${widget.label} URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.jpg',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                setState(() => _previewUrl = url);
                widget.onImageChanged(url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _previewUrl = null;
      _error = null;
    });
    widget.onImageChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _previewUrl != null && _previewUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (widget.required) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _error != null ? Colors.red : const Color(0xFFE5E7EB),
              width: _error != null ? 2 : 1,
            ),
            color: Colors.white,
          ),
          child: _isUploading
              ? const Center(child: CircularProgressIndicator())
              : hasImage
                  ? _buildImagePreview()
                  : _buildUploadPlaceholder(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
      ],
    );
  }

  void _showAiGenerator(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AiImageGeneratorModal(
        sectionName: widget.label,
        initialPrompt: _generateContextPrompt(),
        onImageGenerated: (url) {},
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _previewUrl = result);
      widget.onImageChanged(result);
    }
  }

  String _generateContextPrompt() {
    final label = widget.label.toLowerCase();
    if (label.contains('hotel') || label.contains('stay') || label.contains('accommodation')) {
      return 'Luxury hotel room interior, premium resort style, elegant furnishings, floor to ceiling windows, cinematic lighting, ultra realistic travel photography';
    } else if (label.contains('day')) {
      return 'Immersive travel experience, scenic destination view, tourist activities, cinematic storytelling, premium travel photography, ultra realistic';
    } else if (label.contains('transport')) {
      return 'Premium transportation, luxury airport or railway station, modern vehicle, cinematic travel photography, ultra realistic';
    }
    return 'Luxury travel destination, premium travel photography, cinematic lighting, ultra realistic, 8k quality';
  }

  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.network(
            _previewUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
              ),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[100],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _buildImageButton(Icons.cloud_upload_outlined, _showUploadOptions),
              const SizedBox(width: 4),
              _buildImageButton(Icons.auto_awesome, () => _showAiGenerator(context)),
              const SizedBox(width: 4),
              _buildImageButton(Icons.close, _removeImage),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Stack(
      children: [
        InkWell(
          onTap: _showUploadOptions,
          borderRadius: BorderRadius.circular(11),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, color: Colors.grey[400], size: 32),
              const SizedBox(height: 8),
              Text(
                'Click to upload',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlaceholderButton(Icons.cloud_upload_outlined, 'Upload', _showUploadOptions),
              const SizedBox(width: 4),
              _buildPlaceholderButton(Icons.auto_awesome, 'AI', () => _showAiGenerator(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.black87),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Device'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Enter Image URL'),
              onTap: () {
                Navigator.pop(ctx);
                _showUrlInputDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_search),
              title: const Text('Choose from Presets'),
              onTap: () {
                Navigator.pop(ctx);
                _showPresetSelector();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPresetSelector() {
    final presets = [
      {'name': 'Maldives Beach', 'url': 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?w=800&auto=format&fit=crop'},
      {'name': 'Swiss Alps', 'url': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop'},
      {'name': 'Paris Cityscape', 'url': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&auto=format&fit=crop'},
      {'name': 'Bali Rainforest', 'url': 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&auto=format&fit=crop'},
      {'name': 'Santorini Greece', 'url': 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=800&auto=format&fit=crop'},
      {'name': 'Dubai Skyline', 'url': 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800&auto=format&fit=crop'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Preset Image'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              return InkWell(
                onTap: () {
                  setState(() => _previewUrl = preset['url']);
                  widget.onImageChanged(preset['url']!);
                  Navigator.pop(ctx);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(preset['url']!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black38,
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      preset['name']!,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class HeroImageWidget extends StatefulWidget {
  final String? imageUrl;
  final String? Function(String) onImageChanged;
  final bool required;

  const HeroImageWidget({
    super.key,
    this.imageUrl,
    required this.onImageChanged,
    this.required = false,
  });

  @override
  State<HeroImageWidget> createState() => _HeroImageWidgetState();
}

class _HeroImageWidgetState extends State<HeroImageWidget> {
  bool _isUploading = false;
  String? _error;
  String? _previewUrl;

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.imageUrl;
  }

  @override
  void didUpdateWidget(HeroImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _previewUrl = widget.imageUrl;
    }
  }

  Uint8List _base64Decode(String dataUrl) {
    final parts = dataUrl.split(',');
    if (parts.length < 2) return Uint8List(0);
    String encoded = parts[1];
    while (encoded.length % 4 != 0) {
      encoded += '=';
    }
    final decoded = base64Decode(encoded);
    return Uint8List.fromList(decoded);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isUploading = true;
          _error = null;
        });

        final file = File(result.files.first.path!);
        final bytes = await file.readAsBytes();
        final extension = result.files.first.extension ?? 'jpg';
        final fileName = 'hero_${DateTime.now().millisecondsSinceEpoch}.$extension';

        final r2Service = R2Service();
        final key = await r2Service.uploadFile(
          bytes,
          'images/$fileName',
          'image/$extension',
        );

        if (key != null) {
          final uploadedUrl = '${R2Service.publicBaseUrl}/images/$fileName';
          setState(() {
            _previewUrl = uploadedUrl;
            _isUploading = false;
          });
          widget.onImageChanged(uploadedUrl);
        } else {
          setState(() {
            _error = 'Upload failed. Please try again.';
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isUploading = false;
      });
    }
  }

  void _showUrlInputDialog() {
    final controller = TextEditingController(text: _previewUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Hero Image URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/hero-image.jpg',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                setState(() => _previewUrl = url);
                widget.onImageChanged(url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _previewUrl = null;
      _error = null;
    });
    widget.onImageChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _previewUrl != null && _previewUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Hero Banner Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (widget.required) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _error != null ? Colors.red : const Color(0xFFE5E7EB),
              width: _error != null ? 2 : 1,
            ),
            color: Colors.white,
          ),
          child: _isUploading
              ? const Center(child: CircularProgressIndicator())
              : hasImage
                  ? _buildHeroPreview()
                  : _buildHeroPlaceholder(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
      ],
    );
  }

  Widget _buildHeroImageButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  void _showAiGenerator(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AiImageGeneratorModal(
        sectionName: 'Hero Banner',
        initialPrompt: 'Luxury travel destination banner, cinematic golden hour lighting, premium resort photography, ultra realistic, 8k quality',
        onImageGenerated: (url) {},
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _previewUrl = result);
      widget.onImageChanged(result);
    }
  }

  Widget _buildHeroPreview() {
    final isBase64 = _previewUrl != null && _previewUrl!.startsWith('data:');
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: isBase64
              ? Image.memory(
                  _base64Decode(_previewUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 60)),
                  ),
                )
              : Image.network(
                  _previewUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 60)),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _buildHeroImageButton(Icons.cloud_upload_outlined, _showUploadOptions),
              const SizedBox(width: 4),
              _buildHeroImageButton(Icons.auto_awesome, () => _showAiGenerator(context)),
              const SizedBox(width: 4),
              _buildHeroImageButton(Icons.close, _removeImage),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPlaceholder() {
    return Stack(
      children: [
        InkWell(
          onTap: _showUploadOptions,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.grey[50],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, color: Colors.grey[400], size: 48),
                const SizedBox(height: 12),
                Text(
                  'Click to upload',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeroPlaceholderButton(Icons.cloud_upload_outlined, 'Upload', _showUploadOptions),
              const SizedBox(width: 6),
              _buildHeroPlaceholderButton(Icons.auto_awesome, 'AI', () => _showAiGenerator(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPlaceholderButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.black87),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Device'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Enter Image URL'),
              onTap: () {
                Navigator.pop(ctx);
                _showUrlInputDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_search),
              title: const Text('Choose from Presets'),
              onTap: () {
                Navigator.pop(ctx);
                _showPresetSelector();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPresetSelector() {
    final presets = [
      {'name': 'Maldives Beach', 'url': 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?w=1200&auto=format&fit=crop'},
      {'name': 'Swiss Alps', 'url': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=1200&auto=format&fit=crop'},
      {'name': 'Paris Cityscape', 'url': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=1200&auto=format&fit=crop'},
      {'name': 'Bali Rainforest', 'url': 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=1200&auto=format&fit=crop'},
      {'name': 'Santorini Greece', 'url': 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=1200&auto=format&fit=crop'},
      {'name': 'Dubai Skyline', 'url': 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=1200&auto=format&fit=crop'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Hero Image'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              return InkWell(
                onTap: () {
                  setState(() => _previewUrl = preset['url']);
                  widget.onImageChanged(preset['url']!);
                  Navigator.pop(ctx);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(preset['url']!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black38,
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      preset['name']!,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class AiImageGeneratorModal extends StatefulWidget {
  final String sectionName;
  final String? initialPrompt;
  final Function(String) onImageGenerated;

  const AiImageGeneratorModal({
    super.key,
    required this.sectionName,
    this.initialPrompt,
    required this.onImageGenerated,
  });

  static Future<String?> show(
    BuildContext context, {
    required String sectionName,
    String? initialPrompt,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AiImageGeneratorModal(
        sectionName: sectionName,
        initialPrompt: initialPrompt,
        onImageGenerated: (url) {},
      ),
    );
  }

  @override
  State<AiImageGeneratorModal> createState() => _AiImageGeneratorModalState();
}

class _AiImageGeneratorModalState extends State<AiImageGeneratorModal> {
  final _promptController = TextEditingController();
  String _selectedResolution = 'Landscape (1024 × 576)';
  bool _isOptimizing = false;
  bool _isGenerating = false;
  String? _generatedImageUrl;
  String? _optimizeError;
  String? _generateError;
  bool _isApplying = false;
  final _aiService = AiService();
  final _r2Service = R2Service();

  final List<String> _resolutions = [
    'Landscape (1024 × 576)',
    'Square (1024 × 1024)',
    'Portrait (576 × 1024)',
    'SD Landscape (768 × 512)',
    'HD Landscape (1280 × 720)',
    'Full HD (1920 × 1080)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _promptController.text = widget.initialPrompt!;
    } else {
      _promptController.text = _generateDefaultPrompt();
    }
  }

  String _generateDefaultPrompt() {
    switch (widget.sectionName.toLowerCase()) {
      case 'hero':
        return 'Luxury travel destination banner, cinematic golden hour lighting, premium resort photography, ultra realistic, 8k quality';
      case 'hotel':
        return 'Luxury hotel room interior, premium resort style, elegant furnishings, floor to ceiling windows, cinematic lighting, ultra realistic travel photography';
      case 'day':
        return 'Immersive travel experience, scenic destination view, tourist activities, cinematic storytelling, premium travel photography, ultra realistic';
      case 'transport':
        return 'Premium transportation, luxury airport or railway station, modern vehicle, cinematic travel photography, ultra realistic';
      default:
        return 'Luxury travel destination, premium travel photography, cinematic lighting, ultra realistic, 8k quality';
    }
  }

  Future<void> _optimizePrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _isOptimizing = true;
      _optimizeError = null;
    });
    try {
      final optimized = await _aiService.optimizePrompt(description: prompt);
      _promptController.text = optimized;
    } catch (e) {
      setState(() => _optimizeError = e.toString());
    }
    setState(() => _isOptimizing = false);
  }

  Future<void> _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _isGenerating = true;
      _generateError = null;
    });
    try {
      final res = AiService.resolutionPresets[_selectedResolution];
      final width = res?['width'] ?? 1024;
      final height = res?['height'] ?? 576;
      final url = await _aiService.generateImage(prompt: prompt, width: width, height: height);
      _generatedImageUrl = url;
    } catch (e) {
      setState(() => _generateError = e.toString());
    }
    setState(() => _isGenerating = false);
  }

  void _useImage() async {
    if (_generatedImageUrl == null || _isApplying) return;

    String finalUrl = _generatedImageUrl!;

    if (_generatedImageUrl!.startsWith('data:')) {
      setState(() => _isApplying = true);
      final uploadedUrl = await _r2Service.uploadBase64Image(_generatedImageUrl!, folder: 'itinerary');
      if (uploadedUrl != null) {
        finalUrl = uploadedUrl;
      }
      if (!mounted) return;
      setState(() => _isApplying = false);
    }

    widget.onImageGenerated(finalUrl);
    Navigator.pop(context, finalUrl);
  }

  Uint8List _base64Decode(String dataUrl) {
    final parts = dataUrl.split(',');
    if (parts.length < 2) return Uint8List(0);
    String encoded = parts[1];
    while (encoded.length % 4 != 0) {
      encoded += '=';
    }
    final decoded = base64Decode(encoded);
    return Uint8List.fromList(decoded);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final double dialogWidth = screenWidth > 900 ? 700 : (screenWidth > 600 ? screenWidth * 0.85 : double.infinity);
    final double maxDialogHeight = isMobile 
        ? MediaQuery.of(context).size.height * 0.9 
        : 850;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: isMobile ? 16 : 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPromptSection(),
                    const SizedBox(height: 20),
                    _buildResolutionSection(),
                    const SizedBox(height: 24),
                    if (_generatedImageUrl != null) _buildPreviewSection() else _buildGenerateButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.black87, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'AI Image Generator',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.black54, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Generate high-quality visuals for your ${widget.sectionName.toLowerCase()}.',
            style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image Prompt',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87, letterSpacing: -0.3),
        ),
        if (_optimizeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_optimizeError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _promptController,
          maxLines: null,
          minLines: 5,
          style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Describe your desired image...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isOptimizing ? null : _optimizePrompt,
            icon: _isOptimizing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                  )
                : const Icon(Icons.auto_awesome, size: 18, color: Colors.black87),
            label: Text(
              _isOptimizing ? 'Optimizing Prompt...' : 'Optimize Prompt',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              side: const BorderSide(color: Colors.black87, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resolution',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87, letterSpacing: -0.3),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedResolution,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 22, color: Colors.black54),
              items: _resolutions.map((res) {
                return DropdownMenuItem(
                  value: res,
                  child: Text(res, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedResolution = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: _isGenerating
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('Generating image...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 20),
                  SizedBox(width: 10),
                  Text('Generate Image', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final screenWidth = MediaQuery.of(context).size.width;
 screenWidth < 600;
    final double previewHeight = screenWidth > 900 ? 380.0 : (screenWidth > 600 ? 300.0 : 260.0);
    final res = AiService.resolutionPresets[_selectedResolution];
    final aspectRatio = (res?['width'] ?? 1024) / (res?['height'] ?? 576);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Generated Image',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87, letterSpacing: -0.3),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${res?['width'] ?? 1024} × ${res?['height'] ?? 576}',
                style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: previewHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: _isGenerating
                ? _buildLoadingShimmer()
                : AspectRatio(
                    aspectRatio: aspectRatio,
                    child: _buildImagePreview(),
                  ),
          ),
        ),
        if (_generateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_generateError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _generateImage,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Regenerate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_generatedImageUrl != null && !_isApplying) ? _useImage : null,
                icon: _isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(_isApplying ? 'Saving...' : 'Use Image', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    final isBase64 = _generatedImageUrl != null && _generatedImageUrl!.startsWith('data:');
    if (isBase64) {
      return Image.memory(
        _base64Decode(_generatedImageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Colors.grey[100],
          child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
        ),
      );
    }
    return Image.network(
      _generatedImageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: Colors.grey[100],
        child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildLoadingShimmer();
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'Generating image...',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class ItineraryCreateDialog extends ConsumerStatefulWidget {
  final ItineraryV2? itinerary;
  final Map<String, dynamic>? initialTemplateData;
  final Lead? prefilledLead;

  const ItineraryCreateDialog({
    super.key,
    this.itinerary,
    this.initialTemplateData,
    this.prefilledLead,
  });

  @override
  ConsumerState<ItineraryCreateDialog> createState() => _ItineraryCreateDialogState();
}

class _ItineraryCreateDialogState extends ConsumerState<ItineraryCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final R2Service r2Service = R2Service();
  final bool isUploadingImage = false;
  String? uploadError;
  bool _isLoading = false;

  String? _selectedTemplateKey;
  String? _selectedTemplateName;
  String? _selectedTemplateThumbnail;
  String? _selectedLeadId;

  // Section 1: Client & Journey Details
  final _subjectController = TextEditingController();
  final _startDateController = TextEditingController();
  final _noOfDaysController = TextEditingController(text: '3');
  final _clientNameController = TextEditingController();
  final _clientCompanyController = TextEditingController();
  final _keyLocationsController = TextEditingController();
  
  // Extra client details (if needed)
  final _clientEmailController = TextEditingController();
  final _clientPhoneController = TextEditingController();

  // Pricing & Rooms
  final _adultsController = TextEditingController(text: '2');
  final _roomsController = TextEditingController(text: '1');

  // Section 3: Visuals
  final _heroImageController = TextEditingController();
  final _shortDescController = TextEditingController();

  // Section 4: Experience Timeline Sections
  List<DayPlan> _sections = [];
  final List<FocusNode> _sectionFocusNodes = [];

  // Section 5 & 6: Logistics (Inclusions & Exclusions)
  final List<TextEditingController> _inclusionsControllers = [];
  final List<TextEditingController> _exclusionsControllers = [];

  // Section 7: Stay Accommodations
  List<StayV2> _stays = [];

  // Section 8: Transport Details
  List<TransportV2> _transports = [];

  // Section 9: Terms & Conditions
  List<PolicyV2> _termsAndConditions = [];

  // Additional Activities cost (Section 8/Financial summary)
  final _activitiesCostController = TextEditingController(text: '0');

  // Cost calculations
  double staysTotal = 0;
  double transportsTotal = 0;
  double _totalValue = 0;

  late final ScrollController _scrollController;

  void showImageUploaderDialog({
    required String title,
    required String initialUrl,
    required Function(String) onUrlApplied,
    List<Map<String, String>> presets = const [],
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (presets.isNotEmpty) ...[
                const Text('Select a preset image:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: presets.length,
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      return ListTile(
                        leading: const Icon(Icons.image),
                        title: Text(preset['name'] ?? 'Image ${index + 1}'),
                        onTap: () {
                          onUrlApplied(preset['url'] ?? '');
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                const Divider(),
                const Text('Or enter URL manually:', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: initialUrl),
                onSubmitted: (val) {
                  onUrlApplied(val);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final it = widget.itinerary;
    if (it != null) {
      _selectedLeadId = it.leadId;
      _selectedTemplateKey = it.templateKey ?? 'premium-v3';
      _selectedTemplateName = it.templateName ?? 'Premium Tours (Contemporary)';
      _selectedTemplateThumbnail = it.templateThumbnail ?? '';
      _clientNameController.text = it.clientName;
      _clientEmailController.text = it.clientEmail;
      _clientPhoneController.text = it.clientPhoneNo;
      _clientCompanyController.text = it.clientCompany;

      _subjectController.text = it.subject;
      _startDateController.text = _formatDate(it.startDate);
      _noOfDaysController.text = it.noOfDays.toString();
      _adultsController.text = it.adults.toString();
      _roomsController.text = it.rooms.toString();
      _keyLocationsController.text = it.keyLocations.join(', ');

      _heroImageController.text = it.heroImage;
      _shortDescController.text = it.shortDescription;
      _activitiesCostController.text = it.activitiesCost.toString();

      _sections = List.from(it.sections);
      _stays = List.from(it.stays);
      _transports = List.from(it.transports);
      _termsAndConditions = List.from(it.termsAndConditions);

      for (var inc in it.keyInclusions) {
        _inclusionsControllers.add(TextEditingController(text: inc));
      }
      for (var exc in it.keyExclusions) {
        _exclusionsControllers.add(TextEditingController(text: exc));
      }
    } else if (widget.initialTemplateData != null) {
      _populateFromTemplate(widget.initialTemplateData!);
    } else {
      _selectedTemplateKey = 'premium-v3';
      _selectedTemplateName = 'Premium Tours (Contemporary)';
      _selectedTemplateThumbnail = '';
      // Default initial states
      _sections = [
        DayPlan(name: 'Day 1', title: 'Arrival & Welcome', description: 'Welcome to your destination. Check in at hotel and explore local area.', image: '', meals: MealsV2(), notes: ''),
      ];
      _stays = [];
      _transports = [];
      _termsAndConditions = [
        PolicyV2(title: 'Cancellation Policy', description: 'Cancellations made 15 days or more prior to arrival receive a full refund.'),
        PolicyV2(title: 'Terms of Service', description: 'Guests are responsible for any damages incurred to vehicles or hotels.'),
      ];
      _inclusionsControllers.add(TextEditingController(text: 'Complimentary breakfast'));
      _exclusionsControllers.add(TextEditingController(text: 'Personal expenses & shopping'));
    }
    _calculateCosts();
    if (widget.prefilledLead != null) {
      _selectedLeadId = widget.prefilledLead!.id;
      _clientNameController.text = widget.prefilledLead!.name;
      _clientPhoneController.text = widget.prefilledLead!.phoneNo;
      _clientEmailController.text = widget.prefilledLead!.email;
      if (widget.prefilledLead!.company != null && widget.prefilledLead!.company!.isNotEmpty) {
        _clientCompanyController.text = widget.prefilledLead!.company!;
      }
    }
  }

  void _populateFromTemplate(Map<String, dynamic> data) {
    try {
      final templateData = data['exampleData'] as Map<String, dynamic>? ?? data;
      final it = ItineraryV2.fromJson(templateData);
      setState(() {
        _selectedTemplateKey = data['key'] ?? data['id'] ?? it.templateKey ?? 'premium-v3';
        _selectedTemplateName = data['name'] ?? it.templateName ?? 'Premium Tours (Contemporary)';
        _selectedTemplateThumbnail = data['thumbnail'] ?? it.templateThumbnail ?? '';
        
        if (widget.prefilledLead != null) {
          _selectedLeadId = widget.prefilledLead!.id;
          _clientNameController.text = widget.prefilledLead!.name;
          _clientPhoneController.text = widget.prefilledLead!.phoneNo;
          _clientEmailController.text = widget.prefilledLead!.email;
          if (widget.prefilledLead!.company != null && widget.prefilledLead!.company!.isNotEmpty) {
            _clientCompanyController.text = widget.prefilledLead!.company!;
          } else {
            _clientCompanyController.text = '';
          }
        } else {
          if (it.clientName.isNotEmpty) _clientNameController.text = it.clientName;
          if (it.clientEmail.isNotEmpty) _clientEmailController.text = it.clientEmail;
          if (it.clientPhoneNo.isNotEmpty) _clientPhoneController.text = it.clientPhoneNo;
          if (it.clientCompany.isNotEmpty) _clientCompanyController.text = it.clientCompany;
        }

        if (it.subject.isNotEmpty) _subjectController.text = it.subject;
        if (it.startDate.isNotEmpty) _startDateController.text = _formatDate(it.startDate);
        if (it.noOfDays > 0) _noOfDaysController.text = it.noOfDays.toString();
        if (it.adults > 0) _adultsController.text = it.adults.toString();
        if (it.rooms > 0) _roomsController.text = it.rooms.toString();
        if (it.keyLocations.isNotEmpty) _keyLocationsController.text = it.keyLocations.join(', ');
        if (it.heroImage.isNotEmpty) _heroImageController.text = it.heroImage;
        if (it.shortDescription.isNotEmpty) _shortDescController.text = it.shortDescription;
        if (it.activitiesCost > 0) _activitiesCostController.text = it.activitiesCost.toString();

        if (it.sections.isNotEmpty) _sections = List.from(it.sections);
        if (it.stays.isNotEmpty) _stays = List.from(it.stays);
        if (it.transports.isNotEmpty) _transports = List.from(it.transports);
        if (it.termsAndConditions.isNotEmpty) _termsAndConditions = List.from(it.termsAndConditions);

        if (it.keyInclusions.isNotEmpty) {
          _inclusionsControllers.clear();
          for (var inc in it.keyInclusions) {
            _inclusionsControllers.add(TextEditingController(text: inc));
          }
        }
        if (it.keyExclusions.isNotEmpty) {
          _exclusionsControllers.clear();
          for (var exc in it.keyExclusions) {
            _exclusionsControllers.add(TextEditingController(text: exc));
          }
        }
      });
      _calculateCosts();
    } catch (e) {
      debugPrint('Error populating template: $e');
      setState(() {
        _selectedTemplateKey = data['key'] ?? data['id'] ?? 'premium-v3';
        _selectedTemplateName = data['name'] ?? 'Premium Tours (Contemporary)';
        _selectedTemplateThumbnail = data['thumbnail'] ?? '';
        
        _sections = [
          DayPlan(name: 'Day 1', title: 'Arrival & Welcome', description: 'Welcome to your destination. Check in at hotel and explore local area.', image: '', meals: MealsV2(), notes: ''),
        ];
        _stays = [];
        _transports = [];
        _termsAndConditions = [
          PolicyV2(title: 'Cancellation Policy', description: 'Cancellations made 15 days or more prior to arrival receive a full refund.'),
          PolicyV2(title: 'Terms of Service', description: 'Guests are responsible for any damages incurred to vehicles or hotels.'),
        ];
        _inclusionsControllers.add(TextEditingController(text: 'Complimentary breakfast'));
        _exclusionsControllers.add(TextEditingController(text: 'Personal expenses & shopping'));
      });
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {}
    return dateStr;
  }

  void _calculateCosts() {
    double staysSum = 0;
    for (var stay in _stays) {
      staysSum += stay.pricePerNight * stay.noOfNights;
    }

    double transSum = 0;
    for (var trans in _transports) {
      transSum += trans.price;
    }

    double activities = double.tryParse(_activitiesCostController.text) ?? 0.0;

    setState(() {
      staysTotal = staysSum;
      transportsTotal = transSum;
      _totalValue = staysSum + transSum + activities;
    });
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _clientCompanyController.dispose();
    _subjectController.dispose();
    _noOfDaysController.dispose();
    _adultsController.dispose();
    _roomsController.dispose();
    _startDateController.dispose();
    _keyLocationsController.dispose();
    _heroImageController.dispose();
    _shortDescController.dispose();
    _activitiesCostController.dispose();
    for (var ctrl in _inclusionsControllers) {
      ctrl.dispose();
    }
    for (var ctrl in _exclusionsControllers) {
      ctrl.dispose();
    }
    for (var fn in _sectionFocusNodes) {
      fn.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.itinerary != null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6), // slightly darker grey for better contrast with white cards
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          titleSpacing: isMobile ? 8 : 16,
          shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_document, size: 16, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEdit ? 'Edit Itinerary' : 'Craft Itinerary',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: isMobile ? 14 : 16, color: const Color(0xFF111827)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.black87, size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            SizedBox(width: isMobile ? 4 : 12),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 24, vertical: 24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTemplateBadgeSection(),
                          
                          _buildClientAndJourneyDetailsSection(),
                          const SizedBox(height: 24),
                          
                          _buildVisualsAndOverviewSection(),
                          const SizedBox(height: 24),
                          
                          _buildStayAndPricingSection(),
                          const SizedBox(height: 24),
                          
                          _buildDayWisePlanSection(),
                          const SizedBox(height: 24),
                          
                          _buildInclusionsExclusionsSection(),
                          const SizedBox(height: 24),
                          
                          _buildTermsAndPoliciesSection(),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  if (isMobile)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AiItineraryGenerateDialog(),
                          );
                          if (result != null) {
                            _populateFromTemplate(result);
                          }
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                        tooltip: 'AI Generate',
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AiItineraryGenerateDialog(),
                          );
                          if (result != null) {
                            _populateFromTemplate(result);
                          }
                        },
                        icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                        label: const Text(
                          'AUTO GENERATE',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (isMobile)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                      ),
                      child: IconButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF374151)),
                        tooltip: 'Cancel',
                      ),
                    )
                  else
                    OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        foregroundColor: const Color(0xFF374151),
                      ),
                      child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32, vertical: 16),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isMobile 
                                ? (isEdit ? 'SAVE' : 'CREATE') 
                                : (isEdit ? 'SAVE CHANGES' : 'CREATE ITINERARY'), 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
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

  Widget _buildSectionContainer(String title, {required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD1D5DB)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _responsiveRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          final List<Widget> rowChildren = [];
          for (int i = 0; i < children.length; i++) {
            rowChildren.add(Expanded(child: children[i]));
            if (i < children.length - 1) {
              rowChildren.add(const SizedBox(width: 16));
            }
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowChildren);
        }
        final List<Widget> colChildren = [];
        for (int i = 0; i < children.length; i++) {
          colChildren.add(children[i]);
          if (i < children.length - 1) {
            colChildren.add(const SizedBox(height: 16));
          }
        }
        return Column(children: colChildren);
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, int maxLines = 1, TextInputType? keyboardType, Function(String)? onChanged, Widget? suffixIcon, String? hintText, FocusNode? focusNode}) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        alignLabelWithHint: maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
        suffixIcon: suffixIcon,
      ),
      validator: required ? (val) => val == null || val.trim().isEmpty ? '$label is required' : null : null,
      onChanged: onChanged,
    );
  }

  Widget _buildTextFieldWithValue(String label, String initialValue, {bool required = false, int maxLines = 1, TextInputType? keyboardType, Function(String)? onChanged, Widget? suffixIcon, String? hintText, FocusNode? focusNode}) {
    return _StatefulTextField(
      label: label,
      initialValue: initialValue,
      required: required,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      suffixIcon: suffixIcon,
      hintText: hintText,
      focusNode: focusNode,
    );
  }

  // 1. Client & Journey Details
  Widget _buildClientAndJourneyDetailsSection() {
    return _buildSectionContainer(
      'Client & Journey Details',
      child: Column(
        children: [
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
                  initialLead: widget.itinerary?.leadId != null
                      ? Lead(
                    id: widget.itinerary!.leadId!,
                    leadId: '',
                    name: widget.itinerary!.customerName,
                    phoneNo: widget.itinerary!.customerPhone,
                    email: widget.itinerary!.customerEmail,
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
                    _clientCompanyController.text = lead.company!;
                  }
                } else {
                  _selectedLeadId = null;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField('Itinerary Subject / Title', _subjectController, required: true),
          const SizedBox(height: 16),
          _responsiveRow([
            _buildTextField(
              'Journey Start Date',
              _startDateController,
              hintText: 'mm/dd/yyyy',
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                onPressed: () async {
                  DateTime initialDate = DateTime.now();
                  try {
                    if (_startDateController.text.isNotEmpty) {
                      final parts = _startDateController.text.split('/');
                      if (parts.length == 3) {
                        initialDate = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
                      }
                    }
                  } catch (_) {}
                  final date = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    _startDateController.text = "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";
                  }
                },
              ),
            ),
            _buildTextField('Number of Days', _noOfDaysController, required: true, keyboardType: TextInputType.number),
          ]),
          const SizedBox(height: 16),
          _responsiveRow([
            _buildTextField('Customer Name', _clientNameController, required: true),
            _buildTextField('Customer Company', _clientCompanyController),
          ]),
          const SizedBox(height: 16),
          _responsiveRow([
            _buildTextField('Customer Email', _clientEmailController, keyboardType: TextInputType.emailAddress),
            _buildTextField('Customer Phone', _clientPhoneController, keyboardType: TextInputType.phone),
          ]),
          const SizedBox(height: 16),
          _buildTextField('Key Locations (Comma separated)', _keyLocationsController, hintText: 'e.g. Delhi, Jaipur, Agra'),
        ],
      ),
    );
  }

  // 2. Visuals & Overview
  Widget _buildVisualsAndOverviewSection() {
    return _buildSectionContainer(
      'Visuals & Overview',
      child: Column(
        children: [
          HeroImageWidget(
            imageUrl: _heroImageController.text,
            onImageChanged: (url) {
              setState(() => _heroImageController.text = url);
              return null;
            },
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Brief Overview (Short Description)',
            _shortDescController,
            maxLines: 4,
            hintText: '- A more compact yet opulent variant of our signature Heli-Yatra.\n- Designed for the busy executive who values efficiency and fulfillment.\n- Experience the divine quad in record 4 days.\n- Retains the full Premium essence throughout the journey.',
          ),
        ],
      ),
    );
  }

  // 3. Stay & Pricing
  Widget _buildStayAndPricingSection() {
    return _buildSectionContainer(
      'Stay & Pricing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Accommodations / Stays', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              IconButton(
                onPressed: () {
                  setState(() {
                    _stays.add(StayV2(name: '', checkIn: '', checkOut: '', category: '', noOfNights: 1, pricePerNight: 0, image: '', description: ''));
                  });
                  _calculateCosts();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  });
                },
                icon: const Icon(Icons.add, size: 18, color: Colors.black),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _stays.isEmpty
              ? const Text('No accommodations added yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
              : _responsiveRow(
                  _stays.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stay = entry.value;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('HOTEL ${index + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _stays.removeAt(index));
                                  _calculateCosts();
                                },
                                child: const Icon(Icons.delete, size: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextFieldWithValue('Hotel Name', stay.name, onChanged: (val) {
                            _stays[index] = stay.copyWith(name: val);
                          }),
                          const SizedBox(height: 12),
                          _buildTextFieldWithValue('Hotel Details', stay.description, maxLines: 2, onChanged: (val) {
                            _stays[index] = stay.copyWith(description: val);
                          }),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextFieldWithValue('Price Per Night', stay.pricePerNight.toString(), keyboardType: TextInputType.number, onChanged: (val) {
                                  _stays[index] = stay.copyWith(pricePerNight: double.tryParse(val) ?? 0);
                                  _calculateCosts();
                                }),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextFieldWithValue('No of Nights', stay.noOfNights.toString(), keyboardType: TextInputType.number, onChanged: (val) {
                                  _stays[index] = stay.copyWith(noOfNights: int.tryParse(val) ?? 1);
                                  _calculateCosts();
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField('Hotel Details', TextEditingController(text: stay.description), maxLines: 2, onChanged: (val) {
                            _stays[index] = stay.copyWith(description: val);
                          }),
                          const SizedBox(height: 16),
                          ImageUploadWidget(
                            imageUrl: stay.image,
                            onImageChanged: (url) {
                              _stays[index] = stay.copyWith(image: url);
                              return null;
                            },
                            label: 'Upload Hotel Image',
                            height: 120,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transportation & Flights', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              IconButton(
                onPressed: () {
                  setState(() {
                    _transports.add(TransportV2(type: '', details: '', price: 0));
                  });
                  _calculateCosts();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  });
                },
                icon: const Icon(Icons.add, size: 18, color: Colors.black),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _transports.isEmpty
              ? const Text('No transport added yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
              : _responsiveRow(
                  _transports.asMap().entries.map((entry) {
                    final index = entry.key;
                    final trans = entry.value;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TRANSPORT ${index + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _transports.removeAt(index));
                                  _calculateCosts();
                                },
                                child: const Icon(Icons.delete, size: 16, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField('Type (e.g. Flight/Train/Bus)', TextEditingController(text: trans.type), onChanged: (val) {
                            _transports[index] = trans.copyWith(type: val);
                          }),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildTextFieldWithValue('Details (e.g. UK-123 | 10:00 AM)', trans.details, onChanged: (val) {
                                  _transports[index] = trans.copyWith(details: val);
                                }),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: _buildTextFieldWithValue('Price', trans.price.toString(), keyboardType: TextInputType.number, onChanged: (val) {
                                  _transports[index] = trans.copyWith(price: double.tryParse(val) ?? 0);
                                  _calculateCosts();
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 24),
          SizedBox(
            width: 250,
            child: _buildTextField('Activities Cost', _activitiesCostController, keyboardType: TextInputType.number, onChanged: (val) => _calculateCosts()),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          // Financial Summary Table
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _buildSummaryRow('Activities Cost:', double.tryParse(_activitiesCostController.text) ?? 0),
                ..._stays.map((stay) => _buildSummaryRow('${stay.name.isEmpty ? "Stay" : stay.name} Cost (${stay.noOfNights} Nights):', stay.pricePerNight * stay.noOfNights)),
                ..._transports.map((trans) => _buildSummaryRow('${trans.type.isEmpty ? "Transport" : trans.type} Cost:', trans.price)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFD1D5DB))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Net Price:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    Text('₹${NumberFormat('#,##,###').format(_totalValue)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _responsiveRow([
            _buildTextField('Total Number of Adults', _adultsController, keyboardType: TextInputType.number, onChanged: (val) => setState(() {})),
            _buildTextField(
              'Price Per Adult (Investment)',
              TextEditingController(text: '₹${NumberFormat('#,##,###').format(_totalValue / (int.tryParse(_adultsController.text) ?? 2))}'),
            ),
            _buildTextField('Total Rooms Required', _roomsController, keyboardType: TextInputType.number),
          ]),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          Text('₹${NumberFormat('#,##,###').format(amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  // 4. Day-wise Plan
  Widget _buildDayWisePlanSection() {
    return _buildSectionContainer(
      'Day-wise Plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  final fn = FocusNode();
                  setState(() {
                    _sectionFocusNodes.add(fn);
                    _sections.add(DayPlan(name: 'Day ${_sections.length + 1}', title: 'Day ${_sections.length + 1}', description: '', image: '', meals: MealsV2(), notes: ''));
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                    fn.requestFocus();
                  });
                },
                icon: const Icon(Icons.add, size: 14, color: Colors.black),
                label: const Text('ADD DAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_sections.length, (index) {
            final sec = _sections[index];
            final fn = index < _sectionFocusNodes.length ? _sectionFocusNodes[index] : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DAY ${index + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (index < _sectionFocusNodes.length) {
                              _sectionFocusNodes[index].dispose();
                              _sectionFocusNodes.removeAt(index);
                            }
                            _sections.removeAt(index);
                          });
                        },
                        child: const Icon(Icons.delete, size: 16, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextFieldWithValue('Day Title (e.g. Arrival & Check-in)', sec.title, focusNode: fn, onChanged: (val) {
                    _sections[index] = sec.copyWith(title: val, name: val);
                  }),
                  const SizedBox(height: 12),
                  _buildTextFieldWithValue('Experience Details', sec.description, maxLines: 4, onChanged: (val) {
                    _sections[index] = sec.copyWith(description: val);
                  }),
                  const SizedBox(height: 16),
                  ImageUploadWidget(
                    imageUrl: sec.image,
                    onImageChanged: (url) {
                      setState(() {
                        _sections[index] = sec.copyWith(image: url);
                      });
                      return null;
                    },
                    label: 'Upload Day Image',
                    height: 140,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 5. Inclusions & Exclusions
  Widget _buildInclusionsExclusionsSection() {
    return _buildSectionContainer(
      'Inclusions & Exclusions',
      child: _responsiveRow([
        // Inclusions
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('INCLUSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _inclusionsControllers.add(TextEditingController()));
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                  },
                  icon: const Icon(Icons.add, size: 14, color: Colors.black),
                  label: const Text('ADD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_inclusionsControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: _buildTextField('', _inclusionsControllers[index])),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _inclusionsControllers.removeAt(index)),
                      child: const Icon(Icons.delete, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        // Exclusions
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('EXCLUSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _exclusionsControllers.add(TextEditingController()));
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                  },
                  icon: const Icon(Icons.add, size: 14, color: Colors.black),
                  label: const Text('ADD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_exclusionsControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: _buildTextField('', _exclusionsControllers[index])),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _exclusionsControllers.removeAt(index)),
                      child: const Icon(Icons.delete, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ]),
    );
  }

  // 6. Terms & Policies
  Widget _buildTermsAndPoliciesSection() {
    return _buildSectionContainer(
      'Terms & Policies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _termsAndConditions.add(PolicyV2(title: '', description: ''));
                  });
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  });
                },
                icon: const Icon(Icons.add, size: 14, color: Colors.black),
                label: const Text('ADD POLICY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _responsiveRow(
            _termsAndConditions.asMap().entries.map((entry) {
              final index = entry.key;
              final policy = entry.value;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('POLICY ${index + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        GestureDetector(
                          onTap: () => setState(() => _termsAndConditions.removeAt(index)),
                          child: const Icon(Icons.delete, size: 16, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('Policy Title', TextEditingController(text: policy.title), onChanged: (val) {
                      _termsAndConditions[index] = policy.copyWith(title: val);
                    }),
                    const SizedBox(height: 12),
                    _buildTextField('Policy Terms', TextEditingController(text: policy.description), maxLines: 4, onChanged: (val) {
                      _termsAndConditions[index] = policy.copyWith(description: val);
                    }),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final List<String> keyInclusions = _inclusionsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    final List<String> keyExclusions = _exclusionsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    final List<String> keyLocations = _keyLocationsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final data = {
      'lead': _selectedLeadId,
      'customerName': _clientNameController.text.trim(),
      'customerCompany': _clientCompanyController.text.trim(),
      'customerEmail': _clientEmailController.text.trim(),
      'customerPhone': _clientPhoneController.text.trim(),
      'subject': _subjectController.text.trim(),
      'startDate': _startDateController.text.trim(),
      'noOfDays': int.tryParse(_noOfDaysController.text) ?? 3,
      'adults': int.tryParse(_adultsController.text) ?? 2,
      'rooms': int.tryParse(_roomsController.text) ?? 1,
      'heroImage': _heroImageController.text.trim(),
      'shortDescription': _shortDescController.text.trim(),
      'sections': _sections.map((s) => s.toJson()).toList(),
      'keyInclusions': keyInclusions,
      'keyExclusions': keyExclusions,
      'keyLocations': keyLocations,
      'stays': _stays.map((s) => s.toJson()).toList(),
      'transports': _transports.map((t) => t.toJson()).toList(),
      'termsAndConditions': _termsAndConditions.map((p) => p.toJson()).toList(),
      'activitiesCost': double.tryParse(_activitiesCostController.text) ?? 0.0,
      'totalPrice': _totalValue,
      'pricePerAdult': _totalValue / (int.tryParse(_adultsController.text) ?? 2),
      'templateKey': _selectedTemplateKey,
      'templateName': _selectedTemplateName,
      'templateThumbnail': _selectedTemplateThumbnail,
    };

    final isEdit = widget.itinerary != null;
    try {
      if (isEdit) {
        await ref.read(itineraryV2Provider.notifier).updateItinerary(widget.itinerary!.id, data);
      } else {
        await ref.read(itineraryV2Provider.notifier).createItinerary(data);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTemplateBadgeSection() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              image: (_selectedTemplateThumbnail != null && _selectedTemplateThumbnail!.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(_selectedTemplateThumbnail!), fit: BoxFit.cover)
                  : null,
            ),
            child: (_selectedTemplateThumbnail == null || _selectedTemplateThumbnail!.isEmpty)
                ? const Icon(Icons.style_outlined, color: Colors.grey, size: 28)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECTED TEMPLATE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedTemplateName ?? 'No Template Selected',
                  style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
          ),
          SizedBox(width: isMobile ? 8 : 16),
          isMobile
              ? Container(
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                  child: IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white, size: 18),
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ItineraryTemplateGalleryDialog(
                          onSelect: (template) => _populateFromTemplate(template),
                        ),
                      );
                    },
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ItineraryTemplateGalleryDialog(
                        onSelect: (template) => _populateFromTemplate(template),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync, size: 14, color: Colors.white),
                  label: const Text('Change Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatefulTextField extends StatefulWidget {
  final String label;
  final String initialValue;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;
  final Widget? suffixIcon;
  final String? hintText;
  final FocusNode? focusNode;

  const _StatefulTextField({
    required this.label,
    required this.initialValue,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.suffixIcon,
    this.hintText,
    this.focusNode,
  });

  @override
  State<_StatefulTextField> createState() => _StatefulTextFieldState();
}

class _StatefulTextFieldState extends State<_StatefulTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_StatefulTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      // Don't overwrite user's active typing.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: widget.focusNode,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        alignLabelWithHint: widget.maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.5)),
        suffixIcon: widget.suffixIcon,
      ),
      validator: widget.required
          ? (val) => val == null || val.trim().isEmpty
              ? '${widget.label} is required'
              : null
          : null,
      onChanged: widget.onChanged,
    );
  }
}

