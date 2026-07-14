import 'package:flutter/material.dart';

class CallStatusInfo {
  final String label;
  final Color color;
  const CallStatusInfo(this.label, this.color);
}

dynamic _getProperty(dynamic log, String name) {
  if (log == null) return null;
  if (log is CallLog) {
    if (name == 'source') return log.source;
    if (name == 'status') return log.status;
    if (name == 'duration') return log.duration;
    if (name == 'ivr') return log.ivr;
    if (name == 'callDetails') return log.callDetails;
    if (name == 'startTime') return log.startTime;
    if (name == 'endTime') return log.endTime;
  }
  if (log is Map) {
    return log[name];
  }
  // Try reflection/dynamic property read as a fallback for objects like DetailedCall
  try {
    if (name == 'source') return log.source;
    if (name == 'status') return log.status;
    if (name == 'duration') return log.duration;
    if (name == 'ivr') return log.ivr;
    if (name == 'callDetails') return log.callDetails;
    if (name == 'startTime') return log.startTime;
    if (name == 'endTime') return log.endTime;
  } catch (_) {}
  return null;
}

int getActiveDuration(dynamic log) {
  final String source = _getProperty(log, 'source')?.toString().toLowerCase() ?? '';

  if (source == 'ivr') {
    final int rawDuration = num.tryParse(_getProperty(log, 'duration')?.toString() ?? '0')?.toInt() ?? 0;
    if (rawDuration > 0) return rawDuration;

    final ivrMap = _getProperty(log, 'ivr') as Map<String, dynamic>?;

    if (ivrMap != null) {
      final ivrDur =
          ivrMap['duration'] ??
          ivrMap['callDuration'] ??
          ivrMap['billDuration'] ??
          ivrMap['totalDuration'];
      if (ivrDur != null) {
        final parsed = num.tryParse(ivrDur.toString())?.toInt();
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return 0;
  }

  final details = _getProperty(log, 'callDetails') as List<dynamic>?;

  if (details != null && details.isNotEmpty) {
    return details
        .where((d) {
          if (d is! Map) return false;
          final stateVal = d['state']?.toString().toUpperCase() ?? '';
          return stateVal == 'ACTIVE' || stateVal == 'CONNECTED';
        })
        .fold(
          0,
          (sum, d) {
            if (d is! Map) return sum;
            final durVal = d['duration'];
            final parsed = num.tryParse(durVal?.toString() ?? '')?.toInt() ?? 0;
            return sum + parsed;
          },
        );
  }
  return 0;
}

bool hasActiveState(dynamic log) {
  final details = _getProperty(log, 'callDetails') as List<dynamic>?;
  if (details != null && details.isNotEmpty) {
    return details.any((d) {
      if (d is! Map) return false;
      final stateVal = d['state']?.toString().toUpperCase() ?? '';
      return stateVal == 'ACTIVE' || stateVal == 'CONNECTED';
    });
  }
  return false;
}

bool isCallConnected(dynamic log) {
  if (log == null) return false;
  
  if (hasActiveState(log)) {
    return true;
  }
  
  final details = _getProperty(log, 'callDetails') as List<dynamic>?;
  if (details == null || details.isEmpty) {
    final status = _getProperty(log, 'status')?.toString().toLowerCase() ?? '';
    final dur = int.tryParse(_getProperty(log, 'duration')?.toString() ?? '0') ?? 0;
    final source = _getProperty(log, 'source')?.toString().toLowerCase() ?? '';
    
    if (source == 'ivr') {
      return status == 'completed' || status == 'connected' || status == 'answered' || dur > 0;
    }
    return status == 'delivered' || status == 'completed' || status == 'connected' || status == 'answered' || dur > 0;
  }
  
  return false;
}

String formatCallDuration(int seconds) {
  if (seconds == 0) return '0s';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final parts = <String>[];
  if (h > 0) parts.add('${h}h');
  if (m > 0 || h > 0) parts.add('${m.toString().padLeft(h > 0 ? 2 : 1, '0')}m');
  parts.add('${s.toString().padLeft(m > 0 || h > 0 ? 2 : 1, '0')}s');
  return parts.join(' ');
}

String formatCallStatus(String status) {
  if (status.isEmpty) return 'Unknown';
  return status
      .split('_')
      .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

CallStatusInfo getCallConnectionStatus(dynamic log) {
  final String source = _getProperty(log, 'source')?.toString().toLowerCase() ?? '';
  final String statusStr = _getProperty(log, 'status')?.toString() ?? '';
  final String s = statusStr.toLowerCase();

  if (source == 'ivr') {
    final formattedStatus = formatCallStatus(statusStr);
    Color statusColor = Colors.grey;
    if (s == 'completed' || s == 'connected' || s == 'answered') {
      statusColor = Colors.green;
    } else if (s == 'missed' || s == 'failed') {
      statusColor = Colors.red;
    }
    return CallStatusInfo(formattedStatus, statusColor);
  }

  // Else (Non-IVR):
  final isConnected = isCallConnected(log);
  if (isConnected) {
    return const CallStatusInfo('Connected', Colors.green);
  } else {
    return const CallStatusInfo('Missed', Colors.red);
  }
}

class CallLogsResult {
  final List<CallLog> logs;
  final int totalCount;
  final int totalPages;
  final int currentPage;

  CallLogsResult({
    required this.logs,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
  });
}

class CallLog {
  final String id;
  final String source; // IVR, APP_INITIATED, WEB
  final String callType; // INCOMING, OUTGOING
  final String status; // completed, missed, delivered
  final int duration;
  final String callerNumber;
  final String receiverNumber;
  final String? recordingUrl;
  final Map<String, dynamic>? ivr;
  final String? startTime;
  final String? endTime;
  final Map<String, dynamic>? initiatedBy;
  final Map<String, dynamic>? crmUserMapped;
  final List<dynamic>? callDetails;
  final String createdAt;
  final String? simSlot;
  final String? simDisplayName;

  CallLog({
    required this.id,
    required this.source,
    required this.callType,
    required this.status,
    required this.duration,
    required this.callerNumber,
    required this.receiverNumber,
    this.recordingUrl,
    this.ivr,
    this.startTime,
    this.endTime,
    this.initiatedBy,
    this.crmUserMapped,
    this.callDetails,
    required this.createdAt,
    this.simSlot,
    this.simDisplayName,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['_id'] ?? '',
      source: json['source'] ?? json['callSource'] ?? 'Unknown',
      callType: json['callType'] ?? 'OUTGOING',
      status: json['status'] ?? 'completed',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      callerNumber: json['callerNumber'] ?? '',
      receiverNumber: json['receiverNumber'] ?? json['phone'] ?? '',
      recordingUrl: json['recordingUrl'],
      ivr: json['ivr'] is Map<String, dynamic> ? json['ivr'] : null,
      startTime: json['startTime'],
      endTime: json['endTime'],
      initiatedBy: json['initiatedBy'] is Map<String, dynamic> ? json['initiatedBy'] : null,
      crmUserMapped: json['crmUserMapped'] is Map<String, dynamic> ? json['crmUserMapped'] : null,
      callDetails: json['callDetails'] is List ? json['callDetails'] : null,
      createdAt: json['createdAt'] ?? '',
      simSlot: json['simSlot']?.toString() ?? json['simSlotIndex']?.toString(),
      simDisplayName: json['simDisplayName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'source': source,
      'callType': callType,
      'status': status,
      'duration': duration,
      'callerNumber': callerNumber,
      'receiverNumber': receiverNumber,
      'recordingUrl': recordingUrl,
      'ivr': ivr,
      'startTime': startTime,
      'endTime': endTime,
      'initiatedBy': initiatedBy,
      'crmUserMapped': crmUserMapped,
      'callDetails': callDetails,
      'createdAt': createdAt,
      'simSlot': simSlot,
      'simDisplayName': simDisplayName,
    };
  }
}
