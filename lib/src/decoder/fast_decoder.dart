import '../core/csv_config.dart';

// ASCII constants for hot-loop byte comparison
const _lf = 10; // \n
const _cr = 13; // \r
const _dot = 46; // .
const _minus = 45; // -
const _zero = 48; // 0
const _nine = 57; // 9
const _lowerE = 101; // e
const _upperE = 69; // E
const _lowerF = 102; // f
const _lowerT = 116; // t
const _plus = 43; // +
const _bom = 0xFEFF;

const _trueLength = 4;
const _falseLength = 5;

/// High-performance batch CSV decoder using byte-level (`codeUnits`) parsing.
///
/// Techniques:
/// - Direct codeUnit array indexing (no string ops in hot loop)
/// - Labeled loop control flow (`outerLoop`, `cell_loop`)
/// - Type inference by first-byte detection
/// - No `tryParse()` — detects int vs double by scanning for `.`
class FastDecoder {
  /// Create a batch decoder instance (stateless, reusable).
  const FastDecoder();

  /// Decode CSV string with automatic type inference.
  ///
  /// Type detection by first byte:
  /// - `"` → quoted string
  /// - `t`/`f` → boolean
  /// - digit/`-` → int or double
  /// - delimiter/newline → null
  List<List<dynamic>> decode(String input, CsvConfig config) {
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
    final transform = config.decoderTransform;
    final hasHeader = config.hasHeader;

    final rows = <List<dynamic>>[];
    List<String>? headers;
    var cursor = 0;

    // Strip BOM
    if (len > 0 && bytes[0] == _bom) cursor = 1;

    outerLoop:
    while (cursor < len) {
      // Check for empty line
      if (bytes[cursor] == _cr || bytes[cursor] == _lf) {
        final ch = bytes[cursor];
        cursor++;
        if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
        if (!skipEmpty) rows.add(<dynamic>[]);
        continue outerLoop;
      }

      final currentRow = <dynamic>[];

      // Read cells in this row
      while (true) {
        // --- Read one cell ---
        if (cursor >= len) {
          // Trailing delimiter at end of input → empty field
          currentRow.add(dynamicTyping ? null : '');
          break;
        }

        final ch = bytes[cursor];

        if (ch == _cr || ch == _lf) {
          // Trailing delimiter before newline → empty field
          currentRow.add(dynamicTyping ? null : '');
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }

        if (ch == quoteCode) {
          // --- Quoted string ---
          cursor++;
          final buf = StringBuffer();
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == escapeCode &&
                cursor + 1 < len &&
                bytes[cursor + 1] == quoteCode) {
              buf.writeCharCode(quoteCode);
              cursor += 2;
            } else if (c == quoteCode) {
              cursor++;
              break;
            } else {
              buf.writeCharCode(c);
              cursor++;
            }
          }

          dynamic value = buf.toString();
          if (transform != null) {
            final hdr =
                (headers != null && currentRow.length < headers.length)
                    ? headers[currentRow.length]
                    : null;
            value = transform(value, currentRow.length, hdr);
          }
          currentRow.add(value);
        } else if (_isDelimiterAt(
            bytes, cursor, singleCharDelim, firstDelim, delimBytes, delimLen,
            len)) {
          // --- Empty field (consecutive delimiter) ---
          dynamic value = dynamicTyping ? null : '';
          if (transform != null) {
            final hdr =
                (headers != null && currentRow.length < headers.length)
                    ? headers[currentRow.length]
                    : null;
            value = transform(value, currentRow.length, hdr);
          }
          currentRow.add(value);
          // Don't advance cursor — the separator consumer below will eat it
        } else if (dynamicTyping && (ch == _lowerT || ch == _lowerF)) {
          // --- Try boolean ---
          final isTrue = ch == _lowerT;
          final expected = isTrue ? _trueLength : _falseLength;
          var matched = false;
          if (cursor + expected <= len) {
            final word = input.substring(cursor, cursor + expected);
            if ((isTrue && word == 'true') || (!isTrue && word == 'false')) {
              final afterWord = cursor + expected;
              if (afterWord >= len ||
                  bytes[afterWord] == _cr ||
                  bytes[afterWord] == _lf ||
                  _isDelimiterAt(bytes, afterWord, singleCharDelim, firstDelim,
                      delimBytes, delimLen, len)) {
                dynamic value = isTrue;
                cursor += expected;
                if (transform != null) {
                  final hdr =
                      (headers != null && currentRow.length < headers.length)
                          ? headers[currentRow.length]
                          : null;
                  value = transform(value, currentRow.length, hdr);
                }
                currentRow.add(value);
                matched = true;
              }
            }
          }
          if (!matched) {
            // Fall through to unquoted string
            final start = cursor;
            cursor++;
            while (cursor < len) {
              final c = bytes[cursor];
              if (c == _cr || c == _lf) break;
              if (_isDelimiterAt(bytes, cursor, singleCharDelim, firstDelim,
                  delimBytes, delimLen, len)) {
                break;
              }
              cursor++;
            }
            dynamic value = input.substring(start, cursor);
            if (transform != null) {
              final hdr =
                  (headers != null && currentRow.length < headers.length)
                      ? headers[currentRow.length]
                      : null;
              value = transform(value, currentRow.length, hdr);
            }
            currentRow.add(value);
          }
        } else if (dynamicTyping &&
            (ch == _minus || (ch >= _zero && ch <= _nine))) {
          // --- Number (int or double) ---
          final start = cursor;
          var isDouble = false;
          cursor++;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == _dot || c == _lowerE || c == _upperE) {
              isDouble = true;
              cursor++;
            } else if (c == _plus || c == _minus) {
              cursor++;
            } else if (c >= _zero && c <= _nine) {
              cursor++;
            } else {
              break;
            }
          }

