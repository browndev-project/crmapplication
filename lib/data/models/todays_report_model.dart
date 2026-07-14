class TodaysReportV2Model {
  final String date;
  final String designation;
  final List<EmployeeReportV2> employees;
  final ReportSummary summary;

  TodaysReportV2Model({
    required this.date,
    required this.designation,
    required this.employees,
    required this.summary,
  });

  factory TodaysReportV2Model.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return TodaysReportV2Model(
      date: json['date'] ?? '',
      designation: json['designation'] ?? '',
      employees: list.map((e) => EmployeeReportV2.fromJson(e)).toList(),
      summary: ReportSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

class ReportSummary {
  final int totalCalls;
  final int totalDuration;
  final int talkTime;
  final int totalLeadsWorked;
  final int agentNotPickedUp;
  final int activeEmployees;

  ReportSummary({
    required this.totalCalls,
    required this.totalDuration,
    required this.talkTime,
    required this.totalLeadsWorked,
    required this.agentNotPickedUp,
    required this.activeEmployees,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      totalCalls: json['totalCalls'] ?? 0,
      totalDuration: json['totalDuration'] ?? 0,
      talkTime: json['talkTime'] ?? 0,
      totalLeadsWorked: json['totalLeadsWorked'] ?? 0,
      agentNotPickedUp: json['agentNotPickedUp'] ?? 0,
      activeEmployees: json['activeEmployees'] ?? 0,
    );
  }
}

class EmployeeReportV2 {
  final String employeeId;
  final String name;
  final String email;
  final String phoneNo;
  final String designation;
  final String? avatar;
  final int assignedLeadsToday;
  final int leadsWorkedToday;
  final Map<String, dynamic> workedSourceBreakdown;
  final Map<String, dynamic> statusCounts;
  final int totalCalls;
  final int incomingCalls;
  final int outgoingCalls;
  final int connectedCalls;
  final int notConnectedCalls;
  final int totalDuration;
  final int incomingDuration;
  final int outgoingDuration;
  final int agentNotPickedUpCalls;
  final int talkTime;
  final int tasksCompletedToday;
  final List<DetailedCall> detailedCalls;

  EmployeeReportV2({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.phoneNo,
    required this.designation,
    this.avatar,
    required this.assignedLeadsToday,
    required this.leadsWorkedToday,
    required this.workedSourceBreakdown,
    required this.statusCounts,
    required this.totalCalls,
    required this.incomingCalls,
    required this.outgoingCalls,
    required this.connectedCalls,
    required this.notConnectedCalls,
    required this.totalDuration,
    required this.incomingDuration,
    required this.outgoingDuration,
    required this.agentNotPickedUpCalls,
    required this.talkTime,
    required this.tasksCompletedToday,
    required this.detailedCalls,
  });

  factory EmployeeReportV2.fromJson(Map<String, dynamic> json) {
    return EmployeeReportV2(
      employeeId: json['employeeId'] ?? '',
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      designation: json['designation'] ?? '',
      avatar: json['avatar'],
      assignedLeadsToday: json['assignedLeadsToday'] ?? 0,
      leadsWorkedToday: json['leadsWorkedToday'] ?? 0,
      workedSourceBreakdown: json['workedSourceBreakdown'] != null
          ? Map<String, dynamic>.from(json['workedSourceBreakdown'])
          : {},
      statusCounts: json['statusCounts'] != null
          ? Map<String, dynamic>.from(json['statusCounts'])
          : {},
      totalCalls: json['totalCalls'] ?? 0,
      incomingCalls: json['incomingCalls'] ?? 0,
      outgoingCalls: json['outgoingCalls'] ?? 0,
      connectedCalls: json['connectedCalls'] ?? 0,
      notConnectedCalls: json['notConnectedCalls'] ?? 0,
      totalDuration: json['totalDuration'] ?? 0,
      incomingDuration: json['incomingDuration'] ?? 0,
      outgoingDuration: json['outgoingDuration'] ?? 0,
      agentNotPickedUpCalls: json['agentNotPickedUpCalls'] ?? 0,
      talkTime: json['talkTime'] ?? 0,
      tasksCompletedToday: json['tasksCompletedToday'] ?? 0,
      detailedCalls: (json['detailedCalls'] as List?)
              ?.map((e) => DetailedCall.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DetailedCall {
  final String id;
  final String phone;
  final DateTime? startTime;
  final DateTime? createdAt;
  final String callType;
  final int duration;
  final String source;
  final String status;
  final String agentLabel;
  final String initiatorName;
  final List<dynamic>? callDetails;

  DetailedCall({
    required this.id,
    required this.phone,
    this.startTime,
    this.createdAt,
    required this.callType,
    required this.duration,
    required this.source,
    required this.status,
    required this.agentLabel,
    required this.initiatorName,
    this.callDetails,
  });

  factory DetailedCall.fromJson(Map<String, dynamic> json) {
    return DetailedCall(
      id: json['_id'] ?? '',
      phone: json['phone'] ?? '',
      startTime: DateTime.tryParse(json['startTime'] ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
      callType: json['callType'] ?? '',
      duration: json['duration'] ?? 0,
      source: json['source'] ?? '',
      status: json['status'] ?? '',
      agentLabel: json['agentLabel'] ?? '',
      initiatorName: json['initiatorName'] ?? '',
      callDetails: json['callDetails'] is List ? json['callDetails'] : null,
    );
  }
}

class GroupedCallItem {
  final String phone;
  final int totalCalls;
  final DateTime? latestCallTime;
  final DetailedCall? latestCall;

  GroupedCallItem({
    required this.phone,
    required this.totalCalls,
    this.latestCallTime,
    this.latestCall,
  });

  factory GroupedCallItem.fromJson(Map<String, dynamic> json) {
    return GroupedCallItem(
      phone: json['phone'] ?? '',
      totalCalls: json['totalCalls'] ?? 0,
      latestCallTime: DateTime.tryParse(json['latestCallTime'] ?? ''),
      latestCall: json['latestCall'] != null ? DetailedCall.fromJson(json['latestCall']) : null,
    );
  }
}

class GroupedCallsResponse {
  final List<GroupedCallItem> data;
  final int totalGroups;
  final int page;
  final int limit;
  final int totalPages;

  GroupedCallsResponse({
    required this.data,
    required this.totalGroups,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory GroupedCallsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return GroupedCallsResponse(
      data: list.map((e) => GroupedCallItem.fromJson(e)).toList(),
      totalGroups: json['totalGroups'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}
