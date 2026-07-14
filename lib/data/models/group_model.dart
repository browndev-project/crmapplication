import 'team_model.dart';

class Group {
  final String id;
  final String name;
  final String status;
  final int teamsCount;
  final String createdBy;
  final String createdAt;
  final String? managerName;
  final String? managerId;
  final List<String> managerNames;
  final List<String> managerIds;
  final List<Team> teams;

  Group({
    required this.id,
    required this.name,
    required this.status,
    this.teamsCount = 0,
    this.createdBy = '',
    this.createdAt = '',
    this.managerName,
    this.managerId,
    this.managerNames = const [],
    this.managerIds = const [],
    this.teams = const [],
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      status: (json['status'] == 'Active' || json['active'] == true) ? 'Active' : 'Inactive',
      teamsCount: json['teamsCount'] ?? (json['teams'] is List ? (json['teams'] as List).length : 0),
      createdBy: json['createdBy'] is Map ? json['createdBy']['name'] ?? 'Admin' : 'Admin',
      createdAt: json['createdAt'] ?? '',
      managerName: json['manager'] != null ? json['manager']['name'] : null,
      managerId: json['manager'] != null ? json['manager']['_id'] : null,
      managerNames: () {
        if (json['managers'] is List) {
          return (json['managers'] as List).map((m) => m['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        } else if (json['manager'] != null) {
          return [json['manager']['name']?.toString() ?? ''];
        }
        return <String>[];
      }(),
      managerIds: () {
        if (json['managers'] is List) {
          return (json['managers'] as List).map((m) => m['_id']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        } else if (json['manager'] != null) {
          return [json['manager']['_id']?.toString() ?? ''];
        }
        return <String>[];
      }(),
      teams: (json['teams'] as List?)?.map((e) => Team.fromJson(e)).toList() ?? [], 
    );
  }
}

class GroupListResponse {
  final List<Group> groups;
  final int totalCount;
  final int page;
  final int totalPages;
  final int limit;

  GroupListResponse({
    required this.groups,
    required this.totalCount,
    required this.page,
    required this.totalPages,
    required this.limit,
  });

  factory GroupListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final groupsList = (data['groups'] as List?) ?? [];
    final pagination = data['pagination'] ?? {};

    return GroupListResponse(
      groups: groupsList.map((e) => Group.fromJson(e)).toList(),
      totalCount: data['totalCount'] ?? 0,
      page: pagination['page'] ?? 1,
      totalPages: pagination['totalPages'] ?? 1,
      limit: pagination['limit'] ?? 10,
    );
  }
}
