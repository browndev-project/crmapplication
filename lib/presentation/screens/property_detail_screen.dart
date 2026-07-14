import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/property_provider.dart';
import '../../data/models/property_model.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../../core/utils/date_utils.dart';
import '../../core/constants/permission_constants.dart';
import '../widgets/property_create_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/property_share_dialog.dart';
import '../../core/utils/media_helper.dart';
import './public_view_screen.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final Property property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prop = widget.property;

    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;
    final canEdit = permissions.hasPermission(PermissionModules.PROPERTY_UPDATE, userRole: userRole);
    final canDelete = permissions.hasPermission(PermissionModules.PROPERTY_DELETE, userRole: userRole);

    final dynamic rawAmenities = (prop.amenities as dynamic);
    final safeAmenities = rawAmenities != null ? (List<String>.from(rawAmenities.map((e) => e?.toString() ?? ''))).where((e) => e.isNotEmpty).toList() : const <String>[];
    
    final dynamic rawImages = (prop.images as dynamic);
    final safeImages = rawImages != null ? (List<String>.from(rawImages.map((e) => e?.toString() ?? ''))).where((e) => e.isNotEmpty).toList() : const <String>[];
    
    final dynamic rawVideos = (prop.videos as dynamic);
    final safeVideos = rawVideos != null ? (List<String>.from(rawVideos.map((e) => e?.toString() ?? ''))).where((e) => e.isNotEmpty).toList() : const <String>[];

    final double rawPrice = prop.price;
    final double rawArea = prop.area?.value.toDouble() ?? 0.0;
    final double rawRate = (rawPrice > 0 && rawArea > 0) ? (rawPrice / rawArea) : 0.0;

    final priceFormatter = NumberFormat('₹ #,##,###', 'en_IN');
    final rateFormatter = NumberFormat('₹ #,##,###', 'en_IN');
    final labelColor = isDark ? Colors.grey[400]! : Colors.blueGrey[700]!;

    final isRent = prop.listingType.toLowerCase().contains('rent');

    String dimStr = "";
    if (prop.length != null && prop.breadth != null && prop.length!.value > 0 && prop.breadth!.value > 0) {
      dimStr = " (${prop.length!.value.toInt()} \u00D7 ${prop.breadth!.value.toInt()} ${prop.length!.unit})";
    }
    final areaValueStr = "${prop.area?.value.toInt() ?? 0} ${Property.getDisplayLabel(prop.area?.unit ?? 'sqft')}$dimStr";

    final locParts = [
      if (prop.location?.address1.isNotEmpty == true) prop.location!.address1,
      if (prop.location?.address2.isNotEmpty == true) prop.location!.address2,
      if (prop.location?.city.isNotEmpty == true) prop.location!.city,
      if (prop.location?.state.isNotEmpty == true) prop.location!.state,
      if (prop.location?.pincode != null && prop.location!.pincode!.isNotEmpty) prop.location!.pincode,
      if (prop.location?.country.isNotEmpty == true) prop.location!.country,
    ];
    final locationStr = locParts.isNotEmpty ? locParts.join(', ') : 'No Address Provided';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(180), 
          child: Container(
            color: theme.cardColor,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Actions Row at the top right
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (context) => PropertyCreateDialog(property: prop, projectId: prop.projectId),
                            ),
                            tooltip: "Edit Property",
                          ),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                            onPressed: () => _confirmDelete(context, prop),
                            tooltip: "Delete Property",
                          ),
                        IconButton(
                          icon: const Icon(Icons.public_outlined, size: 20, color: Colors.blueAccent),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => PublicViewScreen(property: prop)));
                          },
                          tooltip: "Web View",
                        ),
                        const SizedBox(width: 4),
                        if (ref.watch(permissionsProvider).hasPermission(PermissionModules.PROPERTY_VIEW, userRole: ref.watch(loginProvider).user?.systemRole))
                          OutlinedButton(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (context) => PropertyShareDialog(property: prop),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              backgroundColor: isDark ? Colors.transparent : Colors.white,
                            ),
                            child: const Text(
                              "Share",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // Row 2: Title and Subtitle taking full width below the actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${prop.propertyType.toUpperCase()} • ${prop.listingType.toUpperCase()}",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prop.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // TabBar
                  TabBar(
                    tabs: const [
                      Tab(text: "Overview"),
                      Tab(text: "Stats & Leads"),
                      Tab(text: "Media & Plans"),
                    ],
                    indicatorColor: isDark ? Colors.white : Colors.black,
                    indicatorWeight: 2.5,
                    labelColor: isDark ? Colors.white : Colors.black,
                    unselectedLabelColor: Colors.grey[500],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // --- OVERVIEW TAB ---
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card 1: Specs Grid (dynamic fields based on listing type)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    color: theme.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isRent) ...[
                            // RENT Overview Fields
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItem(icon: Icons.apartment, title: "PROPERTY TYPE", value: prop.propertyTypeLabel)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.category, title: "CATEGORY", value: prop.categoryLabel)),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItem(icon: Icons.trending_up, title: "STATUS", value: prop.statusLabel)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.explore_outlined, title: "SITE FACING", value: prop.facingLabel.isEmpty ? 'N/A' : prop.facingLabel)),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.king_bed_outlined,
                                    title: "BEDROOMS (BHK)",
                                    value: prop.builtUp
                                        ? "Built Up"
                                        : (prop.bedrooms != null ? "${prop.bedrooms} BHK" : 'N/A'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.navigation_outlined, title: "DIRECTION", value: prop.directionLabel.isEmpty ? 'N/A' : prop.directionLabel)),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItem(icon: Icons.bathtub_outlined, title: "BATHROOMS", value: prop.bathrooms != null && prop.bathrooms! > 0 ? "${prop.bathrooms}" : 'N/A')),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.home_outlined, title: "FURNISHING STATUS", value: prop.furnishingStatusLabel)),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.account_balance_wallet_outlined,
                                    title: "RENT / MONTH",
                                    value: prop.basic != null && prop.basic!.isNotEmpty
                                        ? "${priceFormatter.format(rawPrice)} (${prop.basic})"
                                        : priceFormatter.format(rawPrice),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.show_chart, title: "RATE", value: "${rateFormatter.format(rawRate)} / ${Property.getDisplayLabel(prop.area?.unit ?? 'sqft')}")),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItem(icon: Icons.security_outlined, title: "SECURITY DEPOSIT", value: priceFormatter.format(prop.securityDeposit))),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.receipt_long_outlined,
                                    title: "MAINTENANCE CHARGES",
                                    value: prop.maintenanceCharges != null
                                        ? "${priceFormatter.format(prop.maintenanceCharges!.value)} (${Property.getDisplayLabel(prop.maintenanceCharges!.billingCycle)})"
                                        : "Included",
                                  ),
                                ),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItem(icon: Icons.people_outline, title: "ALLOWED TENANTS", value: prop.allowedTenantsLabel.isEmpty ? 'Any' : prop.allowedTenantsLabel)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.wc_outlined, title: "PREFERRED GENDER", value: prop.preferredGenderLabel.isEmpty ? 'Any' : prop.preferredGenderLabel)),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItemNoIcon(title: "LOCK-IN PERIOD", value: "${prop.lockInPeriodMonths} Months")),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItemNoIcon(title: "NOTICE PERIOD", value: "${prop.noticePeriodMonths} Months")),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.calendar_today_outlined,
                                    title: "AVAILABILITY DATE",
                                    value: prop.availabilityDate != null
                                        ? DateTimeUtils.formatSafe(prop.availabilityDate, format: 'dd MMM yyyy')
                                        : "Immediate",
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.inventory_outlined,
                                    title: "INVENTORY DATE",
                                    value: prop.inventoryDate != null
                                        ? DateTimeUtils.formatSafe(prop.inventoryDate, format: 'dd MMM yyyy')
                                        : "N/A",
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.square_foot_outlined,
                                    title: "DIMENSIONS & AREA",
                                    value: areaValueStr,
                                  ),
                                ),
                              ],
                            ),
                            _buildDivider(),
                            _buildOverviewItem(
                              icon: Icons.location_on_outlined,
                              title: "LOCATION",
                              value: locationStr,
                            ),
                          ] else ...[
                            // SELL Overview Fields
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItem(icon: Icons.apartment, title: "PROPERTY TYPE", value: prop.propertyTypeLabel)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.category, title: "CATEGORY", value: prop.categoryLabel)),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItem(icon: Icons.trending_up, title: "STATUS", value: prop.statusLabel)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.explore_outlined, title: "SITE FACING", value: prop.facingLabel.isEmpty ? 'N/A' : prop.facingLabel)),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.king_bed_outlined,
                                    title: "BEDROOMS (BHK)",
                                    value: prop.builtUp
                                        ? "Built Up"
                                        : (prop.bedrooms != null ? "${prop.bedrooms} BHK" : 'N/A'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.navigation_outlined, title: "DIRECTION", value: prop.directionLabel.isEmpty ? 'N/A' : prop.directionLabel)),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.monetization_on_outlined,
                                    title: "PRICE",
                                    value: prop.basic != null && prop.basic!.isNotEmpty
                                        ? "${priceFormatter.format(rawPrice)} (${prop.basic})"
                                        : priceFormatter.format(rawPrice),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _buildOverviewItem(icon: Icons.show_chart, title: "RATE", value: "${rateFormatter.format(rawRate)} / ${Property.getDisplayLabel(prop.area?.unit ?? 'sqft')}")),
                              ],
                            ),
                            _buildDivider(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildOverviewItem(icon: Icons.monetization_on_outlined, title: "TOKEN AMOUNT", value: priceFormatter.format(prop.token))),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.inventory_outlined,
                                    title: "INVENTORY DATE",
                                    value: prop.inventoryDate != null
                                        ? DateTimeUtils.formatSafe(prop.inventoryDate, format: 'dd MMM yyyy')
                                        : "N/A",
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildOverviewItem(
                                    icon: Icons.square_foot_outlined,
                                    title: "DIMENSIONS & AREA",
                                    value: areaValueStr,
                                  ),
                                ),
                              ],
                            ),
                            _buildDivider(),
                            _buildOverviewItem(
                              icon: Icons.location_on_outlined,
                              title: "LOCATION",
                              value: locationStr,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 2: Property Owner Details
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    color: theme.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PROPERTY OWNER DETAILS",
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: labelColor, 
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRichDetail("Property Owner Name: ", prop.ownerName ?? 'N/A', isDark),
                                const SizedBox(height: 8),
                                _buildRichDetail("Property Owner Number: ", prop.ownerNumber ?? 'N/A', isDark),
                                if (prop.ownerEmail != null) ...[
                                  const SizedBox(height: 8),
                                  _buildRichDetail("Property Owner Email: ", prop.ownerEmail!, isDark),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 3: Amenities (Render badge-tags for both Rent and Sell if available, Rent always shows)
                  if (isRent || safeAmenities.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      color: theme.cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "AMENITIES",
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold, 
                                color: labelColor, 
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (safeAmenities.isEmpty)
                              Text(
                                "No amenities listed",
                                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: safeAmenities.map((amenity) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    amenity,
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                )).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Card 4: Description (Rent always shows, Sell shows if not empty)
                  if (isRent || prop.description.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      color: theme.cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DESCRIPTION",
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold, 
                                color: labelColor, 
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "•  ",
                                  style: TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey[400] : Colors.black87,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    prop.description.isNotEmpty ? prop.description : "No description provided.",
                                    style: TextStyle(
                                      fontSize: 13, 
                                      height: 1.5, 
                                      color: isDark ? Colors.grey[400] : Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Card 5: Policies & Rules (Rent always shows, Sell shows if not empty)
                  if (isRent || prop.policies.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      color: theme.cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "POLICIES & RULES",
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold, 
                                color: labelColor, 
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (prop.policies.isEmpty)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "•  ",
                                    style: TextStyle(
                                      fontSize: 14, 
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey[400] : Colors.black87,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "No policy",
                                      style: TextStyle(
                                        fontSize: 13, 
                                        height: 1.5, 
                                        color: isDark ? Colors.grey[400] : Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              ...prop.policies.map((policy) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "•  ",
                                      style: TextStyle(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.grey[400] : Colors.black87,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        policy,
                                        style: TextStyle(
                                          fontSize: 13, 
                                          height: 1.5, 
                                          color: isDark ? Colors.grey[400] : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Internal Notes Card
                  if (prop.internalNotes != null && prop.internalNotes!.trim().isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      color: theme.cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("INTERNAL NOTES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor, letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("•  ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.black87)),
                                Expanded(
                                  child: Text(
                                    prop.internalNotes!,
                                    style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.grey[400] : Colors.grey[800]),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Metadata Bottom Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Created: ${prop.createdBy ?? 'Admin'}",
                          style: TextStyle(
                            fontSize: 10, 
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                        Text(
                          "Updated: ${prop.updatedBy ?? 'Admin'}",
                          style: TextStyle(
                            fontSize: 10, 
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- STATS & LEADS TAB ---
            _buildLeadsTab(prop, isDark, labelColor, theme),

            // --- MEDIA & PLANS TAB ---
            _buildMediaTab(safeImages, safeVideos, prop.brochureUrl, prop.paymentPlan, isDark, labelColor, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem({required IconData icon, required String title, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon, 
          size: 20, 
          color: isDark ? Colors.white60 : Colors.grey[500],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(), 
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: isDark ? Colors.grey[400] : Colors.grey[500], 
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w700, 
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewItemNoIcon({required String title, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(), 
          style: TextStyle(
            fontSize: 10, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.grey[400] : Colors.grey[500], 
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.w700, 
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[200]),
  );

  Widget _buildRichDetail(String label, String value, bool isDark) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.black87),
        children: [
          TextSpan(text: label, style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600])),
          TextSpan(text: value, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildLeadsTab(Property prop, bool isDark, Color labelColor, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Column(
                      children: [
                        Text(
                          "TOTAL LEADS",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trending_up, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                            const SizedBox(width: 6),
                            Text(
                              prop.leadsCount.toString(),
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Column(
                      children: [
                        Text(
                          "TOTAL VISITS",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_outlined, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                            const SizedBox(width: 6),
                            Text(
                              prop.visitsSummary.total.toString(),
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            color: theme.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "VISITS DETAIL",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 16),
                  _buildVisitDetailRow(
                    label: "Scheduled Visits",
                    value: prop.visitsSummary.scheduled.toString(),
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildVisitDetailRow(
                    label: "Completed Visits",
                    value: prop.visitsSummary.completed.toString(),
                    color: Colors.green,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildVisitDetailRow(
                    label: "Cancelled Visits",
                    value: prop.visitsSummary.cancelled.toString(),
                    color: Colors.red,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Created: ${prop.createdBy ?? 'Admin'}",
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                ),
                Text(
                  "Updated: ${prop.updatedBy ?? 'Admin'}",
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitDetailRow({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab(List<String> images, List<String> videos, String? brochure, String? plan, bool isDark, Color labelColor, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Property Brochure Card
          if (brochure != null && brochure.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 28,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Property Brochure",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "PDF Document",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(brochure)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      foregroundColor: isDark ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Text(
                      "Download",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    label: const Icon(Icons.open_in_new, size: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Property Photos Card
          if (images.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PROPERTY PHOTOS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(16),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                InteractiveViewer(
                                  panEnabled: true,
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      MediaHelper.getMediaUrl(images[index]),
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.all(40),
                                        child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          MediaHelper.getMediaUrl(images[index]),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Video Tours Card
          if (videos.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "VIDEO TOURS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...videos.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => launchUrl(Uri.parse(url)),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_fill_rounded, size: 20, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                url,
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.open_in_new, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 4. Payment Plan & Milestones Card
          if (plan != null && plan.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PAYMENT PLAN & MILESTONES",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      plan,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (images.isEmpty && videos.isEmpty && (brochure == null || brochure.isEmpty) && (plan == null || plan.isEmpty))
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text("No media assets available for this property.", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Created: ${widget.property.createdBy ?? 'Admin'}",
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                ),
                Text(
                  "Updated: ${widget.property.updatedBy ?? 'Admin'}",
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Property prop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Property?"),
        content: Text("Are you sure you want to delete '${prop.name}'? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final notifier = (prop.projectId.isEmpty)
                  ? ref.read(allPropertiesProvider.notifier)
                  : ref.read(projectPropertiesProvider(prop.projectId).notifier);
              final success = await notifier.deleteProperty(prop.id);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Property deleted successfully")));
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

