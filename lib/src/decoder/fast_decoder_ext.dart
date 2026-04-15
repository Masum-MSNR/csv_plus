import '../core/csv_config.dart';
import 'fast_decoder.dart';

// ASCII constants for byte-level comparison
const _lf = 10;
const _cr = 13;
const _bom = 0xFEFF;

/// Flexible and typed decode operations for [FastDecoder].
extension FastDecoderFlexible on FastDecoder {
  /// Decode with lenient parsing: unquoted strings, whitespace trimming.
  ///
  /// Like [FastDecoder.decode] but trims leading/trailing whitespace from
  /// unquoted fields and treats all unmatched quotes as literal characters.
  List<List<dynamic>> decodeFlexible(String input, CsvConfig config) {
    if (input.isEmpty) return [];

    final bytes = input.codeUnits;
    final len = bytes.length;
    final delimBytes = config.fieldDelimiter.codeUnits;
    final delimLen = delimBytes.length;
    final firstDelim = delimBytes[0];
    final singleCharDelim = delimLen == 1;
    final quoteCode = config.quoteCharacter.codeUnitAt(0);
    final escapeCode = config.escapeCharacter.codeUnitAt(0);
    final skipEmpty = config.skipEmptyLines;
    final dynamicTyping = config.dynamicTyping;

    final rows = <List<dynamic>>[];
    var cursor = 0;

    if (len > 0 && bytes[0] == _bom) cursor = 1;

    while (cursor < len) {
      if (bytes[cursor] == _cr || bytes[cursor] == _lf) {
        final ch = bytes[cursor];
        cursor++;
        if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
        if (!skipEmpty) rows.add(<dynamic>[]);
        continue;
      }

      final currentRow = <dynamic>[];

      while (true) {
        if (cursor >= len) {
          currentRow.add(dynamicTyping ? null : '');
          break;
        }

        final ch = bytes[cursor];

        if (ch == _cr || ch == _lf) {
          currentRow.add(dynamicTyping ? null : '');
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }

        if (ch == quoteCode) {
          // Quoted field — try to parse normally
          cursor++;
          final buf = StringBuffer();
          var closed = false;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == escapeCode &&
                cursor + 1 < len &&
                bytes[cursor + 1] == quoteCode) {
              buf.writeCharCode(quoteCode);
              cursor += 2;
            } else if (c == quoteCode) {
              cursor++;
              closed = true;
              break;
            } else {
              buf.writeCharCode(c);
              cursor++;
            }
          }
          if (!closed) {
            // Unmatched quote — treat as literal
            currentRow.add('"${buf.toString()}');
          } else {
            currentRow.add(buf.toString());
          }
        } else if (FastDecoder.isDelimiterAt(bytes, cursor, singleCharDelim,
            firstDelim, delimBytes, delimLen, len)) {
          currentRow.add(dynamicTyping ? null : '');
        } else {
          // Unquoted field — read and trim whitespace
          final start = cursor;
          cursor++;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == _cr || c == _lf) break;
            if (FastDecoder.isDelimiterAt(bytes, cursor, singleCharDelim,
                firstDelim, delimBytes, delimLen, len)) {
              break;
            }
            cursor++;
          }
          var value = input.substring(start, cursor).trim();
          if (dynamicTyping) {
            currentRow.add(FastDecoder.inferType(value));
          } else {
            currentRow.add(value.isEmpty ? null : value);
          }
        }

        // Consume separator
        if (cursor >= len) break;
        final next = bytes[cursor];
        if (next == _cr || next == _lf) {
          cursor++;
          if (next == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }
        if (singleCharDelim && next == firstDelim) {
          cursor++;
        } else if (!singleCharDelim &&
            FastDecoder.matchDelimiter(
                bytes, cursor, delimBytes, delimLen, len)) {
          cursor += delimLen;
        }
      }

      rows.add(currentRow);
    }

    return rows;
  }

  /// Decode all fields as integers.
  List<List<int>> decodeIntegers(String input, CsvConfig config) {
    final stringRows = decodeStrings(input, config);
    return stringRows.map((row) {
      return row.map((s) => s.isEmpty ? 0 : int.parse(s)).toList();
    }).toList();
  }

  /// Decode all fields as doubles.
  List<List<double>> decodeDoubles(String input, CsvConfig config) {
    final stringRows = decodeStrings(input, config);
    return stringRows.map((row) {
      return row.map((s) => s.isEmpty ? 0.0 : double.parse(s)).toList();
    }).toList();
  }

  /// Decode all fields as booleans.
  List<List<bool>> decodeBooleans(String input, CsvConfig config) {
    final stringRows = decodeStrings(input, config);
    return stringRows.map((row) {
      return row.map((s) => s.toLowerCase() == 'true').toList();
    }).toList();
  }
}
