class CompanyAttendanceResponse {
  final bool success;
  final String message;
  final AttendanceData? data;

  CompanyAttendanceResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory CompanyAttendanceResponse.fromJson(Map<String, dynamic> json) {
    return CompanyAttendanceResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? AttendanceData.fromJson(json['data']) : null,
    );
  }
}

class AttendanceData {
  final String date;
  final int total;
  final List<AttendanceRecord> records;

  AttendanceData({
    required this.date,
    required this.total,
    required this.records,
  });

  factory AttendanceData.fromJson(Map<String, dynamic> json) {
    return AttendanceData(
      date: json['date'] ?? '',
      total: json['total'] ?? 0,
      records: (json['records'] as List?)
          ?.map((e) => AttendanceRecord.fromJson(e))
          .toList() ?? [],
    );
  }
}

class AttendanceRecord {
  final String attendanceId;
  final AttendanceUser user;
  final String status; // 'inactive', 'active', 'break'
  final String? loginAt;
  final String? logoutAt;
  final int totalWorkMs;
  final int totalBreakMs;
  final List<AttendanceBreak> breaks;

  AttendanceRecord({
    required this.attendanceId,
    required this.user,
    required this.status,
    this.loginAt,
    this.logoutAt,
    required this.totalWorkMs,
    required this.totalBreakMs,
    required this.breaks,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      attendanceId: json['attendanceId'] ?? '',
      user: AttendanceUser.fromJson(json['user'] ?? {}),
      status: json['status'] ?? 'inactive',
      loginAt: json['loginAt'],
      logoutAt: json['logoutAt'],
      totalWorkMs: json['totalWorkMs'] ?? 0,
      totalBreakMs: json['totalBreakMs'] ?? 0,
      breaks: (json['breaks'] as List?)
          ?.map((e) => AttendanceBreak.fromJson(e))
          .toList() ?? [],
    );
  }
}

class AttendanceUser {
  final String id;
  final String name;
  final String phoneNo;

  AttendanceUser({
    required this.id,
    required this.name,
    required this.phoneNo,
  });

  factory AttendanceUser.fromJson(Map<String, dynamic> json) {
    return AttendanceUser(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown',
      phoneNo: json['phoneNo'] ?? '',
    );
  }
}

class AttendanceBreak {
  final String id;
  final String reason;
  final String startAt;
  final String? endAt;
  final int durationMs;

  AttendanceBreak({
    required this.id,
    required this.reason,
    required this.startAt,
    this.endAt,
    required this.durationMs,
  });

  factory AttendanceBreak.fromJson(Map<String, dynamic> json) {
    return AttendanceBreak(
      id: json['_id'] ?? '',
      reason: json['reason'] ?? '',
      startAt: json['startAt'] ?? '',
      endAt: json['endAt'],
      durationMs: json['durationMs'] ?? 0,
    );
  }
}

// --- History Models ---

class AttendanceHistoryResponse {
  final int statusCode;
  final AttendanceHistoryData? data;
  final String message;
  final bool success;

  AttendanceHistoryResponse({
    required this.statusCode,
    this.data,
    required this.message,
    required this.success,
  });

  factory AttendanceHistoryResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryResponse(
      statusCode: json['statusCode'] ?? 0,
      data: json['data'] != null ? AttendanceHistoryData.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

class AttendanceHistoryData {
  final List<AttendanceRecordHistory> records;
  final Pagination pagination;

  AttendanceHistoryData({required this.records, required this.pagination});

  factory AttendanceHistoryData.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryData(
      records: (json['records'] as List?)
          ?.map((e) => AttendanceRecordHistory.fromJson(e))
          .toList() ?? [],
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

class AttendanceRecordHistory {
  final String id;
  final String status;
  final int totalWorkMs;
  final int totalBreakMs;
  final String deviceType;
  final String user; // User ID as String
  final String date;
  final String? loginAt;
  final String? logoutAt;
  final String? lastActivityAt;
  final String createdAt;

  AttendanceRecordHistory({
    required this.id,
    required this.status,
    required this.totalWorkMs,
    required this.totalBreakMs,
    required this.deviceType,
    required this.user,
    required this.date,
    this.loginAt,
    this.logoutAt,
    this.lastActivityAt,
    required this.createdAt,
  });

  factory AttendanceRecordHistory.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordHistory(
      id: json['_id'] ?? '',
      status: json['status'] ?? 'inactive',
      totalWorkMs: json['totalWorkMs'] ?? 0,
      totalBreakMs: json['totalBreakMs'] ?? 0,
      deviceType: json['deviceType'] ?? 'unknown',
      user: json['user']?.toString() ?? '',
      date: json['date'] ?? '',
      loginAt: json['loginAt'],
      logoutAt: json['logoutAt'],
      lastActivityAt: json['lastActivityAt'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int totalRecords;
  final int totalPages;

  Pagination({
    required this.page,
    required this.limit,
    required this.totalRecords,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalRecords: json['totalRecords'] ?? 0,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}
