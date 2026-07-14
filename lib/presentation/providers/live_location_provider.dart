import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/staff_service.dart';
import '../../core/services/property_service.dart';
import '../../data/models/location_model.dart';
import '../../data/models/property_model.dart';

enum LiveViewMode { staff, business }

class LiveLocationState {
  final LiveViewMode viewMode;
  final List<StaffLocationUser> staffUsers;
  final List<Project> projects;
  final List<Property> properties;
  final List<NearbyStaffUser> nearbyStaff;
  final String selectedRole; // '' means all
  final String? selectedProjectId;
  final bool isLoading;
  final String? error;

  LiveLocationState({
    this.viewMode = LiveViewMode.staff,
    this.staffUsers = const [],
    this.projects = const [],
    this.properties = const [],
    this.nearbyStaff = const [],
    this.selectedRole = '',
    this.selectedProjectId,
    this.isLoading = false,
    this.error,
  });

  LiveLocationState copyWith({
    LiveViewMode? viewMode,
    List<StaffLocationUser>? staffUsers,
    List<Project>? projects,
    List<Property>? properties,
    List<NearbyStaffUser>? nearbyStaff,
    String? selectedRole,
    String? selectedProjectId,
    bool clearProject = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LiveLocationState(
      viewMode: viewMode ?? this.viewMode,
      staffUsers: staffUsers ?? this.staffUsers,
      projects: projects ?? this.projects,
      properties: properties ?? this.properties,
      nearbyStaff: nearbyStaff ?? this.nearbyStaff,
      selectedRole: selectedRole ?? this.selectedRole,
      selectedProjectId: clearProject ? null : (selectedProjectId ?? this.selectedProjectId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Staff filtered by selected role
  List<StaffLocationUser> get filteredStaff {
    if (selectedRole.isEmpty) return staffUsers;
    return staffUsers.where((s) => s.systemRole == selectedRole).toList();
  }

  /// Staff with valid coordinates only
  List<StaffLocationUser> get mappableStaff {
    return filteredStaff.where((s) => s.lat != null && s.lng != null).toList();
  }

  /// Projects with valid coordinates only
  List<Project> get mappableProjects {
    return projects.where((p) => p.location?.lat != null && p.location?.lng != null).toList();
  }

  /// Properties with valid coordinates only
  List<Property> get mappableProperties {
    return properties.where((p) => p.location?.lat != null && p.location?.lng != null).toList();
  }

  /// Nearby staff filtered by role and valid coordinates
  List<NearbyStaffUser> get mappableNearbyStaff {
    final filtered = selectedRole.isEmpty
        ? nearbyStaff
        : nearbyStaff.where((s) => s.systemRole == selectedRole).toList();
    return filtered.where((s) => s.lat != null && s.lng != null).toList();
  }
}

class LiveLocationNotifier extends StateNotifier<LiveLocationState> {
  final StaffService _staffService = StaffService();
  final PropertyService _propertyService = PropertyService();

  LiveLocationNotifier() : super(LiveLocationState()) {
    loadStaffData();
    _loadProjects();
  }

  void switchView(LiveViewMode mode) {
    state = state.copyWith(viewMode: mode, clearError: true);
    if (mode == LiveViewMode.staff) {
      loadStaffData();
    }
  }

  void selectRole(String role) {
    state = state.copyWith(selectedRole: role);
    // Only load nearby staff in business mode if a project is already selected
    if (state.viewMode == LiveViewMode.business && 
        state.selectedProjectId != null && 
        role.isNotEmpty) {
      _loadNearbyStaffForProject(state.selectedProjectId!);
    }
  }

  void selectProject(String? projectId) {
    state = state.copyWith(selectedProjectId: projectId);
    if (projectId != null && projectId.isNotEmpty) {
      _loadPropertiesForProject(projectId);
      // Only load nearby staff if a role is already selected
      if (state.selectedRole.isNotEmpty) {
        _loadNearbyStaffForProject(projectId);
      }
    } else {
      state = state.copyWith(properties: [], nearbyStaff: [], clearProject: true);
    }
  }

  Future<void> loadStaffData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Load all roles in parallel
      final results = await Future.wait([
        _staffService.fetchStaffWithLocations(systemRole: 'sales_manager'),
        _staffService.fetchStaffWithLocations(systemRole: 'team_leader'),
        _staffService.fetchStaffWithLocations(systemRole: 'sales_executive'),
      ]);
      final allStaff = <StaffLocationUser>[];
      for (final list in results) {
        allStaff.addAll(list);
      }
      state = state.copyWith(staffUsers: allStaff, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadProjects() async {
    try {
      final response = await _propertyService.getProjects();
      state = state.copyWith(projects: response.data.projects);
    } catch (e) {
      debugPrint('Error loading projects for location: $e');
    }
  }

  Future<void> _loadPropertiesForProject(String projectId) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _propertyService.getProperties(projectId: projectId);
      state = state.copyWith(properties: response.data.properties, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadNearbyStaffForProject(String projectId) async {
    try {
      debugPrint('DEBUG: Loading nearby staff for project: $projectId');
      // Find the project to get its coordinates
      final project = state.projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => state.projects.first,
      );
      final lat = project.location?.lat;
      final lng = project.location?.lng;
      
      debugPrint('DEBUG: Project location: $lat, $lng');
      
      if (lat != null && lng != null) {
        final nearby = await _staffService.findNearbyStaff(
          lat: lat,
          lng: lng,
          maxDistance: 10000, // Renamed parameter
          projectId: projectId,
          systemRole: state.selectedRole, // Passing the role filter to backend
        );
        debugPrint('DEBUG: Found ${nearby.length} nearby staff');
        state = state.copyWith(nearbyStaff: nearby);
      } else {
        debugPrint('DEBUG: Skipping nearby API call - lat/lng is null');
      }
    } catch (e) {
      debugPrint('DEBUG: Error loading nearby staff: $e');
    }
  }

  Future<void> refresh() async {
    if (state.viewMode == LiveViewMode.staff) {
      await loadStaffData();
    } else {
      await _loadProjects();
      if (state.selectedProjectId != null) {
        await _loadPropertiesForProject(state.selectedProjectId!);
        await _loadNearbyStaffForProject(state.selectedProjectId!);
      }
    }
  }
}

final liveLocationProvider = StateNotifierProvider<LiveLocationNotifier, LiveLocationState>((ref) {
  return LiveLocationNotifier();
});
