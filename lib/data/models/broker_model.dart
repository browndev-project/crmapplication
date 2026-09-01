class BrokerResponse {
  final int statusCode;
  final BrokerData? data;
  final String message;
  final bool success;

  BrokerResponse({
    required this.statusCode,
    this.data,
    required this.message,
    required this.success,
  });

  factory BrokerResponse.fromJson(Map<String, dynamic> json) {
    return BrokerResponse(
      statusCode: json['statusCode'] ?? 0,
      data: json['data'] != null ? BrokerData.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

class BrokerData {
  final List<Broker> brokers;
  final int totalCount;
  final BrokerPagination pagination;

  BrokerData({
    required this.brokers,
    required this.totalCount,
    required this.pagination,
  });

  factory BrokerData.fromJson(Map<String, dynamic> json) {
    return BrokerData(
      brokers: (json['brokers'] as List?)?.map((e) => Broker.fromJson(e)).toList() ?? [],
      totalCount: json['totalCount'] ?? 0,
      pagination: BrokerPagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

class BrokerAddress {
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String pinCode;
  final String country;

  BrokerAddress({
    this.address1 = '',
    this.address2 = '',
    this.city = '',
    this.state = '',
    this.pinCode = '',
    this.country = 'India',
  });

  factory BrokerAddress.fromJson(Map<String, dynamic> json) {
    return BrokerAddress(
      address1: json['address1'] ?? '',
      address2: json['address2'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pinCode: json['pinCode'] ?? '',
      country: json['country'] ?? 'India',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'pinCode': pinCode,
      'country': country,
    };
  }

  String toDisplayString() {
    final parts = [address1, address2, city, state, pinCode, country]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'No address details' : parts.join(', ');
  }
}

class Broker {
  final String id;
  final String type; // 'Broker' or 'ChannelPartner'
  final String name;
  final String phoneNo;
  final String email;
  final String agencyName;
  final String panNumber;
  final String reraNumber;
  final String uniqueId;
  final List<String> assignedUsers;
  final String status; // 'active' or 'inactive'
  final String notes;
  final int bookingsCount;
  final double totalBrokerage;
  final double paidBrokerage;
  final double pendingBrokerage;
  final BrokerAddress address;
  final String? createdAt;

  Broker({
    required this.id,
    required this.type,
    required this.name,
    required this.phoneNo,
    this.email = '',
    this.agencyName = '',
    this.panNumber = '',
    this.reraNumber = '',
    this.uniqueId = '',
    this.assignedUsers = const [],
    this.status = 'active',
    this.notes = '',
    this.bookingsCount = 0,
    this.totalBrokerage = 0.0,
    this.paidBrokerage = 0.0,
    this.pendingBrokerage = 0.0,
    required this.address,
    this.createdAt,
  });

  factory Broker.fromJson(Map<String, dynamic> json) {
    return Broker(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'Broker',
      name: json['name'] ?? 'Unknown Partner',
      phoneNo: json['phoneNo'] ?? '',
      email: json['email'] ?? '',
      agencyName: json['agencyName'] ?? '',
      panNumber: json['panNumber'] ?? '',
      reraNumber: json['reraNumber'] ?? '',
      uniqueId: json['uniqueId'] ?? '',
      assignedUsers: (json['assignedUsers'] as List?)
              ?.map((e) => e is Map ? (e['_id'] ?? e['id'] ?? '').toString() : e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      status: json['status'] ?? 'active',
      notes: json['notes'] ?? '',
      bookingsCount: json['bookingsCount'] ?? 0,
      totalBrokerage: (json['totalBrokerage'] ?? 0).toDouble(),
      paidBrokerage: (json['paidBrokerage'] ?? 0).toDouble(),
      pendingBrokerage: (json['pendingBrokerage'] ?? 0).toDouble(),
      address: BrokerAddress.fromJson(json['address'] ?? {}),
      createdAt: json['createdAt'],
    );
  }
}

class DailyLeadTrend {
  final String date;
  final String displayDate;
  final int leads;

  DailyLeadTrend({
    required this.date,
    required this.displayDate,
    required this.leads,
  });

  factory DailyLeadTrend.fromJson(Map<String, dynamic> json) {
    return DailyLeadTrend(
      date: json['date'] ?? '',
      displayDate: json['displayDate'] ?? '',
      leads: json['leads'] ?? 0,
    );
  }
}

class BrokerDashboardData {
  final Broker? broker;
  final int totalLeads;
  final int activePipeline;
  final int totalBookings;
  final double totalBrokerage;
  final double paidBrokerage;
  final double pendingBrokerage;
  final List<DailyLeadTrend> dailyLeadsTrend;

  BrokerDashboardData({
    this.broker,
    required this.totalLeads,
    required this.activePipeline,
    required this.totalBookings,
    required this.totalBrokerage,
    required this.paidBrokerage,
    required this.pendingBrokerage,
    required this.dailyLeadsTrend,
  });

  factory BrokerDashboardData.fromJson(Map<String, dynamic> json) {
    return BrokerDashboardData(
      broker: json['broker'] != null ? Broker.fromJson(json['broker']) : null,
      totalLeads: json['totalLeads'] ?? 0,
      activePipeline: json['activePipeline'] ?? 0,
      totalBookings: json['totalBookings'] ?? 0,
      totalBrokerage: (json['totalBrokerage'] ?? 0).toDouble(),
      paidBrokerage: (json['paidBrokerage'] ?? 0).toDouble(),
      pendingBrokerage: (json['pendingBrokerage'] ?? 0).toDouble(),
      dailyLeadsTrend: (json['dailyLeadsTrend'] as List?)
              ?.map((e) => DailyLeadTrend.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class BrokerPagination {
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  BrokerPagination({
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory BrokerPagination.fromJson(Map<String, dynamic> json) {
    return BrokerPagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? 1,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPrevPage: json['hasPrevPage'] ?? false,
    );
  }
}

class BrokerStats {
  final int totalAgents;
  final int channelPartners;
  final int activeBrokers;
  final int inactiveBrokers;

  BrokerStats({
    required this.totalAgents,
    required this.channelPartners,
    required this.activeBrokers,
    required this.inactiveBrokers,
  });

  factory BrokerStats.fromJson(Map<String, dynamic> json) {
    return BrokerStats(
      totalAgents: json['totalAgents'] ?? 0,
      channelPartners: json['channelPartners'] ?? 0,
      activeBrokers: json['activeBrokers'] ?? 0,
      inactiveBrokers: json['inactiveBrokers'] ?? 0,
    );
  }
}

class BrokerReferredLead {
  final String id;
  final String name;
  final String phoneNo;
  final String notes;
  final String createdAt;

  BrokerReferredLead({
    required this.id,
    required this.name,
    required this.phoneNo,
    required this.notes,
    required this.createdAt,
  });

  factory BrokerReferredLead.fromJson(Map<String, dynamic> json) {
    return BrokerReferredLead(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}
