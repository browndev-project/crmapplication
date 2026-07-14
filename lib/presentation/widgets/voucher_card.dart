import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/voucher_model.dart';
import '../screens/lead_profile_screen.dart';

import '../../core/utils/date_utils.dart';

class VoucherCard extends StatelessWidget {
  final Voucher voucher;
  final VoidCallback? onView;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VoucherCard({
    super.key,
    required this.voucher,
    this.onView,
    this.onShare,
    this.onDownload,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          // Header: ID and Voucher Type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '#${voucher.voucherNo}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      voucher.voucherType,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 8),

          // Client Phone
          Text(
            voucher.clientPhone,
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
                child: const Icon(Icons.person, size: 16, color: Colors.black),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.clientName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      voucher.clientEmail,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (voucher.voucherType == 'HOTEL' && voucher.hotelDetails != null && (voucher.hotelDetails!.imageUrl.isNotEmpty || voucher.hotelDetails!.name.isNotEmpty)) ...[
            const SizedBox(height: 12),
            if (voucher.hotelDetails!.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  voucher.hotelDetails!.imageUrl,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (voucher.hotelDetails!.name.isNotEmpty)
              Text(
                voucher.hotelDetails!.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            if (voucher.hotelDetails!.address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                voucher.hotelDetails!.address,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ],
          const SizedBox(height: 16),

          // Dates / Info
          Row(
            children: [
              Expanded(child: _buildDateCol('VOUCHER DATE', voucher.voucherDate, theme)),
              if (voucher.voucherType == 'HOTEL')
                Expanded(child: _buildInfoCol('NO OF ROOMS', '${voucher.noOfRooms ?? 0}', theme))
              else
                Expanded(child: _buildInfoCol('TOTAL KMS', '${voucher.travelTotalKms ?? 0}', theme)),
            ],
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          const SizedBox(height: 16),

          // Footer: Total Amount, Balance on the left; Action Buttons on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '₹${NumberFormat('#,##,###.##').format(voucher.financials.totalAmount)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance',
                            style: TextStyle(color: Colors.red[400], fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '₹${NumberFormat('#,##,###.##').format(voucher.financials.balanceAmount)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDownload != null) ...[
                    _buildIconButton(Icons.download_outlined, onDownload, theme),
                    const SizedBox(width: 6),
                  ],
                  if (onEdit != null && voucher.status.toUpperCase() != 'CANCELLED') ...[
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

          // View Details, View Lead, and Share row (equally sized)
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
              if (voucher.leadId != null)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LeadProfileScreen(leadId: voucher.leadId!)),
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

  Widget _buildInfoCol(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.textTheme.bodyLarge?.color),
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

}
