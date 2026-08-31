import 'package:csv/csv.dart';

void main() {
  try {
    const converter = CsvToListConverter();
    print('CsvToListConverter exists! $converter');
  } catch (e) {
    print('Error: $e');
  }
}
