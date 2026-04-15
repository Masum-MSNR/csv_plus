/// Auto-detects field delimiter, BOM, and Excel `sep=` hint from input.
class DelimiterDetector {
  /// Create a delimiter detector instance (stateless, reusable).
  const DelimiterDetector();

  static const _candidates = [',', ';', '\t', '|'];
  static const _bom = 0xFEFF;
  static const _maxSampleLines = 10;

  /// Detect the most likely field delimiter from a sample string.
  ///
  /// Algorithm:
  /// 1. Check for Excel `sep=X` hint on first line
  /// 2. Score candidates by frequency and consistency across first 10 lines
  /// 3. Return highest-scoring candidate, default `,`
  String detectDelimiter(String sample) {
    final (stripped, sepDelim) = checkSepHint(stripBom(sample).$1);
    if (sepDelim != null) return sepDelim;

    final lines = _sampleLines(stripped);
    if (lines.isEmpty) return ',';

    var bestCandidate = ',';
    var bestScore = -1;

    for (final candidate in _candidates) {
      var score = 0;
      var prevCount = -1;

      for (final line in lines) {
        final count = _countOutsideQuotes(line, candidate);
        score += count;
        if (prevCount >= 0 && count == prevCount && count > 0) {
          score += 2; // consistency bonus
        }
        prevCount = count;
      }

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }

  /// Strip UTF-8 BOM if present. Returns (stripped string, had BOM).
  (String, bool) stripBom(String input) {
    if (input.isNotEmpty && input.codeUnitAt(0) == _bom) {
      return (input.substring(1), true);
    }
    return (input, false);
  }

  /// Check for Excel `sep=X` hint on first line.
  /// Returns (remaining string, detected delimiter or null).
  (String, String?) checkSepHint(String input) {
    if (input.length < 5) return (input, null);

    // Look for sep=X followed by newline
    if (input.startsWith('sep=')) {
      final newlineIdx = input.indexOf('\n');
      final crIdx = input.indexOf('\r');
      final endIdx = crIdx >= 0 && crIdx < (newlineIdx < 0 ? input.length : newlineIdx)
          ? crIdx
          : newlineIdx;

      if (endIdx > 4) {
        final delimiter = input.substring(4, endIdx);
        var remaining = input.substring(endIdx);
        // Skip the newline(s)
        if (remaining.startsWith('\r\n')) {
          remaining = remaining.substring(2);
        } else if (remaining.startsWith('\r') || remaining.startsWith('\n')) {
          remaining = remaining.substring(1);
        }
        return (remaining, delimiter);
      }
    }
    return (input, null);
  }

  List<String> _sampleLines(String input) {
    final lines = <String>[];
    var start = 0;
    var inQuotes = false;

    for (var i = 0; i < input.length && lines.length < _maxSampleLines; i++) {
      final ch = input.codeUnitAt(i);
      if (ch == 34) {
        // "
        inQuotes = !inQuotes;
      } else if (!inQuotes && (ch == 10 || ch == 13)) {
        // \n or \r
        lines.add(input.substring(start, i));
        if (ch == 13 && i + 1 < input.length && input.codeUnitAt(i + 1) == 10) {
          i++;
        }
        start = i + 1;
      }
    }

    if (start < input.length && lines.length < _maxSampleLines) {
      lines.add(input.substring(start));
    }

    return lines;
  }

  static int _countOutsideQuotes(String line, String delimiter) {
    var count = 0;
    var inQuotes = false;
    final delimLen = delimiter.length;

    for (var i = 0; i < line.length; i++) {
      if (line.codeUnitAt(i) == 34) {
        // "
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (delimLen == 1) {
          if (line.codeUnitAt(i) == delimiter.codeUnitAt(0)) count++;
        } else if (i + delimLen <= line.length &&
            line.substring(i, i + delimLen) == delimiter) {
          count++;
          i += delimLen - 1;
        }
      }
    }

    return count;
  }
}
