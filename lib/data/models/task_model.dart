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

class TaskData {
  final List<Task> tasks;
  final int totalCount;
  final Pagination pagination;
  final Map<String, int>? totalCountByStatus;

  TaskData({
    required this.tasks,
    required this.totalCount,
    required this.pagination,
    this.totalCountByStatus,
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
    }

    // Handle total count
    int total = json['totalCount'] ?? 0;
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

    return TaskData(
      tasks: allTasks,
      totalCount: total,
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
      totalCountByStatus: statusCounts,
    );
  }
}

class Task {
  final String id;
  final String status;
  final String title;
  final String? description;
  final String? dueDate;
  final TaskLead? lead;
  final String? createdAt;

  Task({
    required this.id,
    required this.status,
    required this.title,
    this.description,
    this.dueDate,
    this.lead,
    this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? '',
      status: json['status'] ?? 'Not Started',
      title: json['title'] ?? 'No Title',
      description: json['description'],
      dueDate: json['dueDate'],
      lead: json['lead'] != null ? TaskLead.fromJson(json['lead']) : null,
      createdAt: json['createdAt'],
    );
  }
}

class TaskLead {
  final String id;
  final String name;

  TaskLead({required this.id, required this.name});

  factory TaskLead.fromJson(Map<String, dynamic> json) {
    return TaskLead(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown',
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;

  Pagination({
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNextPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? 1,
      hasNextPage: json['hasNextPage'] ?? false,
    );
  }
}
