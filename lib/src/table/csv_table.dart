import '../codec/csv_codec.dart';
import '../core/csv_config.dart';
import '../core/csv_exception.dart';
import 'csv_column.dart';
import 'csv_row.dart';
import 'csv_schema.dart';

/// 2D CSV data structure with headers, manipulation, querying, and aggregation.
class CsvTable {
  List<String> _headers;
  final List<List<dynamic>> _data;

  /// Create from raw 2D data (no headers).
  CsvTable(List<List<dynamic>> rows)
      : _headers = [],
        _data = rows.map((r) => List<dynamic>.from(r)).toList();

  /// Create from 2D data where first row is headers.
  CsvTable.withHeaders(List<List<dynamic>> rows)
      : _headers = rows.isNotEmpty
            ? rows.first.map((e) => e?.toString() ?? '').toList()
            : [],
        _data = rows.length > 1
            ? rows.skip(1).map((r) => List<dynamic>.from(r)).toList()
            : [];

  /// Create from explicit headers + data rows.
  CsvTable.fromData({
    required List<String> headers,
    required List<List<dynamic>> rows,
  })  : _headers = List<String>.from(headers),
        _data = rows.map((r) => List<dynamic>.from(r)).toList();

  /// Create from a list of Maps.
  factory CsvTable.fromMaps(List<Map<String, dynamic>> maps) {
    if (maps.isEmpty) return CsvTable.fromData(headers: [], rows: []);
    final headers = maps.first.keys.toList();
    final data = maps.map((m) => headers.map((h) => m[h]).toList()).toList();
    return CsvTable.fromData(headers: headers, rows: data);
  }

  /// Parse from CSV string.
  factory CsvTable.parse(String csv, {CsvConfig config = const CsvConfig()}) {
    final allRows =
        CsvCodec(config.copyWith(hasHeader: false)).decode(csv);
    if (allRows.isEmpty) return CsvTable.fromData(headers: [], rows: []);

    final headers = allRows.first.map((e) => e?.toString() ?? '').toList();
    final data = allRows.skip(1).toList();
    return CsvTable.fromData(headers: headers, rows: data);
  }

  /// Create empty table with column definitions.
  CsvTable.empty({List<String> headers = const []})
      : _headers = List<String>.from(headers),
        _data = [];

  CsvTable._internal(this._headers, this._data);

  // --- Properties ---

  /// Column headers. Empty list if no headers defined.
  List<String> get headers => List.unmodifiable(_headers);

  /// Whether headers are defined.
  bool get hasHeaders => _headers.isNotEmpty;

  /// Number of data rows.
  int get rowCount => _data.length;

  /// Number of columns.
  int get columnCount =>
      _headers.isNotEmpty ? _headers.length : (_data.isNotEmpty ? _data.first.length : 0);

  /// Whether the table has no data rows.
  bool get isEmpty => _data.isEmpty;

  bool get isNotEmpty => _data.isNotEmpty;

  // --- Row Access ---

  /// Get row by index as [CsvRow].
  CsvRow operator [](int index) {
    final headerMap = _buildHeaderMap();
    return CsvRow(_data[index], headerMap);
  }

  /// Set/replace row at index.
  void operator []=(int index, List<dynamic> row) {
    _data[index] = List<dynamic>.from(row);
  }

  /// Get all rows as [CsvRow] list.
  List<CsvRow> get rows {
    final headerMap = _buildHeaderMap();
    return _data.map((r) => CsvRow(r, headerMap)).toList();
  }

  /// Get first row.
  CsvRow get first => this[0];

  /// Get last row.
  CsvRow get last => this[_data.length - 1];

  // --- Column Access ---

  /// Get all values in a column by header name.
  List<dynamic> column(String name) {
    final idx = _headers.indexOf(name);
    if (idx < 0) {
      throw CsvException('Column "$name" not found');
    }
    return columnAt(idx);
  }

  /// Get all values in a column by index.
  List<dynamic> columnAt(int index) {
    return _data.map((r) => index < r.length ? r[index] : null).toList();
  }

  /// Get column descriptor by name.
  CsvColumn getColumn(String name) {
    final idx = _headers.indexOf(name);
    if (idx < 0) throw CsvException('Column "$name" not found');
    return getColumnAt(idx);
  }

  /// Get column descriptor by index.
  CsvColumn getColumnAt(int index) {
    return CsvColumn(
      name: index < _headers.length ? _headers[index] : 'col_$index',
      index: index,
      values: columnAt(index),
    );
  }

  // --- Cell Access ---

  /// Get cell value at (row, col).
  dynamic cell(int row, int col) => _data[row][col];

