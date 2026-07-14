class User {
  final String id;
  final bool active;
  final String role;
  final String uniqueId;
  final String name;
  final String email;
  final String phoneNo;
  final String company;
  final String systemRole;

  User({
    required this.id,
    required this.active,
    required this.role,
    required this.uniqueId,
    required this.name,
    required this.email,
    required this.phoneNo,
    required this.company,
    required this.systemRole,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      active: json['active'] ?? false,
      role: json['role'] ?? '',
      uniqueId: json['uniqueId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      company: json['company'] ?? '',
      systemRole: json['systemRole'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'active': active,
      'role': role,
      'uniqueId': uniqueId,
      'name': name,
      'email': email,
      'phoneNo': phoneNo,
      'company': company,
      'systemRole': systemRole,
    };
  }
}

class LoginResponse {
  final User? user;
  final String accessToken;
  final String sessionId; 
  final String message;
  final bool success;

  LoginResponse({
    this.user,
    required this.accessToken,
    required this.sessionId,
    required this.message,
    required this.success,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      user: json['data']?['user'] != null ? User.fromJson(json['data']['user']) : null,
      accessToken: json['data']?['accessToken'] ?? '',
      sessionId: json['data']?['sessionId'] ?? '',
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}
