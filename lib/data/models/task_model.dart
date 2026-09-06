class TaskResponse {
  final int statusCode;
  final TaskData? data;
  final String message;
  final bool success;

  TaskResponse({
    required this.statusCode,
    this.data,
    required this.message,
    required this.success,
  });

  factory TaskResponse.fromJson(Map<String, dynamic> json) {
    return TaskResponse(
      statusCode: json['statusCode'] ?? 0,
      data: json['data'] != null ? TaskData.fromJson(json['data']) : null,
      message: json['message'] ?? '',
      success: json['success'] ?? false,
    );
  }
}

// class TaskData {
//   final List<Task> tasks;
//   final int totalCount;
//   final Pagination pagination;
//   final Map<String, int>? totalCountByStatus;
// 
//   TaskData({
//     required this.tasks,
//     required this.totalCount,
//     required this.pagination,
//     this.totalCountByStatus,
//   });
// ...
// }

class TaskData {
  final List<Task> tasks;
  final int totalCount;
  final Pagination pagination;
  final Map<String, int>? totalCountByStatus;
  final Map<String, int>? categoryCounts;

  TaskData({
    required this.tasks,
    required this.totalCount,
    required this.pagination,
    this.totalCountByStatus,
    this.categoryCounts,
  });

  factory TaskData.fromJson(Map<String, dynamic> json) {
    List<Task> allTasks = [];
    
    // Handle grouped format (tasksByStatus)
    if (json['tasksByStatus'] != null && json['tasksByStatus'] is Map) {
        final Map<String, dynamic> groups = json['tasksByStatus'];
        groups.forEach((status, list) {
            if (list is List) {
                allTasks.addAll(list.map((e) => Task.fromJson(e)).toList());
            }
        });
    } 
    // Handle flat list format (tasks)
    else if (json['tasks'] != null && json['tasks'] is List) {
        allTasks = (json['tasks'] as List).map((e) => Task.fromJson(e)).toList();
    } else if (json['data'] != null && json['data'] is List) {
        allTasks = (json['data'] as List).map((e) => Task.fromJson(e)).toList();
    }

    // Handle total count
    // int total = json['totalCount'] ?? json['total'] ?? 0;
    int total = json['totalCount'] ?? json['total'] ?? 0;
    if (total == 0 && json['pagination'] != null && json['pagination'] is Map) {
      final p = json['pagination'];
      total = p['totalCount'] ?? p['total'] ?? p['totalRecords'] ?? p['totalTasks'] ?? 0;
    }
    if (total == 0 && json['totalCountByStatus'] != null && json['totalCountByStatus'] is Map) {
        final Map<String, dynamic> counts = json['totalCountByStatus'];
        counts.forEach((_, count) {
            if (count is int) {
              total += count;
            } else if (count is String) {
              total += int.tryParse(count) ?? 0;
            }
        });
    }

    Map<String, int> statusCounts = {};
    if (json['totalCountByStatus'] != null && json['totalCountByStatus'] is Map) {
        final Map<String, dynamic> counts = json['totalCountByStatus'];
        counts.forEach((key, val) {
            if (val is int) {
                statusCounts[key] = val;
            } else if (val is String) {
                statusCounts[key] = int.tryParse(val) ?? 0;
            }
        });
    }

    Map<String, int> catCounts = {};
    final rawCat = json['categoryCounts'] ?? json['counts'];
    if (rawCat is Map) {
      rawCat.forEach((key, val) {
        if (val is int) {
          catCounts[key.toString()] = val;
        } else if (val is String) {
          catCounts[key.toString()] = int.tryParse(val) ?? 0;
        }
      });
    }

    return TaskData(
      tasks: allTasks,
      totalCount: total,
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
      totalCountByStatus: statusCounts,
      categoryCounts: catCounts.isNotEmpty ? catCounts : null,
    );
  }
}

