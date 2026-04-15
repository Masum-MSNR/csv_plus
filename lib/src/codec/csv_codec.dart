import 'codec_adapter.dart';
import '../core/csv_config.dart';
import '../decoder/csv_decoder.dart';
import '../decoder/fast_decoder.dart';
import '../encoder/csv_encoder.dart';
import '../encoder/fast_encoder.dart';
import '../table/csv_row.dart';
import '../table/csv_table.dart';

const _fastDecoder = FastDecoder();
const _fastEncoder = FastEncoder();

/// Main facade for CSV encoding and decoding.
///
/// Wraps [FastEncoder] and [FastDecoder] with shared [CsvConfig].
class CsvCodec {
  /// Configuration for this codec.
  final CsvConfig config;

  const CsvCodec([this.config = const CsvConfig()]);

  /// Excel-compatible preset: `;` delimiter, UTF-8 BOM.
  const CsvCodec.excel() : config = const CsvConfig.excel();

  /// Tab-separated values preset.
  const CsvCodec.tsv() : config = const CsvConfig.tsv();

  /// Pipe-separated values preset.
  const CsvCodec.pipe() : config = const CsvConfig.pipe();

  // ---------------------------------------------------------------------------
  // Batch decode
  // ---------------------------------------------------------------------------

  /// Decode CSV string to list of rows.
  List<List<dynamic>> decode(String input) {
    return _fastDecoder.decode(input, config);
  }

  /// Decode with first row as headers. Returns [CsvRow] objects.
  List<CsvRow> decodeWithHeaders(String input) {
    final withHeader = config.hasHeader
        ? config
        : config.copyWith(hasHeader: true);
    final rawRows = _fastDecoder.decode(input, withHeader);

    // Extract headers from input
    final headerConfig = const CsvConfig(
      dynamicTyping: false,
      hasHeader: false,
      skipEmptyLines: true,
    ).copyWith(
      fieldDelimiter: config.fieldDelimiter,
      quoteCharacter: config.quoteCharacter,
      escapeCharacter: config.escapeCharacter,
    );
    final allRows = _fastDecoder.decodeStrings(input, headerConfig);
    if (allRows.isEmpty) return [];

    final headers = allRows.first;
    final headerMap = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      headerMap[headers[i]] = i;
    }

    return rawRows.map((row) => CsvRow(row, headerMap)).toList();
  }

  /// Decode all fields as strings (no type inference).
  List<List<String>> decodeStrings(String input) {
    return _fastDecoder.decodeStrings(input, config);
  }

  /// Decode with lenient parsing: trims whitespace, treats unmatched quotes
  /// as literal characters.
  List<List<dynamic>> decodeFlexible(String input) {
    return _fastDecoder.decodeFlexible(input, config);
  }

  /// Decode all fields as integers.
  List<List<int>> decodeIntegers(String input) {
    return _fastDecoder.decodeIntegers(input, config);
  }

  /// Decode all fields as doubles.
  List<List<double>> decodeDoubles(String input) {
    return _fastDecoder.decodeDoubles(input, config);
  }

  // ---------------------------------------------------------------------------
  // Batch encode
  // ---------------------------------------------------------------------------

  /// Encode rows to CSV string.
  String encode(List<List<dynamic>> rows) {
    return _fastEncoder.encode(rows, config);
  }

  /// Encode all-string data (optimized fast path).
  String encodeStrings(List<List<String>> rows) {
    return _fastEncoder.encodeStrings(rows, config);
  }

  // ---------------------------------------------------------------------------
  // Decode to table
  // ---------------------------------------------------------------------------

  /// Decode CSV string into a [CsvTable] with headers.
  CsvTable decodeToTable(String input) {
    return CsvTable.parse(input, config: config);
  }

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  /// Streaming decoder for use with `Stream.transform()`.
  CsvDecoder get decoder => CsvDecoder(config);

  /// Streaming encoder for use with `Stream.transform()`.
  CsvEncoder get encoder => CsvEncoder(config);

  // ---------------------------------------------------------------------------
  // dart:convert Codec adapter
  // ---------------------------------------------------------------------------

  /// Returns a `dart:convert` compatible [Codec] for pipeline use (`.fuse()`).
  CsvCodecAdapter asCodec() => CsvCodecAdapter(config);

  // ---------------------------------------------------------------------------
  // Map conversion
  // ---------------------------------------------------------------------------

  /// Encode a Map as two-column CSV (key, value).
  String encodeMap(Map<String, dynamic> map) {
    return _fastEncoder.encodeMap(map, config);
  }

  /// Decode two-column CSV into Map.
  Map<String, dynamic> decodeMap(String input) {
    final rows = decode(input);
    final map = <String, dynamic>{};
    for (final row in rows) {
      if (row.length >= 2) {
        map[row[0].toString()] = row[1];
      }
    }
    return map;
  }
}

/// Default codec instance with standard settings.
const csvPlus = CsvCodec();

/// Excel-compatible codec instance.
const csvExcel = CsvCodec.excel();

/// Tab-separated codec instance.
const csvTsv = CsvCodec.tsv();
