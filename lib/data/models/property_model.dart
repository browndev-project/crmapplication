class PropertyResponse {
  final int statusCode;
  final PropertyData data;
  final String message;
  final bool success;

  PropertyResponse({
    required this.statusCode,
    required this.data,
    required this.message,
    required this.success,
  });

  factory PropertyResponse.fromJson(Map<String, dynamic> json) {
    return PropertyResponse(
      statusCode: json['statusCode'] ?? 200,
      data: json['data'] != null ? PropertyData.fromJson(json['data']) : PropertyData.empty(),
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

class PropertyData {
  final List<Property> properties;
  final int totalCount;
  final Pagination pagination;

  PropertyData({
    required this.properties,
    required this.totalCount,
    required this.pagination,
  });

  PropertyData.empty()
      : properties = const [],
        totalCount = 0,
        pagination = Pagination(page: 1, limit: 20, hasNextPage: false);

  factory PropertyData.fromJson(Map<String, dynamic> json) {
    final rawProperties = json['properties'];
    final properties = rawProperties is List
        ? rawProperties.map((i) => Property.fromJson(i is Map<String, dynamic> ? i : {})).toList()
        : <Property>[];
    return PropertyData(
      properties: properties,
      totalCount: json['totalCount'] ?? 0,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : Pagination(page: 1, limit: 20, hasNextPage: false),
    );
  }
}

class Property {
  final String id;
  final String status;
  final double price;
  final double token;
  final String companyId;
  final String projectId;
  final String name;
  final String description;
  final String propertyType;
  final String category;
  final Dimension? area;
  final Dimension? length;
  final Dimension? breadth;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String? updatedById;
  final PropertyLocation? location;
  final String? internalNotes;
  final Project? project;
  final int leadsCount;
  final VisitsSummary visitsSummary;
  final List<String> amenities;
  final List<String> images;
  final List<String> videos;
  final String? brochureUrl;
  final String? paymentPlan;
  final String? ownerName;
  final String? ownerNumber;
  final String? ownerEmail;
  final String? facing;
  final int? bedrooms;
  final String? direction;
  
  // New Fields from Docs
  final String listingType; // "Sell" | "Rent"
  final double securityDeposit;
  final MaintenanceCharges? maintenanceCharges;
  final String? allowedTenants;
  final String? preferredGender;
  final int lockInPeriodMonths;
  final int noticePeriodMonths;
  final List<String> policies;
  final String? availabilityDate;
  final String furnishingStatus;
  final int? bathrooms;
  final bool builtUp;
  final String? basic;
  final String? inventoryDate;

  Property({
    required this.id,
    required this.status,
    required this.price,
    required this.token,
    required this.companyId,
    required this.projectId,
    required this.name,
    this.description = '',
    required this.propertyType,
    this.category = 'Residential',
    this.area,
    this.length,
    this.breadth,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.updatedById,
    this.location,
    this.internalNotes,
    this.project,
    required this.leadsCount,
    required this.visitsSummary,
    this.amenities = const [],
    this.images = const [],
    this.videos = const [],
    this.brochureUrl,
    this.paymentPlan,
    this.ownerName,
    this.ownerNumber,
    this.ownerEmail,
    this.facing,
    this.bedrooms,
    this.direction,
    this.listingType = 'Sell',
    this.securityDeposit = 0,
    this.maintenanceCharges,
    this.allowedTenants,
    this.preferredGender,
    this.lockInPeriodMonths = 0,
    this.noticePeriodMonths = 1,
    this.policies = const [],
    this.availabilityDate,
    this.furnishingStatus = 'Unfurnished',
    this.bathrooms,
    this.builtUp = false,
    this.basic,
    this.inventoryDate,
  });

  String get statusLabel => Property.getDisplayLabel(status);
  String get listingTypeLabel => Property.getDisplayLabel(listingType);
  String get propertyTypeLabel => Property.getDisplayLabel(propertyType);
  String get categoryLabel => Property.getDisplayLabel(category);
  String get facingLabel => facing != null ? Property.getDisplayLabel(facing!) : '';
  String get directionLabel => direction != null ? Property.getDisplayLabel(direction!) : '';
  String get furnishingStatusLabel => Property.getDisplayLabel(furnishingStatus);
  String get allowedTenantsLabel => allowedTenants != null ? Property.getDisplayLabel(allowedTenants!) : '';
  String get preferredGenderLabel => preferredGender != null ? Property.getDisplayLabel(preferredGender!) : '';

  static String toSnakeCase(String? val) {
    if (val == null) return '';
    return val.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  }

  static String? toSnakeCaseOrNull(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    return val.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  }

  static String getDisplayLabel(String key) {
    const mapping = {
      'available': 'Available',
      'on_hold': 'On Hold',
      'token_received': 'Token Received',
      'booked': 'Booked',
      'sold': 'Sold',
      'blocked': 'Blocked',
      'ready_to_move': 'Ready to Move',
      'rented': 'Rented',
      'notice_period': 'Notice Period',
      'sqft': 'Sq. Ft.',
      'sqyd': 'Sq. Yd.',
      'acre': 'Acre',
      'gaj': 'Gaj',
      'bigha': 'Bigha',
      'feet': 'Feet',
      'yards': 'Yards',
      'meters': 'Meters',
      'park_facing': 'Park Facing',
      'kothi_facing': 'Kothi Facing',
      'dda_flat_facing': 'DDA Flat Facing',
      'road_facing': 'Road Facing',
      'north': 'North',
      'south': 'South',
      'east': 'East',
      'west': 'West',
      'north_east': 'North East',
      'north_west': 'North West',
      'south_east': 'South East',
      'south_west': 'South West',
      'included': 'Included',
      'monthly': 'Monthly',
      'quarterly': 'Quarterly',
      'yearly': 'Yearly',
      'unfurnished': 'Unfurnished',
      'semi_furnished': 'Semi Furnished',
      'fully_furnished': 'Fully Furnished',
      'family': 'Family',
      'bachelors': 'Bachelors',
      'company_lease': 'Company Lease',
      'any': 'Any',
      'male': 'Male',
      'female': 'Female',
      'other': 'Other',
      'sell': 'Sell',
      'rent': 'Rent',
      'plot': 'Plot',
      'flat': 'Flat',
      'floor': 'Floor',
      'room': 'Room',
      'farmhouse': 'Farmhouse',
      'farm_house': 'Farm House',
      'villa': 'Villa',
      'duplex': 'Duplex',
      'shop': 'Shop',
      'house': 'House',
      'green_land': 'Green Land',
      'office': 'Office',
      'warehouse': 'Warehouse',
      'coworking_space': 'Coworking Space',
      'studio_apartment': 'Studio Apartment',
      'penthouse': 'Penthouse',
      'residential': 'Residential',
      'commercial': 'Commercial',
      'industrial': 'Industrial',
      'land': 'Land',
    };
    final normalized = key.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    return mapping[normalized] ?? key;
  }

  factory Property.fromJson(dynamic json) {
    if (json is! Map) {
      return Property(
        id: '', status: '', price: 0, token: 0, companyId: '', projectId: '',
        name: '', propertyType: '', createdAt: '', updatedAt: '',
        leadsCount: 0, visitsSummary: VisitsSummary(total: 0, scheduled: 0, completed: 0, cancelled: 0),
      );
    }
    String asStr(dynamic value, [String fallback = '']) {
      if (value == null) return fallback;
      if (value is String) return value.isNotEmpty ? value : fallback;
      if (value is Map) {
        final name = value['name'] ?? value['title'] ?? value['label'] ?? value['value'];
        if (name is String && name.isNotEmpty) return name;
        return fallback;
      }
      final s = value.toString();
      return s.isNotEmpty ? s : fallback;
    }

    String idFrom(dynamic value, [String fallback = '']) {
      if (value == null) return fallback;
      if (value is String) return value;
      if (value is Map) {
        final id = value['_id'] ?? value['id'];
        if (id is String && id.isNotEmpty) return id;
        return fallback;
      }
      return value.toString();
    }

    String parseUserName(dynamic user) {
      if (user == null) return 'Admin';
      if (user is Map) return user['fullName'] ?? user['name'] ?? 'Admin';
      return user.toString();
    }

    String? strOrNull(dynamic value) {
      if (value == null) return null;
      if (value is String) return value.isNotEmpty ? value : null;
      if (value is Map) {
        final name = value['name'] ?? value['title'] ?? value['label'];
        if (name is String && name.isNotEmpty) return name;
        return null;
      }
      final s = value.toString();
      return s.isNotEmpty ? s : null;
    }

    return Property(
      id: idFrom(json['_id']),
      status: toSnakeCase(asStr(json['status'])),
      price: (json['price'] ?? 0).toDouble(),
      token: (json['token'] ?? 0).toDouble(),
      companyId: idFrom(json['companyId']),
      projectId: idFrom(json['projectId']),
      name: asStr(json['name']),
      description: asStr(json['description']),
      propertyType: toSnakeCase(asStr(json['propertyType'])),
      category: toSnakeCase(asStr(json['category'], 'Residential')),
      area: json['area'] != null ? Dimension.fromJson(json['area']) : null,
      length: json['length'] != null ? Dimension.fromJson(json['length']) : null,
      breadth: json['breadth'] != null ? Dimension.fromJson(json['breadth']) : null,
      createdAt: asStr(json['createdAt']),
      updatedAt: asStr(json['updatedAt']),
      createdBy: parseUserName(json['createdBy']),
      updatedBy: parseUserName(json['updatedBy']),
      updatedById: json['updatedBy'] is Map ? json['updatedBy']['_id'] : json['updatedBy'],
      location: json['location'] != null ? PropertyLocation.fromJson(json['location']) : null,
      internalNotes: strOrNull(json['internalNotes']),
      project: json['project'] != null 
          ? Project.fromJson(json['project']) 
          : (json['projectId'] is Map ? Project.fromJson(json['projectId']) : null),
      leadsCount: json['leadsCount'] ?? 0,
      visitsSummary: VisitsSummary.fromJson(json['visitsSummary']),
      amenities: json['amenities'] is List ? (json['amenities'] as List).map((e) => e?.toString() ?? '').cast<String>().where((e) => e.isNotEmpty).toList() : const [],
      images: json['images'] is List ? (json['images'] as List).map((e) => e?.toString() ?? '').cast<String>().where((e) => e.isNotEmpty).toList() : const [],
      videos: json['videos'] is List ? (json['videos'] as List).map((e) => e?.toString() ?? '').cast<String>().where((e) => e.isNotEmpty).toList() : const [],
      brochureUrl: strOrNull(json['brochureUrl']),
      paymentPlan: strOrNull(json['paymentPlan']),
      ownerName: strOrNull(json['ownerName']),
      ownerNumber: json['ownerNumber'] != null ? '${json['ownerNumber']}' : null,
      ownerEmail: strOrNull(json['ownerEmail']),
      facing: toSnakeCaseOrNull(strOrNull(json['facing'])),
      bedrooms: json['bedrooms'] is num 
          ? (json['bedrooms'] as num).toInt() 
          : (json['bedrooms'] != null ? int.tryParse(json['bedrooms'].toString()) : null),
      direction: toSnakeCaseOrNull(strOrNull(json['direction'])),
      listingType: toSnakeCase(asStr(json['listingType'], 'Sell')),
      securityDeposit: (json['securityDeposit'] ?? 0).toDouble(),
      maintenanceCharges: json['maintenanceCharges'] != null ? MaintenanceCharges.fromJson(json['maintenanceCharges']) : null,
      allowedTenants: toSnakeCaseOrNull(strOrNull(json['allowedTenants'])),
      preferredGender: toSnakeCaseOrNull(strOrNull(json['preferredGender'])),
      lockInPeriodMonths: json['lockInPeriodMonths'] ?? 0,
      noticePeriodMonths: json['noticePeriodMonths'] ?? 1,
      policies: json['policies'] is List ? (json['policies'] as List).map((e) => e?.toString() ?? '').cast<String>().where((e) => e.isNotEmpty).toList() : const [],
      availabilityDate: strOrNull(json['availabilityDate']),
      furnishingStatus: toSnakeCase(asStr(json['furnishingStatus'], 'Unfurnished')),
      bathrooms: json['bathrooms'] is num 
          ? (json['bathrooms'] as num).toInt() 
          : (json['bathrooms'] != null ? int.tryParse(json['bathrooms'].toString()) : null),
      builtUp: json['builtUp'] ?? json['builtup'] ?? false,
      basic: strOrNull(json['basic']),
      inventoryDate: strOrNull(json['inventoryDate']) ?? strOrNull(json['inventorydate']),
    );
  }
}

class MaintenanceCharges {
  final double value;
  final String billingCycle;

  MaintenanceCharges({required this.value, required this.billingCycle});

  factory MaintenanceCharges.fromJson(dynamic json) {
    if (json is! Map) return MaintenanceCharges(value: 0, billingCycle: 'included');
    return MaintenanceCharges(
      value: (json['value'] ?? 0).toDouble(),
      billingCycle: Property.toSnakeCase(json['billingCycle'] ?? 'included'),
    );
  }
}

class Dimension {
  final double value;
  final String unit;

  Dimension({required this.value, required this.unit});

  factory Dimension.fromJson(dynamic json) {
    if (json is! Map) {
      return Dimension(value: 0, unit: '');
    }
    return Dimension(
      value: (json['value'] ?? 0).toDouble(),
      unit: Property.toSnakeCase(json['unit'] ?? ''),
    );
  }
}

class PropertyLocation {
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String country;
  final String? pincode;
  final double? lat;
  final double? lng;

  PropertyLocation({
    required this.address1,
    required this.address2,
    required this.city,
    required this.state,
    required this.country,
    this.pincode,
    this.lat,
    this.lng,
  });

  factory PropertyLocation.fromJson(dynamic json) {
    if (json is! Map) {
      return PropertyLocation(address1: '', address2: '', city: '', state: '', country: '');
    }
    final coords = json['coordinates'];
    double? latitude;
    double? longitude;

    if (coords is List && coords.length >= 2) {
      longitude = (coords[0] as num?)?.toDouble();
      latitude = (coords[1] as num?)?.toDouble();
    } else if (coords is Map) {
      latitude = (coords['lat'] ?? coords['latitude'])?.toDouble();
      longitude = (coords['lng'] ?? coords['longitude'])?.toDouble();
    } else {
      latitude = (json['lat'] ?? json['latitude'])?.toDouble();
      longitude = (json['lng'] ?? json['longitude'])?.toDouble();
    }

    return PropertyLocation(
      address1: json['address1'] ?? '',
      address2: json['address2'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      pincode: json['pincode'],
      lat: latitude,
      lng: longitude,
    );
  }
}

class Project {
  final String id;
  final String name;
  final String developerName;
  final String description;
  final String companyId;
  final String status;
  final String category;
  final Dimension? totalArea;
  final bool active;
  final ProjectLocation? location;
  final String? createdBy;
  final String? updatedBy;
  final String createdAt;
  final String updatedAt;
  final int propertiesCount;
  final int leadsCount;
  final VisitsSummary visitsSummary;
  final String? reraId;
  final String? possessionDate;
  final List<String> amenities;
  final List<String> images;
  final List<String> videos;
  final String? brochureUrl;
  final String? paymentPlan;
  final String? source;
  
  // New breakdown stats from Docs
  final List<CountStat> propertyListingTypeCounts;
  final List<CountStat> propertyCategoryCounts;

  Project({
    required this.id,
    required this.name,
    required this.developerName,
    required this.description,
    required this.companyId,
    required this.status,
    required this.category,
    this.totalArea,
    required this.active,
    this.location,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.propertiesCount,
    required this.leadsCount,
    required this.visitsSummary,
    this.reraId,
    this.possessionDate,
    this.amenities = const [],
    this.images = const [],
    this.videos = const [],
    this.brochureUrl,
    this.paymentPlan,
    this.source,
    this.propertyListingTypeCounts = const [],
    this.propertyCategoryCounts = const [],
  });

  factory Project.fromJson(dynamic json) {
    if (json is! Map) {
      return Project(
        id: '', name: '', developerName: '', description: '', companyId: '',
        status: 'active', category: 'General', active: false,
        createdAt: '', updatedAt: '', propertiesCount: 0, leadsCount: 0,
        visitsSummary: VisitsSummary(total: 0, scheduled: 0, completed: 0, cancelled: 0),
      );
    }
    String asStr(dynamic value, [String fallback = '']) {
      if (value == null) return fallback;
      if (value is String) return value.isNotEmpty ? value : fallback;
      if (value is Map) {
        final name = value['name'] ?? value['title'] ?? value['label'] ?? value['value'];
        if (name is String && name.isNotEmpty) return name;
        return fallback;
      }
      final s = value.toString();
      return s.isNotEmpty ? s : fallback;
    }

    String idFrom(dynamic value, [String fallback = '']) {
      if (value == null) return fallback;
      if (value is String) return value;
      if (value is Map) {
        final id = value['_id'] ?? value['id'];
        if (id is String && id.isNotEmpty) return id;
        return fallback;
      }
      return value.toString();
    }

    String? strOrNull(dynamic value) {
      if (value == null) return null;
      if (value is String) return value.isNotEmpty ? value : null;
      if (value is Map) {
        final name = value['name'] ?? value['title'] ?? value['label'];
        if (name is String && name.isNotEmpty) return name;
        return null;
      }
      final s = value.toString();
      return s.isNotEmpty ? s : null;
    }

    String parseUserName(dynamic user) {
      if (user == null) return 'Admin';
      if (user is Map) return user['fullName'] ?? user['name'] ?? 'Admin';
      return user.toString();
    }

    return Project(
      id: idFrom(json['_id']),
      name: asStr(json['name']),
      developerName: asStr(json['developerName']),
      description: asStr(json['description']),
      companyId: idFrom(json['companyId']),
      status: asStr(json['status'], 'active'),
      category: asStr(json['category'], 'General'),
      totalArea: json['totalArea'] != null ? Dimension.fromJson(json['totalArea']) : null,
      active: json['active'] ?? false,
      location: json['location'] != null ? ProjectLocation.fromJson(json['location']) : null,
      createdBy: parseUserName(json['createdBy']),
      updatedBy: parseUserName(json['updatedBy']),
      createdAt: asStr(json['createdAt']),
      updatedAt: asStr(json['updatedAt']),
      propertiesCount: json['propertiesCount'] ?? 0,
      leadsCount: json['leadsCount'] ?? 0,
      visitsSummary: VisitsSummary.fromJson(json['visitsSummary']),
      reraId: strOrNull(json['reraId']),
      possessionDate: strOrNull(json['possessionDate']),
      amenities: json['amenities'] is List ? (json['amenities'] as List).map((e) => e?.toString() ?? '').cast<String>().where((e) => e.isNotEmpty).toList() : const [],
      images: json['images'] is List ? (json['images'] as List).map((e) => e?.toString() ?? '').cast<String>().where((e) => e.isNotEmpty).toList() : const [],
      videos: json['videos'] is List ? (json['videos'] as List).map((e) => e?.toString() ?? '').cast<String>().where((e) => e.isNotEmpty).toList() : const [],
      brochureUrl: strOrNull(json['brochureUrl']),
      paymentPlan: strOrNull(json['paymentPlan']),
      source: strOrNull(json['source']),
      propertyListingTypeCounts: json['propertyListingTypeCounts'] is List 
          ? (json['propertyListingTypeCounts'] as List).map((e) => CountStat.fromJson(e)).toList() 
          : const [],
      propertyCategoryCounts: json['propertyCategoryCounts'] is List 
          ? (json['propertyCategoryCounts'] as List).map((e) => CountStat.fromJson(e)).toList() 
          : const [],
    );
  }
}

class CountStat {
  final String id;
  final int count;

  CountStat({required this.id, required this.count});

  factory CountStat.fromJson(dynamic json) {
    if (json is! Map) return CountStat(id: 'Unknown', count: 0);
    return CountStat(
      id: (json['_id'] ?? 'Unknown').toString(),
      count: json['count'] ?? 0,
    );
  }
}

class ProjectListResponse {
  final int statusCode;
  final ProjectListData data;
  final String message;
  final bool success;

  ProjectListResponse({
    required this.statusCode,
    required this.data,
    required this.message,
    required this.success,
  });

  factory ProjectListResponse.fromJson(Map<String, dynamic> json) {
    return ProjectListResponse(
      statusCode: json['statusCode'] ?? 200,
      data: json['data'] != null ? ProjectListData.fromJson(json['data']) : ProjectListData.empty(),
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

class ProjectListData {
  final List<Project> projects;
  final int totalCount;
  final Pagination pagination;

  ProjectListData({
    required this.projects,
    required this.totalCount,
    required this.pagination,
  });

  ProjectListData.empty()
      : projects = const [],
        totalCount = 0,
        pagination = Pagination(page: 1, limit: 20, hasNextPage: false);

  factory ProjectListData.fromJson(Map<String, dynamic> json) {
    final rawProjects = json['projects'];
    final projects = rawProjects is List
        ? rawProjects.map((i) => Project.fromJson(i is Map<String, dynamic> ? i : {})).toList()
        : <Project>[];
    return ProjectListData(
      projects: projects,
      totalCount: json['totalCount'] ?? 0,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : Pagination(page: 1, limit: 20, hasNextPage: false),
    );
  }
}

class ProjectLocation {
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String country;
  final String? pincode;
  final double? lat;
  final double? lng;

  ProjectLocation({
    required this.address1,
    required this.address2,
    required this.city,
    required this.state,
    required this.country,
    this.pincode,
    this.lat,
    this.lng,
  });

  factory ProjectLocation.fromJson(dynamic json) {
    if (json is! Map) {
      return ProjectLocation(address1: '', address2: '', city: '', state: '', country: '');
    }
    final coords = json['coordinates'];
    double? latitude;
    double? longitude;

    if (coords is List && coords.length >= 2) {
      longitude = (coords[0] as num?)?.toDouble();
      latitude = (coords[1] as num?)?.toDouble();
    } else if (coords is Map) {
      latitude = (coords['lat'] ?? coords['latitude'])?.toDouble();
      longitude = (coords['lng'] ?? coords['longitude'])?.toDouble();
    } else {
      latitude = (json['lat'] ?? json['latitude'])?.toDouble();
      longitude = (json['lng'] ?? json['longitude'])?.toDouble();
    }

    return ProjectLocation(
      address1: json['address1'] ?? '',
      address2: json['address2'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      pincode: json['pincode'],
      lat: latitude,
      lng: longitude,
    );
  }
}

class VisitsSummary {
  final int total;
  final int scheduled;
  final int completed;
  final int cancelled;

  VisitsSummary({
    required this.total,
    required this.scheduled,
    required this.completed,
    required this.cancelled,
  });

  factory VisitsSummary.fromJson(dynamic json) {
    if (json is! Map) {
      return VisitsSummary(total: 0, scheduled: 0, completed: 0, cancelled: 0);
    }
    return VisitsSummary(
      total: json['total'] ?? 0,
      scheduled: json['scheduled'] ?? 0,
      completed: json['completed'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final bool hasNextPage;

  Pagination({
    required this.page,
    required this.limit,
    required this.hasNextPage,
  });

  factory Pagination.fromJson(dynamic json) {
    if (json is! Map) {
      return Pagination(page: 1, limit: 20, hasNextPage: false);
    }
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      hasNextPage: json['hasNextPage'] ?? false,
    );
  }
}

class PropertyNameResponse {
  final int statusCode;
  final List<PropertyName> properties;
  final String message;
  final bool success;

  PropertyNameResponse({
    required this.statusCode,
    required this.properties,
    required this.message,
    required this.success,
  });

  factory PropertyNameResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final rawProperties = data is Map ? data['properties'] : json['properties'];
    final properties = rawProperties is List
        ? rawProperties.map((i) => PropertyName.fromJson(i is Map<String, dynamic> ? i : {})).toList()
        : <PropertyName>[];
    return PropertyNameResponse(
      statusCode: json['statusCode'] ?? 200,
      properties: properties,
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

class PropertyName {
  final String id;
  final String status;
  final String projectId;
  final String name;

  PropertyName({
    required this.id,
    required this.status,
    required this.projectId,
    required this.name,
  });

  factory PropertyName.fromJson(dynamic json) {
    if (json is! Map) {
      return PropertyName(id: '', status: '', projectId: '', name: '');
    }
    String asStr(dynamic value, [String fallback = '']) {
      if (value == null) return fallback;
      if (value is String) return value.isNotEmpty ? value : fallback;
      if (value is Map) {
        final name = value['name'] ?? value['title'] ?? value['label'];
        if (name is String && name.isNotEmpty) return name;
        return fallback;
      }
      final s = value.toString();
      return s.isNotEmpty ? s : fallback;
    }
    return PropertyName(
      id: asStr(json['_id']),
      status: asStr(json['status']),
      projectId: asStr(json['projectId']),
      name: asStr(json['name']),
    );
  }
}
