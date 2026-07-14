class OverallReportModel {
  final EmployeeProfile employee;
  final LeadsOverview leads;
  final TasksOverview tasks;
  final MeetingsOverview meetings;

  OverallReportModel({
    required this.employee,
    required this.leads,
    required this.tasks,
    required this.meetings,
  });

  factory OverallReportModel.fromJson(Map<String, dynamic> json) {
    return OverallReportModel(
      employee: EmployeeProfile.fromJson(json['employee'] ?? {}),
      leads: LeadsOverview.fromJson(json['leads'] ?? {}),
      tasks: TasksOverview.fromJson(json['tasks'] ?? {}),
      meetings: MeetingsOverview.fromJson(json['meetings'] ?? {}),
    );
  }
}

class EmployeeProfile {
  final String id;
  final String name;
  final String phoneNo;
  final String designation;
  final String email;

  EmployeeProfile({
    required this.id,
    required this.name,
    required this.phoneNo,
    required this.designation,
    required this.email,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      phoneNo: json['phoneNo'] ?? '',
      designation: json['designation'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

class StatusCount {
  final String status;
  final int count;

  StatusCount({required this.status, required this.count});

  factory StatusCount.fromJson(Map<String, dynamic> json) {
    return StatusCount(
      status: json['status'] ?? 'Unknown',
      count: json['count'] ?? 0,
    );
  }
}

class LeadsOverview {
  final int totalAssigned;
  final List<StatusCount> byStatus;

  LeadsOverview({required this.totalAssigned, required this.byStatus});

  factory LeadsOverview.fromJson(Map<String, dynamic> json) {
    var list = json['byStatus'] as List? ?? [];
    List<StatusCount> statusList = list.map((i) => StatusCount.fromJson(i)).toList();
    return LeadsOverview(
      totalAssigned: json['totalAssigned'] ?? 0,
      byStatus: statusList,
    );
  }
}

class TasksOverview {
  final int total;
  final List<StatusCount> byStatus;

  TasksOverview({required this.total, required this.byStatus});

  factory TasksOverview.fromJson(Map<String, dynamic> json) {
    var list = json['byStatus'] as List? ?? [];
    List<StatusCount> statusList = list.map((i) => StatusCount.fromJson(i)).toList();
    return TasksOverview(
      total: json['total'] ?? 0,
      byStatus: statusList,
    );
  }
}

class MeetingsOverview {
  final int total;
  final List<StatusCount> byStatus;

  MeetingsOverview({required this.total, required this.byStatus});

  factory MeetingsOverview.fromJson(Map<String, dynamic> json) {
    var list = json['byStatus'] as List? ?? [];
    List<StatusCount> statusList = list.map((i) => StatusCount.fromJson(i)).toList();
    return MeetingsOverview(
      total: json['total'] ?? 0,
      byStatus: statusList,
    );
  }
}
