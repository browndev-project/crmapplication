
class PermissionResponse {
  final int statusCode;
  final PermissionData data;
  final String message;
  final bool success;

  PermissionResponse({
    required this.statusCode,
    required this.data,
    required this.message,
    required this.success,
  });

  factory PermissionResponse.fromJson(Map<String, dynamic> json) {
    return PermissionResponse(
      statusCode: json['statusCode'] ?? 200,
      data: PermissionData.fromJson(json['data'] ?? {}),
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

class PermissionData {
  final UserPermissionInfo user;

  PermissionData({required this.user});

  factory PermissionData.fromJson(Map<String, dynamic> json) {
    return PermissionData(
      user: UserPermissionInfo.fromJson(json['user'] ?? {}),
    );
  }
}

class UserPermissionInfo {
  final String role;
  final List<dynamic> permissions;
  final List<String> modules;

  UserPermissionInfo({
    required this.role,
    required this.permissions,
    required this.modules,
  });

  factory UserPermissionInfo.fromJson(Map<String, dynamic> json) {
    return UserPermissionInfo(
      role: json['role'] ?? '',
      permissions: json['permissions'] ?? [],
      modules: List<String>.from(json['modules'] ?? []),
    );
  }
}
