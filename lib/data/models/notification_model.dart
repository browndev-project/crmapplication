class AppNotification {
  final String id;
  final String title;
  final String message;
  final String sourceType; // task, meeting, general, etc.
  final String entityType; // Task, Meeting, Lead, etc.
  final String? entityId;
  final String? relationId;
  final String? dueAt;
  final String? company;
  final String? user;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? data;
  final bool isRead;

  String get type => sourceType;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.sourceType,
    required this.entityType,
    this.entityId,
    this.relationId,
    this.dueAt,
    this.company,
    this.user,
    required this.createdAt,
    required this.updatedAt,
    this.data,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final sType = (json['sourceType'] ?? json['type'] ?? 'task').toString();
    final eType = (json['entityType'] ?? (sType.isNotEmpty ? sType[0].toUpperCase() + sType.substring(1) : 'Task')).toString();

    return AppNotification(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      sourceType: sType,
      entityType: eType,
      entityId: json['entityId']?.toString(),
      relationId: json['relationId']?.toString(),
      dueAt: json['dueAt']?.toString(),
      company: json['company']?.toString(),
      user: json['user']?.toString(),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      data: json,
      isRead: json['status'] == 'read' || (json['isRead'] ?? false),
    );
  }
}

class NotificationResponse {
  final bool success;
  final String message;
  final List<AppNotification> notifications;

  NotificationResponse({
    required this.success,
    required this.message,
    required this.notifications,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<dynamic> list = [];
    if (data is List) {
      list = data;
    } else if (data is Map && data['notifications'] is List) {
      list = data['notifications'];
    }

    final isSuccess = json['success'] == true ||
        json['statusCode'] == 200 ||
        json['statusCode'] == 201;

    return NotificationResponse(
      success: isSuccess,
      message: json['message']?.toString() ?? 'OK',
      notifications: list
          .whereType<Map<String, dynamic>>()
          .map((e) => AppNotification.fromJson(e))
          .toList(),
    );
  }
}
