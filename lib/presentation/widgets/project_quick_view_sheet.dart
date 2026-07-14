import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/property_model.dart';
import '../providers/visit_provider.dart';
import '../../data/models/visit_model.dart';
import '../../core/utils/date_utils.dart';
import '../screens/project_detail_screen.dart';
import '../providers/property_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/media_helper.dart';
import '../screens/all_properties_screen.dart';

class ProjectQuickViewSheet extends ConsumerStatefulWidget {
  final Project project;

  const ProjectQuickViewSheet({super.key, required this.project});

  @override
  ConsumerState<ProjectQuickViewSheet> createState() => _ProjectQuickViewSheetState();
}

class _ProjectQuickViewSheetState extends ConsumerState<ProjectQuickViewSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final project = widget.project;

    final dynamic rawAmenities = (project.amenities as dynamic);
    final safeAmenities = rawAmenities != null ? (List<String>.from(rawAmenities.map((e) => e?.toString() ?? ''))).where((e) => e.isNotEmpty).toList() : const <String>[];
    
    final dynamic rawImages = (project.images as dynamic);
    final safeImages = rawImages != null ? (List<String>.from(rawImages.map((e) => e?.toString() ?? ''))).where((e) => e.isNotEmpty).toList() : const <String>[];
    
    final dynamic rawVideos = (project.videos as dynamic);
    final safeVideos = rawVideos != null ? (List<String>.from(rawVideos.map((e) => e?.toString() ?? ''))).where((e) => e.isNotEmpty).toList() : const <String>[];

    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(context).size.height * 1.0,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Top Notch indicator
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Property.getDisplayLabel(project.category).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Go to Project Workspace Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailScreen(project: project),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        "Go to Project Workspace",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // TabBar
            TabBar(
              tabs: const [
                Tab(text: "Overview"),
                Tab(text: "Stats & Visits"),
                Tab(text: "Media & Plans"),
              ],
              indicatorColor: isDark ? Colors.white : Colors.black,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: isDark ? Colors.white : Colors.black,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const Divider(height: 1, thickness: 0.5),

            // TabBarView Content
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
                child: TabBarView(
                  children: [
                    _buildOverviewTab(project, safeAmenities, isDark),
                    _buildStatsTab(project, isDark),
                    _buildMediaTab(project, safeImages, safeVideos, isDark),
                  ],
                ),
              ),
            ),

            // Footer Section
            const Divider(height: 1, thickness: 0.5),
            Container(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Created: ${project.createdBy ?? 'Admin'}",
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  Text(
                    "Updated: ${project.updatedBy ?? 'Admin'}",
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Project project, List<String> safeAmenities, bool isDark) {
    final fullAddress = project.location != null
        ? [
            if (project.location!.address1.isNotEmpty) project.location!.address1,
            if (project.location!.address2.isNotEmpty) project.location!.address2,
            if (project.location!.city.isNotEmpty) project.location!.city,
            if (project.location!.state.isNotEmpty) project.location!.state,
            if (project.location!.pincode != null && project.location!.pincode!.isNotEmpty) project.location!.pincode,
            if (project.location!.country.isNotEmpty) project.location!.country,
          ].join(', ')
        : 'No address';

    final possessionDt = project.possessionDate != null
        ? DateTimeUtils.parseSafe(project.possessionDate!)
        : null;
    final possessionStr = possessionDt != null
        ? DateFormat('dd MMM yyyy').format(possessionDt)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _buildOverviewRow(Icons.home_work_outlined, "TOTAL AREA", project.totalArea != null ? "${project.totalArea!.value} ${project.totalArea!.unit}" : "-", isDark),
              const Divider(height: 20, thickness: 0.5),
              _buildOverviewRow(Icons.location_on_outlined, "FULL ADDRESS", fullAddress, isDark),
              const Divider(height: 20, thickness: 0.5),
              _buildOverviewRow(Icons.badge_outlined, "RERA ID", project.reraId ?? "-", isDark),
              if (possessionStr != null) ...[
                const Divider(height: 20, thickness: 0.5),
                _buildOverviewRow(Icons.calendar_today_outlined, "POSSESSION DATE", possessionStr, isDark),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Key Features Section
        if (project.description.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "KEY FEATURES",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  project.description,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ],
            ),
          ),

        if (project.description.isNotEmpty && safeAmenities.isNotEmpty)
          const SizedBox(height: 16),

        // Amenities Section
        if (safeAmenities.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AMENITIES",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                ...safeAmenities.map((amenity) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              amenity,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

        if (safeAmenities.isEmpty && project.description.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: const Text(
              "No amenities or key features listed.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(Project project, bool isDark) {
    final visitsState = ref.watch(projectVisitsProvider(project.id));
    final propertiesState = ref.watch(projectPropertiesProvider(project.id));

    final propertyState = ref.watch(propertyProvider);
    final currentProject = propertyState.projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );

    // Compute property counts by type from already loaded properties
    final Map<String, int> propertiesByType = {};
    for (final prop in propertiesState.properties) {
      final rawType = prop.propertyType.isNotEmpty ? prop.propertyType : 'Other';
      final type = rawType.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : w).join(' ');
      propertiesByType[type] = (propertiesByType[type] ?? 0) + 1;
    }

    final hasPropertyTypeData = propertiesByType.isNotEmpty;

    // Compute categories map - prefer loaded properties list if available
    final Map<String, int> categoriesMap = {};
    if (propertiesState.properties.isNotEmpty) {
      for (final prop in propertiesState.properties) {
        final category = prop.category.isNotEmpty ? prop.category : 'Other';
        categoriesMap[category] = (categoriesMap[category] ?? 0) + 1;
      }
    } else {
      if (currentProject.propertyCategoryCounts.isNotEmpty) {
        for (final stat in currentProject.propertyCategoryCounts) {
          if (stat.count > 0) {
            categoriesMap[stat.id] = stat.count;
          }
        }
      }
      if (categoriesMap.isEmpty && currentProject.propertiesCount > 0) {
        categoriesMap['residential'] = currentProject.propertiesCount;
      }
    }

    // Compute listing types map
    String formatListingType(String raw) {
      final lower = raw.toLowerCase();
      if (lower == 'sell' || lower == 'sale') return 'sell';
      if (lower == 'rent') return 'rent';
      return Property.toSnakeCase(raw);
    }

    final Map<String, int> listingTypesMap = {};
    if (propertiesState.properties.isNotEmpty) {
      for (final prop in propertiesState.properties) {
        final raw = prop.listingType;
        final type = formatListingType(raw);
        listingTypesMap[type] = (listingTypesMap[type] ?? 0) + 1;
      }
    } else {
      if (currentProject.propertyListingTypeCounts.isNotEmpty) {
        for (final stat in currentProject.propertyListingTypeCounts) {
          if (stat.count > 0) {
            listingTypesMap[formatListingType(stat.id)] = stat.count;
          }
        }
      }
      if (listingTypesMap.isEmpty && currentProject.propertiesCount > 0) {
        listingTypesMap['sell'] = currentProject.propertiesCount;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Two side-by-side metric cards
        Row(
          children: [
            Expanded(
              child: _buildMetricCard("TOTAL LEADS", Icons.trending_up, "${currentProject.leadsCount}", Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllPropertiesScreen(projectId: currentProject.id),
                    ),
                  );
                },
                child: _buildMetricCard("PROPERTIES", Icons.home, "${currentProject.propertiesCount}", Colors.purple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Properties by Category Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "PROPERTIES BY CATEGORY",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              if (categoriesMap.isEmpty)
                const Text(
                  "No properties",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                )
              else
                ...categoriesMap.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${entry.value}",
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Properties by Listing Type Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "PROPERTIES BY LISTING TYPE",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              if (listingTypesMap.isEmpty)
                const Text(
                  "No properties",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                )
              else
                ...listingTypesMap.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                             Property.getDisplayLabel(entry.key),
                             style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                           ),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                             decoration: BoxDecoration(
                               color: Colors.green.withValues(alpha: 0.08),
                               borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${entry.value}",
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Properties by Type Card (if data available)
        if (hasPropertyTypeData)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "PROPERTIES BY TYPE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...propertiesByType.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                             Property.getDisplayLabel(entry.key),
                             style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                           ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${entry.value}",
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

        if (hasPropertyTypeData) const SizedBox(height: 16),

        // Visits Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "VISITS SUMMARY",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildVisitRow("Scheduled Visits", visitsState.scheduledCount, Colors.blue),
              const SizedBox(height: 12),
              _buildVisitRow("Completed Visits", visitsState.completedCount, Colors.green),
              const SizedBox(height: 12),
              _buildVisitRow("Cancelled Visits", visitsState.cancelledCount, Colors.red),
            ],
          ),
        ),

        // Real-time Visits Records List
        if (visitsState.isLoading)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visitsState.visits.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            "VISIT RECORDS",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: visitsState.visits.length,
            itemBuilder: (context, index) {
              return _buildCompactVisitCard(visitsState.visits[index], isDark);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCompactVisitCard(Visit visit, bool isDark) {
    final theme = Theme.of(context);
    DateTime? dt;
    try {
      if (visit.dateTime.isNotEmpty) {
        dt = DateTimeUtils.parseSafe(visit.dateTime);
      }
    } catch (_) {}

    Color statusColor;
    switch (visit.status) {
      case 'Scheduled':
        statusColor = const Color(0xFF6366F1);
        break;
      case 'Completed':
        statusColor = const Color(0xFF10B981);
        break;
      case 'Cancelled':
        statusColor = const Color(0xFFF43F5E);
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                visit.lead?.name ?? 'Unknown Lead',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                visit.status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (dt != null)
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(dt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          if (visit.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              visit.description,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitRow(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            "$count",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab(Project project, List<String> safeImages, List<String> safeVideos, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // R2 Photo Gallery Section
        if (safeImages.isNotEmpty) ...[
          const Text(
            "PROJECT GALLERY",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: safeImages.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => MediaHelper.launchMediaUrl(context, safeImages[index]),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    image: DecorationImage(
                      image: NetworkImage(safeImages[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // R2 Videos Section
        if (safeVideos.isNotEmpty) ...[
          const Text(
            "PROJECT VIDEOS",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ...safeVideos.map((videoUrl) => GestureDetector(
                onTap: () => MediaHelper.launchMediaUrl(context, videoUrl),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          videoUrl,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => MediaHelper.launchMediaUrl(context, videoUrl),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 24),
        ],

        // Brochure Download Section
        const Text(
          "DOCUMENTS & PLANS",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (project.brochureUrl != null && project.brochureUrl!.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text(
                          "Project Brochure.pdf",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(project.brochureUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text("Download"),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 0.5),
              ],
              const Text(
                "PAYMENT PLAN",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                (project.paymentPlan != null && project.paymentPlan!.isNotEmpty) 
                    ? project.paymentPlan! 
                    : "No payment plan custom configurations specified.",
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