// class Task {
//   final String id;
//   final String status;
//   final String title;
//   final String? description;
//   final String? dueDate;
//   final TaskLead? lead;
//   final TaskLead? assignedTo;
//   final String? createdAt;
//   final List<String> voiceNotes;
// 
//   Task({
//     required this.id,
//     required this.status,
//     required this.title,
//     this.description,
//     this.dueDate,
//     this.lead,
//     this.assignedTo,
//     this.createdAt,
//     this.voiceNotes = const [],
//   });
// 
//   factory Task.fromJson(Map<String, dynamic> json) {
//     return Task(
//       id: json['_id'] ?? '',
//       status: json['status'] ?? 'Not Started',
//       title: json['title'] ?? 'No Title',
//       description: json['description'],
//       dueDate: json['dueDate'],
//       lead: json['lead'] != null ? TaskLead.fromJson(json['lead']) : null,
//       assignedTo: json['assignedTo'] != null ? TaskLead.fromJson(json['assignedTo']) : null,
//       createdAt: json['createdAt'],
//       voiceNotes: json['voiceNotes'] != null ? List<String>.from(json['voiceNotes']) : const [],
//     );
//   }
// }
// 
// class TaskLead {
//   final String id;
//   final String name;
// 
//   TaskLead({required this.id, required this.name});
// 
//   factory TaskLead.fromJson(Map<String, dynamic> json) {
//     return TaskLead(
//       id: json['_id'] ?? '',
//       name: json['name'] ?? 'Unknown',
//     );
//   }
// }

class Task {
  final String id;
  final String status;
  final String title;
  final String? description;
  final String? dueDate;
  final TaskLead? lead;
  final TaskLead? assignedTo;
  final String? createdAt;
  final String? updatedAt;
  final String priority;
  final String? phone;
  final List<String> voiceNotes;

  Task({
    required this.id,
    required this.status,
    required this.title,
    this.description,
    this.dueDate,
    this.lead,
    this.assignedTo,
    this.createdAt,
    this.updatedAt,
    this.priority = 'Medium',
    this.phone,
    this.voiceNotes = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    final leadObj = json['lead'] != null ? TaskLead.fromJson(json['lead']) : null;
    final directPhone = json['phone'] ?? json['phoneNo'] ?? json['phoneNumber'] ?? json['leadPhone'];

    return Task(
      id: json['_id'] ?? json['id'] ?? '',
      status: json['status'] ?? 'Not Started',
      title: json['title'] ?? 'No Title',
      description: json['description'],
      dueDate: json['dueDate'],
      lead: leadObj,
      assignedTo: json['assignedTo'] != null ? TaskLead.fromJson(json['assignedTo']) : null,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      priority: json['priority'] ?? 'Medium',
      phone: (leadObj?.phone != null && leadObj!.phone!.isNotEmpty) ? leadObj.phone : (directPhone?.toString()),
      voiceNotes: json['voiceNotes'] != null ? List<String>.from(json['voiceNotes']) : const [],
    );
  }
}

class TaskLead {
  final String id;
  final String name;
  final String? phone;
  final String? company;

  TaskLead({
    required this.id, 
    required this.name,
    this.phone,
    this.company,
  });

  factory TaskLead.fromJson(dynamic json) {
    if (json is String) {
      return TaskLead(id: json, name: 'Lead');
    }
    if (json is Map) {
      return TaskLead(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown',
        phone: json['phone']?.toString() ?? json['phoneNo']?.toString() ?? json['phoneNumber']?.toString(),
        company: json['company'] is String ? json['company'] : (json['company'] is Map ? json['company']['name']?.toString() : null),
      );
    }
    return TaskLead(id: '', name: 'Unknown');
  }
}

// class Pagination {
//   final int page;
//   final int limit;
//   final int totalPages;
//   final bool hasNextPage;
// 
//   Pagination({
//     required this.page,
//     required this.limit,
//     required this.totalPages,
//     required this.hasNextPage,
//   });
// 
//   factory Pagination.fromJson(Map<String, dynamic> json) {
//     return Pagination(
//       page: json['page'] ?? 1,
//       limit: json['limit'] ?? 10,
//       totalPages: json['totalPages'] ?? 1,
//       hasNextPage: json['hasNextPage'] ?? false,
//     );
//   }
// }

class Pagination {
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final int totalCount;

  Pagination({
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNextPage,
    this.totalCount = 0,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    final rawCount = json['totalCount'] ?? json['total'] ?? json['totalRecords'] ?? json['totalTasks'] ?? 0;
    final parsedCount = rawCount is int ? rawCount : (int.tryParse(rawCount.toString()) ?? 0);
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? 1,
      hasNextPage: json['hasNextPage'] ?? false,
      totalCount: parsedCount,
    );
  }
}
