
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value.toString());
  return parsed ?? 0.0;
}

class BookingResponse {
  final int statusCode;
  final BookingData? data;
  final String message;
  final bool success;

  BookingResponse({
    required this.statusCode,
    this.data,
    required this.message,
    required this.success,
  });

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      statusCode: json['statusCode'] ?? 200,
      data: json['data'] != null ? BookingData.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

class BookingData {
  final List<Booking> bookings;
  final BookingStats? stats;

  BookingData({
    required this.bookings,
    this.stats,
  });

  factory BookingData.fromJson(Map<String, dynamic> json) {
    var bookingsList = <Booking>[];
    if (json['bookings'] is List) {
      bookingsList = (json['bookings'] as List)
          .map((i) => Booking.fromJson(i is Map<String, dynamic> ? i : {}))
          .toList();
    } else if (json['data'] is Map && json['data']['bookings'] is List) {
      bookingsList = (json['data']['bookings'] as List)
          .map((i) => Booking.fromJson(i is Map<String, dynamic> ? i : {}))
          .toList();
    } else if (json['booking'] != null) {
      bookingsList = [Booking.fromJson(json['booking'])];
    }
    BookingStats? stats;
    if (json['stats'] != null) {
      stats = BookingStats.fromJson(json['stats']);
    } else if (json['active'] != null || json['completed'] != null || json['cancelled'] != null) {
      stats = BookingStats.fromJson(json);
    }

    return BookingData(
      bookings: bookingsList,
      stats: stats,
    );
  }
}

class BookingStats {
  final int active;
  final int completed;
  final int cancelled;

  BookingStats({
    this.active = 0,
    this.completed = 0,
    this.cancelled = 0,
  });

  factory BookingStats.fromJson(Map<String, dynamic> json) {
    return BookingStats(
      active: json['active'] ?? 0,
      completed: json['completed'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
    );
  }
}

class BookingLead {
  final String id;
  final String name;
  final String email;
  final String phoneNo;

  BookingLead({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNo,
  });

  factory BookingLead.fromJson(Map<String, dynamic> json) {
    return BookingLead(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'email': email,
    'phoneNo': phoneNo,
  };
}

class BookingProperty {
  final String id;
  final String name;
  final String block;
  final String type;
  final String brokerageType;
  final double brokerageValue;

  BookingProperty({
    required this.id,
    required this.name,
    this.block = '',
    this.type = '',
    this.brokerageType = 'none',
    this.brokerageValue = 0.0,
  });

  factory BookingProperty.fromJson(Map<String, dynamic> json) {
    return BookingProperty(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? json['title'] ?? '',
      block: json['block'] ?? '',
      type: json['type'] ?? '',
      brokerageType: json['brokerageType'] ?? 'none',
      brokerageValue: _parseDouble(json['brokerageValue']),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'block': block,
    'type': type,
    'brokerageType': brokerageType,
    'brokerageValue': brokerageValue,
  };
}

class BookingBroker {
  final String id;
  final String name;
  final String agencyName;
  final String phoneNo;
  final String email;

  BookingBroker({
    required this.id,
    required this.name,
    this.agencyName = '',
    this.phoneNo = '',
    this.email = '',
  });

