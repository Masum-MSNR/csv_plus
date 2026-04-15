import '../core/csv_exception.dart';
import '../table/csv_row.dart';
import '../table/csv_table.dart';

/// Filtering and querying operations on [CsvTable].
extension CsvTableFiltering on CsvTable {
  /// Filter rows matching predicate. Returns new [CsvTable].
  CsvTable where(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    final filtered =
        rawData.where((r) => test(CsvRow(r, headerMap))).toList();
    return CsvTable.internal(
      List<String>.from(headers),
      filtered.map((r) => List<dynamic>.from(r)).toList(),
    );
  }

  /// Find first row matching predicate (or null).
  CsvRow? firstWhere(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    for (final r in rawData) {
      final row = CsvRow(r, headerMap);
      if (test(row)) return row;
    }
    return null;
  }

  /// Check if any row matches predicate.
  bool any(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    return rawData.any((r) => test(CsvRow(r, headerMap)));
  }

  /// Check if all rows match predicate.
  bool every(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    return rawData.every((r) => test(CsvRow(r, headerMap)));
  }

  /// Get rows in index range. Returns new [CsvTable].
  CsvTable range(int start, [int? end]) {
    final slice = rawData.sublist(start, end);
    return CsvTable.internal(
      List<String>.from(headers),
      slice.map((r) => List<dynamic>.from(r)).toList(),
    );
  }

  /// Get first N rows.
  CsvTable take(int count) => range(0, count.clamp(0, rawData.length));

  /// Skip first N rows.
  CsvTable skip(int count) => range(count.clamp(0, rawData.length));

  /// Get distinct rows based on all fields or specific columns.
  CsvTable distinct({List<String>? columns}) {
    final seen = <String>{};
    final result = <List<dynamic>>[];

    List<int>? colIndices;
    if (columns != null) {
      colIndices = columns.map((c) {
        final idx = headers.indexOf(c);
        if (idx < 0) throw CsvException('Column "$c" not found');
        return idx;
      }).toList();
    }

    for (final row in rawData) {
      final key = colIndices != null
          ? colIndices
              .map((i) => i < row.length ? row[i] : null)
              .join('\x00')
          : row.join('\x00');
      if (seen.add(key)) {
        result.add(List<dynamic>.from(row));
      }
    }

    return CsvTable.internal(List<String>.from(headers), result);
  }
}
