import 'package:crmapp/data/models/service_model.dart';
import 'package:crmapp/data/models/common_models.dart';
import 'package:crmapp/data/models/visit_model.dart';

class LeadAddress {
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String pinCode;
  final String country;

  LeadAddress({
    this.address1 = '',
    this.address2 = '',
    this.city = '',
    this.state = '',
    this.pinCode = '',
    this.country = '',
  });

  factory LeadAddress.fromJson(Map<String, dynamic> json) {
    return LeadAddress(
      address1: json['address1'] ?? '',
      address2: json['address2'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pinCode: json['pinCode'] ?? '',
      country: json['country'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'address1': address1,
    'address2': address2,
    'city': city,
    'state': state,
    'pinCode': pinCode,
    'country': country,
  };
}

class Lead {
  final String id;
  final String leadId; // Added for unique display ID
  final String source;
  final String status;
  final String pipeline;
  final String name;
  final String email;
  final String phoneNo;
  final String description;
  final String? dob; // Added
  final String? gender; // Added
  final String? referralName; // Added
  final LeadAddress? address; // Added nested address
  final Service? service;
  final AssignedTo? assignedTo;
  final String createdAt;
  final String updatedAt;
  final double amount;

  // Travel / Trip Details
  final String? destination;
  final String? travelDates;       // Combined raw string (legacy)
  final String? travelStartDate;   // Parsed start date
  final String? travelEndDate;     // Parsed end date
  final int? travellers;
  final int? adultCount;
  final int? childrenCount;
  final String? hotelPreference;
  final String? vehiclePreference;
  final String? travelBudget;
  final String? pickupDrop;
  final String? pickup;
  final String? drop;
  final String? specialRequests;
  final String? travelerType;
  
  // New detailed fields
  final List<String>? taskIds;
  final List<String>? meetingIds;
  final List<String>? statusHistoryIds;
  final List<String>? assignHistoryIds;

  // Flexible fields for Details which might be objects in other endpoints
  final List<Task>? tasks;
  final List<Meeting>? meetings;
  final List<StatusHistory>? statusHistory;
  final List<AssignHistory>? assignHistory;
  final List<Visit>? visits;

  final UserShort? createdBy;
  final String? company; 
  final IdName? group;
  final IdName? team;
  final AssignedTeam? assignedTeam;

  final IdName? project;
  final IdName? property;
  final List<SubAssignee>? subAssignees;
  final LeadRequirements? requirements;

  Lead({
    required this.id,
    required this.leadId,
    required this.source,
    required this.status,
    required this.pipeline,
    required this.name,
    required this.email,
    required this.phoneNo,
    required this.description,
    this.dob,
    this.gender,
    this.referralName,
    this.address,
    this.service,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.amount = 0,
    this.destination,
    this.travelDates,
    this.travelStartDate,
    this.travelEndDate,
    this.travellers,
    this.adultCount,
    this.childrenCount,
    this.hotelPreference,
    this.vehiclePreference,
    this.travelBudget,
    this.pickupDrop,
    this.pickup,
    this.drop,
    this.specialRequests,
    this.travelerType,
    this.taskIds,
    this.meetingIds,
    this.statusHistoryIds,
    this.assignHistoryIds,
    this.tasks,
    this.meetings,
    this.statusHistory,
    this.assignHistory,
    this.visits,
    this.createdBy,
    this.company,
    this.group,
    this.team,
    this.assignedTeam,
    this.project,
    this.property,
    this.subAssignees,
    this.requirements,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: _safeString(json['_id']),
      leadId: _safeString(json['leadId']),
      source: _safeString(json['source']),
      status: _safeString(json['status']),
      pipeline: _safeString(json['pipeline']),
      name: _safeString(json['name']),
      email: _safeString(json['email']),
      phoneNo: _safeString(json['phoneNo']),
      description: _safeString(json['description']),
      dob: json['dob'] != null ? _safeString(json['dob']) : null,
      gender: json['gender'] != null ? _safeString(json['gender']) : null,
      referralName: json['referralName'] != null ? _safeString(json['referralName']) : null,
      address: json['address'] is Map ? LeadAddress.fromJson(Map<String, dynamic>.from(json['address'] as Map)) : null,
      service: json['service'] is Map ? Service.fromJson(Map<String, dynamic>.from(json['service'] as Map)) : null,
      assignedTo: json['assignedTo'] is Map ? AssignedTo.fromJson(Map<String, dynamic>.from(json['assignedTo'] as Map)) : null,
      createdAt: _safeString(json['createdAt']),
      updatedAt: _safeString(json['updatedAt']),
      amount: (json['amount'] ?? 0).toDouble(),
      destination: (json['travelDetails'] is Map && json['travelDetails']['destination'] != null)
          ? _safeString(json['travelDetails']['destination'])
          : ((json['trip'] is Map && json['trip']['destination'] != null)
              ? _safeString(json['trip']['destination'])
              : (json['destination'] != null ? _safeString(json['destination']) : null)),
      travelDates: (json['travelDetails'] is Map && json['travelDetails']['travelDates'] != null)
          ? _safeString(json['travelDetails']['travelDates'])
          : ((json['travelDetails'] is Map && json['travelDetails']['dates'] != null)
              ? _safeString(json['travelDetails']['dates'])
              : ((json['trip'] is Map && json['trip']['startDate'] != null)
                  ? _safeString(json['trip']['startDate']) + (json['trip']['endDate'] != null ? ' to ${json['trip']['endDate']}' : '')
                  : (json['travelDates'] != null
                      ? _safeString(json['travelDates'])
                      : (json['dates'] != null ? _safeString(json['dates']) : null)))),
      // Parse start/end dates from various backend structures
      travelStartDate: (() {
        // Prefer explicit startDate fields
        if (json['travelDetails'] is Map && json['travelDetails']['startDate'] != null) return _safeString(json['travelDetails']['startDate']);
        if (json['trip'] is Map && json['trip']['startDate'] != null) return _safeString(json['trip']['startDate']);
        // Fall back to splitting combined travelDates
        final raw = (json['travelDetails'] is Map && json['travelDetails']['travelDates'] != null)
            ? _safeString(json['travelDetails']['travelDates'])
            : (json['travelDates'] != null ? _safeString(json['travelDates']) : null);
        if (raw != null && raw.contains(' to ')) return raw.split(' to ')[0].trim();
        return raw;
      })(),
      travelEndDate: (() {
        if (json['travelDetails'] is Map && json['travelDetails']['endDate'] != null) return _safeString(json['travelDetails']['endDate']);
        if (json['trip'] is Map && json['trip']['endDate'] != null) return _safeString(json['trip']['endDate']);
        final raw = (json['travelDetails'] is Map && json['travelDetails']['travelDates'] != null)
            ? _safeString(json['travelDetails']['travelDates'])
            : (json['travelDates'] != null ? _safeString(json['travelDates']) : null);
        if (raw != null && raw.contains(' to ')) return raw.split(' to ')[1].trim();
        return null;
      })(),
      travellers: (json['travelDetails'] is Map && json['travelDetails']['travellers'] != null)
          ? int.tryParse(json['travelDetails']['travellers'].toString())
          : ((json['trip'] is Map && (json['trip']['numAdults'] != null || json['trip']['numChildren'] != null))
              ? ((json['trip']['numAdults'] ?? 0) + (json['trip']['numChildren'] ?? 0))
              : (json['travellers'] != null ? int.tryParse(json['travellers'].toString()) : null)),
      adultCount: (json['trip'] is Map && json['trip']['numAdults'] != null)
          ? int.tryParse(json['trip']['numAdults'].toString())
          : null,
      childrenCount: (json['trip'] is Map && json['trip']['numChildren'] != null)
          ? int.tryParse(json['trip']['numChildren'].toString())
          : null,
      hotelPreference: (json['travelDetails'] is Map && json['travelDetails']['hotel'] != null)
          ? _safeString(json['travelDetails']['hotel'])
          : ((json['travelDetails'] is Map && json['travelDetails']['hotelPreference'] != null)
              ? _safeString(json['travelDetails']['hotelPreference'])
              : ((json['trip'] is Map && json['trip']['hotelCategory'] != null)
                  ? _safeString(json['trip']['hotelCategory'])
                  : (json['hotel'] != null
                      ? _safeString(json['hotel'])
                      : (json['hotelPreference'] != null ? _safeString(json['hotelPreference']) : null)))),
      vehiclePreference: (json['travelDetails'] is Map && json['travelDetails']['vehicle'] != null)
          ? _safeString(json['travelDetails']['vehicle'])
          : ((json['travelDetails'] is Map && json['travelDetails']['vehiclePreference'] != null)
              ? _safeString(json['travelDetails']['vehiclePreference'])
              : ((json['trip'] is Map && json['trip']['vehiclePreference'] != null)
                  ? _safeString(json['trip']['vehiclePreference'])
                  : (json['vehicle'] != null
                      ? _safeString(json['vehicle'])
                      : (json['vehiclePreference'] != null ? _safeString(json['vehiclePreference']) : null)))),
      travelBudget: (json['travelDetails'] is Map && json['travelDetails']['travelBudget'] != null)
          ? _safeString(json['travelDetails']['travelBudget'])
          : ((json['travelDetails'] is Map && json['travelDetails']['budget'] != null)
              ? _safeString(json['travelDetails']['budget'])
              : ((json['trip'] is Map && json['trip']['budgetRange'] != null)
                  ? _safeString(json['trip']['budgetRange'])
                  : (json['travelBudget'] != null
                      ? _safeString(json['travelBudget'])
                      : (json['budget'] != null ? _safeString(json['budget']) : null)))),
      pickupDrop: (json['travelDetails'] is Map && json['travelDetails']['pickupDrop'] != null)
          ? _safeString(json['travelDetails']['pickupDrop'])
          : ((json['travelDetails'] is Map && json['travelDetails']['pickup_drop'] != null)
              ? _safeString(json['travelDetails']['pickup_drop'])
              : ((json['trip'] is Map && json['trip']['pickupLocation'] != null)
                  ? _safeString(json['trip']['pickupLocation'])
                  : (json['pickupDrop'] != null
                      ? _safeString(json['pickupDrop'])
                      : (json['pickup_drop'] != null ? _safeString(json['pickup_drop']) : null)))),
      pickup: (json['travelDetails'] is Map && json['travelDetails']['pickup'] != null)
          ? _safeString(json['travelDetails']['pickup'])
          : ((json['trip'] is Map && json['trip']['pickupLocation'] != null)
              ? _safeString(json['trip']['pickupLocation'])
              : ((json['trip'] is Map && json['trip']['pickup'] != null)
                  ? _safeString(json['trip']['pickup'])
                  : (json['pickup'] != null ? _safeString(json['pickup']) : null))),
      drop: (json['travelDetails'] is Map && json['travelDetails']['drop'] != null)
          ? _safeString(json['travelDetails']['drop'])
          : ((json['trip'] is Map && json['trip']['dropLocation'] != null)
              ? _safeString(json['trip']['dropLocation'])
              : ((json['trip'] is Map && json['trip']['drop'] != null)
                  ? _safeString(json['trip']['drop'])
                  : (json['drop'] != null ? _safeString(json['drop']) : null))),
      specialRequests: (json['travelDetails'] is Map && json['travelDetails']['specialRequests'] != null)
          ? _safeString(json['travelDetails']['specialRequests'])
          : ((json['travelDetails'] is Map && json['travelDetails']['special_requests'] != null)
              ? _safeString(json['travelDetails']['special_requests'])
              : ((json['trip'] is Map && json['trip']['specialRequests'] != null)
                  ? _safeString(json['trip']['specialRequests'])
                  : (json['specialRequests'] != null
                      ? _safeString(json['specialRequests'])
                      : (json['special_requests'] != null ? _safeString(json['special_requests']) : null)))),
      travelerType: (json['travelDetails'] is Map && json['travelDetails']['travelerType'] != null)
          ? _safeString(json['travelDetails']['travelerType'])
          : ((json['trip'] is Map && json['trip']['travelerType'] != null)
              ? _safeString(json['trip']['travelerType'])
              : (json['travelerType'] != null ? _safeString(json['travelerType']) : null)),
      
      // Handle Lists of IDs
      taskIds: json['tasks'] != null ? (json['tasks'] as List).whereType<String>().cast<String>().toList() : null,
      meetingIds: json['meetings'] != null ? (json['meetings'] as List).whereType<String>().cast<String>().toList() : null,
      statusHistoryIds: json['statusHistory'] != null ? (json['statusHistory'] as List).whereType<String>().cast<String>().toList() : null,
      assignHistoryIds: json['assignHistory'] != null ? (json['assignHistory'] as List).whereType<String>().cast<String>().toList() : null,

      // Handle Lists of Objects (if present, e.g. in details view)
      tasks: json['tasks'] != null ? (json['tasks'] as List).whereType<Map<String, dynamic>>().map((e) => Task.fromJson(e)).toList() : null,
      meetings: json['meetings'] != null ? (json['meetings'] as List).whereType<Map<String, dynamic>>().map((e) => Meeting.fromJson(e)).toList() : null,
      statusHistory: json['statusHistory'] != null ? (json['statusHistory'] as List).whereType<Map<String, dynamic>>().map((e) => StatusHistory.fromJson(e)).toList() : null,
      assignHistory: json['assignHistory'] != null ? (json['assignHistory'] as List).whereType<Map<String, dynamic>>().map((e) => AssignHistory.fromJson(e)).toList() : null,
      visits: json['visits'] != null ? (json['visits'] as List).whereType<Map<String, dynamic>>().map((e) => Visit.fromJson(e)).toList() : null,

      createdBy: json['createdBy'] is String ? null : (json['createdBy'] is Map ? UserShort.fromJson(Map<String, dynamic>.from(json['createdBy'] as Map)) : null),
      company: json['company'] is String ? json['company'] : (json['company'] is Map ? json['company']['_id'] : null),
      group: json['group'] is Map ? IdName.fromJson(Map<String, dynamic>.from(json['group'] as Map)) : null,
      team: json['team'] is Map ? IdName.fromJson(Map<String, dynamic>.from(json['team'] as Map)) : null,
      assignedTeam: json['assignedTeam'] is Map ? AssignedTeam.fromJson(Map<String, dynamic>.from(json['assignedTeam'] as Map)) : null,
      project: json['project'] is Map ? IdName.fromJson(Map<String, dynamic>.from(json['project'] as Map)) : null,
      property: json['property'] is Map ? IdName.fromJson(Map<String, dynamic>.from(json['property'] as Map)) : null,
      subAssignees: json['subAssignees'] != null
          ? (json['subAssignees'] as List)
              .map((e) {
                if (e is Map) {
                  return SubAssignee.fromJson(Map<String, dynamic>.from(e));
                } else if (e is String) {
                  return SubAssignee(id: e, name: '');
                }
                return null;
              })
              .whereType<SubAssignee>()
              .toList()
          : null,
      requirements: json['requirements'] is Map
          ? LeadRequirements.fromJson(Map<String, dynamic>.from(json['requirements'] as Map))
          : null,
    );
  }
}

String _safeString(dynamic value) {
     if (value == null) return '';
     if (value is String) return value;
     if (value is Map) {
         if (value.containsKey('name')) return value['name']?.toString() ?? '';
         if (value.containsKey('_id')) return value['_id']?.toString() ?? ''; 
         return value.toString(); 
     }
     return value.toString();
}

// IdName moved to common_models.dart



class AssignedTo {
  final String id;
  final String uniqueId;
  final String name;
  final String phoneNo;
  final String systemRole;

  AssignedTo({
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.phoneNo,
    required this.systemRole,
  });

  factory AssignedTo.fromJson(Map<String, dynamic> json) {
    return AssignedTo(
      id: json['_id'] ?? '',
      uniqueId: json['uniqueId'] ?? '',
      name: json['name'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      systemRole: json['systemRole'] ?? '',
    );
  }
}

class AssignedTeam {
  final String id;
  final String name;
  
  AssignedTeam({required this.id, required this.name});
  
  factory AssignedTeam.fromJson(Map<String, dynamic> json) {
      return AssignedTeam(
          id: json['_id'] ?? '',
          name: json['name'] ?? ''
      );
  }
}


class UserShort {
  final String id;
  final String uniqueId;
  final String name;
  final String email;

  UserShort({required this.id, required this.uniqueId, required this.name, required this.email});

  factory UserShort.fromJson(Map<String, dynamic> json) {
    return UserShort(
      id: json['_id'] ?? '',
      uniqueId: json['uniqueId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

class SubAssignee {
  final String id;
  final String name;
  final String systemRole;
  final String email;
  final String phoneNo;

  SubAssignee({
    required this.id,
    required this.name,
    this.systemRole = '',
    this.email = '',
    this.phoneNo = '',
  });

  factory SubAssignee.fromJson(Map<String, dynamic> json) {
    return SubAssignee(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      systemRole: json['systemRole'] ?? '',
      email: json['email'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
    );
  }
}

class Task {
  final String id;
  final String title;
  final String status;
  final String? description;
  final String? dueDate;
  final UserShort? createdBy;
  final String createdAt;

  Task({required this.id, required this.title, required this.status, this.description, this.dueDate, this.createdBy, required this.createdAt});

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: _safeString(json['_id']),
      title: _safeString(json['title']),
      status: _safeString(json['status']),
      description: _safeString(json['description']),
      dueDate: json['dueDate'], // Nullable
      createdBy: json['createdBy'] != null ? UserShort.fromJson(json['createdBy']) : null,
      createdAt: _safeString(json['createdAt']),
    );
  }
}

class Meeting {
  final String id;
  final String subject;
  final String description;
  final String status;
  final String? scheduledAt;
  final UserShort? createdBy;
  final String? host;
  final bool sendMail;
  final bool whatsappAutomation;
  final String? meetLink;
  final String? clientEmail;
  final String? employeeEmail;
  final String? type;
  final bool isMailSent;
  final String createdAt;

  Meeting({
    required this.id,
    required this.subject,
    required this.description,
    required this.status,
    this.scheduledAt,
    this.createdBy,
    this.host,
    this.sendMail = false,
    this.whatsappAutomation = false,
    this.meetLink,
    this.clientEmail,
    this.employeeEmail,
    this.type,
    this.isMailSent = false,
    required this.createdAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: _safeString(json['_id']),
      subject: _safeString(json['subject']),
      description: _safeString(json['description']),
      status: _safeString(json['status']),
      scheduledAt: json['scheduledAt'],
      createdBy: json['createdBy'] != null ? UserShort.fromJson(json['createdBy']) : null,
      host: json['host'],
      sendMail: json['sendMail'] == true,
      whatsappAutomation: json['whatsappAutomation'] == true,
      meetLink: json['meetLink'],
      clientEmail: json['clientEmail'],
      employeeEmail: json['employeeEmail'],
      type: json['type'],
      isMailSent: json['isMailSent'] == true,
      createdAt: _safeString(json['createdAt']),
    );
  }
}

class StatusHistory {
  final String id;
  final String status;
  final String? comment;
  final UserShort? updatedBy;
  final String createdAt;

  StatusHistory({required this.id, required this.status, this.comment, this.updatedBy, required this.createdAt});

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    return StatusHistory(
      id: _safeString(json['_id']),
      status: _safeString(json['status']), // Fixed: Uses safe parsing for status object
      comment: _safeString(json['comment']),
      updatedBy: json['updatedBy'] != null ? UserShort.fromJson(json['updatedBy']) : null,
      createdAt: _safeString(json['createdAt']),
    );
  }
}

class AssignHistory {
  final String id;
  final UserShort? fromUser;
  final UserShort? toUser;
  final UserShort? changedBy;
  final String createdAt;
  final String? type;
  final List<SubAssignee>? removedSubAssignees;
  final List<SubAssignee>? addedSubAssignees;
  final String? description;
  final String? details;
  final String? comment;
  final String? field;
  final String? oldValue;
  final String? newValue;
  final Map<String, dynamic>? metadata;
  final String? actionType;
  final List<SubAssignee>? subAssigneesAdded;
  final List<SubAssignee>? subAssigneesRemoved;
  final List<SubAssignee>? currentSubAssignees;

  AssignHistory({
    required this.id,
    this.fromUser,
    this.toUser,
    this.changedBy,
    required this.createdAt,
    this.type,
    this.removedSubAssignees,
    this.addedSubAssignees,
    this.description,
    this.details,
    this.comment,
    this.field,
    this.oldValue,
    this.newValue,
    this.metadata,
    this.actionType,
    this.subAssigneesAdded,
    this.subAssigneesRemoved,
    this.currentSubAssignees,
  });

  factory AssignHistory.fromJson(Map<String, dynamic> json) {
    // Collect metadata (all keys not explicitly parsed as main fields, including system ID/version fields we want to exclude)
    final parsedKeys = {
      '_id', 'id', 'fromUser', 'toUser', 'changedBy', 'createdAt', 'type',
      'removedSubAssignees', 'addedSubAssignees', 'description', 'details',
      'comment', 'field', 'oldValue', 'newValue', 'from', 'to', 'previous', 'current',
      'leadId', 'lead', '__v', 'v', 'lead_id', 'leadID', 'version',
      'actionType', 'action_type', 'subAssigneesAdded', 'subAssigneesRemoved', 'currentSubAssignees'
    };
    final metadata = <String, dynamic>{};
    json.forEach((key, value) {
      if (!parsedKeys.contains(key) && value != null) {
        metadata[key] = value;
      }
    });

    List<SubAssignee>? parseSubAssignees(dynamic listJson) {
      if (listJson == null || listJson is! List) return null;
      return listJson
          .map((e) {
            if (e is Map) {
              return SubAssignee.fromJson(Map<String, dynamic>.from(e));
            } else if (e is String) {
              return SubAssignee(id: e, name: '');
            }
            return null;
          })
          .whereType<SubAssignee>()
          .toList();
    }

    return AssignHistory(
      id: json['_id'] ?? json['id'] ?? '',
      fromUser: json['fromUser'] != null ? UserShort.fromJson(json['fromUser']) : null,
      toUser: json['toUser'] != null ? UserShort.fromJson(json['toUser']) : null,
      changedBy: json['changedBy'] != null ? UserShort.fromJson(json['changedBy']) : null,
      createdAt: json['createdAt']?.toString() ?? json['updatedAt']?.toString() ?? json['date']?.toString() ?? json['timestamp']?.toString() ?? '',
      type: json['type'],
      removedSubAssignees: parseSubAssignees(json['removedSubAssignees'] ?? json['subAssigneesRemoved']),
      addedSubAssignees: parseSubAssignees(json['addedSubAssignees'] ?? json['subAssigneesAdded']),
      subAssigneesAdded: parseSubAssignees(json['subAssigneesAdded'] ?? json['addedSubAssignees']),
      subAssigneesRemoved: parseSubAssignees(json['subAssigneesRemoved'] ?? json['removedSubAssignees']),
      currentSubAssignees: parseSubAssignees(json['currentSubAssignees'] ?? json['newSubAssignees'] ?? json['subAssignees']),
      actionType: json['actionType']?.toString() ?? json['action_type']?.toString(),
      description: json['description']?.toString() ?? json['activityDescription']?.toString(),
      details: json['details']?.toString(),
      comment: json['comment']?.toString(),
      field: json['field']?.toString(),
      oldValue: json['oldValue']?.toString() ?? json['from']?.toString() ?? json['previous']?.toString() ?? json['fromUser']?['name']?.toString(),
      newValue: json['newValue']?.toString() ?? json['to']?.toString() ?? json['current']?.toString() ?? json['toUser']?['name']?.toString(),
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }
}

// Visit moved to visit_model.dart

class LeadsResponse {
  final List<Lead> leads;
  final int totalCount;
  final int totalPages;
  final int currentPage;

  LeadsResponse({
    required this.leads,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
  });

  factory LeadsResponse.fromJson(Map<String, dynamic> json) {
    // Robustly handle nested data structure: { data: { data: { leads: [...] } } } OR { data: { leads: [...] } }
    var outerData = json['data'] ?? {};
    var innerData = outerData;
    
    if (outerData is Map && outerData['data'] != null) {
       innerData = outerData['data'];
    }

    final leadsList = (innerData['leads'] as List?)?.map((e) => Lead.fromJson(e)).toList() ?? [];
    final pagination = innerData['pagination'] ?? {};

    return LeadsResponse(
      leads: leadsList,
      totalCount: innerData['totalCount'] ?? (pagination['total'] ?? 0),
      totalPages: pagination['totalPages'] ?? 1,
      currentPage: pagination['page'] ?? 1,
    );
  }
}

class RealEstateArea {
  final String value;
  final String unit;

  RealEstateArea({this.value = '', this.unit = ''});

  factory RealEstateArea.fromJson(Map<String, dynamic> json) {
    return RealEstateArea(
      value: json['value']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'unit': unit,
  };
}

class RealEstateRequirements {
  final String listingType;
  final String category;
  final String propertyType;
  final String bhk;
  final String preferredArea;
  final String timeline;
  final String furnishingStatus;
  final RealEstateArea? area;
  final String additionalRequirements;

  RealEstateRequirements({
    this.listingType = '',
    this.category = '',
    this.propertyType = '',
    this.bhk = '',
    this.preferredArea = '',
    this.timeline = '',
    this.furnishingStatus = '',
    this.area,
    this.additionalRequirements = '',
  });

  factory RealEstateRequirements.fromJson(Map<String, dynamic> json) {
    return RealEstateRequirements(
      listingType: json['listingType']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      propertyType: json['propertyType']?.toString() ?? '',
      bhk: json['bhk']?.toString() ?? '',
      preferredArea: json['preferredArea']?.toString() ?? '',
      timeline: json['timeline']?.toString() ?? '',
      furnishingStatus: json['furnishingStatus']?.toString() ?? '',
      area: json['area'] is Map ? RealEstateArea.fromJson(Map<String, dynamic>.from(json['area'] as Map)) : null,
      additionalRequirements: json['additionalRequirements']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'listingType': listingType,
    'category': category,
    'propertyType': propertyType,
    'bhk': bhk,
    'preferredArea': preferredArea,
    'timeline': timeline,
    'furnishingStatus': furnishingStatus,
    'area': area?.toJson(),
    'additionalRequirements': additionalRequirements,
  };
}

class LeadRequirements {
  final RealEstateRequirements? realEstate;

  LeadRequirements({this.realEstate});

  factory LeadRequirements.fromJson(Map<String, dynamic> json) {
    return LeadRequirements(
      realEstate: json['realEstate'] is Map 
          ? RealEstateRequirements.fromJson(Map<String, dynamic>.from(json['realEstate'] as Map)) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'realEstate': realEstate?.toJson(),
  };
}

