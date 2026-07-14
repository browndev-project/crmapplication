import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';
import '../screens/whatsapp/whatsapp_share_screen.dart';
import '../screens/whatsapp/widgets/whatsapp_icon.dart';

class ProjectShareDialog extends ConsumerStatefulWidget {
  final Project project;

  const ProjectShareDialog({super.key, required this.project});

  @override
  ConsumerState<ProjectShareDialog> createState() => _ProjectShareDialogState();
}

class _ProjectShareDialogState extends ConsumerState<ProjectShareDialog> {
  String? _shareMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateMessage();
  }

  Future<void> _generateMessage() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(propertyProvider.notifier).generateProjectShareMessage(widget.project.id);
      if (mounted) {
        setState(() {
          _shareMessage = data['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating message: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyToClipboard() {
    if (_shareMessage == null) return;
    Clipboard.setData(ClipboardData(text: _shareMessage!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendWhatsApp() {
    if (_shareMessage == null) return;
    
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WhatsAppShareScreen(
          initialMessage: _shareMessage!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share Project',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.project.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _isLoading
                              ? const LinearProgressIndicator(minHeight: 2)
                              : SingleChildScrollView(
                                  child: Text(
                                    _shareMessage ?? 'Generating message...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading || _shareMessage == null ? null : _copyToClipboard,
                  icon: const Icon(Icons.copy, size: 14, color: Colors.black),
                  label: const Text('Copy Text', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading || _shareMessage == null ? null : _sendWhatsApp,
                  icon: whatsAppIcon(size: 14, color: Colors.white),
                  label: const Text('Share on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
