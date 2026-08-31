class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final String eventType;
  final DateTime dateTime;
  final String status;
  final String? leadId;
  final String? leadName;
  final String? assignedToId;
  final String? assignedToName;
  final String source;
  final String sourceId;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventType,
    required this.dateTime,
    required this.status,
    this.leadId,
    this.leadName,
    this.assignedToId,
    this.assignedToName,
    required this.source,
    required this.sourceId,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    String? lId;
    String? lName;
    if (json['lead'] is Map) {
      final map = json['lead'] as Map;
      lId = map['_id']?.toString() ?? map['id']?.toString();
      lName = map['name']?.toString();
    } else if (json['lead'] is String && json['lead'].toString().isNotEmpty) {
      lId = json['lead'].toString();
    } else if (json['leadId'] != null && json['leadId'].toString().isNotEmpty) {
      lId = json['leadId'].toString();
    }

    String? aId;
    String? aName;
    if (json['assignedTo'] is Map) {
      final map = json['assignedTo'] as Map;
      aId = map['_id']?.toString() ?? map['id']?.toString();
      aName = map['name']?.toString();
    } else if (json['assignedTo'] is String && json['assignedTo'].toString().isNotEmpty) {
      aId = json['assignedTo'].toString();
    }

    return CalendarEvent(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']).toLocal() : DateTime.now(),
      status: json['status']?.toString() ?? '',
      leadId: lId,
      leadName: lName,
      assignedToId: aId,
      assignedToName: aName,
      source: json['source']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
    );
  }
}