          final numStr = input.substring(start, cursor);
          dynamic value;
          if (isDouble) {
            value = double.tryParse(numStr) ?? numStr;
          } else {
            value = int.tryParse(numStr) ?? numStr;
          }
          if (transform != null) {
            final hdr =
                (headers != null && currentRow.length < headers.length)
                    ? headers[currentRow.length]
                    : null;
            value = transform(value, currentRow.length, hdr);
          }
          currentRow.add(value);
        } else {
          // --- Unquoted string ---
          final start = cursor;
          cursor++;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == _cr || c == _lf) break;
            if (_isDelimiterAt(bytes, cursor, singleCharDelim, firstDelim,
                delimBytes, delimLen, len)) {
              break;
            }
            cursor++;
          }
          dynamic value = input.substring(start, cursor);
          if (dynamicTyping) {
            value = _inferType(value as String);
          }
          if (transform != null) {
            final hdr =
                (headers != null && currentRow.length < headers.length)
                    ? headers[currentRow.length]
                    : null;
            value = transform(value, currentRow.length, hdr);
          }
          currentRow.add(value);
        }

        // --- After cell: consume separator or end row ---
        if (cursor >= len) break; // end of input → end of row
        final next = bytes[cursor];
        if (next == _cr || next == _lf) {
          cursor++;
          if (next == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break; // end of row
        }
        // Consume field delimiter
        if (singleCharDelim && next == firstDelim) {
          cursor++;
        } else if (!singleCharDelim &&
            _matchDelimiter(bytes, cursor, delimBytes, delimLen, len)) {
          cursor += delimLen;
        }
        // Continue to read next cell
      }

      // Finalize row
      if (hasHeader && headers == null) {
        headers = currentRow.map((e) => e?.toString() ?? '').toList();
        continue;
      }

      rows.add(currentRow);
    }

    return rows;
  }

  /// Decode all fields as strings (no type inference overhead).
  List<List<String>> decodeStrings(String input, CsvConfig config) {
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

    final rows = <List<String>>[];
    var cursor = 0;

    if (len > 0 && bytes[0] == _bom) cursor = 1;

    while (cursor < len) {
      final currentRow = <String>[];

      cell_loop:
      while (true) {
        if (cursor >= len) break cell_loop;

        final ch = bytes[cursor];

        if (ch == _cr || ch == _lf) {
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break cell_loop;
        }

        // Skip field delimiter between cells
        if (currentRow.isNotEmpty) {
          if (singleCharDelim && ch == firstDelim) {
            cursor++;
          } else if (!singleCharDelim &&
              ch == firstDelim &&
              _matchDelimiter(bytes, cursor, delimBytes, delimLen, len)) {
            cursor += delimLen;
          }
          if (cursor >= len) break cell_loop;
        }

        // Re-read char after possible delimiter skip
        final cellStart = bytes[cursor];

        if (cellStart == quoteCode) {
          cursor++;
          final buf = StringBuffer();
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == escapeCode &&
                cursor + 1 < len &&
                bytes[cursor + 1] == quoteCode) {
              buf.writeCharCode(quoteCode);
              cursor += 2;
            } else if (c == quoteCode) {
              cursor++;
              break;
            } else {
              buf.writeCharCode(c);
              cursor++;
            }
          }
          currentRow.add(buf.toString());
        } else if (cellStart == _cr || cellStart == _lf) {
          // Empty line after delimiter skip shouldn't happen, but handle it
          cursor++;
          if (cellStart == _cr && cursor < len && bytes[cursor] == _lf) {
            cursor++;
          }
          break cell_loop;
        } else {
          // Unquoted field
          final start = cursor;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == _cr || c == _lf) break;
            if (singleCharDelim && c == firstDelim) break;
            if (!singleCharDelim &&
                c == firstDelim &&
                _matchDelimiter(bytes, cursor, delimBytes, delimLen, len)) {
              break;
            }
            cursor++;
          }
          currentRow.add(input.substring(start, cursor));
        }

        continue cell_loop;
      }

      if (skipEmpty && currentRow.every((s) => s.isEmpty)) continue;
      rows.add(currentRow);
    }

    return rows;
  }

  static bool _matchDelimiter(
    List<int> bytes,
    int pos,
    List<int> delimBytes,
    int delimLen,
    int totalLen,
  ) {
    if (pos + delimLen > totalLen) return false;
    for (var i = 1; i < delimLen; i++) {
      if (bytes[pos + i] != delimBytes[i]) return false;
    }
    return true;
  }

  static bool _isDelimiterAt(
    List<int> bytes,
    int pos,
    bool singleCharDelim,
    int firstDelim,
    List<int> delimBytes,
    int delimLen,
    int totalLen,
  ) {
    if (singleCharDelim) return bytes[pos] == firstDelim;
    return bytes[pos] == firstDelim &&
        _matchDelimiter(bytes, pos, delimBytes, delimLen, totalLen);
  }

  /// Decode with lenient parsing: unquoted strings, whitespace trimming.
  ///
  /// Like [decode] but trims leading/trailing whitespace from unquoted fields
  /// and treats all unmatched quotes as literal characters.
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
        } else if (_isDelimiterAt(bytes, cursor, singleCharDelim, firstDelim,
            delimBytes, delimLen, len)) {
          currentRow.add(dynamicTyping ? null : '');
        } else {
          // Unquoted field — read and trim whitespace
          final start = cursor;
          cursor++;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == _cr || c == _lf) break;
            if (_isDelimiterAt(bytes, cursor, singleCharDelim, firstDelim,
                delimBytes, delimLen, len)) {
              break;
            }
            cursor++;
          }
          var value = input.substring(start, cursor).trim();
          if (dynamicTyping) {
            currentRow.add(_inferType(value));
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
            _matchDelimiter(bytes, cursor, delimBytes, delimLen, len)) {
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

  static dynamic _inferType(String value) {
    if (value.isEmpty) return null;
    if (value == 'true') return true;
    if (value == 'false') return false;

    // Try int first (no dot, no e/E)
    final bytes = value.codeUnits;
    var hasDot = false;
    var hasExp = false;
    var isNumeric = true;

    for (var i = 0; i < bytes.length; i++) {
      final c = bytes[i];
      if (c >= _zero && c <= _nine) continue;
      if (c == _minus && i == 0) continue;
      if (c == _dot && !hasDot) {
        hasDot = true;
        continue;
      }
      if ((c == _lowerE || c == _upperE) && !hasExp && i > 0) {
        hasExp = true;
        continue;
      }
      if ((c == _plus || c == _minus) && hasExp) continue;
      isNumeric = false;
      break;
    }

    if (isNumeric && bytes.isNotEmpty) {
      if (hasDot || hasExp) {
        final d = double.tryParse(value);
        if (d != null) return d;
      } else {
        final n = int.tryParse(value);
        if (n != null) return n;
      }
    }

    return value;
  }
}
