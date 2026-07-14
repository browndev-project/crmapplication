import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/invoice_model.dart';
import '../screens/lead_profile_screen.dart';

import '../../core/utils/date_utils.dart';

class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback? onView;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onStatusChanged;

  const InvoiceCard({
    super.key,
    required this.invoice,
    this.onView,
    this.onShare,
    this.onDownload,
    this.onEdit,
    this.onDelete,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statusColor = _getStatusColor(invoice.status);
    final statusBg = statusColor.withValues(alpha: 0.1);

    final isPaidOrCancelled = invoice.status.toUpperCase() == 'PAID' || invoice.status.toUpperCase() == 'CANCELLED';
    bool isOverdue = false;
    if (!isPaidOrCancelled) {
      try {
        final due = DateTimeUtils.parseSafe(invoice.dueDate);
        if (due != null) {
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final dueDateOnly = DateTime(due.year, due.month, due.day);
          isOverdue = dueDateOnly.isBefore(todayDate);
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${invoice.invoiceNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onStatusChanged == null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(invoice.status), size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            invoice.status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : PopupMenuButton<String>(
                      tooltip: 'Change Status',
                      onSelected: onStatusChanged,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      color: isDark ? const Color(0xFF1E2130) : Colors.white,
                      itemBuilder: (context) {
                        return ['DRAFT', 'CREATED', 'SENT', 'PAID', 'CANCELLED'].map((status) {
                          final isCurrent = status.toUpperCase() == invoice.status.toUpperCase();
                          final col = _getStatusColor(status);
                          return PopupMenuItem<String>(
                            value: status,
                            child: Row(
                              children: [
                                Icon(_getStatusIcon(status), size: 16, color: col),
                                const SizedBox(width: 8),
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: col,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (isCurrent)
                                  Icon(Icons.check, size: 16, color: col),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getStatusIcon(invoice.status), size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              invoice.status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_outlined, size: 12, color: statusColor),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 8),

          // Subject
          if (invoice.subject != null && invoice.subject!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                invoice.subject!,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Client Phone
          Text(
            invoice.clientPhoneNo,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          // Client Details Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, size: 16, color: Colors.black),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.clientName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      '@${invoice.clientCompany}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dates
          Row(
            children: [
              Expanded(child: _buildDateCol('DATE', invoice.invoiceDate, theme)),
              Expanded(child: _buildDateCol('DUE', invoice.dueDate, theme, dateColor: isOverdue ? Colors.red : null)),
            ],
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          const SizedBox(height: 16),

          // Footer: Total and Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    Text(
                      '₹${NumberFormat('#,##,###.##').format(invoice.grandTotal)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDownload != null) ...[
                    _buildIconButton(Icons.download_outlined, onDownload, theme),
                    const SizedBox(width: 6),
                  ],
                  if (onEdit != null) ...[
                    _buildIconButton(Icons.edit_outlined, onEdit, theme),
                    const SizedBox(width: 6),
                  ],
                  if (onDelete != null)
                    _buildIconButton(Icons.delete_outline, onDelete, theme, color: Colors.red),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons: View Details, View Lead, and Share
          Row(
            children: [
              if (onView != null)
                Expanded(
                  child: InkWell(
                    onTap: onView,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'View Details',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (invoice.leadId != null)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LeadProfileScreen(leadId: invoice.leadId!)),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'View Lead',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              if (onView != null && onShare != null) const SizedBox(width: 8),
              if (onShare != null)
                Expanded(
                  child: InkWell(
                    onTap: onShare,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Share',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateCol(String label, String dateStr, ThemeData theme, {Color? dateColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          DateTimeUtils.formatSafe(dateStr, format: 'dd MMM yyyy'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: dateColor ?? theme.textTheme.bodyLarge?.color),
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback? onTap, ThemeData theme, {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? Colors.black).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color ?? Colors.black),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'CREATED':
      case 'DRAFT':
        return const Color(0xFF6366F1); // Indigo
      case 'SENT':
        return const Color(0xFF3B82F6); // Blue
      case 'PAID':
      case 'COMPLETED':
      case 'ACCEPTED':
        return const Color(0xFF10B981); // Green
      case 'PARTIALLY_PAID':
        return const Color(0xFFF59E0B); // Amber
      case 'OVERDUE':
      case 'EXPIRED':
      case 'CANCELLED':
      case 'REJECTED':
        return const Color(0xFFEF4444); // Red
      case 'CONFIRMED':
        return const Color(0xFF06B6D4); // Cyan
      case 'REFUNDED':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF64748B); // Slate/Grey
    }
  }

  IconData _getStatusIcon(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'DRAFT':
        return Icons.edit_note;
      case 'CREATED':
        return Icons.add_circle_outline;
      case 'SENT':
        return Icons.send_outlined;
      case 'PAID':
      case 'COMPLETED':
      case 'ACCEPTED':
        return Icons.check_circle_outline;
      case 'PARTIALLY_PAID':
        return Icons.pending_outlined;
      case 'OVERDUE':
      case 'EXPIRED':
        return Icons.history_outlined;
      case 'CANCELLED':
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'CONFIRMED':
        return Icons.verified_outlined;
      case 'REFUNDED':
        return Icons.keyboard_return_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
