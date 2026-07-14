import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/quotation_model.dart';
import '../providers/quotation_provider.dart';
import 'quotation_share_dialog.dart';
import 'quotation_create_dialog.dart';
import '../../core/utils/document_launcher.dart';
import '../screens/quotation_detail_screen.dart';
import 'itinerary_explorer_dialog.dart';
import '../screens/lead_profile_screen.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/login_provider.dart';

import '../../core/utils/date_utils.dart';

class QuotationCard extends ConsumerWidget {
  final Quotation quotation;
  const QuotationCard({super.key, required this.quotation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final isAcceptedOrCancelled = quotation.status.toUpperCase() == 'ACCEPTED' || quotation.status.toUpperCase() == 'APPROVED' || quotation.status.toUpperCase() == 'CANCELLED';
    bool isOverdue = false;
    if (!isAcceptedOrCancelled) {
      try {
        final valid = DateTimeUtils.parseSafe(quotation.validUntil);
        if (valid != null) {
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final validDateOnly = DateTime(valid.year, valid.month, valid.day);
          isOverdue = validDateOnly.isBefore(todayDate);
        }
      } catch (_) {}
    }

    final statusColor = _getStatusColor(quotation.status);
    final statusBg = statusColor.withValues(alpha: 0.1);

    final canEdit = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.QUOTATION_UPDATE, userRole: userRole) && quotation.status.toUpperCase() != 'CANCELLED';
    final canDelete = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.QUOTATION_DELETE, userRole: userRole);
    final canDownload = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.QUOTATION_DOWNLOAD, userRole: userRole);
    final canShare = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.QUOTATION_SEND, userRole: userRole);
    final canView = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.QUOTATION_VIEW, userRole: userRole);
    final canViewItinerary = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_VIEW, userRole: userRole);

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
          // Header: Number and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${quotation.quotationNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(quotation.status), size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      quotation.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Client Phone
          if (quotation.subject.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                quotation.subject,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Text(
            quotation.clientPhoneNo.isNotEmpty ? quotation.clientPhoneNo : '- No Phone -',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          // Client Details Row (Avatar)
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
                      quotation.clientName.isNotEmpty ? quotation.clientName : '- No Name -',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      quotation.clientCompany.isNotEmpty ? '@${quotation.clientCompany}' : '- No Company -',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dates Row
          Row(
            children: [
              Expanded(child: _buildDateCol('DATE', quotation.quotationDate, theme)),
              Expanded(child: _buildDateCol('VALID UNTIL', quotation.validUntil, theme, dateColor: isOverdue ? Colors.red : null)),
            ],
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          const SizedBox(height: 16),

          // Footer: Grand Total and Icons Actions
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
                      '₹${NumberFormat('#,##,###.##').format(quotation.grandTotal)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canDownload) ...[
                    _buildIconButton(Icons.download_outlined, () {
                      DocumentLauncher.launchDocument(
                        context: context,
                        urlFetcher: () => ref.read(quotationsProvider.notifier).getShareLink(quotation.id),
                        loadingMessage: 'Opening quotation...',
                      );
                    }, theme),
                    const SizedBox(width: 6),
                  ],
                  if (canEdit) ...[
                    _buildIconButton(Icons.edit_outlined, () {
                      showDialog(
                        context: context,
                        builder: (context) => QuotationCreateDialog(quotation: quotation),
                      );
                    }, theme),
                    const SizedBox(width: 6),
                  ],
                  if (quotation.itineraryId != null && canViewItinerary) ...[
                    _buildIconButton(Icons.route_outlined, () {
                      showDialog(
                        context: context,
                        builder: (context) => ItineraryExplorerDialog(itineraryId: quotation.itineraryId!),
                      );
                    }, theme, color: Colors.blue),
                    const SizedBox(width: 6),
                  ],
                  if (canDelete)
                    _buildIconButton(Icons.delete_outline, () => _showDeleteConfirm(context, ref), theme, color: Colors.red),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Actions Row: View Details, View Lead, and Share
          Row(
            children: [
              if (canView)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuotationDetailScreen(quotationId: quotation.id),
                        ),
                      );
                    },
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
              if (quotation.leadId != null)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LeadProfileScreen(leadId: quotation.leadId!)),
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
              if (canView && canShare) const SizedBox(width: 8),
              if (canShare)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => QuotationShareDialog(quotation: quotation),
                      );
                    },
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
      case 'APPROVED':
        return const Color(0xFF10B981); // Green
      case 'PARTIALLY_PAID':
      case 'PENDING':
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
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'PARTIALLY_PAID':
      case 'PENDING':
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

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (sbContext, setState) {
            return AlertDialog(
              title: const Text('Delete Quotation'),
              content: isDeleting
                  ? const Row(
                      children: [
                        CircularProgressIndicator(color: Colors.black),
                        SizedBox(width: 16),
                        Text('Deleting quotation...'),
                      ],
                    )
                  : const Text('Are you sure you want to delete this quotation?'),
              actions: isDeleting
                  ? null
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                      ),
                      TextButton(
                        onPressed: () async {
                          setState(() {
                            isDeleting = true;
                          });
                          try {
                            await ref.read(quotationsProvider.notifier).deleteQuotation(quotation.id);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Quotation deleted successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setState(() {
                                isDeleting = false;
                              });
                              // Show user-friendly error dialog rather than silent failure
                              showDialog(
                                context: context,
                                builder: (errCtx) => AlertDialog(
                                  title: const Text('Error Deleting Quotation'),
                                  content: Text(e.toString()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(errCtx),
                                      child: const Text('OK', style: TextStyle(color: Colors.black)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}
