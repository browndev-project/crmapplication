import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/voucher_model.dart';
import '../../data/models/lead_model.dart';
import '../screens/marketing/widgets/send_email_dialog.dart';
import '../providers/voucher_provider.dart';
import '../screens/whatsapp/whatsapp_share_screen.dart';

class VoucherShareDialog extends ConsumerStatefulWidget {
  final Voucher voucher;
  final Lead? lead;

  const VoucherShareDialog({super.key, required this.voucher, this.lead});

  @override
  ConsumerState<VoucherShareDialog> createState() => _VoucherShareDialogState();
}

class _VoucherShareDialogState extends ConsumerState<VoucherShareDialog> {
  String? _voucherLink;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _voucherLink = widget.voucher.voucherLink;
    if (_voucherLink == null) {
      _generateLink();
    }
  }

  Future<void> _generateLink() async {
    setState(() => _isLoading = true);
    try {
      final link = await ref.read(vouchersProvider.notifier).generateShareLink(widget.voucher.id);
      if (mounted) {
        setState(() {
          _voucherLink = link;
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
    if (_voucherLink == null) return;
    Clipboard.setData(ClipboardData(text: _voucherLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendWhatsApp() async {
    if (_voucherLink == null) return;
    
    setState(() => _isLoading = true);
    try {
      final message = await ref.read(vouchersProvider.notifier).getShareMessage(widget.voucher.id);
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
        final fallbackMessage = "Dear ${widget.voucher.clientName},\n\nPlease find your voucher (${widget.voucher.voucherNo}) here:\n$_voucherLink\n\nThank you,\nAlpha Tech";
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
    if (_voucherLink == null) return;

    // Create a mock Lead object for the SendEmailDialog, or use the provided lead
    final recipient = widget.lead ?? Lead(
      id: '',
      leadId: 'V-${widget.voucher.voucherNo}',
      name: widget.voucher.clientName,
      email: widget.voucher.clientEmail,
      phoneNo: widget.voucher.clientPhone,
      company: '',
      status: 'Issued',
      source: 'Voucher',
      pipeline: 'Active',
      description: 'Mock lead for voucher sharing',
      amount: widget.voucher.financials.totalAmount,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => SendEmailDialog(
        recipients: [recipient],
        initialSubject: 'Voucher ${widget.voucher.voucherNo}',
        initialBody: 'Dear ${widget.voucher.clientName},\n\nPlease find your voucher ${widget.voucher.voucherNo} here: $_voucherLink\n\nRegards,\nTrevion CRM',
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
                  'Share Voucher',
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
                      const Icon(Icons.description_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Voucher: ${widget.voucher.voucherNo}',
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
                    child: Row(
                      children: [
                        Expanded(
                          child: _isLoading
                              ? const LinearProgressIndicator(minHeight: 2)
                              : Text(
                                  _voucherLink ?? 'Generating link...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        if (!_isLoading && _voucherLink != null)
                          InkWell(
                            onTap: _copyToClipboard,
                            child: const Icon(Icons.copy_rounded, size: 18),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || _voucherLink == null ? null : _sendWhatsApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      elevation: 0,
                    ),
                    child: const Text('Send WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || _voucherLink == null ? null : _sendEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      elevation: 0,
                    ),
                    child: const Text('Send Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
