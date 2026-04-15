import 'package:csv_plus/csv_plus.dart';

/// CsvTable manipulation examples.
void main() {
  // --- Create from CSV string ---
  final csv = '''name,age,city,score
Alice,30,NYC,95.5
Bob,25,LA,88.0
Charlie,35,NYC,72.3
Diana,28,SF,91.0
Eve,32,LA,85.5''';

  final table = CsvTable.parse(csv);
  print('=== Table (${table.rowCount} rows, ${table.columnCount} cols) ===');
  print(table.toFormattedString());
  print('');

  // --- Column access ---
  print('Ages: ${table.column('age')}');
  print('');

  // --- Filtering ---
  final nycResidents = table.where((row) => row['city'] == 'NYC');
  print('NYC residents (${nycResidents.rowCount}):');
  print(nycResidents.toFormattedString());

  // --- Sorting ---
  final sorted = table.copy();
  sorted.sortBy('score', ascending: false);
  print('Top scorer: ${sorted[0]['name']} (${sorted[0]['score']})');
  print('');

  // --- Aggregation ---
  print('Total score: ${table.sum('score')}');
  print('Average age: ${table.avg('age')}');
  print('Min score: ${table.min('score')}');
  print('Max score: ${table.max('score')}');
  print('');

  // --- Group by ---
  final byCity = table.groupBy('city');
  print('Cities: ${byCity.keys.toList()}');
  for (final entry in byCity.entries) {
    print('  ${entry.key}: ${entry.value.rowCount} people');
  }
  print('');

  // --- Column manipulation ---
  final modified = table.copy();
  modified.addColumn('grade', defaultValue: 'N/A');
  modified.removeColumn('city');
  modified.renameColumn('score', 'points');
  print('Modified headers: ${modified.headers}');
  print('');

  // --- Schema inference ---
  final schema = table.inferSchema();
  print('Inferred schema:');
  for (final col in schema.columns) {
    print('  ${col.name}: ${col.type} (nullable: ${col.nullable})');
  }
  print('');

  // --- Iterator ---
  print('Iterating:');
  final iter = table.iterator;
  while (iter.moveNext()) {
    final row = iter.current;
    print('  ${row['name']} from ${row['city']}');
  }
  print('');

  // --- Create from Maps ---
  final fromMaps = CsvTable.fromMaps([
    {'product': 'Widget', 'price': 9.99, 'qty': 100},
    {'product': 'Gadget', 'price': 24.99, 'qty': 50},
  ]);
  print('From maps:');
  print(fromMaps.toCsv());
}
