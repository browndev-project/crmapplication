class AutoDialerColdLeadDetails {
  final String id;
  final String name;
  final String phoneNo;
  final String? email;
  final String? city;
  final String? state;
  final String status;
  final String? notes;

  AutoDialerColdLeadDetails({
    required this.id,
    required this.name,
    required this.phoneNo,
    this.email,
    this.city,
    this.state,
    required this.status,
    this.notes,
  });

  factory AutoDialerColdLeadDetails.fromJson(Map<String, dynamic> json) {
    return AutoDialerColdLeadDetails(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phoneNo: json['phoneNo']?.toString() ?? '',
      email: json['email']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      status: json['status']?.toString() ?? 'New',
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phoneNo': phoneNo,
      if (email != null) 'email': email,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }
}

class AutoDialerLeadDetails {
  final String id;
  final String name;
  final String phoneNo;
  final String? mobile;
  final String? company;
  final String status;
  final String? city;
  final String? state;
  final String? notes;

  AutoDialerLeadDetails({
    required this.id,
    required this.name,
    required this.phoneNo,
    this.mobile,
    this.company,
    required this.status,
    this.city,
    this.state,
    this.notes,
  });

  factory AutoDialerLeadDetails.fromJson(Map<String, dynamic> json) {
    return AutoDialerLeadDetails(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['clientName']?.toString() ?? '',
      phoneNo: json['phoneNo']?.toString() ??
          json['mobile']?.toString() ??
          json['phone']?.toString() ??
          '',
      mobile: json['mobile']?.toString() ?? json['phone']?.toString(),
      company: json['company']?.toString() ?? json['companyName']?.toString(),
      status: json['status']?.toString() ?? 'New',
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phoneNo': phoneNo,
      if (mobile != null) 'mobile': mobile,
      if (company != null) 'company': company,
      'status': status,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (notes != null) 'notes': notes,
    };
  }
}

class AutoDialerContactInfo {
  final String name;
  // Original:
  // final String phoneNo;
  final String phoneNo;
  String get phone => phoneNo;
  final AutoDialerColdLeadDetails? coldLeadDetails;
  final AutoDialerLeadDetails? leadDetails;

  AutoDialerContactInfo({
    required this.name,
    required this.phoneNo,
    this.coldLeadDetails,
    this.leadDetails,
  });

  factory AutoDialerContactInfo.fromJson(Map<String, dynamic> json) {
    return AutoDialerContactInfo(
      name: json['name']?.toString() ?? '',
      phoneNo: json['phoneNo']?.toString() ?? '',
      coldLeadDetails: json['coldLeadDetails'] != null
          ? AutoDialerColdLeadDetails.fromJson(json['coldLeadDetails'])
          : null,
      leadDetails: json['leadDetails'] != null
          ? AutoDialerLeadDetails.fromJson(json['leadDetails'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNo': phoneNo,
      if (coldLeadDetails != null) 'coldLeadDetails': coldLeadDetails!.toJson(),
      if (leadDetails != null) 'leadDetails': leadDetails!.toJson(),
    };
  }
}

class AutoDialerQueueItem {
  final String queueId;
  final String? coldCampaignId;
  final String? campaignId;
  final String campaignTitle;
  final String targetType; // "ColdLead" or "Lead"
  final int queueOrder;
  final String status;
  // Original:
  // final AutoDialerContactInfo contactInfo;
  final AutoDialerContactInfo contactInfo;
  AutoDialerContactInfo get contact => contactInfo;

  AutoDialerQueueItem({
    required this.queueId,
    this.coldCampaignId,
    this.campaignId,
    required this.campaignTitle,
    required this.targetType,
    required this.queueOrder,
    required this.status,
    required this.contactInfo,
  });

  factory AutoDialerQueueItem.fromJson(Map<String, dynamic> json) {
    return AutoDialerQueueItem(
      queueId: json['queueId']?.toString() ?? json['_id']?.toString() ?? '',
      coldCampaignId: json['coldCampaignId']?.toString(),
      campaignId: json['campaignId']?.toString() ?? json['coldCampaignId']?.toString(),
      campaignTitle: json['campaignTitle']?.toString() ?? 'Outbound Campaign',
      targetType: json['targetType']?.toString() ?? 'ColdLead',
      queueOrder: (json['queueOrder'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'In_Progress',
      contactInfo: json['contactInfo'] != null
          ? AutoDialerContactInfo.fromJson(json['contactInfo'])
          : AutoDialerContactInfo(name: '', phoneNo: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'queueId': queueId,
      if (coldCampaignId != null) 'coldCampaignId': coldCampaignId,
      if (campaignId != null) 'campaignId': campaignId,
      'campaignTitle': campaignTitle,
      'targetType': targetType,
      'queueOrder': queueOrder,
      'status': status,
      'contactInfo': contactInfo.toJson(),
    };
  }
}

class AutoDialerCompletePayload {
  final String callResult; // "Connected", "Not Connected", "No Answer", "Busy", "Wrong Number", "Qualified", "Unqualified"
  final String status; // Updated status for ColdLead or Lead
  final String notes;
  final String? appCallId;
  final String? startTime;
  final String? endTime;
  final int? duration;
  final String callType;
  final String? callerNumber;
  final String? receiverNumber;
  final String? recordingUrl;
  final String? recordingSource;
  final Map<String, dynamic>? callDetails;
  final Map<String, dynamic>? meta;
  final String? callRequestId;

  AutoDialerCompletePayload({
    required this.callResult,
    required this.status,
    required this.notes,
    this.appCallId,
    this.startTime,
    this.endTime,
    this.duration,
    this.callType = 'OUTGOING',
    this.callerNumber,
    this.receiverNumber,
    this.recordingUrl,
    this.recordingSource = 'ANDROID_NATIVE',
    this.callDetails,
    this.meta,
    this.callRequestId,
  });

  Map<String, dynamic> toJson() {
    return {
      'callResult': callResult,
      'status': status,
      'notes': notes,
      if (appCallId != null) 'appCallId': appCallId,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (duration != null) 'duration': duration,
      'callType': callType,
      if (callerNumber != null && callerNumber!.isNotEmpty) 'callerNumber': callerNumber,
      if (receiverNumber != null && receiverNumber!.isNotEmpty) 'receiverNumber': receiverNumber,
      if (recordingUrl != null && recordingUrl!.isNotEmpty) 'recordingUrl': recordingUrl,
      if (recordingSource != null && recordingSource!.isNotEmpty) 'recordingSource': recordingSource,
      if (callDetails != null) 'callDetails': callDetails,
      if (meta != null) 'meta': meta,
      if (callRequestId != null) 'callRequestId': callRequestId,
    };
  }
}

class AutoDialerCompleteResponse {
  final String? completedQueueId;
  final AutoDialerQueueItem? nextCall;
  final String? message;
  final bool success;

  AutoDialerCompleteResponse({
    this.completedQueueId,
    this.nextCall,
    this.message,
    required this.success,
  });

  factory AutoDialerCompleteResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    AutoDialerQueueItem? next;
    String? completedId;

    if (data is Map<String, dynamic>) {
      completedId = data['completedQueueId']?.toString();
      if (data['nextCall'] != null && data['nextCall'] is Map<String, dynamic>) {
        next = AutoDialerQueueItem.fromJson(data['nextCall']);
      }
    }

    return AutoDialerCompleteResponse(
      completedQueueId: completedId,
      nextCall: next,
      message: json['message']?.toString(),
      success: json['success'] == true,
    );
  }
}
