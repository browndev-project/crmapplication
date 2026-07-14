import 'package:flutter/material.dart';
import '../../data/models/call_log_model.dart';

dynamic _getProperty(dynamic log, String name) {
  if (log == null) return null;
  if (log is Map) {
    return log[name];
  }
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

int getLeadCallDuration(dynamic log) {
  if (log == null) return 0;
  
  if (!isLeadCallConnected(log)) {
    return 0;
  }
  
  // 1. Try to get active talk duration from callDetails first
  int activeDur = getActiveDuration(log);
  if (activeDur > 0) return activeDur;
  
  // 2. Fallback: Parse startTime and endTime
  final startStr = _getProperty(log, 'startTime')?.toString() ?? '';
  final endStr = _getProperty(log, 'endTime')?.toString() ?? '';
  if (startStr.isNotEmpty && endStr.isNotEmpty) {
    final start = DateTime.tryParse(startStr);
    final end = DateTime.tryParse(endStr);
    if (start != null && end != null) {
      final diff = end.difference(start).inSeconds;
      if (diff > 0) return diff;
    }
  }
  
  // 3. Fallback: raw duration field
  int rawDur = 0;
  if (log is CallLog) {
    rawDur = log.duration;
  } else if (log is Map) {
    rawDur = int.tryParse(log['duration']?.toString() ?? '0') ?? 0;
  }
  return rawDur;
}


bool _hasActiveState(dynamic log) {
  if (log == null) return false;
  final details = _getProperty(log, 'callDetails') as List<dynamic>?;
  if (details != null && details.isNotEmpty) {
    for (var d in details) {
      if (d is Map) {
        final state = d['state']?.toString().toUpperCase() ?? '';
        if (state == 'ACTIVE' || state == 'CONNECTED') {
          return true;
        }
      }
    }
  }
  return false;
}

bool isLeadCallConnected(dynamic log) {
  if (log == null) return false;
  
  final source = _getProperty(log, 'source')?.toString().toLowerCase() ?? '';
  final status = _getProperty(log, 'status')?.toString().toLowerCase() ?? '';
  
  if (status == 'missed' ||
      status == 'no_answer' ||
      status == 'rejected' ||
      status == 'cancelled' ||
      status == 'failed') {
    return false;
  }

  final details = _getProperty(log, 'callDetails') as List<dynamic>?;
  // If call details are present, but there is no ACTIVE/CONNECTED state, it was never answered
  if (details != null && details.isNotEmpty) {
    if (!_hasActiveState(log)) {
      return false;
    }
  }
  
  int dur = 0;
  if (log is CallLog) {
    dur = log.duration;
  } else if (log is Map) {
    dur = int.tryParse(log['duration']?.toString() ?? '0') ?? 0;
  }
  
  if (source == 'ivr') {
    return status == 'completed' || status == 'connected' || status == 'answered' || dur > 0;
  }
  
  final hasActive = _hasActiveState(log);
  return status == 'delivered' || status == 'completed' || status == 'connected' || status == 'answered' || hasActive || dur > 0;
}

CallStatusInfo getLeadCallConnectionStatus(dynamic log) {
  if (log == null) return const CallStatusInfo('Unknown', Colors.grey);
  
  final source = _getProperty(log, 'source')?.toString().toLowerCase() ?? '';
  final statusStr = _getProperty(log, 'status')?.toString() ?? '';
  final status = statusStr.toLowerCase();
  
  if (source == 'ivr') {
    final formattedStatus = formatCallStatus(statusStr);
    Color statusColor = Colors.grey;
    if (status == 'completed' || status == 'connected' || status == 'answered') {
      statusColor = Colors.green;
    } else if (status == 'missed' || status == 'failed') {
      statusColor = Colors.red;
    }
    return CallStatusInfo(formattedStatus, statusColor);
  }
  
  final isConnected = isLeadCallConnected(log);
  if (isConnected) {
    return const CallStatusInfo('Connected', Colors.green);
  }

  // If callDetails is present and has no active state, show status as "Missed"
  final details = _getProperty(log, 'callDetails') as List<dynamic>?;
  if (details != null && details.isNotEmpty && !_hasActiveState(log)) {
    return const CallStatusInfo('Missed', Colors.red);
  }
  
  // Specific checks for unanswered and cut/rejected calls
  if (status == 'missed' || status == 'no_answer') {
    return const CallStatusInfo('Missed', Colors.red);
  }
  
  if (status == 'rejected' || status == 'cancelled' || status == 'failed') {
    return const CallStatusInfo('Call Cut', Colors.red);
  }
  
  if (status.isNotEmpty && status != 'delivered') {
    try {
      final label = statusStr[0].toUpperCase() + statusStr.substring(1);
      return CallStatusInfo(label, Colors.orange);
    } catch (_) {}
    return const CallStatusInfo('Attempted', Colors.orange);
  }
  
  return const CallStatusInfo('Missed', Colors.red);
}
