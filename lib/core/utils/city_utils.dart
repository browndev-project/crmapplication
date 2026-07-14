import 'formatters.dart';

class CityUtils {
  static const Map<String, String> _synonyms = {
    'gurgaon': 'Gurugram',
    'new delhi': 'Delhi',
    'bombay': 'Mumbai',
    'calcutta': 'Kolkata',
    'madras': 'Chennai',
    'bangalore': 'Bengaluru',
  };

  static bool _isLikelyGarbage(String city) {
    if (city.length < 3) return true;
    if (city.length > 40) return true;
    if (!RegExp(r'^[a-zA-Z\s\-\.]+$').hasMatch(city)) return true;
    final lower = city.toLowerCase().trim();
    if (lower == 'sdfadfads' || lower == 'sdfadfad') return true;
    if (RegExp(r'^(.)\1{2,}$').hasMatch(lower.replaceAll(RegExp(r'\s+'), ''))) return true;
    final letters = lower.replaceAll(RegExp(r'\s+'), '');
    if (letters.length >= 3) {
      int vowelCount = 0;
      for (final ch in letters.split('')) {
        if ('aeiou'.contains(ch)) vowelCount++;
      }
      if (vowelCount / letters.length < 0.2) return true;
    }
    return false;
  }

  static String _normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (_synonyms.containsKey(lower)) return _synonyms[lower]!;
    return toTitleCase(trimmed);
  }

  static List<String> clean(List<String?> rawCities) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawCities) {
      if (raw == null) continue;
      final normalized = _normalize(raw);
      if (normalized.isEmpty) continue;
      if (_isLikelyGarbage(normalized)) continue;
      if (seen.contains(normalized)) continue;
      seen.add(normalized);
      result.add(normalized);
    }
    result.sort();
    return result;
  }
}