  /// Get cell value by row index and column name.
  dynamic cellByName(int row, String columnName) {
    final idx = _headers.indexOf(columnName);
    if (idx < 0) throw CsvException('Column "$columnName" not found');
    return _data[row][idx];
  }

  /// Set cell value.
  void setCell(int row, int col, dynamic value) => _data[row][col] = value;

  /// Set cell by row index and column name.
  void setCellByName(int row, String columnName, dynamic value) {
    final idx = _headers.indexOf(columnName);
    if (idx < 0) throw CsvException('Column "$columnName" not found');
    _data[row][idx] = value;
  }

  // --- Row Manipulation ---

  /// Add a row at the end.
  void addRow(List<dynamic> row) => _data.add(List<dynamic>.from(row));

  /// Add a row from a map (requires headers).
  void addRowFromMap(Map<String, dynamic> map) {
    final row = _headers.map((h) => map[h]).toList();
    _data.add(row);
  }

  /// Insert a row at index.
  void insertRow(int index, List<dynamic> row) {
    _data.insert(index, List<dynamic>.from(row));
  }

  /// Remove row at index. Returns removed row.
  CsvRow removeRow(int index) {
    final removed = _data.removeAt(index);
    return CsvRow(removed, _buildHeaderMap());
  }

  /// Remove rows matching predicate. Returns count removed.
  int removeWhere(bool Function(CsvRow row) test) {
    final headerMap = _buildHeaderMap();
    var removed = 0;
    _data.removeWhere((r) {
      if (test(CsvRow(r, headerMap))) {
        removed++;
        return true;
      }
      return false;
    });
    return removed;
  }

  /// Add multiple rows.
  void addRows(List<List<dynamic>> rows) {
    for (final row in rows) {
      _data.add(List<dynamic>.from(row));
    }
  }

  // --- Column Manipulation ---

  /// Add a new column with optional default value.
  void addColumn(String name, {dynamic defaultValue}) {
    _headers.add(name);
    for (final row in _data) {
      row.add(defaultValue);
    }
  }

  /// Insert column at index.
  void insertColumn(int index, String name, {dynamic defaultValue}) {
    _headers.insert(index, name);
    for (final row in _data) {
      row.insert(index, defaultValue);
    }
  }

  /// Remove column by name. Returns removed values.
  List<dynamic> removeColumn(String name) {
    final idx = _headers.indexOf(name);
    if (idx < 0) throw CsvException('Column "$name" not found');
    return removeColumnAt(idx);
  }

  /// Remove column by index. Returns removed values.
  List<dynamic> removeColumnAt(int index) {
    if (index < _headers.length) _headers.removeAt(index);
    final values = <dynamic>[];
    for (final row in _data) {
      if (index < row.length) {
        values.add(row.removeAt(index));
      } else {
        values.add(null);
      }
    }
    return values;
  }

  /// Rename a column.
  void renameColumn(String oldName, String newName) {
    final idx = _headers.indexOf(oldName);
    if (idx < 0) throw CsvException('Column "$oldName" not found');
    _headers[idx] = newName;
  }

  /// Reorder columns to match the given header order.
  void reorderColumns(List<String> newOrder) {
    final indices = newOrder.map((n) {
      final idx = _headers.indexOf(n);
      if (idx < 0) throw CsvException('Column "$n" not found');
      return idx;
    }).toList();

    _headers = newOrder.toList();
    for (var r = 0; r < _data.length; r++) {
      final oldRow = _data[r];
      _data[r] = indices.map((i) => i < oldRow.length ? oldRow[i] : null).toList();
    }
  }

  // --- Querying & Filtering ---

  /// Filter rows matching predicate. Returns new [CsvTable].
  CsvTable where(bool Function(CsvRow row) test) {
    final headerMap = _buildHeaderMap();
    final filtered =
        _data.where((r) => test(CsvRow(r, headerMap))).toList();
    return CsvTable._internal(
      List<String>.from(_headers),
      filtered.map((r) => List<dynamic>.from(r)).toList(),
    );
  }

  /// Find first row matching predicate (or null).
  CsvRow? firstWhere(bool Function(CsvRow row) test) {
    final headerMap = _buildHeaderMap();
    for (final r in _data) {
      final row = CsvRow(r, headerMap);
      if (test(row)) return row;
    }
    return null;
  }

  /// Check if any row matches predicate.
  bool any(bool Function(CsvRow row) test) {
    final headerMap = _buildHeaderMap();
    return _data.any((r) => test(CsvRow(r, headerMap)));
  }

  /// Check if all rows match predicate.
  bool every(bool Function(CsvRow row) test) {
    final headerMap = _buildHeaderMap();
    return _data.every((r) => test(CsvRow(r, headerMap)));
  }