  factory BookingBroker.fromJson(Map<String, dynamic> json) {
    return BookingBroker(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      agencyName: json['agencyName'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'agencyName': agencyName,
    'phoneNo': phoneNo,
    'email': email,
  };
}

class BookingPaymentMilestone {
  final String id;
  final String milestoneName;
  final double amount;
  final String dueDate;
  final String status;
  final String? paidDate;

  BookingPaymentMilestone({
    this.id = '',
    required this.milestoneName,
    required this.amount,
    required this.dueDate,
    this.status = 'pending',
    this.paidDate,
  });

  factory BookingPaymentMilestone.fromJson(Map<String, dynamic> json) {
    return BookingPaymentMilestone(
      id: json['_id'] ?? '',
      milestoneName: json['milestoneName'] ?? '',
      amount: _parseDouble(json['amount']),
      dueDate: json['dueDate'] ?? '',
      status: json['status'] ?? 'pending',
      paidDate: json['paidDate'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) '_id': id,
    'milestoneName': milestoneName,
    'amount': amount,
    'dueDate': dueDate,
    'status': status,
    'paidDate': paidDate,
  };
}

class BookingTemplate {
  final String? name;
  final String? language;
  final List<dynamic> components;

  BookingTemplate({
    this.name,
    this.language,
    this.components = const [],
  });

  factory BookingTemplate.fromJson(Map<String, dynamic> json) {
    return BookingTemplate(
      name: json['name'],
      language: json['language'],
      components: json['components'] ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'language': language,
    'components': components,
  };
}

class BookingVariableMapping {
  final String key;
  final String section;
  final String source;
  final String customValue;

  BookingVariableMapping({
    this.key = '',
    this.section = '',
    this.source = '',
    this.customValue = '',
  });

  factory BookingVariableMapping.fromJson(Map<String, dynamic> json) {
    return BookingVariableMapping(
      key: json['key'] ?? '',
      section: json['section'] ?? '',
      source: json['source'] ?? '',
      customValue: json['customValue'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'section': section,
    'source': source,
    'customValue': customValue,
  };
}

class Booking {
  final String id;
  final String company;
  final BookingLead? lead;
  final BookingProperty? property;
  final double finalAmount;
  final double bookingAmount;
  final String status;
  final bool isBrokerageDeal;
  final BookingBroker? broker;
  final String brokerageType;
  final double brokerageValue;
  final double brokerageAmount;
  final double paidBrokerageAmount;
  final String brokerageStatus;
  final List<BookingPaymentMilestone> paymentPlan;
  final bool sendReminders;
  final int reminderDaysBefore;
  final String reminderTime;
  final BookingTemplate? reminderTemplate;
  final List<BookingVariableMapping> reminderVariableMappings;
  final bool sendOverdueReminders;
  final int overdueReminderDaysLimit;
  final String overdueReminderTime;
  final BookingTemplate? overdueReminderTemplate;
  final List<BookingVariableMapping> overdueReminderVariableMappings;
  final String? createdBy;
  final String? updatedBy;
  final String? createdAt;
  final String? updatedAt;

  Booking({
    required this.id,
    required this.company,
    this.lead,
    this.property,
    required this.finalAmount,
    required this.bookingAmount,
    required this.status,
    this.isBrokerageDeal = false,
    this.broker,
    this.brokerageType = 'none',
    this.brokerageValue = 0.0,
    this.brokerageAmount = 0.0,
    this.paidBrokerageAmount = 0.0,
    this.brokerageStatus = 'no_brokerage',
    this.paymentPlan = const [],
    this.sendReminders = true,
    this.reminderDaysBefore = 7,
    this.reminderTime = "10:00",
    this.reminderTemplate,
    this.reminderVariableMappings = const [],
    this.sendOverdueReminders = true,
    this.overdueReminderDaysLimit = 7,
    this.overdueReminderTime = "10:00",
    this.overdueReminderTemplate,
    this.overdueReminderVariableMappings = const [],
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    String getCreatedBy(dynamic value) {
      if (value == null) return '';
      if (value is Map) return value['name'] ?? '';
      return value.toString();
    }

    BookingLead? leadVal;
    if (json['lead'] != null) {
      if (json['lead'] is Map) {
        leadVal = BookingLead.fromJson(Map<String, dynamic>.from(json['lead']));
      } else {
        leadVal = BookingLead(id: json['lead'].toString(), name: '', email: '', phoneNo: '');
      }
    }

    BookingProperty? propertyVal;
    if (json['property'] != null) {
      if (json['property'] is Map) {
        propertyVal = BookingProperty.fromJson(Map<String, dynamic>.from(json['property']));
      } else {
        propertyVal = BookingProperty(id: json['property'].toString(), name: '');
      }
    }

    BookingBroker? brokerVal;
    if (json['broker'] != null) {
      if (json['broker'] is Map) {
        brokerVal = BookingBroker.fromJson(Map<String, dynamic>.from(json['broker']));
      } else {
        brokerVal = BookingBroker(id: json['broker'].toString(), name: '');
      }
    }

    return Booking(
      id: json['_id'] ?? '',
      company: json['company'] ?? '',
      lead: leadVal,
      property: propertyVal,
      finalAmount: _parseDouble(json['finalAmount']),
      bookingAmount: _parseDouble(json['bookingAmount']),
      status: json['status'] ?? 'active',
      isBrokerageDeal: json['isBrokerageDeal'] ?? false,
      broker: brokerVal,
      brokerageType: json['brokerageType'] ?? 'none',
      brokerageValue: _parseDouble(json['brokerageValue']),
      brokerageAmount: _parseDouble(json['brokerageAmount']),
      paidBrokerageAmount: _parseDouble(json['paidBrokerageAmount']),
      brokerageStatus: json['brokerageStatus'] ?? 'no_brokerage',
      paymentPlan: json['paymentPlan'] is List
          ? (json['paymentPlan'] as List)
              .map((i) => BookingPaymentMilestone.fromJson(i is Map<String, dynamic> ? i : {}))
              .toList()
          : const [],
      sendReminders: json['sendReminders'] ?? true,
      reminderDaysBefore: json['reminderDaysBefore'] ?? 7,
      reminderTime: json['reminderTime'] ?? "10:00",
      reminderTemplate: json['reminderTemplate'] != null
          ? BookingTemplate.fromJson(json['reminderTemplate'])
          : null,
      reminderVariableMappings: json['reminderVariableMappings'] is List
          ? (json['reminderVariableMappings'] as List)
              .map((i) => BookingVariableMapping.fromJson(i is Map<String, dynamic> ? i : {}))
              .toList()
          : const [],
      sendOverdueReminders: json['sendOverdueReminders'] ?? true,
      overdueReminderDaysLimit: json['overdueReminderDaysLimit'] ?? 7,
      overdueReminderTime: json['overdueReminderTime'] ?? "10:00",
      overdueReminderTemplate: json['overdueReminderTemplate'] != null
          ? BookingTemplate.fromJson(json['overdueReminderTemplate'])
          : null,
      overdueReminderVariableMappings: json['overdueReminderVariableMappings'] is List
          ? (json['overdueReminderVariableMappings'] as List)
              .map((i) => BookingVariableMapping.fromJson(i is Map<String, dynamic> ? i : {}))
              .toList()
          : const [],
      createdBy: getCreatedBy(json['createdBy']),
      updatedBy: getCreatedBy(json['updatedBy']),
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) '_id': id,
    'company': company,
    if (lead != null) 'lead': lead!.id,
    if (property != null) 'property': property!.id,
    'finalAmount': finalAmount,
    'bookingAmount': bookingAmount,
    'status': status,
    'isBrokerageDeal': isBrokerageDeal,
    if (broker != null) 'broker': broker!.id,
    'brokerageType': brokerageType,
    'brokerageValue': brokerageValue,
    'brokerageAmount': brokerageAmount,
    'paidBrokerageAmount': paidBrokerageAmount,
    'brokerageStatus': brokerageStatus,
    'paymentPlan': paymentPlan.map((i) => i.toJson()).toList(),
    'sendReminders': sendReminders,
    'reminderDaysBefore': reminderDaysBefore,
    'reminderTime': reminderTime,
    if (reminderTemplate != null) 'reminderTemplate': reminderTemplate!.toJson(),
    'reminderVariableMappings': reminderVariableMappings.map((i) => i.toJson()).toList(),
    'sendOverdueReminders': sendOverdueReminders,
    'overdueReminderDaysLimit': overdueReminderDaysLimit,
    'overdueReminderTime': overdueReminderTime,
    if (overdueReminderTemplate != null) 'overdueReminderTemplate': overdueReminderTemplate!.toJson(),
    'overdueReminderVariableMappings': overdueReminderVariableMappings.map((i) => i.toJson()).toList(),
  };
}
