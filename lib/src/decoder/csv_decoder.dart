import 'dart:async';
import 'dart:convert';

import '../core/csv_config.dart';

/// Streaming CSV decoder using a chunked state machine.
///
/// Handles chunk boundaries that split mid-field, mid-escape, or mid-CRLF.
/// Use for memory-efficient processing of large inputs.
class CsvDecoder extends StreamTransformerBase<String, List<dynamic>> {
  final CsvConfig config;

  /// Create a streaming decoder with the given [config].
  const CsvDecoder([this.config = const CsvConfig()]);

  /// Batch: decode complete CSV string to rows.
  List<List<dynamic>> convert(String input) {
    final rows = <List<dynamic>>[];
    final machine = _StateMachine(config, rows.add);
    machine.addChunk(input);
    machine.finish();
    return rows;
  }

  @override
  Stream<List<dynamic>> bind(Stream<String> stream) {
    final controller = StreamController<List<dynamic>>();
    final machine = _StateMachine(config, controller.add);

    stream.listen(
      machine.addChunk,
      onError: controller.addError,
      onDone: () {
        machine.finish();
        controller.close();
      },
      cancelOnError: true,
    );

    return controller.stream;
  }

  /// Chunked conversion sink for `dart:convert` pipeline compatibility.
  Sink<String> startChunkedConversion(Sink<List<dynamic>> sink) {
    return _CsvDecoderSink(config, sink);
  }
}

enum _State { fieldStart, unquotedField, quotedField, afterQuote }

/// Chunked CSV parsing state machine. Preserves state across chunk boundaries.
class _StateMachine {
  final CsvConfig config;
  final void Function(List<dynamic> row) _emit;

  late final int _quoteCode = config.quoteCharacter.codeUnitAt(0);
  late final int _escapeCode = config.escapeCharacter.codeUnitAt(0);
  late final List<int> _delimCodes = config.fieldDelimiter.codeUnits;
  late final bool _singleDelim = _delimCodes.length == 1;
  late final bool _dynamicTyping = config.dynamicTyping;
  late final bool _skipEmpty = config.skipEmptyLines;
  late final bool _hasHeader = config.hasHeader;

  _State _state = _State.fieldStart;
  final _buf = StringBuffer();
  var _currentRow = <dynamic>[];
  var _isQuoted = false;
  var _pendingCr = false;
  var _pendingEscape = false;
  var _bomChecked = false;
  List<String>? _headers;

  _StateMachine(this.config, this._emit);

