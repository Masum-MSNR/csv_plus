import '../core/csv_exception.dart';
import '../table/csv_row.dart';
import '../table/csv_table.dart';

/// Sorting operations on [CsvTable].
extension CsvTableSorting on CsvTable {
  /// Sort by column name.
  void sortBy(String column, {bool ascending = true}) {
    final idx = headers.indexOf(column);
    if (idx < 0) throw CsvException('Column "$column" not found');
    sortByIndex(idx, ascending: ascending);
  }

  /// Sort by column index.
  void sortByIndex(int column, {bool ascending = true}) {
    rawData.sort((a, b) {
      final va = column < a.length ? a[column] : null;
      final vb = column < b.length ? b[column] : null;
      return CsvTable.compareValues(va, vb, ascending);
    });
  }

  /// Sort by multiple columns.
  void sortByMultiple(List<(String column, bool ascending)> criteria) {
    final indices = criteria.map((c) {
      final idx = headers.indexOf(c.$1);
      if (idx < 0) throw CsvException('Column "${c.$1}" not found');
      return (idx, c.$2);
    }).toList();

    rawData.sort((a, b) {
      for (final (col, asc) in indices) {
        final va = col < a.length ? a[col] : null;
        final vb = col < b.length ? b[col] : null;
        final cmp = CsvTable.compareValues(va, vb, asc);
        if (cmp != 0) return cmp;
      }
      return 0;
    });
  }

  /// Sort with custom comparator.
  void sort(int Function(CsvRow a, CsvRow b) compare) {
    final headerMap = buildHeaderMap();
    rawData.sort(
        (a, b) => compare(CsvRow(a, headerMap), CsvRow(b, headerMap)));
  }
}
