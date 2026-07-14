import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';
import '../widgets/invoice_share_dialog.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../../core/utils/document_launcher.dart';
import '../providers/login_provider.dart';
import '../widgets/access_denied_widget.dart';

import '../../core/utils/date_utils.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  final Invoice? initialInvoice;

  const InvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    this.initialInvoice,
  });

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasFetched) {
        _hasFetched = true;
        ref.read(invoiceDetailProvider.notifier).fetchDetails(widget.invoiceId);
      }
    });
  }
  
  Invoice? get invoice => ref.watch(invoiceDetailProvider).invoice;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceDetailProvider);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;
    final currentInvoice = invoice;

    if (!permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_VIEW, userRole: userRole)) {
      return const AccessDeniedWidget(
        sectionName: "Invoice Details",
        showAppBar: true,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentInvoice?.category != null && currentInvoice!.category!.isNotEmpty)
              Text(
                currentInvoice.category!.toUpperCase(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            Text(
              'Invoice #${currentInvoice?.invoiceNumber ?? ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (currentInvoice != null) ...[
            if (permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_SEND, userRole: userRole))
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.black, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => InvoiceShareDialog(invoice: currentInvoice),
                  );
                },
              ),
            if (permissions.can(PermissionModules.INVOICE, permission: PermissionModules.INVOICE_DOWNLOAD, userRole: userRole))
              IconButton(
                icon: const Icon(Icons.file_download_outlined, color: Colors.black, size: 20),
                onPressed: () {
                  DocumentLauncher.launchDocument(
                    context: context,
                    urlFetcher: () => ref.read(invoicesProvider.notifier).generateShareLink(currentInvoice.id),
                    loadingMessage: 'Opening invoice...',
                  );
                },
              ),
            _buildStatusChip(currentInvoice.status),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (state.isLoading && currentInvoice == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null && currentInvoice == null)
            Expanded(child: Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red))))
          else if (currentInvoice != null)
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dates Section
                    _buildSectionHeader('Invoice Date'),
                    _buildValueText(_formatDate(currentInvoice.invoiceDate)),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Due Date'),
                    _buildValueText(_formatDate(currentInvoice.dueDate)),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Deal Date'),
                    _buildValueText(_formatDate(currentInvoice.dealDate ?? currentInvoice.invoiceDate)),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Status'),
                    _buildValueText(currentInvoice.status),
                    const SizedBox(height: 24),
                    const Divider(),

                    // Client Details
                    const SizedBox(height: 16),
                    _buildSectionHeader('Client Details'),
                    _buildDetailRow('Company', currentInvoice.clientCompany),
                    _buildDetailRow('Name', currentInvoice.clientName),
                    _buildDetailRow('Phone', currentInvoice.clientPhoneNo),
                    _buildDetailRow('Email', currentInvoice.clientEmail),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Lead / Reference
                    const SizedBox(height: 16),
                    _buildSectionHeader('Lead / Reference'),
                    _buildDetailRow('Lead ID', currentInvoice.leadReference ?? '-'),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Billing Address
                    const SizedBox(height: 16),
                    _buildSectionHeader('Billing Address'),
                    _buildValueText(currentInvoice.billingAddress.street),
                    _buildValueText('${currentInvoice.billingAddress.city} ${currentInvoice.billingAddress.state}'),
                    _buildValueText(currentInvoice.billingAddress.zip),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Shipping Address
                    const SizedBox(height: 16),
                    _buildSectionHeader('Shipping Address'),
                    _buildValueText(currentInvoice.shippingAddress.street),
                    _buildValueText('${currentInvoice.shippingAddress.city} ${currentInvoice.shippingAddress.state}'),
                    _buildValueText(currentInvoice.shippingAddress.zip),
                    const SizedBox(height: 24),

                    // Invoice Items
                    _buildSectionHeader('Invoice Items'),
                    const SizedBox(height: 12),
                    _buildItemsTable(currentInvoice),
                    const SizedBox(height: 24),

                    // Totals
                    _buildSummaryRow('Sub Total', currentInvoice.subTotal),
                    _buildSummaryRow('Discount', currentInvoice.discountTotal),
                    _buildSummaryRow('Tax', currentInvoice.taxTotal),
                    _buildSummaryRow('Adjustment', currentInvoice.adjustment),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(
                          '₹ ${NumberFormat('#,##,###.00').format(currentInvoice.grandTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),

                    // Bank Details
                    const SizedBox(height: 16),
                    _buildSectionHeader('Bank Details'),
                    _buildDetailRow('Account Holder', currentInvoice.account.accountOwner),
                    _buildDetailRow('Bank Name', currentInvoice.account.bankName),
                    _buildDetailRow('Account No', currentInvoice.account.accountNumber),
                    _buildDetailRow('IFSC', currentInvoice.account.bankIfsc),
                    if (currentInvoice.account.upiId.isNotEmpty)
                      _buildDetailRow('UPI ID', currentInvoice.account.upiId),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Terms & Conditions
                    const SizedBox(height: 16),
                    _buildSectionHeader('Terms & Conditions'),
                    _buildValueText(currentInvoice.termsAndConditions.isNotEmpty ? currentInvoice.termsAndConditions : '- None -'),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Description
                    const SizedBox(height: 16),
                    _buildSectionHeader('Description'),
                    _buildValueText(currentInvoice.description.isNotEmpty ? currentInvoice.description : '- None -'),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          
          // Bottom Close Button
          _buildBottomAction(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
      ),
    );
  }

  Widget _buildValueText(String value) {
    return Text(
      value,
      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          Text(
            '₹ ${NumberFormat('#,##,###.00').format(value)}',
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(Invoice invoice) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return _buildItemsCardLayout(invoice);
    }
    return _buildItemsTableLayout(invoice);
  }

  Widget _buildItemsCardLayout(Invoice invoice) {
    return Column(
      children: invoice.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isEven = index % 2 == 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isEven ? Colors.grey[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (item.description.isNotEmpty)
                          Text(item.description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.itemType == 'SERVICE' ? Colors.blue[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item.itemType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.itemType == 'SERVICE' ? Colors.blue[700] : Colors.orange[700])),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildCardRow('Quantity', '${item.quantity.toInt()}'),
              _buildCardRow('Unit Price', _formatCurrency(item.unitPrice)),
              _buildCardRow('Discount', _formatCurrency(item.discount)),
              _buildCardRow('Tax', _formatCurrency(item.tax)),
              _buildCardRow('Amount', _formatCurrency(item.amount)),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    _formatCurrency(item.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    return '₹ ${NumberFormat('#,##,##0.00').format(value)}';
  }

  Widget _buildItemsTableLayout(Invoice invoice) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('ITEM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(child: Text('TYPE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('QTY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('UNIT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('DISC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('TAX', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('AMT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('TOTAL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          ...invoice.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isEven = index % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: isEven ? Colors.white : Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        if (item.description.isNotEmpty)
                          Text(item.description, style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(item.itemType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: item.itemType == 'SERVICE' ? Colors.blue[700] : Colors.orange[700]), textAlign: TextAlign.center),
                  ),
                  Expanded(child: Text('${item.quantity.toInt()}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.unitPrice), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.discount), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.tax), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.amount), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatCurrencyCompact(double value) {
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}k';
    }
    return '₹${NumberFormat('#,##0').format(value)}';
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: Colors.grey[400]!),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: const Text('Close', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
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

  String _formatDate(String dateStr) {
    return DateTimeUtils.formatSafe(dateStr, format: 'dd MMM yyyy');
  }
}
