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

// 'true' / 'false' byte sequences
const _lowerR = 114;
const _lowerU = 117;
const _lowerA = 97;
const _lowerL = 108;
const _lowerS = 115;

/// High-performance batch CSV decoder using byte-level (`codeUnits`) parsing.
///
/// Techniques:
/// - Direct codeUnit array indexing (no string ops in hot loop)
/// - Labeled loop control flow (`outerLoop`, `cell_loop`)
/// - Type inference by first-byte detection
/// - substring + replaceRange for quoted fields (avoids StringBuffer)
/// - Row pre-sizing after first row for fewer allocations
class FastDecoder {
  /// Create a batch decoder instance (stateless, reusable).
  const FastDecoder();

  /// Decode CSV string with automatic type inference.
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
    final hasTransform = transform != null;

    final rows = <List<dynamic>>[];
    List<String>? headers;
    var cursor = 0;
    var colCount = -1;

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

      final currentRow =
          colCount > 0 ? List<dynamic>.generate(colCount, (_) => null, growable: true) : <dynamic>[];
      var cellIdx = 0;

      // Read cells in this row
      while (true) {
        if (cursor >= len) {
          _addCell(currentRow, cellIdx, colCount, dynamicTyping ? null : '');
          cellIdx++;
          break;
        }

        final ch = bytes[cursor];

        if (ch == _cr || ch == _lf) {
          _addCell(currentRow, cellIdx, colCount, dynamicTyping ? null : '');
          cellIdx++;
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }

        if (ch == quoteCode) {
          // --- Quoted string: substring approach ---
          cursor++;
          final start = cursor;
          List<int>? escapePositions;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == escapeCode &&
                cursor + 1 < len &&
                bytes[cursor + 1] == quoteCode) {
              (escapePositions ??= []).add(cursor - start);
              cursor += 2;
            } else if (c == quoteCode) {
              cursor++;
              break;
            } else {
              cursor++;
            }
          }
          String value = input.substring(start, cursor - 1);
          if (escapePositions != null) {
            for (var i = escapePositions.length - 1; i >= 0; i--) {
              value = value.replaceRange(
                  escapePositions[i], escapePositions[i] + 1, '');
            }
          }
          dynamic cell = value;
          if (hasTransform) {
            final hdr =
                (headers != null && cellIdx < headers.length)
                    ? headers[cellIdx]
                    : null;
            cell = transform(cell, cellIdx, hdr);
          }
          _addCell(currentRow, cellIdx, colCount, cell);
          cellIdx++;
        } else if (singleCharDelim
            ? ch == firstDelim
            : _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
          // --- Empty field (consecutive delimiter) ---
          dynamic cell = dynamicTyping ? null : '';
          if (hasTransform) {
            final hdr =
                (headers != null && cellIdx < headers.length)
                    ? headers[cellIdx]
                    : null;
            cell = transform(cell, cellIdx, hdr);
          }
          _addCell(currentRow, cellIdx, colCount, cell);
          cellIdx++;
        } else if (dynamicTyping && (ch == _lowerT || ch == _lowerF)) {
          // --- Try boolean by individual byte check ---
          var matched = false;
          if (ch == _lowerT) {
            if (cursor + 4 <= len &&
                bytes[cursor + 1] == _lowerR &&
                bytes[cursor + 2] == _lowerU &&
                bytes[cursor + 3] == _lowerE) {
              final after = cursor + 4;
              if (after >= len ||
                  bytes[after] == _cr ||
                  bytes[after] == _lf ||
                  (singleCharDelim
                      ? bytes[after] == firstDelim
                      : _matchDelim(
                          bytes, after, delimBytes, delimLen, len))) {
                dynamic cell = true;
                cursor += 4;
                if (hasTransform) {
                  final hdr =
                      (headers != null && cellIdx < headers.length)
                          ? headers[cellIdx]
                          : null;
                  cell = transform(cell, cellIdx, hdr);
                }
                _addCell(currentRow, cellIdx, colCount, cell);
                cellIdx++;
                matched = true;
              }
            }
          } else {
            if (cursor + 5 <= len &&
                bytes[cursor + 1] == _lowerA &&
                bytes[cursor + 2] == _lowerL &&
                bytes[cursor + 3] == _lowerS &&
                bytes[cursor + 4] == _lowerE) {
              final after = cursor + 5;
              if (after >= len ||
                  bytes[after] == _cr ||
                  bytes[after] == _lf ||
                  (singleCharDelim
                      ? bytes[after] == firstDelim
                      : _matchDelim(
                          bytes, after, delimBytes, delimLen, len))) {
                dynamic cell = false;
                cursor += 5;
                if (hasTransform) {
                  final hdr =
                      (headers != null && cellIdx < headers.length)
                          ? headers[cellIdx]
                          : null;
                  cell = transform(cell, cellIdx, hdr);
                }
                _addCell(currentRow, cellIdx, colCount, cell);
                cellIdx++;
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
              if (singleCharDelim
                  ? c == firstDelim
                  : _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
                break;
              }
              cursor++;
            }
            dynamic cell = input.substring(start, cursor);
            if (hasTransform) {
              final hdr =
                  (headers != null && cellIdx < headers.length)
                      ? headers[cellIdx]
                      : null;
              cell = transform(cell, cellIdx, hdr);
            }
            _addCell(currentRow, cellIdx, colCount, cell);
            cellIdx++;
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
          dynamic cell;
          if (isDouble) {
            cell = double.tryParse(numStr) ?? numStr;
          } else {
            cell = int.tryParse(numStr) ?? numStr;
          }
          if (hasTransform) {
            final hdr =
                (headers != null && cellIdx < headers.length)
                    ? headers[cellIdx]
                    : null;
            cell = transform(cell, cellIdx, hdr);
          }
          _addCell(currentRow, cellIdx, colCount, cell);
          cellIdx++;
        } else {
          // --- Unquoted string ---
          final start = cursor;
          cursor++;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == _cr || c == _lf) break;
            if (singleCharDelim
                ? c == firstDelim
                : _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
              break;
            }
            cursor++;
          }
          dynamic cell = input.substring(start, cursor);
          if (dynamicTyping) {
            cell = inferType(cell as String);
          }
          if (hasTransform) {
            final hdr =
                (headers != null && cellIdx < headers.length)
                    ? headers[cellIdx]
                    : null;
            cell = transform(cell, cellIdx, hdr);
          }
          _addCell(currentRow, cellIdx, colCount, cell);
          cellIdx++;
        }

        // --- After cell: consume separator or end row ---
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
            _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
          cursor += delimLen;
        }
      }

      // Trim pre-sized row if fewer cells than expected
      final row =
          (colCount > 0 && cellIdx < colCount)
              ? currentRow.sublist(0, cellIdx)
              : currentRow;

      if (hasHeader && headers == null) {
        headers = row.map((e) => e?.toString() ?? '').toList();
        colCount = headers.length;
        continue;
      }

      if (colCount < 0) colCount = cellIdx;
      rows.add(row);
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
    var colCount = -1;
    var isEmpty = true;

    if (len > 0 && bytes[0] == _bom) cursor = 1;

    while (cursor < len) {
      final currentRow =
          colCount > 0 ? List<String>.generate(colCount, (_) => '', growable: true) : <String>[];
      var cellIdx = 0;
      isEmpty = true;

      cell_loop:
      while (true) {
        if (cursor >= len) break cell_loop;

        final ch = bytes[cursor];

        if (ch == _cr || ch == _lf) {
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break cell_loop;
        }

        // Consume field delimiter between cells
        if (cellIdx > 0) {
          if (singleCharDelim && ch == firstDelim) {
            cursor++;
          } else if (!singleCharDelim &&
              ch == firstDelim &&
              _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
            cursor += delimLen;
          }
          if (cursor >= len) break cell_loop;
        }

        final cellStart = bytes[cursor];

        if (cellStart == quoteCode) {
          // --- Quoted field: substring approach ---
          cursor++;
          final start = cursor;
          List<int>? escapePositions;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == escapeCode &&
                cursor + 1 < len &&
                bytes[cursor + 1] == quoteCode) {
              (escapePositions ??= []).add(cursor - start);
              cursor += 2;
            } else if (c == quoteCode) {
              cursor++;
              break;
            } else {
              cursor++;
            }
          }
          String value = input.substring(start, cursor - 1);
          if (escapePositions != null) {
            for (var i = escapePositions.length - 1; i >= 0; i--) {
              value = value.replaceRange(
                  escapePositions[i], escapePositions[i] + 1, '');
            }
          }
          if (isEmpty && value.isNotEmpty) isEmpty = false;
          _addStr(currentRow, cellIdx, colCount, value);
          cellIdx++;
        } else if (cellStart == _cr || cellStart == _lf) {
          cursor++;
          if (cellStart == _cr && cursor < len && bytes[cursor] == _lf) {
            cursor++;
          }
          break cell_loop;
        } else {
          // --- Unquoted field ---
          final start = cursor;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == _cr || c == _lf) break;
            if (singleCharDelim
                ? c == firstDelim
                : (c == firstDelim &&
                    _matchDelim(bytes, cursor, delimBytes, delimLen, len))) {
              break;
            }
            cursor++;
          }
          final value = input.substring(start, cursor);
          if (isEmpty && value.isNotEmpty) isEmpty = false;
          _addStr(currentRow, cellIdx, colCount, value);
          cellIdx++;
        }

        continue cell_loop;
      }

      if (skipEmpty && isEmpty) continue;

      final row =
          (colCount > 0 && cellIdx < colCount)
              ? currentRow.sublist(0, cellIdx)
              : currentRow;

      if (colCount < 0) colCount = cellIdx;
      rows.add(row);
    }

    return rows;
  }

  // --- Helpers (static for inlining) ---

  static bool _matchDelim(
    List<int> bytes,
    int pos,
    List<int> delimBytes,
    int delimLen,
    int totalLen,
  ) {
    if (pos + delimLen > totalLen) return false;
    for (var i = 0; i < delimLen; i++) {
      if (bytes[pos + i] != delimBytes[i]) return false;
    }
    return true;
  }

  /// Check if bytes match multi-char delimiter at position.
  static bool matchDelimiter(
    List<int> bytes,
    int pos,
    List<int> delimBytes,
    int delimLen,
    int totalLen,
  ) =>
      _matchDelim(bytes, pos, delimBytes, delimLen, totalLen);

  /// Check if current position is a field delimiter.
  static bool isDelimiterAt(
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
        _matchDelim(bytes, pos, delimBytes, delimLen, totalLen);
  }

  /// Infer a dynamic type from a string value.
  static dynamic inferType(String value) {
    if (value.isEmpty) return null;
    if (value == 'true') return true;
    if (value == 'false') return false;

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

  // Add cell to pre-sized or growing row
  static void _addCell(
      List<dynamic> row, int idx, int colCount, dynamic value) {
    if (colCount > 0 && idx < colCount) {
      row[idx] = value;
    } else {
      row.add(value);
    }
  }

  static void _addStr(List<String> row, int idx, int colCount, String value) {
    if (colCount > 0 && idx < colCount) {
      row[idx] = value;
    } else {
      row.add(value);
    }
  }
}
