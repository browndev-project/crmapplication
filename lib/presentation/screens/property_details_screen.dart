import 'package:flutter/material.dart';
import '../widgets/common_shimmer_skeleton.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/property_service.dart';
import '../../data/models/property_model.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;
  final String title;
  final String subtitle;
  final Property? initialProperty;

  const PropertyDetailsScreen({
    super.key,
    required this.propertyId,
    required this.title,
    required this.subtitle,
    this.initialProperty,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> with SingleTickerProviderStateMixin {
  final PropertyService _propertyService = PropertyService();
  
  late TabController _tabController;
  Property? _property;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _property = widget.initialProperty;
    if (_property != null) {
      _isLoading = false;
    }
    _fetchPropertyDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPropertyDetails() async {
    if (_property == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final p = await _propertyService.getProperty(widget.propertyId);
      setState(() {
        _property = p;
        _isLoading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint("======== PROPERTY DETAILS SCREEN FETCH ERROR ========");
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stackTrace");
      debugPrint("=====================================================");
      if (_property == null) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF151722) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: isDark ? Colors.white54 : Colors.grey[600],
                indicatorColor: const Color(0xFF2563EB),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    child: Text(
                      'Overview',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Stats & Leads',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Media & Plans',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const AppShimmerDetailSkeleton()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading details',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPropertyDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(isDark),
                    _buildStatsTab(isDark),
                    _buildMediaTab(isDark),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    if (_property == null) return const SizedBox.shrink();
    final p = _property!;
    
    Widget buildGridItem(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.grey[400]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isNotEmpty ? value : '-',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final formattedPrice = p.listingType.toLowerCase() == 'rent' ? '₹ ${p.price.toInt()}' : '₹ ${p.price.toInt()}';
    final formattedDeposit = '₹ ${p.securityDeposit.toInt()}';
    final formattedMaintenance = p.maintenanceCharges != null 
        ? '₹ ${p.maintenanceCharges!.value.toInt()} (${p.maintenanceCharges!.billingCycle})'
        : '-';
    
    final fullAddress = p.location != null
        ? [p.location!.address1, p.location!.address2, p.location!.city, p.location!.state, p.location!.country]
            .where((s) => s.isNotEmpty)
            .join(', ')
        : '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2-Column Attributes Grid Container (with border!)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, width: 1.0),
            ),
            child: Table(
              border: TableBorder(
                horizontalInside: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 1.0),
                verticalInside: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 1.0),
              ),
              children: [
                TableRow(
                  children: [
                    buildGridItem(Icons.business_outlined, 'Property Type', p.propertyType),
                    buildGridItem(Icons.category_outlined, 'Category', p.category),
                  ],
                ),
                TableRow(
                  children: [
                    buildGridItem(Icons.gavel_outlined, 'Status', p.status.replaceAll('_', ' ')),
                    buildGridItem(Icons.wb_sunny_outlined, 'Site Facing', p.facing ?? '-'),
                  ],
                ),
                TableRow(
                  children: [
                    buildGridItem(Icons.bed_outlined, 'Bedrooms (BHK)', p.bedrooms != null ? '${p.bedrooms} BHK' : '-'),
                    buildGridItem(Icons.explore_outlined, 'Direction', p.direction ?? '-'),
                  ],
                ),
                TableRow(
                  children: [
                    buildGridItem(Icons.bathtub_outlined, 'Bathrooms', p.bathrooms != null ? '${p.bathrooms}' : '-'),
                    buildGridItem(Icons.weekend_outlined, 'Furnishing Status', p.furnishingStatus),
                  ],
                ),
                TableRow(
                  children: [
                    buildGridItem(Icons.monetization_on_outlined, p.listingType.toLowerCase() == 'rent' ? 'Rent / Month' : 'Price', formattedPrice),
                    buildGridItem(Icons.percent_outlined, 'Rate', p.basic ?? '-'),
                  ],
                ),
                TableRow(
                  children: [
                    buildGridItem(Icons.security_outlined, 'Security Deposit', formattedDeposit),
                    buildGridItem(Icons.build_outlined, 'Maintenance', formattedMaintenance),
                  ],
                ),
                TableRow(
                  children: [
                    buildGridItem(Icons.people_outline, 'Allowed Tenants', p.allowedTenants ?? '-'),
                    buildGridItem(Icons.wc_outlined, 'Preferred Gender', p.preferredGender ?? '-'),
                  ],
                ),
                TableRow(
                  children: [
                    buildGridItem(Icons.lock_clock_outlined, 'Lock-in Period', p.lockInPeriodMonths > 0 ? '${p.lockInPeriodMonths} Months' : '-'),
                    buildGridItem(Icons.notifications_active_outlined, 'Notice Period', p.noticePeriodMonths > 0 ? '${p.noticePeriodMonths} Months' : '-'),
                  ],
                ),
                TableRow(
                  children: [
                    buildGridItem(Icons.calendar_month_outlined, 'Availability Date', p.availabilityDate ?? '-'),
                    buildGridItem(Icons.straighten_outlined, 'Dimensions & Area', p.area != null ? '${p.area!.value} ${p.area!.unit}' : '-'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Inventory Date & Location Card (with border!)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, width: 1.0),
            ),
            child: Column(
              children: [
                buildGridItem(Icons.date_range_outlined, 'Inventory Date', p.inventoryDate ?? '-'),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]!),
                buildGridItem(Icons.location_on_outlined, 'Location', fullAddress),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Property Owner Details Section
          Text(
            'PROPERTY OWNER DETAILS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, width: 1.0),
            ),
            padding: const EdgeInsets.all(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha:0.01) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB), width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Property Owner Name: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey[500],
                          ),
                        ),
                        TextSpan(
                          text: p.ownerName ?? '-',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Property Owner Number: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey[500],
                          ),
                        ),
                        TextSpan(
                          text: p.ownerNumber ?? '-',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Amenities Section
          Text(
            'AMENITIES',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, width: 1.0),
            ),
            padding: const EdgeInsets.all(16),
            child: p.amenities.isEmpty
                ? Text('-', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white54 : Colors.black54))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.amenities.map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, width: 1.0),
                        ),
                        child: Text(
                          amenity,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),

          // Description Section
          Text(
            'DESCRIPTION',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, width: 1.0),
            ),
            padding: const EdgeInsets.all(16),
            child: Text(
              p.description.isNotEmpty ? '• ${p.description}' : '-',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Policies & Rules
          Text(
            'POLICIES & RULES',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, width: 1.0),
            ),
            padding: const EdgeInsets.all(16),
            child: p.policies.isEmpty
                ? Text('-', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white54 : Colors.black54))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: p.policies.map((policy) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          '• $policy',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatsTab(bool isDark) {
    if (_property == null) return const SizedBox.shrink();
    final p = _property!;

    Widget buildStatCard(String label, int value, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  '$value',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildDetailRow(String label, int count, Color color) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: color, width: 1.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: buildStatCard('TOTAL LEADS', p.leadsCount, Icons.show_chart, const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildStatCard('TOTAL VISITS', p.visitsSummary.total, Icons.home_outlined, const Color(0xFF2563EB)),
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          Text(
            'VISITS DETAIL',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
            ),
            child: Column(
              children: [
                buildDetailRow('Scheduled Visits', p.visitsSummary.scheduled, const Color(0xFF2563EB)),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]!),
                buildDetailRow('Completed Visits', p.visitsSummary.completed, const Color(0xFF10B981)),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]!),
                buildDetailRow('Cancelled Visits', p.visitsSummary.cancelled, const Color(0xFFEF4444)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab(bool isDark) {
    if (_property == null) return const SizedBox.shrink();
    final p = _property!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!, width: 1.0),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, size: 28, color: isDark ? Colors.white54 : Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Property Brochure',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PDF Document',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final uri = Uri.parse('https://trevion.browndevs.com/public/properties/${p.id}');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    'Download',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCCCCCC), width: 1.0),
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
