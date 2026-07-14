import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/lead_model.dart';
import '../screens/marketing/widgets/send_email_dialog.dart';
import '../providers/invoice_provider.dart';
import '../screens/whatsapp/whatsapp_share_screen.dart';

class InvoiceShareDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final Lead? lead;

  const InvoiceShareDialog({super.key, required this.invoice, this.lead});

  @override
  ConsumerState<InvoiceShareDialog> createState() => _InvoiceShareDialogState();
}

class _InvoiceShareDialogState extends ConsumerState<InvoiceShareDialog> {
  String? _invoiceLink;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _invoiceLink = widget.invoice.invoiceLink;
    if (_invoiceLink == null) {
      _generateLink();
    }
  }

  Future<void> _generateLink() async {
    setState(() => _isLoading = true);
    try {
      final link = await ref.read(invoicesProvider.notifier).generateShareLink(widget.invoice.id);
      if (mounted) {
        setState(() {
          _invoiceLink = link;
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
    if (_invoiceLink == null) return;
    Clipboard.setData(ClipboardData(text: _invoiceLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendWhatsApp() async {
    if (_invoiceLink == null) return;
    
    setState(() => _isLoading = true);
    try {
      final message = await ref.read(invoicesProvider.notifier).getShareMessage(widget.invoice.id);
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
        final fallbackMessage = "Dear ${widget.invoice.clientName},\n\nPlease find your invoice (INV-${widget.invoice.invoiceNumber}) here:\n$_invoiceLink\n\nThank you,\nAlpha Tech";
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
    if (_invoiceLink == null) return;

    // Create a mock Lead object for the SendEmailDialog, or use the provided lead
    final recipient = widget.lead ?? Lead(
      id: widget.invoice.leadId ?? '',
      leadId: 'L-INV-${widget.invoice.invoiceNumber}', // Mock display ID
      name: widget.invoice.clientName,
      email: widget.invoice.clientEmail,
      phoneNo: widget.invoice.clientPhoneNo,
      company: widget.invoice.clientCompany,
      status: 'Invoiced',
      source: 'Invoice',
      pipeline: 'Active',
      description: 'Mock lead for invoice sharing',
      amount: widget.invoice.grandTotal,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => SendEmailDialog(
        recipients: [recipient],
        initialSubject: 'Invoice INV-${widget.invoice.invoiceNumber}',
        initialBody: 'Dear ${widget.invoice.clientName},\n\nPlease find your invoice INV-${widget.invoice.invoiceNumber} here: $_invoiceLink\n\nRegards,\nTrevion CRM',
      ),
    );
    
    // Note: We might want to pass pre-filled body here if SendEmailDialog supported it.
    // For now, it opens the existing dialog.
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
                  'Share Invoice',
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
                          'Invoice: INV-${widget.invoice.invoiceNumber}',
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
                                  _invoiceLink ?? 'Generating link...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        if (!_isLoading && _invoiceLink != null)
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
                    onPressed: _isLoading || _invoiceLink == null ? null : _sendWhatsApp,
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
                    onPressed: _isLoading || _invoiceLink == null ? null : _sendEmail,
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
