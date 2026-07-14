import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/itinerary_model.dart';
import '../../data/models/lead_model.dart';
import '../screens/marketing/widgets/send_email_dialog.dart';
import '../providers/itinerary_provider.dart';
import '../screens/whatsapp/whatsapp_share_screen.dart';

class ItineraryShareDialog extends ConsumerStatefulWidget {
  final ItineraryV2 itinerary;
  final Lead? lead;

  const ItineraryShareDialog({super.key, required this.itinerary, this.lead});

  @override
  ConsumerState<ItineraryShareDialog> createState() => _ItineraryShareDialogState();
}

class _ItineraryShareDialogState extends ConsumerState<ItineraryShareDialog> {
  String? _shareLink;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateLink();
  }

  Future<void> _generateLink() async {
    setState(() => _isLoading = true);
    try {
      final link = await ref.read(itineraryV2Provider.notifier).generatePdfUrl(widget.itinerary.id);
      if (mounted) {
        setState(() {
          _shareLink = link;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating link: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyToClipboard() {
    if (_shareLink == null) return;
    Clipboard.setData(ClipboardData(text: _shareLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendWhatsApp() async {
    if (_shareLink == null) return;
    
    setState(() => _isLoading = true);
    try {
      final message = await ref.read(itineraryV2Provider.notifier).getShareMessage(widget.itinerary.id);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WhatsAppShareScreen(
              initialMessage: message,
              preselectedLead: widget.lead,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final fallbackMessage = "Dear ${widget.itinerary.clientName},\n\nPlease review your planned itinerary (${widget.itinerary.subject}) here:\n$_shareLink\n\nThank you,\nAlpha Tech";
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WhatsAppShareScreen(
              initialMessage: fallbackMessage,
              preselectedLead: widget.lead,
            ),
          ),
        );
      }
    }
  }

  void _sendEmail() {
    if (_shareLink == null) return;

    // Create a mock Lead object for the SendEmailDialog, or use the provided lead
    final recipient = widget.lead ?? Lead(
      id: '',
      leadId: 'IT-${widget.itinerary.id.hashCode}',
      name: widget.itinerary.clientName,
      email: widget.itinerary.clientEmail,
      phoneNo: widget.itinerary.clientPhoneNo,
      company: widget.itinerary.clientCompany,
      status: 'Proposed',
      source: 'Itinerary',
      pipeline: 'Active',
      description: 'Mock lead for itinerary sharing',
      amount: widget.itinerary.totalPrice,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => SendEmailDialog(
        recipients: [recipient],
        initialSubject: 'Travel Plan Itinerary: ${widget.itinerary.subject}',
        initialBody: 'Dear ${widget.itinerary.clientName},\n\nPlease review your planned itinerary ${widget.itinerary.subject} here:\n$_shareLink\n\nRegards,\nTrevion CRM',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  'Share Itinerary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route_outlined, size: 18, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.itinerary.subject,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _isLoading
                              ? const LinearProgressIndicator(minHeight: 2)
                              : Text(
                                  _shareLink ?? 'Generating link...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        if (!_isLoading && _shareLink != null)
                          InkWell(
                            onTap: _copyToClipboard,
                            child: const Icon(Icons.copy_rounded, size: 18, color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || _shareLink == null ? null : _sendWhatsApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: const Text('Send WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || _shareLink == null ? null : _sendEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: const Text('Send Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
