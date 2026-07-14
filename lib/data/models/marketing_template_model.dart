
class MarketingTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;
  final DateTime? createdAt;

  MarketingTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.createdAt,
  });

  factory MarketingTemplate.fromJson(Map<String, dynamic> json) {
    return MarketingTemplate(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      subject: json['subject'] ?? '',
      body: json['body'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'subject': subject,
      'body': body,
    };
  }
}
