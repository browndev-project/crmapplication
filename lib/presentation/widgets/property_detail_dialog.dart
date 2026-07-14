import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../data/models/property_model.dart';
import '../../core/utils/date_utils.dart';

class PropertyDetailDialog extends ConsumerWidget {
  final Property property;

  const PropertyDetailDialog({super.key, required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(loginProvider).user;
    final hasLastUpdatePermission = ref.watch(permissionsProvider).hasPermission(
      PermissionModules.PROPERTY_LAST_UPDATED, 
      userRole: user?.systemRole
    );
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    String priceStr = "Price on Request";
    if (property.price > 0) {
       priceStr = "₹${property.price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
       if (property.basic != null && property.basic!.isNotEmpty) {
         priceStr += " (${property.basic})";
       }
    }

    String dimStr = "";
    if (property.length != null && property.breadth != null) {
      dimStr = "(${property.length!.value.toInt()} \u00D7 ${property.breadth!.value.toInt()} ${property.length!.unit})";
    }
    
    String areaStr = "";
    if (property.area != null) {
      areaStr = "${property.area!.value.toInt()} ${property.area!.unit} $dimStr";
    }

    final createdDate = DateTimeUtils.parseSafe(property.createdAt);
    final createdDateStr = createdDate != null ? DateTimeUtils.formatShort(createdDate) : property.createdAt;

    final updatedDate = DateTimeUtils.parseSafe(property.updatedAt);
    final updatedDateStr = updatedDate != null ? DateTimeUtils.formatShort(updatedDate) : property.updatedAt;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E1E2A) : const Color(0xFFF5F6F8),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      property.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Info Card
                    _buildCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(Icons.category, property.propertyType),
                          const SizedBox(height: 8),
                          if (areaStr.isNotEmpty) ...[
                            _buildInfoRow(Icons.crop_square, areaStr),
                            const SizedBox(height: 8),
                          ],
                          _buildInfoRow(Icons.payments_outlined, priceStr),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.location_on_outlined, 
                            property.location?.address1 ?? "No Address Provided",
                          ),
                          if (property.builtUp) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.king_bed, "Built Up"),
                          ] else if (property.bedrooms != null) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.king_bed, "${property.bedrooms} BHK"),
                          ],
                          if (property.inventoryDate != null) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.inventory_outlined,
                              "Inventory Date: ${DateTimeUtils.formatSafe(property.inventoryDate, format: 'dd MMM yyyy')}",
                            ),
                          ],
                          if (property.facing != null && property.facing!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.explore, property.facing!),
                          ],
                          if (property.ownerName != null && property.ownerName!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.person, "Owner: ${property.ownerName}"),
                          ],
                          if (property.ownerNumber != null && property.ownerNumber!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.phone, "Owner Tel: ${property.ownerNumber}"),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stats Card
                    _buildCard(
                      isDark: isDark,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Leads & Visits
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Total Leads", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text("${property.leadsCount}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text("Total Visits", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.home_outlined, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text("${property.visitsSummary.total}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Right side: Visits Summary Box
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A36) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Visits Summary", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  _buildVisitSummaryRow("Scheduled", property.visitsSummary.scheduled),
                                  const SizedBox(height: 4),
                                  _buildVisitSummaryRow("Completed", property.visitsSummary.completed),
                                  const SizedBox(height: 4),
                                  _buildVisitSummaryRow("Cancelled", property.visitsSummary.cancelled),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    if (property.description.isNotEmpty) ...[
                      _buildCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Description", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(property.description, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Internal Notes
                    if (property.internalNotes != null && property.internalNotes!.isNotEmpty) ...[
                      _buildCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Internal Notes", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(property.internalNotes!, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Audit Info
                    _buildCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("AUDIT INFO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("CREATED BY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(property.createdBy ?? "Admin", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(createdDateStr, style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              if (hasLastUpdatePermission)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("LAST UPDATED BY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(property.updatedBy ?? "Admin", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(updatedDateStr, style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A36) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildVisitSummaryRow(String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text("$count", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
