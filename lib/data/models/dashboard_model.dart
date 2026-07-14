class DashboardData {
  final LeadAssignmentStats? leadAssignment;
  final TodayScheduleStats? todaySchedule;
  final LeadSourceStats? leadSources;
  final LeadStatusStats? leadStatus;
  final PipelineStats? pipelines;
  final TodayVisitsStats? todayVisits;
  final PersonalCallStats? personalCallStats;
  final List<TeamMemberCallStats>? teamCallStats;
  final DateTime? lastUpdated;

  DashboardData({
    this.leadAssignment,
    this.todaySchedule,
    this.leadSources,
    this.leadStatus,
    this.pipelines,
    this.todayVisits,
    this.personalCallStats,
    this.teamCallStats,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'leadAssignment': leadAssignment?.toJson(),
      'todaySchedule': todaySchedule?.toJson(),
      'leadSources': leadSources?.toJson(),
      'leadStatus': leadStatus?.toJson(),
      'pipelines': pipelines?.toJson(),
      'todayVisits': todayVisits?.toJson(),
      'personalCallStats': personalCallStats?.toJson(),
      'teamCallStats': teamCallStats?.map((e) => e.toJson()).toList(),
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      leadAssignment: json['leadAssignment'] != null ? LeadAssignmentStats.fromJson(json['leadAssignment']) : null,
      todaySchedule: json['todaySchedule'] != null ? TodayScheduleStats.fromJson(json['todaySchedule']) : null,
      leadSources: json['leadSources'] != null ? LeadSourceStats.fromJson(json['leadSources']) : null,
      leadStatus: json['leadStatus'] != null ? LeadStatusStats.fromJson(json['leadStatus']) : null,
      pipelines: json['pipelines'] != null ? PipelineStats.fromJson(json['pipelines']) : null,
      todayVisits: json['todayVisits'] != null ? TodayVisitsStats.fromJson(json['todayVisits']) : null,
      personalCallStats: json['personalCallStats'] != null ? PersonalCallStats.fromJson(json['personalCallStats']) : null,
      teamCallStats: json['teamCallStats'] != null 
          ? (json['teamCallStats'] as List).map((e) => TeamMemberCallStats.fromJson(e)).toList() 
          : null,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
    );
  }
}

class LeadAssignmentStats {
  final int assigned;
  final int unassigned;

  LeadAssignmentStats({required this.assigned, required this.unassigned});

  factory LeadAssignmentStats.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) json = json['data']; // Handle API wrapper if present
    return LeadAssignmentStats(
      assigned: json['assigned'] ?? 0,
      unassigned: json['unassigned'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'assigned': assigned, 'unassigned': unassigned};
}

class TodayScheduleStats {
  final int tasksDueToday;
  final int meetingsToday;
  final int overdueTasks;
  final int pendingTasks;

  TodayScheduleStats({
    required this.tasksDueToday, 
    required this.meetingsToday,
    this.overdueTasks = 0,
    this.pendingTasks = 0,
  });

  factory TodayScheduleStats.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) json = json['data'];
    return TodayScheduleStats(
      tasksDueToday: json['tasksDueToday'] ?? 0,
      meetingsToday: json['meetingsToday'] ?? 0,
      overdueTasks: json['overdueTasks'] ?? 0,
      pendingTasks: json['pendingTasks'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'tasksDueToday': tasksDueToday, 
    'meetingsToday': meetingsToday,
    'overdueTasks': overdueTasks,
    'pendingTasks': pendingTasks,
  };
}

class LeadSourceStats {
  final Map<String, int> sources;

  LeadSourceStats({required this.sources});

  factory LeadSourceStats.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) json = json['data'];
    // The key is 'leadSources' inside data usually, waiting for specific struct, 
    // but based on typical responses: data: { leadSources: { "Web": 1, ... } }
    final sourceMap = json['leadSources'] is Map ? json['leadSources'] as Map<String, dynamic> : json;
    
    // Convert all values to int safely
    final converted = <String, int>{};
    sourceMap.forEach((key, value) {
        if (value is int) {
          converted[key] = value;
        } else if (value is String) {
          converted[key] = int.tryParse(value) ?? 0;
        }
    });
    return LeadSourceStats(sources: converted);
  }

  Map<String, dynamic> toJson() => {'leadSources': sources};
}

class LeadStatusStats {
  final Map<String, int> statusCounts;

  LeadStatusStats({required this.statusCounts});

  factory LeadStatusStats.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) json = json['data'];
    final map = json['leadStatusCounts'] is Map ? json['leadStatusCounts'] as Map<String, dynamic> : json;
    
    final converted = <String, int>{};
    map.forEach((key, value) {
        if (value is int) {
          converted[key] = value;
        } else if (value is String) {
          converted[key] = int.tryParse(value) ?? 0;
        }
    });

    return LeadStatusStats(statusCounts: converted);
  }

  Map<String, dynamic> toJson() => {'leadStatusCounts': statusCounts};
}

