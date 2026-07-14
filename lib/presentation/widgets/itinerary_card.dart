import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/itinerary_model.dart';
import '../providers/itinerary_provider.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/login_provider.dart';
import 'itinerary_explorer_dialog.dart';
import 'quotation_create_dialog.dart';
import '../screens/lead_profile_screen.dart';
import '../../core/utils/document_launcher.dart';

class ItineraryCard extends ConsumerWidget {
  final ItineraryV2 itinerary;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;

  const ItineraryCard({
    super.key,
    required this.itinerary,
    this.onEdit,
    this.onShare,
    this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final numberFormat = NumberFormat('#,##,###');

    final canView = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_VIEW, userRole: userRole);
    final canDownload = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_DOWNLOAD, userRole: userRole);
    final canSend = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_SEND, userRole: userRole);
    final canEdit = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_UPDATE, userRole: userRole);
    final canDelete = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_DELETE, userRole: userRole);
    final canDuplicate = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_DUPLICATE, userRole: userRole);
    final canGenerateQuote = permissions.can(PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_GENERATE_QUOTE, userRole: userRole);
    final canCreateQuotation = permissions.hasPermission(PermissionModules.QUOTATION_CREATE, userRole: userRole);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.blueGrey[900]!, Colors.blueGrey[800]!]
                    : [Colors.grey[50]!, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itinerary.subject.isNotEmpty ? itinerary.subject : 'Unnamed Journey',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Client: ${itinerary.clientName.isNotEmpty ? itinerary.clientName : "N/A"}',
                        style: TextStyle(color: theme.hintColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${itinerary.noOfDays} Days',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.business_outlined, 'Company', itinerary.clientCompany.isNotEmpty ? itinerary.clientCompany : 'N/A'),
                _buildInfoRow(Icons.email_outlined, 'Email', itinerary.clientEmail.isNotEmpty ? itinerary.clientEmail : 'N/A'),
                _buildInfoRow(Icons.phone_outlined, 'Phone', itinerary.clientPhoneNo.isNotEmpty ? itinerary.clientPhoneNo : 'N/A'),
                _buildInfoRow(Icons.hotel_outlined, 'Stays Count', '${itinerary.stays.length} Locations'),
                
                const Divider(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Value', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      '₹${numberFormat.format(itinerary.totalPrice)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // View button - requires view permission
                      if (canView)
                        _buildActionButton(
                          context,
                          Icons.visibility_outlined,
                          'View',
                          () => showDialog(
                            context: context,
                            builder: (ctx) => ItineraryExplorerDialog(itineraryId: itinerary.id),
                          ),
                        ),
                      
                      // View Lead button
                      if (itinerary.leadId != null)
                        _buildActionButton(
                          context,
                          Icons.person_outline,
                          'View Lead',
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LeadProfileScreen(leadId: itinerary.leadId!)),
                            );
                          },
                          color: Colors.blue[700],
                        ),
                      
                      // Duplicate button - requires duplicate permission
                      if (canDuplicate && onDuplicate != null)
                        _buildActionButton(
                          context,
                          Icons.copy_outlined,
                          'Duplicate',
                          onDuplicate!,
                        ),
                      
                      // Edit button - requires update permission
                      if (canEdit && onEdit != null)
                        _buildActionButton(
                          context,
                          Icons.edit_outlined,
                          'Edit',
                          onEdit!,
                        ),
                      
                      // Share button - requires send permission
                      if (canSend && onShare != null)
                        _buildActionButton(
                          context,
                          Icons.share_outlined,
                          'Share',
                          onShare!,
                        ),
                      
                      // PDF Download button - requires download permission
                      if (canDownload)
                        _buildActionButton(
                          context,
                          Icons.download_outlined,
                          'PDF',
                          () {
                            DocumentLauncher.launchDocument(
                              context: context,
                              urlFetcher: () => ref.read(itineraryV2Provider.notifier).generatePdfUrl(itinerary.id),
                              loadingMessage: 'Generating Itinerary PDF...',
                            );
                          },
                        ),
                      
                      // Generate Quote button - requires generate_quote AND quotation_create permissions
                      if (canGenerateQuote && canCreateQuotation)
                        _buildActionButton(
                          context,
                          Icons.request_quote,
                          'Generate Quote',
                          () {
                            showDialog(
                              context: context,
                              builder: (ctx) => QuotationCreateDialog(prefilledItinerary: itinerary),
                            );
                          },
                          color: Colors.blue[700],
                        ),

                      // Delete button - requires delete permission
                      if (canDelete && onDelete != null)
                        _buildActionButton(
                          context,
                          Icons.delete_outline,
                          'Delete',
                          onDelete!,
                          color: Colors.red,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool visible = true,
    Color? color,
  }) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: color ?? Colors.black),
        label: Text(label, style: TextStyle(color: color ?? Colors.black, fontSize: 11, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          backgroundColor: (color ?? Colors.black).withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
