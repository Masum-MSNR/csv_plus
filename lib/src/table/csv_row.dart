import 'dart:collection';

/// A single CSV row with header-aware access.
///
/// Extends [ListBase] so it can be used anywhere [List] is expected.
/// Supports dual-mode access: by integer index or string header name.
class CsvRow extends ListBase<dynamic> {
  final List<dynamic> _fields;
  final Map<String, int>? _headerMap;

  CsvRow(List<dynamic> fields, [this._headerMap]) : _fields = fields;

  @override
  int get length => _fields.length;

  @override
  set length(int newLength) => _fields.length = newLength;

  /// Access by integer index or string header name.
  ///
  /// ```dart
  /// row[0]       // by index
  /// row['name']  // by header
  /// ```
  @override
  dynamic operator [](Object? key) {
    if (key is int) return _fields[key];
    if (key is String) {
      final idx = _headerMap?[key];
      if (idx != null && idx < _fields.length) return _fields[idx];
      return null;
    }
    return null;
  }

  @override
  void operator []=(int index, dynamic value) => _fields[index] = value;

  /// Set a field by header name.
  void set(String header, dynamic value) {
    final idx = _headerMap?[header];
    if (idx != null && idx < _fields.length) _fields[idx] = value;
  }

  /// The header-to-index mapping. Null if no headers.
  Map<String, int>? get headerMap => _headerMap;

  /// Whether this row has header information.
  bool get hasHeaders => _headerMap != null && _headerMap.isNotEmpty;

  /// Convert to `Map<String, dynamic>`. Requires headers.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (_headerMap == null) return map;
    for (final entry in _headerMap.entries) {
      if (entry.value < _fields.length) {
        map[entry.key] = _fields[entry.value];
      }
    }
    return map;
  }

  /// Get header name for a column index.
  String? getHeaderName(int index) {
    if (_headerMap == null) return null;
    for (final entry in _headerMap.entries) {
      if (entry.value == index) return entry.key;
    }
    return null;
  }
}
