import 'package:csv_plus/csv_plus.dart';

void main() {
  // Quick decode
  final csv = 'name,age\nAlice,30\nBob,25';
  final rows = csvPlus.decode(csv);
  for (final row in rows) {
    print(row);
  }

  // With headers
  final people = csvPlus.decodeWithHeaders(csv);
  for (final person in people) {
    print('${person['name']} is ${person['age']}');
  }

  // Encode
  final encoded = csvPlus.encode([
    ['name', 'age'],
    ['Alice', 30],
  ]);
  print(encoded);
}
