class DownloadLogModel {
  final String id;
  final String module;
  final String format;
  final String userName;
  final int rows;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DownloadLogModel({
    required this.id,
    required this.module,
    required this.format,
    required this.userName,
    required this.rows,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DownloadLogModel.fromJson(Map<String, dynamic> json) {
    // Check if 'meta' exists for rowCount, otherwise fallback or 0
    int rowCount = 0;
    if (json['meta'] != null && json['meta']['rowCount'] != null) {
      rowCount = json['meta']['rowCount'];
    } else {
       rowCount = json['rows'] ?? 0;
    }

    return DownloadLogModel(
      id: json['_id'] ?? '',
      module: json['module'] ?? 'Unknown',
      format: json['format'] ?? 'Unknown',
      userName: _parseUser(json['user']),
      rows: rowCount,
      status: json['status'] ?? 'Unknown',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  static String _parseUser(dynamic user) {
     if (user is Map) return user['name'] ?? 'Unknown User';
     if (user is String) return user;
     return 'Unknown User';
  }
}