  void addChunk(String chunk) {
    final codes = chunk.codeUnits;
    final len = codes.length;
    var i = 0;

    if (!_bomChecked) {
      _bomChecked = true;
      if (len > 0 && codes[0] == 0xFEFF) i = 1;
    }

    while (i < len) {
      final ch = codes[i];
      switch (_state) {
        case _State.fieldStart:
          _isQuoted = false;
          if (_pendingCr) {
            _pendingCr = false;
            if (ch == 10) {
              i++;
              continue;
            }
          }
          if (ch == _quoteCode) {
            _isQuoted = true;
            _state = _State.quotedField;
            i++;
          } else if (ch == 13) {
            if (_currentRow.isNotEmpty) _emitField();
            _emitRow();
            _pendingCr = true;
            i++;
          } else if (ch == 10) {
            if (_currentRow.isNotEmpty) _emitField();
            _emitRow();
            i++;
          } else if (_isFieldDelimAt(codes, i, len)) {
            _emitField();
            i += _delimCodes.length;
          } else {
            _buf.writeCharCode(ch);
            _state = _State.unquotedField;
            i++;
          }

        case _State.unquotedField:
          if (_pendingCr) {
            _pendingCr = false;
            if (ch == 10) {
              i++;
              continue;
            }
          }
          if (ch == 13) {
            _emitField();
            _emitRow();
            _pendingCr = true;
            _state = _State.fieldStart;
            i++;
          } else if (ch == 10) {
            _emitField();
            _emitRow();
            _state = _State.fieldStart;
            i++;
          } else if (_isFieldDelimAt(codes, i, len)) {
            _emitField();
            _state = _State.fieldStart;
            i += _delimCodes.length;
          } else {
            _buf.writeCharCode(ch);
            i++;
          }

        case _State.quotedField:
          if (_pendingEscape) {
            _pendingEscape = false;
            if (ch == _quoteCode) {
              _buf.writeCharCode(_quoteCode);
              i++;
            } else {
              _buf.writeCharCode(_escapeCode);
              // Don't advance — reprocess current char
            }
          } else if (ch == _escapeCode &&
              _escapeCode != _quoteCode &&
              i + 1 >= len) {
            // Escape at chunk boundary (only when escape != quote)
            _pendingEscape = true;
            i++;
          } else if (ch == _escapeCode &&
              i + 1 < len &&
              codes[i + 1] == _quoteCode) {
            _buf.writeCharCode(_quoteCode);
            i += 2;
          } else if (ch == _quoteCode) {
            _state = _State.afterQuote;
            i++;
          } else {
            _buf.writeCharCode(ch);
            i++;
          }

        case _State.afterQuote:
          if (ch == 13) {
            _emitField();
            _emitRow();
            _pendingCr = true;
            _state = _State.fieldStart;
            i++;
          } else if (ch == 10) {
            _emitField();
            _emitRow();
            _state = _State.fieldStart;
            i++;
          } else if (_isFieldDelimAt(codes, i, len)) {
            _emitField();
            _state = _State.fieldStart;
            i += _delimCodes.length;
          } else {
            _buf.writeCharCode(ch);
            _state = _State.quotedField;
            i++;
          }
      }
    }
  }

  void finish() {
    if (_pendingEscape) {
      _pendingEscape = false;
      _buf.writeCharCode(_escapeCode);
    }
    if (_buf.isNotEmpty ||
        _currentRow.isNotEmpty ||
        _state != _State.fieldStart) {
      _emitField();
      _emitRow();
    }
  }

  bool _isFieldDelimAt(List<int> codes, int pos, int len) {
    if (_singleDelim) return codes[pos] == _delimCodes[0];
    if (pos + _delimCodes.length > len) return false;
    for (var j = 0; j < _delimCodes.length; j++) {
      if (codes[pos + j] != _delimCodes[j]) return false;
    }
    return true;
  }

  void _emitField() {
    final raw = _buf.toString();
    _buf.clear();

    dynamic value;
    if (_isQuoted) {
      value = raw;
    } else if (_dynamicTyping) {
      value = _inferType(raw);
    } else {
      value = raw.isEmpty ? '' : raw;
    }

    final transform = config.decoderTransform;
    if (transform != null) {
      final hdr = (_headers != null && _currentRow.length < _headers!.length)
          ? _headers![_currentRow.length]
          : null;
      value = transform(value, _currentRow.length, hdr);
    }

    _currentRow.add(value);
    _isQuoted = false;
  }

  void _emitRow() {
    final row = _currentRow;
    _currentRow = <dynamic>[];

    if (_skipEmpty && row.isEmpty) {
      return;
    }

    if (_hasHeader && _headers == null) {
      _headers = row.map((e) => e?.toString() ?? '').toList();
      return;
    }

    _emit(row);
  }

  static dynamic _inferType(String raw) {
    if (raw.isEmpty) return null;
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    final asInt = int.tryParse(raw);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(raw);
    if (asDouble != null) return asDouble;
    return raw;
  }
}

/// Chunked conversion sink for [CsvDecoder].
class _CsvDecoderSink extends StringConversionSinkBase {
  final _StateMachine _machine;
  final Sink<List<dynamic>> _output;

  _CsvDecoderSink(CsvConfig config, this._output)
      : _machine = _StateMachine(config, _output.add);

  @override
  void addSlice(String str, int start, int end, bool isLast) {
    _machine.addChunk(str.substring(start, end));
    if (isLast) close();
  }

  @override
  void close() {
    _machine.finish();
    _output.close();
  }
}

