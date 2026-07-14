import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/property_service.dart';
import '../../data/models/property_model.dart';

class PropertyState {
  final List<Project> projects;
  final bool isLoading;
  final String? error;

  // Search & Filter parameters
  final String searchQuery;
  final String status;
  final String projectCategory;
  final String propertyCategory;
  final String? from;
  final String? to;
  final String sort;

  // Pagination
  final int page;
  final int limit;
  final bool hasNextPage;
  final int totalCount;

  PropertyState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.status = 'All Status',
    this.projectCategory = 'All Projects',
    this.propertyCategory = 'All Properties',
    this.from,
    this.to,
    this.sort = 'updated_desc',
    this.page = 1,
    this.limit = 20,
    this.hasNextPage = false,
    this.totalCount = 0,
  });

  PropertyState copyWith({
    List<Project>? projects,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? status,
    String? projectCategory,
    String? propertyCategory,
    String? from,
    String? to,
    String? sort,
    int? page,
    int? limit,
    bool? hasNextPage,
    int? totalCount,
  }) {
    return PropertyState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      status: status ?? this.status,
      projectCategory: projectCategory ?? this.projectCategory,
      propertyCategory: propertyCategory ?? this.propertyCategory,
      from: from ?? this.from,
      to: to ?? this.to,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class PropertyNotifier extends StateNotifier<PropertyState> {
  final PropertyService _service = PropertyService();

  PropertyNotifier() : super(PropertyState()) {
    fetchProjects(isRefresh: true);
  }

  Future<void> fetchProjects({bool isRefresh = false}) async {
    if (state.isLoading && !isRefresh) return;
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pageToFetch = isRefresh ? 1 : state.page;
      
      final apiStatus = _mapStatusToApi(state.status);
      final apiProjCat = _mapCategoryToApi(state.projectCategory);
      final apiPropCat = _mapCategoryToApi(state.propertyCategory);

      final response = await _service.getProjects(
        page: pageToFetch,
        limit: state.limit,
        searchQuery: state.searchQuery.trim().isNotEmpty ? state.searchQuery : null,
        status: apiStatus,
        projectCategory: apiProjCat,
        propertyCategory: apiPropCat,
        from: state.from,
        to: state.to,
        sort: state.sort,
      );

      state = state.copyWith(
        projects: isRefresh ? response.data.projects : [...state.projects, ...response.data.projects],
        isLoading: false,
        page: pageToFetch,
        hasNextPage: response.data.pagination.hasNextPage,
        totalCount: response.data.totalCount,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, page: 1);
    fetchProjects(isRefresh: true);
  }

  void setStatus(String status) {
    state = state.copyWith(status: status, page: 1);
    fetchProjects(isRefresh: true);
  }

  void setProjectCategory(String category) {
    state = state.copyWith(projectCategory: category, page: 1);
    fetchProjects(isRefresh: true);
  }

  void setPropertyCategory(String category) {
    state = state.copyWith(propertyCategory: category, page: 1);
    fetchProjects(isRefresh: true);
  }

  void setDateRange(String? from, String? to) {
    state = state.copyWith(from: from, to: to, page: 1);
    fetchProjects(isRefresh: true);
  }

  void setSort(String sort) {
    state = state.copyWith(sort: sort, page: 1);
    fetchProjects(isRefresh: true);
  }

  void applyFilters({
    required String status,
    required String projectCategory,
    required String propertyCategory,
    required String? from,
    required String? to,
    required String sort,
  }) {
    state = state.copyWith(
      status: status,
      projectCategory: projectCategory,
      propertyCategory: propertyCategory,
      from: from,
      to: to,
      sort: sort,
      page: 1,
    );
    fetchProjects(isRefresh: true);
  }

  void resetFilters() {
    state = PropertyState();
    fetchProjects(isRefresh: true);
  }

  Future<void> loadMoreProjects() async {
    if (!state.isLoading && state.hasNextPage) {
      state = state.copyWith(page: state.page + 1);
      await fetchProjects(isRefresh: false);
    }
  }

  String? _mapStatusToApi(String display) {
    if (display == 'All Status') return null;
    final parts = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    return parts.map((e) => e.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')).join(',');
  }

  String? _mapCategoryToApi(String display) {
    if (display.startsWith('All')) return null;
    final parts = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    return parts.join(',');
  }

  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    try {
      await _service.updateProject(projectId, data);
      await fetchProjects(isRefresh: true); // Refresh list to reflect changes
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> createProject(Map<String, dynamic> data) async {
    try {
      await _service.createProject(data);
      await fetchProjects(isRefresh: true); // Refresh list
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<bool> deleteProject(String projectId) async {
    try {
      await _service.deleteProject(projectId);
      await fetchProjects(isRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> bulkUpdateProjects(List<String> projectIds, Map<String, dynamic> updates) async {
    try {
      final success = await _service.bulkUpdateProjects(projectIds, updates);
      if (success) await fetchProjects(isRefresh: true);
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateProjectShareMessage(String projectId) async {
    try {
      return await _service.getProjectShareMessage(projectId);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generatePropertyShareMessage(String propertyId) async {
    try {
      return await _service.getPropertyShareMessage(propertyId);
    } catch (e) {
      rethrow;
    }
  }
}

final propertyProvider = StateNotifierProvider<PropertyNotifier, PropertyState>((ref) {
  return PropertyNotifier();
});

class ProjectPropertiesState {
  final List<Property> properties;
  final bool isLoading;
  final String? error;

  // Search & Filter parameters
  final String searchQuery;
  final String status;
  final String category;
  final String propertyType;
  final String facing;
  final int? bedrooms;
  final int? bathrooms;
  final double? minPrice;
  final double? maxPrice;
  final String areaUnit;
  final double? minArea;
  final double? maxArea;
  final String sort;
  final String direction;
  final String? projectFilter;
  
  // New Filters from Docs
  final String listingType; // "All", "Sell", "Rent"
  final String allowedTenants; // "Any", "Family", "Bachelors", "Company Lease"
  final String city;
  final String furnishingStatus; // "All", "Unfurnished", "Semi-Furnished", "Fully Furnished"
  final String preferredGender;  // "Any", "Male", "Female", "Family Only"
  final String amenities;        // comma-joined e.g. "Parking,Gym"
  final String? availableBy;     // ISO date string
  final String builtUpFilter;    // "true", "false", or ""
  final String? fromInventoryDate;
  final String? toInventoryDate;

  // Pagination
  final int page;
  final int limit;
  final bool hasNextPage;
  final int totalCount;

  ProjectPropertiesState({
    this.properties = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.status = 'all_properties',
    this.category = 'all_categories',
    this.propertyType = 'all_types',
    this.facing = 'all_facings',
    this.bedrooms,
    this.bathrooms,
    this.minPrice,
    this.maxPrice,
    this.areaUnit = 'all',
    this.minArea,
    this.maxArea,
    this.sort = 'updated_desc',
    this.direction = 'all_directions',
    this.projectFilter,
    this.listingType = 'all',
    this.allowedTenants = 'any',
    this.city = 'all_cities',
    this.furnishingStatus = 'all',
    this.preferredGender = 'any',
    this.amenities = '',
    this.availableBy,
    this.builtUpFilter = '',
    this.fromInventoryDate,
    this.toInventoryDate,
    this.page = 1,
    this.limit = 20,
    this.hasNextPage = false,
    this.totalCount = 0,
  });

  ProjectPropertiesState copyWith({
    List<Property>? properties,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? status,
    String? category,
    String? propertyType,
    String? facing,
    int? bedrooms,
    int? bathrooms,
    double? minPrice,
    double? maxPrice,
    String? areaUnit,
    double? minArea,
    double? maxArea,
    String? sort,
    String? direction,
    String? projectFilter,
    String? listingType,
    String? allowedTenants,
    String? city,
    String? furnishingStatus,
    String? preferredGender,
    String? amenities,
    String? availableBy,
    String? builtUpFilter,
    String? fromInventoryDate,
    String? toInventoryDate,
    int? page,
    int? limit,
    bool? hasNextPage,
    int? totalCount,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearMinArea = false,
    bool clearMaxArea = false,
    bool clearBedrooms = false,
    bool clearBathrooms = false,
    bool clearProjectFilter = false,
    bool clearFromInventoryDate = false,
    bool clearToInventoryDate = false,
  }) {
    return ProjectPropertiesState(
      properties: properties ?? this.properties,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      status: status ?? this.status,
      category: category ?? this.category,
      propertyType: propertyType ?? this.propertyType,
      facing: facing ?? this.facing,
      bedrooms: clearBedrooms ? null : (bedrooms ?? this.bedrooms),
      bathrooms: clearBathrooms ? null : (bathrooms ?? this.bathrooms),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      areaUnit: areaUnit ?? this.areaUnit,
      minArea: clearMinArea ? null : (minArea ?? this.minArea),
      maxArea: clearMaxArea ? null : (maxArea ?? this.maxArea),
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
      projectFilter: clearProjectFilter ? null : (projectFilter ?? this.projectFilter),
      listingType: listingType ?? this.listingType,
      allowedTenants: allowedTenants ?? this.allowedTenants,
      city: city ?? this.city,
      furnishingStatus: furnishingStatus ?? this.furnishingStatus,
      preferredGender: preferredGender ?? this.preferredGender,
      amenities: amenities ?? this.amenities,
      availableBy: availableBy ?? this.availableBy,
      builtUpFilter: builtUpFilter ?? this.builtUpFilter,
      fromInventoryDate: clearFromInventoryDate ? null : (fromInventoryDate ?? this.fromInventoryDate),
      toInventoryDate: clearToInventoryDate ? null : (toInventoryDate ?? this.toInventoryDate),
      page: page ?? this.page,
      limit: limit ?? this.limit,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class ProjectPropertiesNotifier extends StateNotifier<ProjectPropertiesState> {
  final PropertyService _service = PropertyService();
  final String projectId;
  final Ref ref;
  final bool isAllProperties;

  ProjectPropertiesNotifier(this.projectId, this.ref, {this.isAllProperties = false}) : super(ProjectPropertiesState()) {
    fetchProjectProperties(isRefresh: true, fetchAll: projectId.isEmpty);
  }

  Future<void> fetchProjectProperties({bool isRefresh = false, bool? fetchAll}) async {
    if (state.isLoading && !isRefresh) return;
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pageToFetch = isRefresh ? 1 : state.page;
      
      debugPrint('===== FETCH: preparing params =====');
      final apiStatus = _mapStatusToApi(state.status);
      final apiCat = _mapCategoryToApi(state.category);
      final apiType = _mapTypeToApi(state.propertyType);
      final apiFacing = state.facing == 'all_facings' ? null : state.facing;
      final apiDirection = state.direction == 'all_directions' ? null : state.direction;
      final apiListingType = state.listingType == 'all' ? null : state.listingType;
      final apiTenants = state.allowedTenants == 'any' ? null : state.allowedTenants;
      final apiCity = state.city == 'all_cities' ? null : state.city;
      final apiFurnishing = state.furnishingStatus == 'all' ? null : state.furnishingStatus;
      final apiPreferredGender = state.preferredGender == 'any' ? null : state.preferredGender;
      final apiAmenities = state.amenities.isEmpty ? null : state.amenities;
      final apiAreaUnit = state.areaUnit == 'all' ? null : state.areaUnit;

      final effectiveProjectId = projectId.isEmpty ? state.projectFilter : projectId;
      final shouldFetchAll = fetchAll ?? projectId.isEmpty;
      debugPrint('===== FETCH: calling _service.getProperties =====');
      final response = await _service.getProperties(
        projectId: effectiveProjectId,
        page: pageToFetch,
        limit: shouldFetchAll ? 1000 : state.limit,
        searchQuery: state.searchQuery.trim().isNotEmpty ? state.searchQuery : null,
        status: apiStatus,
        category: apiCat,
        propertyType: apiType,
        facing: apiFacing,
        bedrooms: state.bedrooms,
        bathrooms: state.bathrooms,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        areaUnit: apiAreaUnit,
        minArea: state.minArea,
        maxArea: state.maxArea,
        listingType: apiListingType,
        allowedTenants: apiTenants,
        city: apiCity,
        furnishingStatus: apiFurnishing,
        preferredGender: apiPreferredGender,
        amenities: apiAmenities,
        availableBy: state.availableBy,
        sort: state.sort,
        direction: apiDirection,
        builtUp: state.builtUpFilter.isEmpty ? null : state.builtUpFilter,
        fromInventoryDate: state.fromInventoryDate,
        toInventoryDate: state.toInventoryDate,
      );

      state = state.copyWith(
        properties: isRefresh ? response.data.properties : [...state.properties, ...response.data.properties],
        isLoading: false,
        page: pageToFetch,
        hasNextPage: response.data.pagination.hasNextPage,
        totalCount: response.data.totalCount,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setStatus(String status) {
    state = state.copyWith(status: status, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setCategory(String category) {
    state = state.copyWith(category: category, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setPropertyType(String type) {
    state = state.copyWith(propertyType: type, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setFacing(String facing) {
    state = state.copyWith(facing: facing, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setDirection(String direction) {
    state = state.copyWith(direction: direction, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setProjectFilter(String? projectId) {
    state = state.copyWith(projectFilter: projectId, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setBedrooms(int? bedrooms) {
    state = state.copyWith(bedrooms: bedrooms, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setBathrooms(int? bathrooms) {
    state = state.copyWith(bathrooms: bathrooms, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setListingType(String type) {
    state = state.copyWith(listingType: type, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setAllowedTenants(String tenants) {
    state = state.copyWith(allowedTenants: tenants, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setCity(String city) {
    state = state.copyWith(city: city, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setPriceRange(double? min, double? max) {
    state = state.copyWith(minPrice: min, maxPrice: max, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setAreaRange(double? min, double? max, String unit) {
    state = state.copyWith(minArea: min, maxArea: max, areaUnit: unit, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void setSort(String sort) {
    state = state.copyWith(sort: sort, page: 1);
    fetchProjectProperties(isRefresh: true);
  }

  void applyFilters({
    required String status,
    required String category,
    required String propertyType,
    required String facing,
    required int? bedrooms,
    required int? bathrooms,
    required String listingType,
    required String allowedTenants,
    required String city,
    required String furnishingStatus,
    required String preferredGender,
    required String amenities,
    required String? availableBy,
    required double? minPrice,
    required double? maxPrice,
    required String areaUnit,
    required double? minArea,
    required double? maxArea,
    required String sort,
    required String direction,
    String? projectFilter,
    String? builtUpFilter,
    String? fromInventoryDate,
    String? toInventoryDate,
  }) {
    state = state.copyWith(
      status: status,
      category: category,
      propertyType: propertyType,
      facing: facing,
      direction: direction,
      listingType: listingType,
      allowedTenants: allowedTenants,
      city: city,
      furnishingStatus: furnishingStatus,
      preferredGender: preferredGender,
      amenities: amenities,
      availableBy: availableBy,
      minPrice: minPrice,
      clearMinPrice: minPrice == null,
      maxPrice: maxPrice,
      clearMaxPrice: maxPrice == null,
      areaUnit: areaUnit,
      minArea: minArea,
      clearMinArea: minArea == null,
      maxArea: maxArea,
      clearMaxArea: maxArea == null,
      sort: sort,
      bedrooms: bedrooms,
      clearBedrooms: bedrooms == null,
      bathrooms: bathrooms,
      clearBathrooms: bathrooms == null,
      projectFilter: projectFilter,
      clearProjectFilter: projectFilter == null,
      builtUpFilter: builtUpFilter,
      fromInventoryDate: fromInventoryDate,
      clearFromInventoryDate: fromInventoryDate == null,
      toInventoryDate: toInventoryDate,
      clearToInventoryDate: toInventoryDate == null,
      page: 1,
    );
    fetchProjectProperties(isRefresh: true);
  }

  void resetFilters() {
    state = ProjectPropertiesState();
    fetchProjectProperties(isRefresh: true);
  }

  Future<void> loadMoreProperties() async {
    if (!state.isLoading && state.hasNextPage) {
      state = state.copyWith(page: state.page + 1);
      await fetchProjectProperties(isRefresh: false);
    }
  }

  String? _mapStatusToApi(String display) {
    if (display == 'all_properties') return null;
    final parts = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    return parts.join(',');
  }

  String? _mapCategoryToApi(String display) {
    if (display == 'all_categories') return null;
    final parts = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    return parts.join(',');
  }

  String? _mapTypeToApi(String display) {
    if (display == 'all_types') return null;
    return display;
  }

  void _refreshRelated(String? assocProjectId) {
    // 1. Refresh global project stats
    ref.read(propertyProvider.notifier).fetchProjects(isRefresh: true);

    // 2. Synchronize allPropertiesProvider and projectPropertiesProvider("") if one is mutated
    if (projectId.isEmpty) {
      if (isAllProperties) {
        final emptyProjNotifier = ref.read(projectPropertiesProvider("").notifier);
        if (!emptyProjNotifier.state.isLoading) {
          emptyProjNotifier.fetchProjectProperties(isRefresh: true);
        }
      } else {
        final allNotifier = ref.read(allPropertiesProvider.notifier);
        if (!allNotifier.state.isLoading) {
          allNotifier.fetchProjectProperties(isRefresh: true);
        }
      }
    } else {
      final allNotifier = ref.read(allPropertiesProvider.notifier);
      if (!allNotifier.state.isLoading) {
        allNotifier.fetchProjectProperties(isRefresh: true);
      }
      final emptyProjNotifier = ref.read(projectPropertiesProvider("").notifier);
      if (!emptyProjNotifier.state.isLoading) {
        emptyProjNotifier.fetchProjectProperties(isRefresh: true);
      }
    }

    // 3. If there is an associated projectId and it is different from the current projectId, refresh that project-specific notifier too
    if (assocProjectId != null && assocProjectId.isNotEmpty && assocProjectId != projectId) {
      final projNotifier = ref.read(projectPropertiesProvider(assocProjectId).notifier);
      if (!projNotifier.state.isLoading) {
        projNotifier.fetchProjectProperties(isRefresh: true);
      }
    }
  }

  Future<void> createProperty(Map<String, dynamic> data) async {
    try {
      await _service.createProperty(data);
      await fetchProjectProperties(isRefresh: true); // Refresh list
      final assocProjectId = data['projectId'] as String?;
      _refreshRelated(assocProjectId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateProperty(String propertyId, Map<String, dynamic> data) async {
    try {
      debugPrint('===== UPDATE FLOW: calling _service.updateProperty =====');
      await _service.updateProperty(propertyId, data);
      debugPrint('===== UPDATE FLOW: _service.updateProperty DONE =====');
      debugPrint('===== UPDATE FLOW: calling fetchProjectProperties =====');
      await fetchProjectProperties(isRefresh: true);
      debugPrint('===== UPDATE FLOW: fetchProjectProperties DONE =====');
      final assocProjectId = data['projectId'] as String?;
      debugPrint('===== UPDATE FLOW: calling _refreshRelated($assocProjectId) =====');
      _refreshRelated(assocProjectId);
      debugPrint('===== UPDATE FLOW: ALL DONE =====');
    } catch (e) {
      debugPrint('===== UPDATE FLOW CAUGHT ERROR: $e =====');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<bool> deleteProperty(String propertyId) async {
    try {
      String? assocProjectId;
      try {
        final prop = state.properties.firstWhere((p) => p.id == propertyId);
        assocProjectId = prop.projectId;
      } catch (_) {}

      await _service.deleteProperty(propertyId);
      await fetchProjectProperties(isRefresh: true);
      _refreshRelated(assocProjectId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> bulkUpdateProperties(List<String> propertyIds, Map<String, dynamic> updates) async {
    try {
      final projectIds = state.properties
          .where((p) => propertyIds.contains(p.id))
          .map((p) => p.projectId)
          .toSet();

      final success = await _service.bulkUpdateProperties(propertyIds, updates);
      if (success) {
        await fetchProjectProperties(isRefresh: true);
        for (final pid in projectIds) {
          _refreshRelated(pid);
        }
        if (projectIds.isEmpty) {
          _refreshRelated(null);
        }
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generatePropertyShareMessage(String propertyId) async {
    try {
      return await _service.getPropertyShareMessage(propertyId);
    } catch (e) {
      rethrow;
    }
  }
}

final projectPropertiesProvider = StateNotifierProvider.family<ProjectPropertiesNotifier, ProjectPropertiesState, String>((ref, projectId) {
  return ProjectPropertiesNotifier(projectId, ref);
});

final allPropertiesProvider = StateNotifierProvider<ProjectPropertiesNotifier, ProjectPropertiesState>((ref) {
  return ProjectPropertiesNotifier("", ref, isAllProperties: true);
});

final citiesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final service = PropertyService();
  try {
    debugPrint('[citiesProvider] Fetching cities from API...');
    final raw = await service.getCities();
    debugPrint('[citiesProvider] Raw cities received: $raw');
    return raw;
  } catch (e, stack) {
    debugPrint('[citiesProvider] Error fetching cities: $e');
    debugPrint(stack.toString());
    rethrow;
  }
});

final amenitiesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final service = PropertyService();
  try {
    debugPrint('[amenitiesProvider] Fetching amenities from API...');
    final raw = await service.getAmenities();
    debugPrint('[amenitiesProvider] Raw amenities received: $raw');
    // For amenities, we might not need the same cleaning as cities,
    // but we can ensure they are trimmed and non-empty.
    final cleaned = raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    debugPrint('[amenitiesProvider] Cleaned amenities list: $cleaned');
    return cleaned;
  } catch (e, stack) {
    debugPrint('[amenitiesProvider] Error fetching amenities: $e');
    debugPrint(stack.toString());
    rethrow;
  }
});
