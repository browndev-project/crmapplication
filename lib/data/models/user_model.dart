class BillingInfo {
  final String planType;
  final String startDate;
  final String endDate;
  final int userLimit;

  BillingInfo({
    required this.planType,
    required this.startDate,
    required this.endDate,
    required this.userLimit,
  });

  factory BillingInfo.fromJson(Map<String, dynamic> json) {
    return BillingInfo(
      planType: json['planType'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      userLimit: json['userLimit'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planType': planType,
      'startDate': startDate,
      'endDate': endDate,
      'userLimit': userLimit,
    };
  }
}

class CompanyDetails {
  final String name;
  final String industry;
  final BillingInfo? billing;

  CompanyDetails({
    required this.name,
    required this.industry,
    this.billing,
  });

  factory CompanyDetails.fromJson(Map<String, dynamic> json) {
    return CompanyDetails(
      name: json['name'] ?? '',
      industry: json['industry'] ?? '',
      billing: json['billing'] != null
          ? BillingInfo.fromJson(Map<String, dynamic>.from(json['billing']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'industry': industry,
      'billing': billing?.toJson(),
    };
  }
}

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
  final String? companyRole;
  final CompanyDetails? companyDetails;
  final String? accountType;
  final String? type;
  final String? agencyName;
  final String? reraNumber;
  final String? status;

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
    this.companyRole,
    this.companyDetails,
    this.accountType,
    this.type,
    this.agencyName,
    this.reraNumber,
    this.status,
  });

  bool get isBroker => (accountType?.toLowerCase() == 'broker') || (role.toLowerCase() == 'broker');

  factory User.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString();
    final isActive = json['active'] ?? (statusStr?.toLowerCase() == 'active');

    return User(
      id: json['_id'] ?? json['id'] ?? '',
      active: isActive,
      role: json['role'] ?? '',
      uniqueId: json['uniqueId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      company: json['company'] ?? '',
      systemRole: json['systemRole'] ?? json['role'] ?? '',
      companyRole: json['companyRole'],
      companyDetails: json['companyDetails'] != null
          ? CompanyDetails.fromJson(Map<String, dynamic>.from(json['companyDetails']))
          : null,
      accountType: json['accountType'],
      type: json['type'],
      agencyName: json['agencyName'],
      reraNumber: json['reraNumber'],
      status: json['status'],
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
      'companyRole': companyRole,
      'companyDetails': companyDetails?.toJson(),
      'accountType': accountType,
      'type': type,
      'agencyName': agencyName,
      'reraNumber': reraNumber,
      'status': status,
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
    final data = json['data'] as Map<String, dynamic>?;
    final userMap = data?['user'] != null ? Map<String, dynamic>.from(data!['user']) : null;
    final accountType = data?['accountType'] ?? userMap?['accountType'];
    if (userMap != null && accountType != null && userMap['accountType'] == null) {
      userMap['accountType'] = accountType;
    }

    return LoginResponse(
      user: userMap != null ? User.fromJson(userMap) : null,
      accessToken: data?['accessToken'] ?? '',
      sessionId: data?['sessionId'] ?? '',
      message: json['message'] ?? '',
      success: json['success'] ?? (json['statusCode'] == 200 || json['statusCode'] == 201),
    );
  }
}
