import 'package:crmapp/data/models/staff_model.dart';

class Team {
  final String id;
  final String name;
  final String groupName;
  final String leaderName;
  final List<String> leaderNames;
  final List<String> leaderIds;
  final int membersCount;
  final String status;
  final DateTime createdAt;
  final List<String> memberIds;
  final List<StaffUser> members;

  Team({
    required this.id,
    required this.name,
    required this.groupName,
    required this.leaderName,
    this.leaderNames = const [],
    this.leaderIds = const [],
    required this.membersCount,
    required this.status,
    required this.createdAt,
    this.memberIds = const [],
    this.members = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown Team',
      groupName: json['group'] is Map ? json['group']['name'] ?? '-' : '-',
      leaderName: () {
        if (json['leaders'] is List && (json['leaders'] as List).isNotEmpty) {
          return (json['leaders'] as List).map((l) => l['name']?.toString() ?? '').where((n) => n.isNotEmpty).join(", ");
        } else if (json['leader'] is Map) {
          return json['leader']['name']?.toString() ?? '-';
        } else if (json['leader'] is String) {
          return json['leader'].toString();
        }
        return '-';
      }(),
      leaderNames: () {
        if (json['leaders'] is List) {
          return (json['leaders'] as List).map((l) => l['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        } else if (json['leader'] is Map && json['leader']['name'] != null) {
          return [json['leader']['name'].toString()];
        }
        return <String>[];
      }(),
      leaderIds: () {
        if (json['leaders'] is List) {
          return (json['leaders'] as List).map((l) => l['_id']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        } else if (json['leader'] is Map && json['leader']['_id'] != null) {
          return [json['leader']['_id'].toString()];
        }
        return <String>[];
      }(),
      membersCount: (json['members'] as List?)?.length ?? 0,
      status: (json['status'] == 'Active' || json['active'] == true) ? 'Active' : 'Inactive',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      memberIds: (json['members'] as List?)?.map((e) => e is Map ? (e['_id']?.toString() ?? '') : e.toString()).where((e) => e.isNotEmpty).toList() ?? [],
      members: (json['members'] as List?)?.whereType<Map<String, dynamic>>().map((e) => StaffUser.fromJson(e)).toList() ?? [],
    );
  }
}

class TeamListResponse {
  final List<Team> teams;
  final int totalCount;
  final int page;
  final int limit;
  final int totalPages;

  TeamListResponse({
    required this.teams,
    required this.totalCount,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory TeamListResponse.fromJson(Map<String, dynamic> json) {
    // Nested data handling similar to StaffModel if needed, but user provided response structure directly in `data`.
    // { "data": { "teams": [...], "pagination": {...} } } OR flat in data.
    // The provided JSON shows: 
    // "data": { "teams": [...], "totalCount": 4, "pagination": { "page": 1, ... } }
    
    final data = json['data'] ?? json;
    final pagination = data['pagination'] ?? {};

    return TeamListResponse(
      teams: (data['teams'] as List?)?.map((e) => Team.fromJson(e)).toList() ?? [],
      totalCount: data['totalCount'] ?? 0,
      page: pagination['page'] ?? 1,
      limit: pagination['limit'] ?? 5,
      totalPages: pagination['totalPages'] ?? 1,
    );
  }
}
