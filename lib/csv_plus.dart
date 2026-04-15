/// Complete, high-performance CSV package for Dart.
///
/// ```dart
/// import 'package:csv_plus/csv_plus.dart';
///
/// // Encode
/// final csv = CsvCodec().encode([['name', 'age'], ['Alice', 30]]);
///
/// // Decode with type inference
/// final rows = CsvCodec().decode(csv); // [['name', 'age'], ['Alice', 30]]
///
/// // Full table manipulation
/// final table = CsvTable.parse(csv);
/// table.sortBy('age');
/// table.where((row) => row['age'] > 25);
/// print(table.avg('age'));
/// ```
///
/// For file I/O (dart:io), import separately:
/// ```dart
/// import 'package:csv_plus/src/io/csv_file.dart';
/// ```
library;

// Core
export 'src/core/csv_config.dart';
export 'src/core/csv_exception.dart';
export 'src/core/quote_mode.dart';

// Codec
export 'src/codec/csv_codec.dart';
export 'src/codec/codec_adapter.dart';

// Encoder
export 'src/encoder/fast_encoder.dart';
export 'src/encoder/csv_encoder.dart';

// Decoder
export 'src/decoder/fast_decoder.dart';
export 'src/decoder/fast_decoder_ext.dart';
export 'src/decoder/csv_decoder.dart';
export 'src/decoder/delimiter_detector.dart';

// Table
export 'src/table/csv_row.dart';
export 'src/table/csv_column.dart';
export 'src/table/csv_schema.dart';
export 'src/table/csv_table.dart';

// Query
export 'src/query/filtering.dart';
export 'src/query/sorting.dart';

// Transform
export 'src/transform/manipulation.dart';
export 'src/transform/aggregation.dart';

// I/O (dart:io — import separately: `import 'package:csv_plus/src/io/csv_file.dart';`)
