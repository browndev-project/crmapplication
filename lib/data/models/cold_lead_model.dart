class ColdLead {
  final String id;
  final String? company;
  final String name;
  final String phoneNo;
  final String? email;
  final String? source;
  final String status;
  final String? notes;
  final bool isConvertedToLead;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ColdLead({
    required this.id,
    this.company,
    required this.name,
    required this.phoneNo,
    this.email,
    this.source,
    required this.status,
    this.notes,
    this.isConvertedToLead = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ColdLead.fromJson(Map<String, dynamic> json) {
    return ColdLead(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      company: json['company']?.toString(),
      name: json['name']?.toString() ?? 'Unnamed',
      phoneNo: json['phoneNo']?.toString() ?? '',
      email: json['email']?.toString(),
      source: json['source']?.toString() ?? 'Cold Data',
      status: json['status']?.toString() ?? 'New',
      notes: json['notes']?.toString(),
      isConvertedToLead: json['isConvertedToLead'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      if (company != null) 'company': company,
      'name': name,
      'phoneNo': phoneNo,
      if (email != null) 'email': email,
      if (source != null) 'source': source,
      'status': status,
      if (notes != null) 'notes': notes,
      'isConvertedToLead': isConvertedToLead,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  ColdLead copyWith({
    String? id,
    String? company,
    String? name,
    String? phoneNo,
    String? email,
    String? source,
    String? status,
    String? notes,
    bool? isConvertedToLead,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ColdLead(
      id: id ?? this.id,
      company: company ?? this.company,
      name: name ?? this.name,
      phoneNo: phoneNo ?? this.phoneNo,
      email: email ?? this.email,
      source: source ?? this.source,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isConvertedToLead: isConvertedToLead ?? this.isConvertedToLead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ColdLeadsPagination {
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const ColdLeadsPagination({
    this.page = 1,
    this.limit = 20,
    this.totalPages = 1,
    this.hasNextPage = false,
    this.hasPrevPage = false,
  });

  factory ColdLeadsPagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ColdLeadsPagination();
    return ColdLeadsPagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasNextPage: json['hasNextPage'] == true,
      hasPrevPage: json['hasPrevPage'] == true,
    );
  }
}

class ColdLeadsResponse {
  final List<ColdLead> coldLeads;
  final int totalCount;
  final ColdLeadsPagination pagination;
  final String message;
  final bool success;

  const ColdLeadsResponse({
    required this.coldLeads,
    required this.totalCount,
    required this.pagination,
    required this.message,
    required this.success,
  });

  factory ColdLeadsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawList = data['coldLeads'];
    final List<ColdLead> leads = [];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          leads.add(ColdLead.fromJson(item));
        }
      }
    }

    final total = (data['totalCount'] as num?)?.toInt() ?? leads.length;
    final pagination = ColdLeadsPagination.fromJson(
      data['pagination'] as Map<String, dynamic>?,
    );

    return ColdLeadsResponse(
      coldLeads: leads,
      totalCount: total,
      pagination: pagination,
      message: json['message']?.toString() ?? '',
      success: json['success'] == true,
    );
  }
}
