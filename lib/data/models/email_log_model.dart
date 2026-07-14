class EmailLogModel {
  final String id;
  final String provider;
  final String type;
  final List<String> recipients;
  final String senderMail;
  final String subject;
  final int mailsSent;
  final DateTime createdAt;
  final String mailedByName;
  final String mailedByEmail;
  final String mailedByDesignation;
  final String employeeEmail;
  final String entityId;

  EmailLogModel({
    required this.id,
    required this.provider,
    required this.type,
    required this.recipients,
    required this.senderMail,
    required this.subject,
    required this.mailsSent,
    required this.createdAt,
    required this.mailedByName,
    this.mailedByEmail = '',
    this.mailedByDesignation = '',
    this.employeeEmail = '',
    this.entityId = '',
  });

  factory EmailLogModel.fromJson(Map<String, dynamic> json) {
    final mailedBy = json['mailedBy'];
    return EmailLogModel(
      id: json['_id'] ?? '',
      provider: json['provider'] ?? 'Unknown',
      type: json['type'] ?? 'Unknown',
      recipients: (json['recipients'] as List? ?? []).map((e) => e.toString()).toList(),
      senderMail: json['senderMail'] ?? '',
      subject: json['subject'] ?? 'No Subject',
      mailsSent: json['mailsSent'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      mailedByName: mailedBy is Map ? (mailedBy['name'] ?? 'Unknown') : 'Unknown',
      mailedByEmail: mailedBy is Map ? (mailedBy['email'] ?? '') : '',
      mailedByDesignation: mailedBy is Map ? (mailedBy['designation'] ?? '') : '',
      employeeEmail: json['employeeMail'] ?? (mailedBy is Map ? mailedBy['email'] ?? '' : '') ?? '',
      entityId: json['entityId'] ?? '',
    );
  }
}
