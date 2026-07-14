class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // task, meeting, general
  final DateTime createdAt;
  final Map<String, dynamic>? data;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.data,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['sourceType'] ?? json['type'] ?? 'general',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
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

    return NotificationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      notifications: list.map((e) => AppNotification.fromJson(e)).toList(),
    );
  }
}