  /// Get rows in index range. Returns new [CsvTable].
  CsvTable range(int start, [int? end]) {
    final slice = _data.sublist(start, end);
    return CsvTable._internal(
      List<String>.from(_headers),
      slice.map((r) => List<dynamic>.from(r)).toList(),
    );
  }

  /// Get first N rows.
  CsvTable take(int count) => range(0, count.clamp(0, _data.length));

  /// Skip first N rows.
  CsvTable skip(int count) => range(count.clamp(0, _data.length));

  /// Get distinct rows based on all fields or specific columns.
  CsvTable distinct({List<String>? columns}) {
    final seen = <String>{};
    final result = <List<dynamic>>[];

    List<int>? colIndices;
    if (columns != null) {
      colIndices = columns.map((c) {
        final idx = _headers.indexOf(c);
        if (idx < 0) throw CsvException('Column "$c" not found');
        return idx;
      }).toList();
    }

    for (final row in _data) {
      final key = colIndices != null
          ? colIndices.map((i) => i < row.length ? row[i] : null).join('\x00')
          : row.join('\x00');
      if (seen.add(key)) {
        result.add(List<dynamic>.from(row));
      }
    }

    return CsvTable._internal(List<String>.from(_headers), result);
  }

  // --- Sorting ---

  /// Sort by column name.
  void sortBy(String column, {bool ascending = true}) {
    final idx = _headers.indexOf(column);
    if (idx < 0) throw CsvException('Column "$column" not found');
    sortByIndex(idx, ascending: ascending);
  }

  /// Sort by column index.
  void sortByIndex(int column, {bool ascending = true}) {
    _data.sort((a, b) {
      final va = column < a.length ? a[column] : null;
      final vb = column < b.length ? b[column] : null;
      return _compareValues(va, vb, ascending);
    });
  }

  /// Sort by multiple columns.
  void sortByMultiple(List<(String column, bool ascending)> criteria) {
    final indices = criteria.map((c) {
      final idx = _headers.indexOf(c.$1);
      if (idx < 0) throw CsvException('Column "${c.$1}" not found');
      return (idx, c.$2);
    }).toList();

    _data.sort((a, b) {
      for (final (col, asc) in indices) {
        final va = col < a.length ? a[col] : null;
        final vb = col < b.length ? b[col] : null;
        final cmp = _compareValues(va, vb, asc);
        if (cmp != 0) return cmp;
      }
      return 0;
    });
  }

  /// Sort with custom comparator.
  void sort(int Function(CsvRow a, CsvRow b) compare) {
    final headerMap = _buildHeaderMap();
    _data.sort((a, b) => compare(CsvRow(a, headerMap), CsvRow(b, headerMap)));
  }

  // --- Transformation ---

  /// Apply a transform to every cell in a column.
  void transformColumn(
      String name, dynamic Function(dynamic value) transform) {
    final idx = _headers.indexOf(name);
    if (idx < 0) throw CsvException('Column "$name" not found');
    for (final row in _data) {
      if (idx < row.length) row[idx] = transform(row[idx]);
    }
  }

  /// Apply a transform to every row. Returns new [CsvTable].
  CsvTable map(CsvRow Function(CsvRow row) transform) {
    final headerMap = _buildHeaderMap();
    final mapped = _data.map((r) {
      final result = transform(CsvRow(r, headerMap));
      return List<dynamic>.from(result);
    }).toList();
    return CsvTable._internal(List<String>.from(_headers), mapped);
  }

  /// Reduce rows to a single value.
  T fold<T>(T initial, T Function(T accumulator, CsvRow row) combine) {
    final headerMap = _buildHeaderMap();
    var result = initial;
    for (final r in _data) {
      result = combine(result, CsvRow(r, headerMap));
    }
    return result;
  }

  // --- Aggregation ---

  /// Count of non-null values in a column.
  int count(String column) {
    return this.column(column).where((v) => v != null).length;
  }

  /// Sum of numeric values in a column.
  num sum(String column) {
    num total = 0;
    for (final v in this.column(column)) {
      if (v is num) total += v;
    }
    return total;
  }

