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
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Top Notch indicator
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Redesigned Blue Header Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          Property.getDisplayLabel(project.category).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.home_work_outlined, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    project.location?.city.isNotEmpty == true 
                                        ? "${project.location!.city}, ${project.location!.state}"
                                        : "Location not added yet",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
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
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Redesigned TabBar as capsule segmented control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "Overview"),
                    Tab(text: "Stats & Visits"),
                    Tab(text: "Media & Plans"),
                  ],
                ),
              ),
            ),

            // TabBarView Content
            Expanded(
              child: Container(
                color: Colors.transparent,
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
            Container(
              color: isDark ? const Color(0xFF1A1A24) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Created: ${project.createdBy ?? 'Admin'}",
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                  Text(
                    "Updated: ${project.updatedBy ?? 'Admin'}",
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[500], fontWeight: FontWeight.w500),
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
    final theme = Theme.of(context);
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
        // Premium card container holding row details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildOverviewRow(Icons.grid_view_rounded, "TOTAL AREA", project.totalArea != null && project.totalArea!.value > 0 ? "${project.totalArea!.value} ${project.totalArea!.unit}" : "-", isDark),
              const Divider(height: 24, thickness: 0.5, color: Colors.black12),
              _buildOverviewRow(Icons.location_on_outlined, "FULL ADDRESS", fullAddress.toLowerCase().contains('no address') ? "-" : fullAddress, isDark),
              const Divider(height: 24, thickness: 0.5, color: Colors.black12),
              _buildOverviewRow(Icons.work_outline_rounded, "RERA ID", project.reraId ?? "-", isDark),
              if (possessionStr != null) ...[
                const Divider(height: 24, thickness: 0.5, color: Colors.black12),
                _buildOverviewRow(Icons.calendar_today_outlined, "POSSESSION DATE", possessionStr, isDark),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Amenities & key features section header
        const Text(
          "Amenities & key features",
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // If description is empty and safeAmenities is empty, show empty state dashboard card!
        if (project.description.isEmpty && safeAmenities.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.star_outline_rounded, 
                    color: isDark ? Colors.white70 : const Color(0xFF2563EB), 
                    size: 24
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "No amenities or key features listed yet.",
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  "Add details to help visitors know more.",
                  style: TextStyle(
                    fontSize: 12, 
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          // Key features card
          if (project.description.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "KEY FEATURES",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    project.description,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ],
              ),
            ),
          // Amenities card
          if (safeAmenities.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AMENITIES",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
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
        ],
      ],
    );
  }

  Widget _buildOverviewRow(IconData icon, String label, String value, bool isDark) {
    final isNotAdded = value == '-' || value.isEmpty || value.toLowerCase().contains('no address') || value.toLowerCase().contains('not added');

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon, 
            size: 18, 
            color: isDark ? Colors.white70 : const Color(0xFF2563EB)
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isNotAdded ? "Not added yet" : value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isNotAdded ? (isDark ? Colors.grey[500] : const Color(0xFF94A3B8)) : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildEmptyStateBanner(String text, IconData icon, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D4ED8), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF0F9FF) : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(Project project, bool isDark) {
    final theme = Theme.of(context);
    final visitsState = ref.watch(projectVisitsProvider(project.id));
    final propertiesState = ref.watch(projectPropertiesProvider(project.id));

    final propertyState = ref.watch(propertyProvider);
    final currentProject = propertyState.projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );

    final Map<String, int> propertiesByType = {};
    for (final prop in propertiesState.properties) {
      final rawType = prop.propertyType.isNotEmpty ? prop.propertyType : 'Other';
      final type = rawType.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : w).join(' ');
      propertiesByType[type] = (propertiesByType[type] ?? 0) + 1;
    }

    final hasPropertyTypeData = propertiesByType.isNotEmpty;

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
                child: _buildMetricCard("PROPERTIES", Icons.home, "${currentProject.propertiesCount}", Colors.pink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Properties by Category Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PROPERTIES BY CATEGORY",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              if (categoriesMap.isEmpty)
                _buildEmptyStateBanner("No properties added yet", Icons.home_work_outlined, isDark)
              else
                ...categoriesMap.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _toTitleCase(Property.getDisplayLabel(entry.key)),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: Text(
                              "${entry.value}",
                              style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 12),
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
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PROPERTIES BY LISTING TYPE",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              if (listingTypesMap.isEmpty)
                _buildEmptyStateBanner("No properties added yet", Icons.home_work_outlined, isDark)
              else
                ...listingTypesMap.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _toTitleCase(Property.getDisplayLabel(entry.key)),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Text(
                              "${entry.value}",
                              style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 12),
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
        if (hasPropertyTypeData) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PROPERTIES BY TYPE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
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
                            _toTitleCase(Property.getDisplayLabel(entry.key)),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: Text(
                              "${entry.value}",
                              style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Visits Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "VISITS SUMMARY",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Visit records",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectDetailScreen(project: project),
                    ),
                  );
                },
                child: const Text(
                  "View all",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

    Color statusTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    Color statusBgColor = isDark ? Colors.white10 : Colors.grey[100]!;
    Color statusBorderColor = isDark ? Colors.white24 : Colors.grey[300]!;

    switch (visit.status) {
      case 'Scheduled':
        statusTextColor = const Color(0xFF1D4ED8);
        statusBgColor = const Color(0xFFEFF6FF);
        statusBorderColor = const Color(0xFF93C5FD);
        break;
      case 'Completed':
        statusTextColor = const Color(0xFF15803D);
        statusBgColor = const Color(0xFFF0FDF4);
        statusBorderColor = const Color(0xFF86EFAC);
        break;
      case 'Cancelled':
        statusTextColor = const Color(0xFFC62828);
        statusBgColor = const Color(0xFFFFEBEE);
        statusBorderColor = const Color(0xFFFFCDD2);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.home_work_outlined, 
              color: isDark ? Colors.white70 : const Color(0xFF2563EB), 
              size: 16
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.lead?.name ?? 'Unknown Lead',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (visit.property != null && visit.property!.name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.house_outlined, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        visit.property!.name,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                if (dt != null)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(dt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusBorderColor),
            ),
            child: Text(
              visit.status,
              style: TextStyle(
                color: statusTextColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, IconData icon, String value, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color iconBgColor = const Color(0xFFEFF6FF);
    Color iconColor = const Color(0xFF2563EB);
    if (label.contains("PROPERTIES")) {
      iconBgColor = const Color(0xFFFDF2F8);
      iconColor = const Color(0xFFDB2777);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: isDark ? Colors.white70 : iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitRow(String title, int count, Color baseColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor = baseColor.withValues(alpha: 0.05);
    Color contentColor = baseColor;

    if (title.contains("Scheduled")) {
      bgColor = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);
      contentColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
    } else if (title.contains("Completed")) {
      bgColor = isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFF0FDF4);
      contentColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534);
    } else if (title.contains("Cancelled")) {
      bgColor = isDark ? const Color(0xFF991B1B).withValues(alpha: 0.3) : const Color(0xFFFEF2F2);
      contentColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: contentColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: contentColor, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 13
                ),
              ),
            ],
          ),
          Text(
            "$count",
            style: TextStyle(
              color: contentColor, 
              fontWeight: FontWeight.bold, 
              fontSize: 14
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab(Project project, List<String> safeImages, List<String> safeVideos, bool isDark) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // R2 Photo Gallery Section
        if (safeImages.isNotEmpty) ...[
          Text(
            "PROJECT GALLERY",
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B), 
              letterSpacing: 0.5
            ),
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
          Text(
            "PROJECT VIDEOS",
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B), 
              letterSpacing: 0.5
            ),
          ),
          const SizedBox(height: 12),
          ...safeVideos.map((videoUrl) => GestureDetector(
                onTap: () => MediaHelper.launchMediaUrl(context, videoUrl),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
        Text(
          "DOCUMENTS & PLANS",
          style: TextStyle(
            fontSize: 10, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B), 
            letterSpacing: 0.5
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
              Text(
                "PAYMENT PLAN",
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B)
                ),
              ),
              const SizedBox(height: 8),
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
