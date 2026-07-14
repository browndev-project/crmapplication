import 'dart:math';
import 'package:intl/intl.dart';

String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

String toTitleCase(String? text) {
  if (text == null || text.isEmpty) return '';
  
  // Standardize delimiters
  final cleaned = text.replaceAll('_', ' ').replaceAll('-', ' ');
  final words = cleaned.split(' ');
  
  // Small words to keep lowercase unless at the start
  final smallWords = {'to', 'in', 'for', 'and', 'the', 'of', 'with', 'at'};
  
  final List<String> result = [];
  for (int i = 0; i < words.length; i++) {
    final word = words[i].trim();
    if (word.isEmpty) continue;
    
    final lowerWord = word.toLowerCase();
    
    if (i > 0 && smallWords.contains(lowerWord)) {
      result.add(lowerWord);
    } else {
      result.add(lowerWord[0].toUpperCase() + lowerWord.substring(1));
    }
  }
  
  return result.join(' ');
}

String formatCurrency(dynamic value, {int decimalDigits = 0}) {
  final amount = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
  final suffix = decimalDigits > 0 ? '.${'0' * decimalDigits}' : '';
  return '\u{20B9}${NumberFormat('#,##,###$suffix').format(amount)}';
}
