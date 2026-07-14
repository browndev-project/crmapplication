import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/quotation_model.dart';
import '../providers/quotation_provider.dart';
import '../widgets/quotation_share_dialog.dart';
import '../widgets/quotation_create_dialog.dart';
import '../widgets/itinerary_explorer_dialog.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/login_provider.dart';
import '../../core/utils/document_launcher.dart';
import '../widgets/access_denied_widget.dart';

class QuotationDetailScreen extends ConsumerStatefulWidget {
  final String quotationId;
  final Quotation? initialQuotation;

  const QuotationDetailScreen({
    super.key,
    required this.quotationId,
    this.initialQuotation,
  });

  @override
  ConsumerState<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends ConsumerState<QuotationDetailScreen> {
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasFetched) {
        _hasFetched = true;
        ref.read(quotationDetailProvider.notifier).fetchDetails(widget.quotationId);
      }
    });
  }

  Quotation? get quotation => ref.watch(quotationDetailProvider).quotation;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quotationDetailProvider);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;
    final currentQuotation = quotation ?? widget.initialQuotation;

    if (!permissions.hasPermission(PermissionModules.QUOTATION_VIEW, userRole: userRole)) {
      return const AccessDeniedWidget(
        sectionName: "Quotation Details",
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
            Text(
              currentQuotation?.clientName ?? '',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              currentQuotation?.quotationNumber ?? '',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (currentQuotation != null) ...[
            if (permissions.hasPermission(PermissionModules.QUOTATION_SEND, userRole: userRole))
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.black, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => QuotationShareDialog(quotation: currentQuotation),
                  );
                },
              ),
            if (permissions.hasPermission(PermissionModules.QUOTATION_DOWNLOAD, userRole: userRole))
              IconButton(
                icon: const Icon(Icons.file_download_outlined, color: Colors.black, size: 20),
                onPressed: () {
                  DocumentLauncher.launchDocument(
                    context: context,
                    urlFetcher: () => ref.read(quotationsProvider.notifier).getShareLink(currentQuotation.id),
                    loadingMessage: 'Opening quotation...',
                  );
                },
              ),
            _buildStatusBadge(currentQuotation.status),
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
          if (state.isLoading && currentQuotation == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null && currentQuotation == null)
            Expanded(child: Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red))))
          else if (currentQuotation != null)
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dates Section
                    _buildSectionHeader('Quotation Date'),
                    _buildValueText(_formatDate(currentQuotation.quotationDate)),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Valid Until'),
                    _buildValueText(_formatDate(currentQuotation.validUntil)),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Subject'),
                    _buildValueText(currentQuotation.subject),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Status'),
                    _buildValueText(currentQuotation.status),
                    const SizedBox(height: 24),
                    const Divider(),

                    // Client Details
                    const SizedBox(height: 16),
                    _buildSectionHeader('Client Details'),
                    _buildDetailRow('Company', currentQuotation.clientCompany),
                    _buildDetailRow('Name', currentQuotation.clientName),
                    _buildDetailRow('Phone', currentQuotation.clientPhoneNo),
                    _buildDetailRow('Email', currentQuotation.clientEmail),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Billing Address
                    const SizedBox(height: 16),
                    _buildSectionHeader('Billing Address'),
                    _buildValueText(currentQuotation.billingAddress.street),
                    _buildValueText('${currentQuotation.billingAddress.city} ${currentQuotation.billingAddress.state}'),
                    _buildValueText(currentQuotation.billingAddress.zip),
                    const SizedBox(height: 24),
                    const Divider(),

                    // Linked Itinerary
                    if (currentQuotation.itineraryId != null) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('Linked Journey Proposal'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.explore_outlined, color: Colors.black, size: 24),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cinematic Itinerary Attached',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'This quotation is attached to a premium live itinerary brochure.',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => ItineraryExplorerDialog(itineraryId: currentQuotation.itineraryId!),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              child: const Text('View Itinerary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                    ],

                    // Quotation Items
                    const SizedBox(height: 16),
                    _buildSectionHeader('Quotation Items'),
                    const SizedBox(height: 12),
                    _buildItemsTable(currentQuotation),
                    const SizedBox(height: 24),

                    // Totals
                    _buildSummaryRow('Sub Total', currentQuotation.subTotal),
                    _buildSummaryRow('Discount', currentQuotation.discountTotal),
                    _buildSummaryRow('Tax', currentQuotation.taxTotal),
                    _buildSummaryRow('Adjustment', currentQuotation.adjustment),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(
                          '₹ ${NumberFormat('#,##,###.00').format(currentQuotation.grandTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),

                    // Terms & Conditions
                    const SizedBox(height: 16),
                    _buildSectionHeader('Terms & Conditions'),
                    _buildValueText(currentQuotation.termsAndConditions.isNotEmpty ? currentQuotation.termsAndConditions : '- None -'),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

          // Bottom Actions
          if (currentQuotation != null) _buildBottomActions(context, currentQuotation, permissions, userRole),
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

  Widget _buildItemsTable(Quotation quotation) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return _buildItemsCardLayout(quotation);
    }
    return _buildItemsTableLayout(quotation);
  }

  Widget _buildItemsCardLayout(Quotation quotation) {
    return Column(
      children: quotation.items.asMap().entries.map((entry) {
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
                    _formatCurrency(item.totalAmount),
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

  Widget _buildItemsTableLayout(Quotation quotation) {
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
                Expanded(flex: 3, child: Text('ITEM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(child: Text('QTY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('UNIT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('DISC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('TAX', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('AMT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('TOTAL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          ...quotation.items.asMap().entries.map((entry) {
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
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        if (item.description.isNotEmpty)
                          Text(item.description, style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Expanded(child: Text('${item.quantity.toInt()}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.unitPrice), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.discount), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.tax), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.amount), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  Expanded(flex: 1, child: Text(_formatCurrencyCompact(item.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
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

  Widget _buildBottomActions(BuildContext context, Quotation quotation, PermissionsState permissions, String? userRole) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey[400]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('Close', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          if (permissions.hasPermission(PermissionModules.QUOTATION_UPDATE, userRole: userRole)) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => QuotationCreateDialog(quotation: quotation),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('Edit Quotation', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'PENDING':
      case 'DRAFT':
        color = Colors.orange;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat('M/d/yyyy').format(dt);
    } catch (e) {
      return dateStr;
    }
  }
}