  /// Average of numeric values in a column.
  double avg(String column) {
    num total = 0;
    var count = 0;
    for (final v in this.column(column)) {
      if (v is num) {
        total += v;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  /// Minimum value in a column.
  dynamic min(String column) {
    dynamic result;
    for (final v in this.column(column)) {
      if (v == null) continue;
      if (result == null || _compareValues(v, result, true) < 0) {
        result = v;
      }
    }
    return result;
  }

  /// Maximum value in a column.
  dynamic max(String column) {
    dynamic result;
    for (final v in this.column(column)) {
      if (v == null) continue;
      if (result == null || _compareValues(v, result, true) > 0) {
        result = v;
      }
    }
    return result;
  }

  /// Group rows by a column's value. Returns `Map<value, CsvTable>`.
  Map<dynamic, CsvTable> groupBy(String column) {
    final idx = _headers.indexOf(column);
    if (idx < 0) throw CsvException('Column "$column" not found');

    final groups = <dynamic, List<List<dynamic>>>{};
    for (final row in _data) {
      final key = idx < row.length ? row[idx] : null;
      (groups[key] ??= []).add(List<dynamic>.from(row));
    }

    return groups.map((key, rows) =>
        MapEntry(key, CsvTable._internal(List<String>.from(_headers), rows)));
  }

  // --- Conversion ---

  /// Convert to list of rows, optionally including header row.
  List<List<dynamic>> toList({bool includeHeaders = false}) {
    final result = <List<dynamic>>[];
    if (includeHeaders && _headers.isNotEmpty) {
      result.add(List<dynamic>.from(_headers));
    }
    for (final r in _data) {
      result.add(List<dynamic>.from(r));
    }
    return result;
  }

  /// Convert to list of maps.
  List<Map<String, dynamic>> toMaps() {
    return _data.map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < _headers.length; i++) {
        map[_headers[i]] = i < row.length ? row[i] : null;
      }
      return map;
    }).toList();
  }

  /// Encode to CSV string.
  String toCsv({CsvConfig config = const CsvConfig()}) {
    return CsvCodec(config).encode(toList(includeHeaders: hasHeaders));
  }

  // --- Schema Validation ---

  /// Validate all rows against a schema. Returns list of violations.
  List<CsvValidationException> validate(CsvSchema schema) {
    return schema.validate(_headers, _data);
  }

  /// Check if table conforms to schema.
  bool conformsTo(CsvSchema schema) => validate(schema).isEmpty;

  // --- Copying ---

  /// Deep copy of the table.
  CsvTable copy() {
    return CsvTable._internal(
      List<String>.from(_headers),
      _data.map((r) => List<dynamic>.from(r)).toList(),
    );
  }

  // --- Printing ---

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('CsvTable($rowCount rows, $columnCount cols)');
    if (hasHeaders) buf.writeln('Headers: $_headers');
    final preview = _data.length > 5 ? _data.sublist(0, 5) : _data;
    for (final row in preview) {
      buf.writeln(row);
    }
    if (_data.length > 5) buf.writeln('... (${_data.length - 5} more rows)');
    return buf.toString();
  }

  /// Pretty-print as aligned table.
  String toFormattedString({int maxRows = 20, int maxColumnWidth = 30}) {
    final allRows = <List<String>>[];
    if (hasHeaders) allRows.add(_headers);
    final previewData = _data.length > maxRows ? _data.sublist(0, maxRows) : _data;
    for (final row in previewData) {
      allRows.add(row.map((c) {
        final s = c?.toString() ?? 'null';
        return s.length > maxColumnWidth
            ? '${s.substring(0, maxColumnWidth - 3)}...'
            : s;
      }).toList());
    }

    if (allRows.isEmpty) return '(empty table)';

    final colCount = allRows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final widths = List.filled(colCount, 0);
    for (final row in allRows) {
      for (var i = 0; i < row.length; i++) {
        if (row[i].length > widths[i]) widths[i] = row[i].length;
      }
    }

    final buf = StringBuffer();
    for (var r = 0; r < allRows.length; r++) {
      final row = allRows[r];
      for (var c = 0; c < colCount; c++) {
        final val = c < row.length ? row[c] : '';
        buf.write(val.padRight(widths[c]));
        if (c < colCount - 1) buf.write(' | ');
      }
      buf.writeln();
      if (r == 0 && hasHeaders) {
        for (var c = 0; c < colCount; c++) {
          buf.write('-' * widths[c]);
          if (c < colCount - 1) buf.write('-+-');
        }
        buf.writeln();
      }
    }

    if (_data.length > maxRows) {
      buf.writeln('... (${_data.length - maxRows} more rows)');
    }
    return buf.toString();
  }

  // --- Private helpers ---

  Map<String, int>? _buildHeaderMap() {
    if (_headers.isEmpty) return null;
    return {for (var i = 0; i < _headers.length; i++) _headers[i]: i};
  }

  static int _compareValues(dynamic a, dynamic b, bool ascending) {
    final multiplier = ascending ? 1 : -1;
    if (a == null && b == null) return 0;
    if (a == null) return 1 * multiplier;
    if (b == null) return -1 * multiplier;
    if (a is num && b is num) return a.compareTo(b) * multiplier;
    if (a is String && b is String) return a.compareTo(b) * multiplier;
    if (a is bool && b is bool) {
      return (a == b ? 0 : (a ? 1 : -1)) * multiplier;
    }
    return a.toString().compareTo(b.toString()) * multiplier;
  }
}
