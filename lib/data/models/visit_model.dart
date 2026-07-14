
import 'package:crmapp/data/models/common_models.dart' show IdName;

class Visit {
  final String id;
  final IdName? project;
  final IdName? property;
  final String status;
  final String company;
  final VisitLeadShort? lead;
  final String dateTime;
  final String description;
  final String? comments;
  final VisitUserShort? createdBy;
  final String createdAt;
  final String updatedAt;

  Visit({
    required this.id,
    this.project,
    this.property,
    required this.status,
    required this.company,
    this.lead,
    required this.dateTime,
    required this.description,
    this.comments,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['_id'] ?? '',
      project: json['project'] != null ? IdName.fromJson(json['project']) : null,
      property: json['property'] != null ? IdName.fromJson(json['property']) : null,
      status: json['status'] ?? 'Scheduled',
      company: json['company'] ?? '',
      lead: json['lead'] != null && json['lead'] is Map<String, dynamic> 
          ? VisitLeadShort.fromJson(json['lead']) 
          : null,
      dateTime: json['dateTime'] ?? json['visitDate'] ?? '',
      description: json['description'] ?? json['notes'] ?? '',
      comments: json['comments'],
      createdBy: json['createdBy'] != null && json['createdBy'] is Map<String, dynamic>
          ? VisitUserShort.fromJson(json['createdBy'])
          : null,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}

class VisitLeadShort {
  final String id;
  final String name;
  final String? pipeline;
  final String? status;

  VisitLeadShort({required this.id, required this.name, this.pipeline, this.status});

  factory VisitLeadShort.fromJson(Map<String, dynamic> json) {
    return VisitLeadShort(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown',
      pipeline: json['pipeline'],
      status: json['status'] is String ? json['status'] : null,
    );
  }
}

class VisitUserShort {
  final String id;
  final String name;
  final String? uniqueId;

  VisitUserShort({required this.id, required this.name, this.uniqueId});

  factory VisitUserShort.fromJson(Map<String, dynamic> json) {
    return VisitUserShort(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown',
      uniqueId: json['uniqueId'],
    );
  }
}

class VisitsResponse {
  final List<Visit> visits;
  final int totalCount;
  final int totalPages;
  final int currentPage;

  VisitsResponse({
    required this.visits,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
  });

  factory VisitsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final visitsList = (data['visits'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => Visit.fromJson(e))
            .toList() ??
        [];
    final pagination = data['pagination'] ?? {};

    return VisitsResponse(
      visits: visitsList,
      totalCount: data['totalCount'] ?? 0,
      totalPages: pagination['totalPages'] ?? 1,
      currentPage: pagination['page'] ?? 1,
    );
  }
}
