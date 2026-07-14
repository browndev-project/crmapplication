class StaffUser {
  final String id;
  final String uniqueId;
  final String name;
  final String email;
  final String phoneNo;
  final String systemRole;
  final String status;
  final bool active;
  final String? groupName;
  final String? teamName;
  final int? membersCount;
  final int? teamsCount;
  final DateTime createdAt;
  final String createdBy;
  final List<String> permissions;
  final String? ivrAgentName;

  StaffUser({
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.email,
    required this.phoneNo,
    required this.systemRole,
    required this.status,
    required this.active,
    required this.createdAt,
    required this.createdBy,
    this.groupName,
    this.teamName,
    this.membersCount,
    this.teamsCount,
    this.permissions = const [],
    this.ivrAgentName,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['_id'] ?? json['id'] ?? '',
      uniqueId: json['uniqueId'] ?? '',
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? '-',
      phoneNo: json['phone'] ?? json['phoneNo'] ?? '-',
      systemRole: json['systemRole'] ?? '',
      status: (json['status'] as String?)?.toLowerCase() ?? 'active',
      active: json['active'] == true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      createdBy: json['createdBy'] is Map 
          ? (json['createdBy']['name'] ?? 'Admin') 
          : (json['createdBy'] ?? 'Admin'),
      groupName: json['group'] is Map ? json['group']['name'] : json['groupName'],
      teamName: json['team'] is Map ? json['team']['name'] : json['teamName'],
      membersCount: json['membersCount'] ?? 0,
      teamsCount: json['teamsCount'] ?? 0,
      permissions: json['permissions'] != null 
          ? List<String>.from(json['permissions']) 
          : [],
      ivrAgentName: json['crmUserMapped'] != null 
          ? (json['crmUserMapped']['name'] ?? json['crmUserMapped']['agentName']) 
          : (json['ivrAgent'] is Map ? (json['ivrAgent']['name'] ?? json['ivrAgent']['agentName'] ?? json['ivrAgent']['agentId']) : null),
    );
  }
}

class StaffListResponse {
  final List<StaffUser> docs;
  final int totalDocs;
  final int limit;
  final int page;
  final int totalPages;

  StaffListResponse({
    required this.docs,
    required this.totalDocs,
    required this.limit,
    required this.page,
    required this.totalPages,
  });

  factory StaffListResponse.fromJson(Map<String, dynamic> json) {
    // Handle nested 'data' object if present
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;
    
    final usersList = (data['users'] as List?) ?? [];
    
    // Handle nested 'pagination' object if present
    final pagination = data['pagination'] is Map<String, dynamic> ? data['pagination'] : data;

    return StaffListResponse(
      docs: usersList.map((e) => StaffUser.fromJson(e)).toList(),
      totalDocs: data['totalCount'] ?? data['totalDocs'] ?? 0,
      limit: pagination['limit'] ?? 10,
      page: pagination['page'] ?? 1,
      totalPages: pagination['totalPages'] ?? 1, 
    );
  }

  // Helper alias to match usage in UI
  List<StaffUser> get users => docs;
}