class PipelineStats {
  final Map<String, int> pipelineCounts;

  PipelineStats({required this.pipelineCounts});

  factory PipelineStats.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) json = json['data'];
    final map = json['pipelines'] is Map ? json['pipelines'] as Map<String, dynamic> : json;
    
     final converted = <String, int>{};
    map.forEach((key, value) {
        if (value is int) {
          converted[key] = value;
        } else if (value is String) {
          converted[key] = int.tryParse(value) ?? 0;
        }
    });

    return PipelineStats(pipelineCounts: converted);
  }

  Map<String, dynamic> toJson() => {'pipelines': pipelineCounts};
}

class TodayVisitsStats {
  final int totalVisits;
  final int scheduled;
  final int completed;
  final int cancelled;

  TodayVisitsStats({
    required this.totalVisits,
    required this.scheduled,
    required this.completed,
    required this.cancelled,
  });

  factory TodayVisitsStats.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) json = json['data'];
    return TodayVisitsStats(
      totalVisits: json['totalVisits'] ?? 0,
      scheduled: json['scheduled'] ?? 0,
      completed: json['completed'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalVisits': totalVisits,
        'scheduled': scheduled,
        'completed': completed,
        'cancelled': cancelled,
      };
}

class PersonalCallStats {
  final int totalCalls;
  final int connectedCalls;
  final int notConnectedCalls;
  final int totalDuration;
  final int incomingDuration;
  final int outgoingDuration;
  final int incomingCalls;
  final int outgoingCalls;

  PersonalCallStats({
    required this.totalCalls,
    required this.connectedCalls,
    required this.notConnectedCalls,
    required this.totalDuration,
    required this.incomingDuration,
    required this.outgoingDuration,
    required this.incomingCalls,
    required this.outgoingCalls,
  });

  factory PersonalCallStats.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) json = json['data'];
    return PersonalCallStats(
      totalCalls: json['totalCalls'] ?? 0,
      connectedCalls: json['connectedCalls'] ?? 0,
      notConnectedCalls: json['notConnectedCalls'] ?? 0,
      totalDuration: json['totalDuration'] ?? 0,
      incomingDuration: json['incomingDuration'] ?? 0,
      outgoingDuration: json['outgoingDuration'] ?? 0,
      incomingCalls: json['incomingCalls'] ?? 0,
      outgoingCalls: json['outgoingCalls'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalCalls': totalCalls,
        'connectedCalls': connectedCalls,
        'notConnectedCalls': notConnectedCalls,
        'totalDuration': totalDuration,
        'incomingDuration': incomingDuration,
        'outgoingDuration': outgoingDuration,
        'incomingCalls': incomingCalls,
        'outgoingCalls': outgoingCalls,
      };
}

class TeamMemberCallStats {
  final String id;
  final String name;
  final String role;
  final bool isSelf;
  final CallCategoryStats total;
  final CallCategoryStats outgoing;
  final CallCategoryStats incoming;

  TeamMemberCallStats({
    required this.id,
    required this.name,
    required this.role,
    required this.isSelf,
    required this.total,
    required this.outgoing,
    required this.incoming,
  });

  factory TeamMemberCallStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};
    return TeamMemberCallStats(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      role: json['role'] ?? '',
      isSelf: json['isSelf'] ?? false,
      total: CallCategoryStats.fromJson(stats['total'] ?? {}),
      outgoing: CallCategoryStats.fromJson(stats['outgoing'] ?? {}),
      incoming: CallCategoryStats.fromJson(stats['incoming'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'isSelf': isSelf,
        'stats': {
          'total': total.toJson(),
          'outgoing': outgoing.toJson(),
          'incoming': incoming.toJson(),
        }
      };
}

class CallCategoryStats {
  final int count;
  final int connected;
  final int missed;
  final int agentNotPicked;
  final int duration;
  final int ivr;

  CallCategoryStats({
    required this.count,
    required this.connected,
    required this.missed,
    required this.agentNotPicked,
    required this.duration,
    required this.ivr,
  });

  factory CallCategoryStats.fromJson(Map<String, dynamic> json) {
    return CallCategoryStats(
      count: json['count'] ?? 0,
      connected: json['connected'] ?? 0,
      missed: json['missed'] ?? 0,
      agentNotPicked: json['agentNotPicked'] ?? 0,
      duration: json['duration'] ?? 0,
      ivr: json['ivr'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'connected': connected,
        'missed': missed,
        'agentNotPicked': agentNotPicked,
        'duration': duration,
        'ivr': ivr,
      };
}
