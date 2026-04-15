import 'dart:async';

import '../core/csv_config.dart';
import '../core/quote_mode.dart';

/// Streaming CSV encoder that transforms rows to CSV string chunks.
class CsvEncoder extends StreamTransformerBase<List<dynamic>, String> {
  final CsvConfig config;

  const CsvEncoder([this.config = const CsvConfig()]);

  /// Batch: encode all rows to a single CSV string.
  String convert(List<List<dynamic>> rows) {
    if (rows.isEmpty) return config.addBom ? '\uFEFF' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;
    final mode = config.quoteMode;
    final transform = config.encoderTransform;

    for (var r = 0; r < rows.length; r++) {
      if (r > 0) buf.write(lineDelim);
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        if (c > 0) buf.write(delim);
        var cell = row[c];
        if (transform != null) cell = transform(cell, c, null);
        _writeCell(buf, cell, delim, quote, escape, mode);
      }
    }

    return buf.toString();
  }

  @override
  Stream<String> bind(Stream<List<dynamic>> stream) {
    final controller = StreamController<String>();
    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;
    final mode = config.quoteMode;
    final transform = config.encoderTransform;
    var first = true;

    stream.listen(
      (row) {
        final buf = StringBuffer();
        if (first && config.addBom) {
          buf.writeCharCode(0xFEFF);
          first = false;
        } else if (!first) {
          buf.write(lineDelim);
        } else {
          first = false;
        }

        for (var c = 0; c < row.length; c++) {
          if (c > 0) buf.write(delim);
          var cell = row[c];
          if (transform != null) cell = transform(cell, c, null);
          _writeCell(buf, cell, delim, quote, escape, mode);
        }

        controller.add(buf.toString());
      },
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: true,
    );

    return controller.stream;
  }

  /// Chunked conversion sink for `dart:convert` pipeline compatibility.
  Sink<List<dynamic>> startChunkedConversion(Sink<String> sink) {
    return _CsvEncoderSink(config, sink);
  }

  /// Encode a single field to a properly quoted string.
  static String encodeField(
    dynamic field, {
    required String fieldDelimiter,
    required String quoteCharacter,
    required String escapeCharacter,
    required QuoteMode quoteMode,
  }) {
    final buf = StringBuffer();
    _writeCell(buf, field, fieldDelimiter, quoteCharacter, escapeCharacter,
        quoteMode);
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
    if (cell == null) return;

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
    if (value.isEmpty) return true;
    if (value.contains(delim)) return true;
    if (value.contains('\n')) return true;
    if (value.contains('\r')) return true;
    if (value.contains(quote)) return true;
    if (value.startsWith(' ') || value.endsWith(' ')) return true;
    return false;
  }
}

/// Chunked conversion sink for [CsvEncoder].
class _CsvEncoderSink implements Sink<List<dynamic>> {
  final CsvConfig _config;
  final Sink<String> _output;
  var _first = true;

  _CsvEncoderSink(this._config, this._output);

  @override
  void add(List<dynamic> row) {
    final buf = StringBuffer();
    if (_first && _config.addBom) {
      buf.writeCharCode(0xFEFF);
      _first = false;
    } else if (!_first) {
      buf.write(_config.lineDelimiter);
    } else {
      _first = false;
    }

    for (var c = 0; c < row.length; c++) {
      if (c > 0) buf.write(_config.fieldDelimiter);
      var cell = row[c];
      if (_config.encoderTransform != null) {
        cell = _config.encoderTransform!(cell, c, null);
      }
      CsvEncoder._writeCell(buf, cell, _config.fieldDelimiter,
          _config.quoteCharacter, _config.escapeCharacter, _config.quoteMode);
    }

    _output.add(buf.toString());
  }

  @override
  void close() {
    _output.close();
  }
}
