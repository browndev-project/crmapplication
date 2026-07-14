class Company {
  final String id;
  final String name;
  final String companyId;
  final String address;
  final String? gstNumber;
  final String status;
  final String email;
  final String phone;
  final String altPhone;

  // Nested Objects
  final CompanyBilling billing;
  final CompanyFeatures features;
  
  // Stats (from API 'counts', not nested in company object)
  final int totalUsers;
  final int totalLeads;
  final int totalServices;

  final DateTime createdAt;
  final DateTime updatedAt;

  Company({
    required this.id,
    required this.name,
    required this.companyId,
    required this.address,
    this.gstNumber,
    required this.status,
    required this.email,
    required this.phone,
    required this.altPhone,
    required this.billing,
    required this.features,
    required this.totalUsers,
    required this.totalLeads,
    required this.totalServices,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json, Map<String, dynamic> counts) {
    final companyData = json;
    return Company(
      id: companyData['_id'] ?? '',
      name: companyData['name'] ?? '',
      companyId: companyData['companyId'] ?? '',
      address: companyData['address'] ?? '',
      gstNumber: companyData['gstNo'],
      status: (companyData['active'] == true) ? 'Active' : 'Inactive',
      email: companyData['email'] ?? '',
      phone: companyData['contactPhone'] ?? '',
      altPhone: companyData['altContactPhone'] ?? '',
      billing: CompanyBilling.fromJson(companyData['billing'] ?? {}),
      features: CompanyFeatures.fromJson(companyData['features'] ?? {}),
      totalUsers: counts['users'] ?? 0,
      totalLeads: counts['leads'] ?? 0,
      totalServices: counts['services'] ?? 0,
      createdAt: DateTime.parse(companyData['createdAt']),
      updatedAt: DateTime.parse(companyData['updatedAt']),
    );
  }
}

class CompanyBilling {
  final String plan;
  final double perUserPrice;
  final int userLimit;
  final SubscriptionRef? subscription;

  CompanyBilling({
    required this.plan,
    required this.perUserPrice,
    required this.userLimit,
    this.subscription,
  });

  factory CompanyBilling.fromJson(Map<String, dynamic> json) {
    return CompanyBilling(
      plan: json['plan'] ?? 'Free',
      perUserPrice: (json['perUserPrice'] ?? 0).toDouble(),
      userLimit: json['userLimit'] ?? 0,
      subscription: json['subscriptionRef'] != null ? SubscriptionRef.fromJson(json['subscriptionRef']) : null,
    );
  }
}

class SubscriptionRef {
  final String id;
  final String currency;
  final String status;
  final int graceDays;
  final int billingCycleDays;
  final bool autoRenewEnabled;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;

  SubscriptionRef({
    required this.id,
    required this.currency,
    required this.status,
    required this.graceDays,
    required this.billingCycleDays,
    required this.autoRenewEnabled,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
  });

  factory SubscriptionRef.fromJson(Map<String, dynamic> json) {
    return SubscriptionRef(
      id: json['_id'] ?? '',
      currency: json['currency'] ?? 'INR',
      status: json['status'] ?? 'inactive',
      graceDays: json['graceDays'] ?? 0,
      billingCycleDays: json['billingCycleDays'] ?? 30,
      autoRenewEnabled: json['autoRenewEnabled'] ?? false,
      currentPeriodStart: DateTime.tryParse(json['currentPeriodStart'] ?? '') ?? DateTime.now(),
      currentPeriodEnd: DateTime.tryParse(json['currentPeriodEnd'] ?? '') ?? DateTime.now(),
    );
  }
  
  // Derived helper for 'daysLeft'
  int get daysLeft {
    final now = DateTime.now();
    final difference = currentPeriodEnd.difference(now);
    return difference.isNegative ? 0 : difference.inDays;
  }
}

class CompanyFeatures {
  final bool leadsEnabled;
  final bool attendanceEnabled;
  final bool collaborationEnabled;

  CompanyFeatures({
    required this.leadsEnabled,
    required this.attendanceEnabled,
    required this.collaborationEnabled,
  });

  factory CompanyFeatures.fromJson(Map<String, dynamic> json) {
    return CompanyFeatures(
      leadsEnabled: json['leads']?['enabled'] ?? false,
      attendanceEnabled: json['attendance']?['enabled'] ?? false,
      collaborationEnabled: json['collaboration']?['enabled'] ?? false,
    );
  }
}
