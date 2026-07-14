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
    return CalendarEvent(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      eventType: json['eventType'] ?? '',
      dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']).toLocal() : DateTime.now(),
      status: json['status'] ?? '',
      leadId: json['lead'] != null ? json['lead']['_id'] : null,
      leadName: json['lead'] != null ? json['lead']['name'] : null,
      assignedToId: json['assignedTo'] != null ? json['assignedTo']['_id'] : null,
      assignedToName: json['assignedTo'] != null ? json['assignedTo']['name'] : null,
      source: json['source'] ?? '',
      sourceId: json['sourceId'] ?? '',
    );
  }
}
