import 'dart:io';

import 'package:csv_plus/csv_plus.dart';
import 'package:csv_plus/src/io/csv_file.dart';

/// File I/O examples (dart:io required).
void main() async {
  final tempDir = Directory.systemTemp.createTempSync('csv_plus_example_');
  final path = '${tempDir.path}/data.csv';

  try {
    // --- Write a table to file ---
    final table = CsvTable.fromData(
      headers: ['name', 'age', 'score'],
      rows: [
        ['Alice', 30, 95.5],
        ['Bob', 25, 88.0],
        ['Charlie', 35, 72.3],
      ],
    );
    await CsvFile.write(path, table);
    print('Wrote ${table.rowCount} rows to $path');

    // --- Read back ---
    final loaded = await CsvFile.read(path);
    print('Read back: ${loaded.rowCount} rows');
    print(loaded.toFormattedString());

    // --- Append rows ---
    await CsvFile.append(path, [
      ['Diana', 28, 91.0],
    ]);
    print('Appended 1 row');

    // --- Stream read ---
    print('Streaming rows:');
    await for (final row in CsvFile.stream(path)) {
      print('  $row');
    }

    // --- Sync operations ---
    final syncPath = '${tempDir.path}/sync.csv';
    CsvFile.writeSync(syncPath, table);
    final syncLoaded = CsvFile.readSync(syncPath);
    print('\nSync read: ${syncLoaded.rowCount} rows');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
