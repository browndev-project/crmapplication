class Meeting {
  final String id;
  final String subject;
  final String description;
  final String status;
  final String scheduledAt;
  final bool isMailSent;
  final bool sendMail;
  final bool whatsappAutomation;
  final String? host;
  final MeetingLeadShort? lead;
  final String? createdBy;
  final String? meetLink;
  final String? clientEmail;
  final String? employeeEmail;
  final String? type;
  final String createdAt;

  Meeting({
    required this.id,
    required this.subject,
    required this.description,
    required this.status,
    required this.scheduledAt,
    required this.isMailSent,
    this.sendMail = false,
    this.whatsappAutomation = false,
    this.host,
    this.lead,
    this.createdBy,
    this.meetLink,
    this.clientEmail,
    this.employeeEmail,
    this.type,
    required this.createdAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['_id'] ?? '',
      subject: json['subject'] ?? 'No Subject',
      description: json['description'] ?? '',
      status: json['status'] ?? 'Scheduled',
      scheduledAt: json['scheduledAt'] ?? '',
      isMailSent: json['isMailSent'] == true,
      sendMail: json['sendMail'] == true,
      whatsappAutomation: json['whatsappAutomation'] == true,
      host: json['host'],
      lead: json['lead'] != null && json['lead'] is Map<String, dynamic>
          ? MeetingLeadShort.fromJson(json['lead'])
          : null,
      createdBy: json['createdBy'] is String ? json['createdBy'] : null,
      meetLink: json['meetLink'],
      clientEmail: json['clientEmail'],
      employeeEmail: json['employeeEmail'],
      type: json['type'] ?? json['sendBy'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class MeetingLeadShort {
  final String id;
  final String name;
  final String? assignedTo;

  MeetingLeadShort({required this.id, required this.name, this.assignedTo});

  factory MeetingLeadShort.fromJson(Map<String, dynamic> json) {
    return MeetingLeadShort(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown Lead',
      assignedTo: json['assignedTo'],
    );
  }
}

class MeetingsResponse {
  final List<Meeting> meetings;
  final int totalCount;
  final int totalPages;
  final int currentPage;

  MeetingsResponse({
    required this.meetings,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
  });

  factory MeetingsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final meetingsList = (data['meetings'] as List?)
            ?.whereType<Map<String, dynamic>>() // Safety check
            .map((e) => Meeting.fromJson(e))
            .toList() ??
        [];
    final pagination = data['pagination'] ?? {};

    return MeetingsResponse(
      meetings: meetingsList,
      totalCount: data['totalCount'] ?? 0,
      totalPages: pagination['totalPages'] ?? 1,
      currentPage: pagination['page'] ?? 1,
    );
  }
}
