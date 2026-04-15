/// Complete, high-performance CSV package for Dart.
///
/// Read, write, stream, manipulate, validate — with maximum speed and type safety.
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
export 'src/decoder/csv_decoder.dart';
export 'src/decoder/delimiter_detector.dart';

// Table
export 'src/table/csv_row.dart';
export 'src/table/csv_column.dart';
export 'src/table/csv_schema.dart';
export 'src/table/csv_table.dart';

// I/O (dart:io — import separately: `import 'package:csv_plus/src/io/csv_file.dart';`)
