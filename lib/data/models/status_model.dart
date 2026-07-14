class LeadStatus {
  final String id;
  final String name;
  final String color;
  final String backgroundColor;
  final bool isActive;
  final bool isDefault;

  LeadStatus({
    required this.id,
    required this.name,
    required this.color,
    required this.backgroundColor,
    required this.isActive,
    this.isDefault = false,
  });

  factory LeadStatus.fromJson(Map<String, dynamic> json) {
    return LeadStatus(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      color: json['color'] ?? '',
      backgroundColor: json['backgroundColor'] ?? '',
      isActive: json['active'] ?? true, 
      isDefault: json['isDefault'] ?? false,
    );
  }
}
