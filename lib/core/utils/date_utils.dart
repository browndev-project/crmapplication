import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Formats a DateTime for API consumption (UTC ISO8601).
  static String toApiString(DateTime? dateTime) {
    if (dateTime == null) return '';
    return dateTime.toUtc().toIso8601String();
  }

  /// Safely parses a date string and converts it to local time.
  static DateTime? parseSafe(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    String trimmed = dateStr.trim();
    
    // Check if it's a Unix timestamp (only digits)
    final asInt = int.tryParse(trimmed);
    if (asInt != null) {
      if (asInt < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt * 1000).toLocal();
      } else {
        return DateTime.fromMillisecondsSinceEpoch(asInt).toLocal();
      }
    }
    
    // HEURISTIC: If it looks like an ISO date/time string but lacks timezone info,
    // we assume the backend sent it in UTC (Standard practice).
    if (trimmed.contains('-') && trimmed.contains(':') && 
        !trimmed.contains('Z') && !trimmed.contains('+')) {
      // Convert space to T for standard ISO format if needed
      trimmed = trimmed.replaceAll(' ', 'T');
      // Append Z to force UTC parsing
      if (trimmed.contains('T')) {
         trimmed = '${trimmed}Z';
      }
    }

    try {
      // 1. Try standard ISO8601 (now with forced Z if missing)
      final dt = DateTime.parse(trimmed);
      return dt.toLocal();
    } catch (_) {
      // 2. Try common display formats
      final formats = [
        'dd MMM yyyy',
        'dd MMM yyyy, hh:mm a',
        'dd/MM/yyyy hh:mm a',
        'yyyy-MM-dd HH:mm:ss',
        'dd/MM/yyyy',
        'dd-MM-yyyy',
        'yyyy-MM-dd',
      ];
      
      for (var format in formats) {
        try {
          return DateFormat(format).parse(trimmed);
        } catch (_) {}
      }
      return null;
    }
  }

  /// Safely parses and formats a date string for display.
  static String formatSafe(String? dateStr, {String format = 'dd MMM yyyy, hh:mm a'}) {
    final dt = parseSafe(dateStr);
    if (dt == null) return dateStr ?? '--';
    return DateFormat(format).format(dt);
  }

  /// Formats for standard day month year
  static String formatDayMonthYear(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  /// Formats a DateTime for display in the UI (local time).
  static String formatDisplay(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  /// Formats a DateTime in a shorter format.
  static String formatShort(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  /// Formats time only
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    return DateFormat('hh:mm a').format(dateTime);
  }
}

