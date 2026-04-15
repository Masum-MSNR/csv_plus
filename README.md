# csv_plus

A complete, high-performance CSV package for Dart. Read, write, stream, manipulate, validate — with maximum speed and type safety.

**Zero dependencies. Pure Dart. Works on VM, Web, and AOT.**

## Features

- **Dual-path architecture**: Batch (byte-level `codeUnits` parsing) and streaming (chunked state machine)
- **Automatic type inference**: Detects `int`, `double`, `bool`, `null`, and `String` from raw CSV
- **CsvTable**: Full 2D data structure with headers, filtering, sorting, grouping, aggregation
- **Schema validation**: Define and validate column types, nullability, and constraints
- **Streaming**: Memory-efficient processing of large files via `Stream` transforms
- **dart:convert compatible**: `CsvCodecAdapter` integrates with Dart's codec pipeline
- **Auto-detection**: Delimiter detection, BOM handling, Excel `sep=` hint support
- **Multiple presets**: CSV, TSV, Excel (semicolons + BOM), pipe-separated
- **File I/O**: Read, write, stream, and append CSV files (via `CsvFile`)
- **Flexible decoding**: Lenient mode that trims whitespace and handles unmatched quotes

## Getting Started

```yaml
dependencies:
  csv_plus: ^0.0.1
```

```dart
import 'package:csv_plus/csv_plus.dart';
```

## Usage

### Encode & Decode

```dart
final codec = CsvCodec();

// Encode
final csv = codec.encode([
  ['name', 'age', 'score'],
  ['Alice', 30, 95.5],
  ['Bob', 25, 88.0],
]);

// Decode (with type inference)
final rows = codec.decode(csv);
// rows[1] = ['Alice', 30, 95.5] — types preserved!

// Decode with headers
final headerRows = codec.decodeWithHeaders(csv);
print(headerRows.first['name']); // Alice
```

### CsvTable

```dart
final table = CsvTable.parse('name,age,city\nAlice,30,NYC\nBob,25,LA');

// Filter
final nyc = table.where((row) => row['city'] == 'NYC');

// Sort
table.sortBy('age', ascending: false);

// Aggregate
print(table.avg('age'));   // 27.5
print(table.sum('age'));   // 55

// Group
final byCity = table.groupBy('city');

// Manipulate columns
table.addColumn('active', defaultValue: true);
table.renameColumn('age', 'years');

// Export
print(table.toCsv());
print(table.toMaps());
```

### Streaming

```dart
import 'package:csv_plus/src/decoder/csv_decoder.dart';
import 'package:csv_plus/src/encoder/csv_encoder.dart';

// Stream decode
final decoder = CsvDecoder(const CsvConfig());
final rows = decoder.bind(csvStringStream);

// Stream encode
final encoder = CsvEncoder(const CsvConfig());
final csvStream = encoder.bind(rowStream);
```

### File I/O

```dart
import 'package:csv_plus/src/io/csv_file.dart';

// Read
final table = await CsvFile.read('data.csv');

// Write
await CsvFile.write('output.csv', table);

// Stream large files
await for (final row in CsvFile.stream('huge.csv')) {
  // process row
}

// Append
await CsvFile.append('data.csv', [['Charlie', 35, 72.3]]);
```

### Presets

```dart
CsvCodec()        // Standard CSV (comma, CRLF)
CsvCodec.excel()  // Excel (semicolons, BOM)
CsvCodec.tsv()    // Tab-separated
CsvCodec.pipe()   // Pipe-separated
```

### Schema Validation

```dart
final schema = CsvSchema(columns: [
  ColumnDef(name: 'name', type: String, required: true, nullable: false),
  ColumnDef(name: 'age', type: int, required: true, nullable: false),
]);

final errors = table.validate(schema);

// Or infer schema from data
final inferred = table.inferSchema();
```

### Type-Specific Decoding

```dart
final codec = CsvCodec();
codec.decodeIntegers('1,2\n3,4');   // List<List<int>>
codec.decodeDoubles('1.5,2.5');     // List<List<double>>
codec.decodeFlexible(' a , b ');    // Trims whitespace, lenient quotes
```

## Architecture

```
lib/src/
  core/        → CsvConfig, QuoteMode, CsvException hierarchy
  codec/       → CsvCodec (facade), CsvCodecAdapter (dart:convert)
  encoder/     → FastEncoder (batch), CsvEncoder (streaming)
  decoder/     → FastDecoder (batch), CsvDecoder (streaming), DelimiterDetector
  table/       → CsvTable, CsvRow, CsvColumn, CsvSchema
  io/          → CsvFile (dart:io, isolated)
```

- **Batch path**: `FastEncoder`/`FastDecoder` use `StringBuffer` and `codeUnits` for maximum throughput
- **Streaming path**: `CsvEncoder`/`CsvDecoder` implement `StreamTransformer` for memory-efficient processing
- `dart:io` is isolated in `io/csv_file.dart` — core library works on all platforms

## License

MIT
