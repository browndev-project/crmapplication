
class IdName {
  final String id;
  final String name;

  IdName({required this.id, required this.name});

  factory IdName.fromJson(Map<String, dynamic> json) {
    return IdName(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
