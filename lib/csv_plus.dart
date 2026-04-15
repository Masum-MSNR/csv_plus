/// Complete, high-performance CSV package for Dart.
///
/// Read, write, stream, manipulate, validate — with maximum speed and type safety.
library;


// Core
export 'src/core/csv_config.dart';
export 'src/core/csv_exception.dart';
export 'src/core/quote_mode.dart';

// Codec (main facade)
export 'src/codec/csv_codec.dart';

// Encoder
export 'src/encoder/fast_encoder.dart';

// Decoder
export 'src/decoder/fast_decoder.dart';

// Table
export 'src/table/csv_row.dart';

// TODO: Export any libraries intended for clients of this package.
