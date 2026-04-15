import '../core/csv_config.dart';
import '../core/quote_mode.dart';

/// High-performance batch CSV encoder using per-call [StringBuffer].
///
/// Thread-safe: no global mutable state.
class FastEncoder {
  /// Create a batch encoder instance (stateless, reusable).
  const FastEncoder();

  /// Encode rows to CSV string with type-aware quoting.
  String encode(List<List<dynamic>> data, CsvConfig config) {
    if (data.isEmpty) return config.addBom ? '\uFEFF' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;
    final mode = config.quoteMode;
    final transform = config.encoderTransform;

    for (var r = 0; r < data.length; r++) {
      final row = data[r];
      for (var c = 0; c < row.length; c++) {
        if (c > 0) buf.write(delim);
        var cell = row[c];
        if (transform != null) cell = transform(cell, c, null);
        _writeCell(buf, cell, delim, quote, escape, mode);
      }
      if (r < data.length - 1) buf.write(lineDelim);
    }

    return buf.toString();
  }

  /// Encode all-string data (skip type checks, always quote).
  String encodeStrings(List<List<String>> data, CsvConfig config) {
    if (data.isEmpty) return config.addBom ? '\uFEFF' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;

    for (var r = 0; r < data.length; r++) {
      final row = data[r];
      for (var c = 0; c < row.length; c++) {
        if (c > 0) buf.write(delim);
        buf.write(quote);
        buf.write(row[c].replaceAll(quote, '$escape$quote'));
        buf.write(quote);
      }
      if (r < data.length - 1) buf.write(lineDelim);
    }

    return buf.toString();
  }

  /// Encode numeric/bool data (no quoting needed).
  String encodeGeneric<T>(List<List<T>> data, CsvConfig config) {
    if (data.isEmpty) return config.addBom ? '\uFEFF' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;

    for (var r = 0; r < data.length; r++) {
      final row = data[r];
      for (var c = 0; c < row.length; c++) {
        if (c > 0) buf.write(delim);
        buf.write(row[c].toString());
      }
      if (r < data.length - 1) buf.write(lineDelim);
    }

    return buf.toString();
  }

  /// Encode a Map as two-column CSV (key, value).
  String encodeMap(Map<String, dynamic> map, CsvConfig config) {
    if (map.isEmpty) return config.addBom ? '\uFEFF' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;
    final mode = config.quoteMode;

    var first = true;
    for (final entry in map.entries) {
      if (!first) buf.write(lineDelim);
      first = false;

      // Key is always a string
      buf.write(quote);
      buf.write(entry.key.replaceAll(quote, '$escape$quote'));
      buf.write(quote);

      buf.write(delim);
      _writeCell(buf, entry.value, delim, quote, escape, mode);
    }

    return buf.toString();
  }

  static void _writeCell(
    StringBuffer buf,
    dynamic cell,
    String delim,
    String quote,
    String escape,
    QuoteMode mode,
  ) {
    if (cell == null) {
      // Null → empty unquoted field
      return;
    }

    final str = cell.toString();

    switch (mode) {
      case QuoteMode.always:
        buf.write(quote);
        buf.write(str.replaceAll(quote, '$escape$quote'));
        buf.write(quote);
      case QuoteMode.strings:
        if (cell is String) {
          buf.write(quote);
          buf.write(str.replaceAll(quote, '$escape$quote'));
          buf.write(quote);
        } else {
          buf.write(str);
        }
      case QuoteMode.necessary:
        if (_needsQuoting(str, delim, quote)) {
          buf.write(quote);
          buf.write(str.replaceAll(quote, '$escape$quote'));
          buf.write(quote);
        } else {
          buf.write(str);
        }
    }
  }

  static bool _needsQuoting(String value, String delim, String quote) {
    if (value.isEmpty) return true; // distinguish empty string from null
    if (value.contains(delim)) return true;
    if (value.contains('\n')) return true;
    if (value.contains('\r')) return true;
    if (value.contains(quote)) return true;
    if (value.startsWith(' ') || value.endsWith(' ')) return true;
    return false;
  }
}
