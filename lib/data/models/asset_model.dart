class AssetModel {
  final String id;
  final String name;
  final String fileType;
  final String r2Key;
  final int size;
  final String uploadedByName;
  final String uploadedByRole;
  final DateTime createdAt;

  AssetModel({
    required this.id,
    required this.name,
    required this.fileType,
    required this.r2Key,
    required this.size,
    required this.uploadedByName,
    required this.uploadedByRole,
    required this.createdAt,
  });

  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown Asset',
      fileType: json['fileType'] ?? '',
      r2Key: json['r2Key'] ?? '',
      size: json['size'] ?? 0,
      uploadedByName: json['uploadedBy']?['name'] ?? 'Unknown',
      uploadedByRole: json['uploadedBy']?['systemRole'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }
}
