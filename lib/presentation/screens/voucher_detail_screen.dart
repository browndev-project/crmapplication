import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/voucher_model.dart';
import '../providers/voucher_provider.dart';
import '../widgets/voucher_share_dialog.dart';
import '../widgets/voucher_create_dialog.dart';
import '../../core/utils/document_launcher.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/login_provider.dart';
import '../widgets/access_denied_widget.dart';

import '../../core/utils/date_utils.dart';

class VoucherDetailScreen extends ConsumerStatefulWidget {
  final String voucherId;
  const VoucherDetailScreen({super.key, required this.voucherId});

  @override
  ConsumerState<VoucherDetailScreen> createState() => _VoucherDetailScreenState();
}

class _VoucherDetailScreenState extends ConsumerState<VoucherDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voucherDetailProvider.notifier).fetchDetails(widget.voucherId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voucherDetailProvider);
    final theme = Theme.of(context);
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final canView = permissions.hasPermission(PermissionModules.VOUCHER_VIEW, userRole: userRole);
    if (!canView) {
      return const AccessDeniedWidget(
        sectionName: "Voucher Details",
        showAppBar: true,
      );
    }

    final canDownload = permissions.hasPermission(PermissionModules.VOUCHER_DOWNLOAD, userRole: userRole);
    final canShare = permissions.hasPermission(PermissionModules.VOUCHER_SEND, userRole: userRole);
    final canEdit = permissions.hasPermission(PermissionModules.VOUCHER_UPDATE, userRole: userRole);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.voucher != null ? 'Voucher #${state.voucher!.voucherNo}' : 'Voucher Details'),
        actions: [
          if (state.voucher != null) ...[
            if (canDownload)
              IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: () {
                  DocumentLauncher.launchDocument(
                    context: context,
                    urlFetcher: () => ref.read(vouchersProvider.notifier).generateShareLink(state.voucher!.id),
                    loadingMessage: 'Opening voucher...',
                  );
                },
              ),
            if (canShare)
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  showDialog(context: context, builder: (_) => VoucherShareDialog(voucher: state.voucher!));
                },
              ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  showDialog(
                    context: context, 
                    builder: (_) => VoucherCreateDialog(voucher: state.voucher!)
                  ).then((_) => ref.read(voucherDetailProvider.notifier).fetchDetails(widget.voucherId));
                },
              ),
          ],
        ],
      ),
      body: state.isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : state.error != null
          ? Center(child: Text(state.error!, style: const TextStyle(color: Colors.red)))
          : state.voucher == null
          ? const Center(child: Text('Voucher not found.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(state.voucher!, theme),
                  const SizedBox(height: 20),
                  
                  if (state.voucher!.voucherType == 'HOTEL')
                    _buildHotelDetailsCard(state.voucher!, theme)
                  else
                    _buildTravelDetailsCard(state.voucher!, theme),
                  
                  const SizedBox(height: 20),
                  if (state.voucher!.guestList.isNotEmpty)
                    _buildGuestList(state.voucher!.guestList, theme),
                  
                  const SizedBox(height: 20),
                  _buildItemsList(state.voucher!.items, theme),
                  
                  const SizedBox(height: 20),
                  _buildFinancialsCard(state.voucher!.financials, theme),
                  
                  const SizedBox(height: 20),
                  _buildTermsCard(state.voucher!.termsAndConditions, theme),
                  
                  const SizedBox(height: 20),
                  _buildInclusionsCard(state.voucher!.inclusions, theme),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(Voucher voucher, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VOUCHER NO', style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('#${voucher.voucherNo}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    _buildTypeBadge(voucher.voucherType),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow('Client Name', voucher.clientName),
            _buildInfoRow('Client Phone', voucher.clientPhone),
            _buildInfoRow('Client Email', voucher.clientEmail),
            _buildInfoRow('Voucher Date', _formatDate(voucher.voucherDate)),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelDetailsCard(Voucher voucher, ThemeData theme) {
    return _buildDetailSection(
      'Hotel Details',
      Icons.hotel_outlined,
      [
        _buildInfoRow('Hotel Name', voucher.hotelDetails?.name ?? 'N/A'),
        _buildInfoRow('Check In', _formatDate(voucher.checkIn ?? 'N/A')),
        _buildInfoRow('Check Out', _formatDate(voucher.checkOut ?? 'N/A')),
        _buildInfoRow('Rooms', '${voucher.noOfRooms ?? 0}'),
        _buildInfoRow('Contact', voucher.hotelDetails?.contact ?? 'N/A'),
        _buildInfoRow('GST No', voucher.hotelDetails?.gstNo ?? 'N/A'),
        _buildInfoRow('Address', voucher.hotelDetails?.address ?? 'N/A'),
      ],
      theme,
    );
  }

  Widget _buildTravelDetailsCard(Voucher voucher, ThemeData theme) {
    final type = voucher.voucherType.toUpperCase();
    String sectionTitle = 'Travel Details';
    IconData sectionIcon = Icons.map_outlined;
    String startLabel = 'Travel Start Date';
    String endLabel = 'Travel End Date';
    bool showKms = true;

    if (type == 'FLIGHT') {
      sectionTitle = 'Flight Details';
      sectionIcon = Icons.flight_takeoff_outlined;
      startLabel = 'Departure Date';
      endLabel = 'Arrival Date';
      showKms = false;
    } else if (type == 'TRANSPORT') {
      sectionTitle = 'Transport Details';
      sectionIcon = Icons.directions_car_outlined;
      startLabel = 'Journey Start Date';
      endLabel = 'Journey End Date';
      showKms = true;
    }

    return _buildDetailSection(
      sectionTitle,
      sectionIcon,
      [
        _buildInfoRow(startLabel, _formatDate(voucher.travelStartDate ?? 'N/A')),
        _buildInfoRow(endLabel, _formatDate(voucher.travelEndDate ?? 'N/A')),
        if (showKms)
          _buildInfoRow('Total Kilometers', '${voucher.travelTotalKms ?? 0} KM'),
      ],
      theme,
    );
  }

  Widget _buildGuestList(List<Guest> guests, ThemeData theme) {
    return _buildDetailSection(
      'Guest List (${guests.length})',
      Icons.people_outline,
      guests.map((g) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w500))),
            Text('${g.age} Yrs, ${g.gender} (${g.type})', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      )).toList(),
      theme,
    );
  }

  Widget _buildItemsList(List<VoucherItem> items, ThemeData theme) {
    return _buildDetailSection(
      'Items',
      Icons.list_alt_outlined,
      items.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.itemType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('₹${NumberFormat('#,##,###.##').format(item.amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.description, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: ${item.quantity} × ₹${item.price}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                if (item.discount > 0 || item.tax > 0)
                  Text('Disc: ₹${item.discount} | Tax: ₹${item.tax}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ],
        ),
      )).toList(),
      theme,
    );
  }

  Widget _buildFinancialsCard(VoucherFinancials financials, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: [
          _buildCalcRow('Subtotal', financials.subTotal),
          _buildCalcRow('Discount', financials.discountTotal),
          _buildCalcRow('Tax', financials.taxTotal),
          const Divider(color: Colors.white24, height: 24),
          _buildCalcRow('Total Amount', financials.totalAmount, isBold: true, fontSize: 18),
          const SizedBox(height: 8),
          _buildCalcRow('Advance Paid', financials.advancePaid, color: Colors.green[300]),
          _buildCalcRow('Balance Amount', financials.balanceAmount, isBold: true, fontSize: 20, color: Colors.orange[300]),
        ],
      ),
    );
  }

  Widget _buildTermsCard(String terms, ThemeData theme) {
    if (terms.isEmpty) return const SizedBox();
    return _buildDetailSection(
      'Terms & Conditions',
      Icons.gavel_outlined,
      [Text(terms, style: TextStyle(color: Colors.grey[600], fontSize: 13))],
      theme,
    );
  }

  Widget _buildInclusionsCard(String inclusions, ThemeData theme) {
    if (inclusions.isEmpty) return const SizedBox();
    return _buildDetailSection(
      'Inclusions',
      Icons.star_outline_rounded,
      [Text(inclusions, style: TextStyle(color: Colors.grey[600], fontSize: 13))],
      theme,
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.black),
            const SizedBox(width: 8),
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildCalcRow(String label, double value, {bool isBold = false, double fontSize = 14, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: fontSize)),
        Text(
          '₹${NumberFormat('#,##,###.##').format(value)}',
          style: TextStyle(color: color ?? Colors.white, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: fontSize),
        ),
      ],
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color = Colors.grey;
    switch (type.toUpperCase()) {
      case 'HOTEL': color = Colors.blue; break;
      case 'TRAVEL': color = Colors.indigo; break;
      case 'FLIGHT': color = Colors.cyan; break;
      case 'TRANSPORT': color = Colors.teal; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(type, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(String dateStr) {
    return DateTimeUtils.formatSafe(dateStr, format: 'dd MMM yyyy');
  }
}
