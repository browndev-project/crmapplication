class ServiceResponse {
  final int statusCode;
  final ServiceData? data;
  final String message;
  final bool success;

  ServiceResponse({
    required this.statusCode,
    this.data,
    required this.message,
    required this.success,
  });

  factory ServiceResponse.fromJson(Map<String, dynamic> json) {
    return ServiceResponse(
      statusCode: json['statusCode'] ?? 0,
      data: json['data'] != null ? ServiceData.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

class ServiceData {
  final List<Service> services;
  final int totalCount;
  final Pagination pagination;

  ServiceData({
    required this.services,
    required this.totalCount,
    required this.pagination,
  });

  factory ServiceData.fromJson(Map<String, dynamic> json) {
    return ServiceData(
      services: (json['services'] as List?)?.map((e) => Service.fromJson(e)).toList() ?? [],
      totalCount: json['totalCount'] ?? 0,
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

class Service {
  final String id;
  final bool active;
  final String name;
  final String? description;
  final String? createdAt;

  Service({
    required this.id,
    required this.active,
    required this.name,
    this.description,
    this.createdAt,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['_id'] ?? '',
      active: json['active'] ?? false,
      name: json['name'] ?? 'Unknown Service',
      description: json['description'],
      createdAt: json['createdAt'],
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;

  Pagination({
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNextPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? 1,
      hasNextPage: json['hasNextPage'] ?? false,
    );
  }
}
