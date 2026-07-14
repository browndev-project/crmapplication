class AttendanceConfigModel {
  final String? id;
  final int inactivityAlertMinutes;
  final bool notifyOnInactivity;
  final List<BreakReason> breakReasons;

  AttendanceConfigModel({
    this.id,
    required this.inactivityAlertMinutes,
    required this.notifyOnInactivity,
    required this.breakReasons,
  });

  factory AttendanceConfigModel.fromJson(Map<String, dynamic> json) {
    return AttendanceConfigModel(
      id: json['_id'],
      inactivityAlertMinutes: json['inactivityAlertMinutes'] ?? 15,
      notifyOnInactivity: json['notifyOnInactivity'] ?? false,
      breakReasons: (json['breakReasons'] as List?)
              ?.map((e) => BreakReason.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inactivityAlertMinutes': inactivityAlertMinutes,
      'notifyOnInactivity': notifyOnInactivity,
      'breakReasons': breakReasons.map((e) => e.toJson()).toList(),
    };
  }
}

class BreakReason {
  final String? id;
  final String key;
  final String label;
  final int allowedMinutes;
  final bool notifyManager;

  BreakReason({
    this.id,
    required this.key,
    required this.label,
    required this.allowedMinutes,
    required this.notifyManager,
  });

  factory BreakReason.fromJson(Map<String, dynamic> json) {
    return BreakReason(
      id: json['_id'],
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      allowedMinutes: json['allowedMinutes'] ?? 0,
      notifyManager: json['notifyManager'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'key': key,
      'label': label,
      'allowedMinutes': allowedMinutes,
      'notifyManager': notifyManager,
    };
  }
}
