import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/itinerary_model.dart';

class SimpleItineraryCard extends StatelessWidget {
  final ItineraryV2 itinerary;
  final VoidCallback? onDownload;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onView;
  final VoidCallback? onShare;
  final VoidCallback? onViewLead;
  final VoidCallback? onGenerateQuote;
  final bool isCopying;

  const SimpleItineraryCard({
    super.key,
    required this.itinerary,
    this.onDownload,
    this.onEdit,
    this.onCopy,
    this.onDelete,
    this.onView,
    this.onShare,
    this.onViewLead,
    this.onGenerateQuote,
    this.isCopying = false,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,##,###');
    final created = DateFormat('dd/MM/yyyy').format(
      DateTime.tryParse(itinerary.createdAt) ?? DateTime.now(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itinerary.subject.isNotEmpty ? itinerary.subject : 'Unnamed Journey',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  itinerary.clientName.isNotEmpty ? itinerary.clientName : 'N/A',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    itinerary.templateName ?? 'Contemporary Style',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                if (itinerary.quotationId != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description, size: 10, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Quoted',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${itinerary.noOfDays} Days', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Text(
                  '\u20B9${format.format(itinerary.totalPrice)}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  'Created: $created',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (onDownload != null)
                  _toolbarButton(Icons.download_outlined, onDownload!),
                const SizedBox(width: 8),
                if (onEdit != null)
                  _toolbarButton(Icons.edit_outlined, onEdit!),
                const SizedBox(width: 8),
                if (onCopy != null)
                   isCopying 
                    ? const SizedBox(width: 36, height: 36, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)))
                    : _toolbarButton(Icons.copy_outlined, onCopy!),
                const SizedBox(width: 8),
                if (onGenerateQuote != null)
                  _toolbarButton(Icons.request_quote, onGenerateQuote!, color: Colors.blue[700]!),
                const SizedBox(width: 8),
                if (onDelete != null)
                  _toolbarButton(Icons.delete_outline, onDelete!, color: Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (onView != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onView,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('View', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (onView != null && onViewLead != null) const SizedBox(width: 8),
                if (onViewLead != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onViewLead,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('View Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if ((onView != null || onViewLead != null) && onShare != null) const SizedBox(width: 8),
                if (onShare != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onShare,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, VoidCallback onPressed, {Color color = Colors.black}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: color),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
