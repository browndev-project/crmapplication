class PerformanceReportModel {
  final String id;
  final String name;
  final String role;
  final int assigned;
  final int updates;
  final int worked;
  final int converted;
  final int revenue;
  final int workTimeMinutes;
  final int breakTimeMinutes;
  final int activeDays;
  final int totalBreaks;
  final int exceededBreaks;
  final num leadsWorkedPerHour;
  final num statusUpdatesPerHour;
  final num revenuePerHour;
  final num conversionContributionPercent;
  final num revenueContributionPercent;

  PerformanceReportModel({
    required this.id,
    required this.name,
    required this.role,
    required this.assigned,
    required this.updates,
    required this.worked,
    required this.converted,
    required this.revenue,
    required this.workTimeMinutes,
    required this.breakTimeMinutes,
    this.activeDays = 0,
    this.totalBreaks = 0,
    this.exceededBreaks = 0,
    this.leadsWorkedPerHour = 0,
    this.statusUpdatesPerHour = 0,
    this.revenuePerHour = 0,
    this.conversionContributionPercent = 0,
    this.revenueContributionPercent = 0,
  });

  factory PerformanceReportModel.fromJson(Map<String, dynamic> json) {
    return PerformanceReportModel(
      id: json['employeeId'] ?? '',
      name: json['name'] ?? 'Unknown',
      role: json['systemRole'] ?? '',
      assigned: json['assignedLeadsUnique'] ?? 0,
      updates: json['statusUpdatesCount'] ?? 0,
      worked: json['uniqueLeadsWorked'] ?? 0,
      converted: json['convertedCount'] ?? 0,
      revenue: json['revenueClosed'] ?? 0,
      workTimeMinutes: _msToMin(json['totalWorkMs']),
      breakTimeMinutes: _msToMin(json['totalBreakMs']),
      activeDays: json['activeDays'] ?? 0,
      totalBreaks: json['totalBreaks'] ?? 0,
      exceededBreaks: json['exceededBreaks'] ?? 0,
      leadsWorkedPerHour: (json['leadsWorkedPerHour'] ?? 0).toDouble(),
      statusUpdatesPerHour: (json['statusUpdatesPerHour'] ?? 0).toDouble(),
      revenuePerHour: (json['revenuePerHour'] ?? 0).toDouble(),
      conversionContributionPercent: (json['conversionContributionPercent'] ?? 0).toDouble(),
      revenueContributionPercent: (json['revenueContributionPercent'] ?? 0).toDouble(),
    );
  }

  static int _msToMin(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value ~/ 60000;
    if (value is double) return (value / 60000).round();
    return 0;
  }
}
