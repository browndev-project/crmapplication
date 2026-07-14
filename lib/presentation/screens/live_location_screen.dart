import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:crmapp/presentation/widgets/global_app_bar.dart';
import 'package:crmapp/presentation/providers/live_location_provider.dart';
import 'package:crmapp/presentation/providers/permissions_provider.dart';
import 'package:crmapp/presentation/providers/login_provider.dart';
import 'package:crmapp/data/models/location_model.dart';
import 'package:crmapp/data/models/property_model.dart';
import 'package:intl/intl.dart';
import 'package:crmapp/core/utils/roles.dart';
import 'package:crmapp/presentation/widgets/access_denied_widget.dart';

class LiveLocationScreen extends ConsumerStatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  ConsumerState<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends ConsumerState<LiveLocationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;

    if (!SystemRoles.canViewCompanyPanel(user?.systemRole)) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Live Location'),
        body: AccessDeniedWidget(
          sectionName: "Live Location",
          showAppBar: false,
        ),
      );
    }

    final state = ref.watch(liveLocationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<LiveLocationState>(liveLocationProvider, (previous, next) {
      if (previous?.viewMode != next.viewMode ||
          previous?.selectedProjectId != next.selectedProjectId ||
          previous?.selectedRole != next.selectedRole ||
          (previous?.isLoading == true && next.isLoading == false)) {
        _fitBounds(next);
      }
    });

    return Scaffold(
      appBar: const GlobalAppBar(title: 'Live Location'),

      body: Column(
        children: [
          // ── Toggle Bar ──
          _buildToggleBar(state, isDark),
          // ── Filter Bar ──
          if (state.viewMode == LiveViewMode.staff) _buildRoleFilters(state, isDark),
          if (state.viewMode == LiveViewMode.business) ...[
            _buildProjectSelector(state, isDark),
            _buildRoleSelector(state, isDark),
          ],
          // ── Map ──
          Expanded(child: _buildMap(state, isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => ref.read(liveLocationProvider.notifier).refresh(),
        backgroundColor: Colors.black,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  // ─────────────────── Toggle Bar ───────────────────
  Widget _buildToggleBar(LiveLocationState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toggleChip('Staff', Icons.people, state.viewMode == LiveViewMode.staff, isDark, () {
            ref.read(liveLocationProvider.notifier).switchView(LiveViewMode.staff);
          }),
          _toggleChip('Business', Icons.business, state.viewMode == LiveViewMode.business, isDark, () {
            ref.read(liveLocationProvider.notifier).switchView(LiveViewMode.business);
          }),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, IconData icon, bool selected, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : (isDark ? Colors.white54 : Colors.black54)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────── Role Filters ───────────────────
  Widget _buildRoleFilters(LiveLocationState state, bool isDark) {
    final roles = [
      {'label': 'All', 'value': ''},
      {'label': 'Managers', 'value': 'sales_manager'},
      {'label': 'Leaders', 'value': 'team_leader'},
      {'label': 'Executives', 'value': 'sales_executive'},
    ];
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: roles.length,
        separatorBuilder: (_, a) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = roles[i];
          final selected = state.selectedRole == r['value'];
          return ChoiceChip(
            label: Text(r['label']!, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
            selected: selected,
            selectedColor: Colors.black,
            backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
            side: BorderSide.none,
            onSelected: (_) {
              ref.read(liveLocationProvider.notifier).selectRole(r['value']!);
            },
          );
        },
      ),
    );
  }

  // ─────────────────── Project Selector ───────────────────
  Widget _buildProjectSelector(LiveLocationState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: state.selectedProjectId,
          hint: Text('Select a Project', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
          dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          items: state.projects.map((p) {
            return DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)));
          }).toList(),
          onChanged: (val) {
            ref.read(liveLocationProvider.notifier).selectProject(val);
          },
        ),
      ),
    );
  }

  // ─────────────────── Role Selector (Business View) ───────────────────
  Widget _buildRoleSelector(LiveLocationState state, bool isDark) {
    final roles = [
      {'label': 'All Staff Types', 'value': ''},
      {'label': 'Sales Managers', 'value': 'sales_manager'},
      {'label': 'Team Leaders', 'value': 'team_leader'},
      {'label': 'Sales Executives', 'value': 'sales_executive'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: state.selectedRole,
          hint: Text('Filter by Staff Type', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
          dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          items: roles.map((r) {
            return DropdownMenuItem(
              value: r['value'],
              child: Text(r['label']!, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (val) {
            ref.read(liveLocationProvider.notifier).selectRole(val!);
          },
        ),
      ),
    );
  }

  // ─────────────────── Map ───────────────────
  Widget _buildMap(LiveLocationState state, bool isDark) {
    // Default center (India)
    LatLng center = const LatLng(20.5937, 78.9629);
    double zoom = 5.0;

    if (state.viewMode == LiveViewMode.staff && state.mappableStaff.isNotEmpty) {
      center = LatLng(state.mappableStaff.first.lat!, state.mappableStaff.first.lng!);
      zoom = 10.0;
    } else if (state.viewMode == LiveViewMode.business) {
      if (state.selectedProjectId != null) {
        final proj = state.projects.where((p) => p.id == state.selectedProjectId).toList();
        if (proj.isNotEmpty && proj.first.location?.lat != null) {
          center = LatLng(proj.first.location!.lat!, proj.first.location!.lng!);
          zoom = 13.0;
        }
      } else if (state.mappableProjects.isNotEmpty) {
        center = LatLng(state.mappableProjects.first.location!.lat!, state.mappableProjects.first.location!.lng!);
        zoom = 8.0;
      }
    }

    final tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: zoom),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'com.trevioncrm',
            ),
            MarkerLayer(markers: _buildMarkers(state)),
          ],
        ),
        // Error indicator
        if (state.error != null)
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Error: ${state.error}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        // Loading indicator
        if (state.isLoading)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
          ),
        // Legend
        Positioned(bottom: 16, left: 16, child: _buildLegend(state, isDark)),
        // Stats
        Positioned(top: 12, right: 12, child: _buildStatsChip(state, isDark)),
      ],
    );
  }

  List<Marker> _buildMarkers(LiveLocationState state) {
    final markers = <Marker>[];

    if (state.viewMode == LiveViewMode.staff) {
      for (final staff in state.mappableStaff) {
        markers.add(Marker(
          point: LatLng(staff.lat!, staff.lng!),
          width: 140,
          height: 80,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showStaffDetails(staff),
            child: _PulsingStaffMarker(
              animation: _pulseAnimation,
              name: staff.name,
              role: staff.systemRole,
            ),
          ),
        ));
      }
    } else {
      // Business view: project pins
      if (state.selectedProjectId == null) {
        for (final proj in state.mappableProjects) {
          markers.add(Marker(
            point: LatLng(proj.location!.lat!, proj.location!.lng!),
            width: 140,
            height: 80,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _showProjectDetails(proj),
              child: _ProjectMarker(name: proj.name),
            ),
          ));
        }
      } else {
        // Show properties for selected project
        for (final prop in state.mappableProperties) {
          markers.add(Marker(
            point: LatLng(prop.location!.lat!, prop.location!.lng!),
            width: 140,
            height: 80,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _showPropertyDetails(prop),
              child: _PropertyMarker(name: prop.name, type: prop.propertyType),
            ),
          ));
        }

        // ALSO show the project pin itself as the central anchor
        final selectedProj = state.projects.firstWhere((p) => p.id == state.selectedProjectId);
        if (selectedProj.location?.lat != null && selectedProj.location?.lng != null) {
          markers.add(Marker(
            point: LatLng(selectedProj.location!.lat!, selectedProj.location!.lng!),
            width: 140,
            height: 80,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _showProjectDetails(selectedProj),
              child: _ProjectMarker(name: selectedProj.name),
            ),
          ));
        }

        // Nearby staff around the project (filtered by role)
        for (final ns in state.mappableNearbyStaff) {
          markers.add(Marker(
            point: LatLng(ns.lat!, ns.lng!),
            width: 140,
            height: 80,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _showNearbyStaffDetails(ns),
              child: _PulsingStaffMarker(
                animation: _pulseAnimation,
                name: ns.name,
                role: ns.systemRole ?? '',
              ),
            ),
          ));
        }
      }
    }
    return markers;
  }

  void _fitBounds(LiveLocationState state) {
    final points = <LatLng>[];

    bool isValid(double? d) => d != null && d.isFinite;

    if (state.viewMode == LiveViewMode.staff) {
      for (final s in state.mappableStaff) {
        if (isValid(s.lat) && isValid(s.lng)) {
          points.add(LatLng(s.lat!, s.lng!));
        }
      }
    } else {
      if (state.selectedProjectId == null) {
        for (final p in state.mappableProjects) {
          if (isValid(p.location?.lat) && isValid(p.location?.lng)) {
            points.add(LatLng(p.location!.lat!, p.location!.lng!));
          }
        }
      } else {
        final proj = state.projects.where((p) => p.id == state.selectedProjectId).toList();
        if (proj.isNotEmpty && isValid(proj.first.location?.lat) && isValid(proj.first.location?.lng)) {
          points.add(LatLng(proj.first.location!.lat!, proj.first.location!.lng!));
        }
        for (final p in state.mappableProperties) {
          if (isValid(p.location?.lat) && isValid(p.location?.lng)) {
            points.add(LatLng(p.location!.lat!, p.location!.lng!));
          }
        }
        for (final s in state.mappableNearbyStaff) {
          if (isValid(s.lat) && isValid(s.lng)) {
            points.add(LatLng(s.lat!, s.lng!));
          }
        }
      }
    }

    if (points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (points.length == 1) {
            _mapController.move(points.first, 15.0);
          } else {
            final bounds = LatLngBounds.fromPoints(points);
            // Check if bounds are essentially a single point
            if (bounds.north == bounds.south && bounds.east == bounds.west) {
               _mapController.move(points.first, 15.0);
            } else {
               _mapController.fitCamera(CameraFit.bounds(
                 bounds: bounds, 
                 padding: const EdgeInsets.all(50.0),
                 maxZoom: 17.0,
               ));
            }
          }
        } catch (e) {
          debugPrint('Error fitting bounds: $e');
        }
      });
    }
  }

  void _showStaffDetails(StaffLocationUser staff) {
    _showCustomBottomSheet(
      title: staff.name,
      fields: {
        'ROLE': staff.systemRole.replaceAll('_', ' ').toLowerCase(),
        'EMAIL': staff.email ?? 'N/A',
        'PHONE': staff.phoneNo ?? 'N/A',
        'COORDINATES': staff.lat != null && staff.lng != null ? '${staff.lat}, ${staff.lng}' : 'N/A',
      },
      lastAddress: staff.lastAddress ?? 'N/A',
      lastUpdated: staff.lastSeen != null 
          ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(staff.lastSeen!).toLocal()) 
          : 'N/A',
    );
  }

  void _showNearbyStaffDetails(NearbyStaffUser staff) {
    _showCustomBottomSheet(
      title: staff.name,
      fields: {
        'ROLE': (staff.systemRole ?? 'Staff').replaceAll('_', ' ').toLowerCase(),
        'EMAIL': staff.email ?? 'N/A',
        'PHONE': staff.phone ?? 'N/A',
        'DISTANCE': '${(staff.distance / 1000).toStringAsFixed(2)} km away',
        'COORDINATES': staff.lat != null && staff.lng != null ? '${staff.lat}, ${staff.lng}' : 'N/A',
      },
      lastAddress: staff.lastAddress ?? 'N/A',
      lastUpdated: staff.lastSeen != null 
          ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(staff.lastSeen!).toLocal()) 
          : 'N/A',
    );
  }

  void _showProjectDetails(Project project) {
    _showCustomBottomSheet(
      title: project.name,
      fields: {
        'CATEGORY': project.category.toUpperCase(),
        'STATUS': project.status.replaceAll('_', ' ').toUpperCase(),
        'DEVELOPER': project.developerName.isEmpty ? 'N/A' : project.developerName,
        'COORDINATES': project.location?.lat != null && project.location?.lng != null ? '${project.location!.lat}, ${project.location!.lng}' : 'N/A',
      },
      lastAddress: [project.location?.address1, project.location?.address2, project.location?.city, project.location?.state].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ').isEmpty ? 'N/A' : [project.location?.address1, project.location?.address2, project.location?.city, project.location?.state].where((e) => e != null && e.toString().trim().isNotEmpty).join(', '),
      lastUpdated: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(project.updatedAt).toLocal()),
    );
  }

  void _showPropertyDetails(Property property) {
    _showCustomBottomSheet(
      title: property.name,
      fields: {
        'PROJECT': property.project?.name ?? 'N/A',
        'TYPE': property.propertyType.toUpperCase(),
        'STATUS': property.status.toUpperCase(),
        'PRICE': '₹${property.price}',
        'COORDINATES': property.location?.lat != null && property.location?.lng != null ? '${property.location!.lat}, ${property.location!.lng}' : 'N/A',
      },
      lastAddress: [property.location?.address1, property.location?.address2, property.location?.city, property.location?.state].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ').isEmpty ? 'N/A' : [property.location?.address1, property.location?.address2, property.location?.city, property.location?.state].where((e) => e != null && e.toString().trim().isNotEmpty).join(', '),
      lastUpdated: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(property.updatedAt).toLocal()),
    );
  }

  void _showCustomBottomSheet({
    required String title,
    required Map<String, String> fields,
    required String lastAddress,
    required String lastUpdated,
  }) {
 Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black))),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(backgroundColor: Colors.grey.withValues(alpha: 0.1)),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1, color: Colors.black12),
            
            // Fields
            ...fields.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(e.value, style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500)),
                ],
              ),
            )),
            
            // Address box
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LAST ADDRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(lastAddress, style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Last Updated
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LAST UPDATED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(lastUpdated, style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color getRoleColor(String role) {
    switch (role) {
      case 'sales_manager': return const Color(0xFF00BFA5);
      case 'team_leader': return const Color(0xFF448AFF);
      case 'sales_executive': return const Color(0xFFFF9800);
      default: return const Color(0xFF00BFA5);
    }
  }

  String formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}';
    } catch (_) {
      return timestamp;
    }
  }

  Widget _buildLegend(LiveLocationState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: state.viewMode == LiveViewMode.staff
            ? [
                _legendItem(const Color(0xFF00BFA5), 'Managers'),
                _legendItem(const Color(0xFF448AFF), 'Leaders'),
                _legendItem(const Color(0xFFFF9800), 'Executives'),
              ]
            : [
                _legendItem(const Color(0xFFE91E63), 'Projects'),
                _legendItem(const Color(0xFF7C4DFF), 'Properties'),
                _legendItem(const Color(0xFF00BFA5), 'Nearby Staff'),
              ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatsChip(LiveLocationState state, bool isDark) {
    final count = state.viewMode == LiveViewMode.staff
        ? state.mappableStaff.length
        : (state.selectedProjectId != null ? state.mappableProperties.length : state.mappableProjects.length);
    final label = state.viewMode == LiveViewMode.staff ? 'Staff on map' : 'Locations';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count $label', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────── Marker Label ───────────────────
class _MarkerLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color iconColor;
  
  const _MarkerLabel({required this.text, this.icon, this.iconColor = Colors.black});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(text, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Pulsing Staff Marker ───────────────────
class _PulsingStaffMarker extends StatelessWidget {
  final Animation<double> animation;
  final String name;
  final String role;

  const _PulsingStaffMarker({required this.animation, required this.name, required this.role});

  Color get _color {
    switch (role) {
      case 'sales_manager': return const Color(0xFF00BFA5);
      case 'team_leader': return const Color(0xFF448AFF);
      case 'sales_executive': return const Color(0xFFFF9800);
      default: return const Color(0xFF00BFA5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MarkerLabel(text: name),
        const SizedBox(height: 2),
        SizedBox(
          width: 50,
          height: 50,
          child: AnimatedBuilder(
            animation: animation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pin Icon
                Icon(Icons.location_on, color: _color, size: 36),
                // White dot in pin
                Positioned(
                  top: 8,
                  child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
              ],
            ),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer continuous wave
                  Container(
                    width: 20 + (30 * animation.value),
                    height: 20 + (30 * animation.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _color.withValues(alpha: 1.0 - animation.value), width: 1.5),
                      color: _color.withValues(alpha: (1.0 - animation.value) * 0.2),
                    ),
                  ),
                  if (child != null) child,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────── Project Marker ───────────────────
class _ProjectMarker extends StatelessWidget {
  final String name;
  const _ProjectMarker({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MarkerLabel(text: name, icon: Icons.business, iconColor: const Color(0xFFE91E63)),
        const SizedBox(height: 2),
        Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.location_on, color: Color(0xFFE91E63), size: 36),
            Positioned(
              top: 6,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.business, color: Color(0xFFE91E63), size: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────── Property Marker ───────────────────
class _PropertyMarker extends StatelessWidget {
  final String name;
  final String type;
  const _PropertyMarker({required this.name, required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MarkerLabel(text: name, icon: Icons.home, iconColor: const Color(0xFF7C4DFF)),
        const SizedBox(height: 2),
        Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.location_on, color: Color(0xFF7C4DFF), size: 32),
            Positioned(
              top: 5,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.home, color: Color(0xFF7C4DFF), size: 9),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
