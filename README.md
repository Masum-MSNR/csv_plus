# csv_plus

A complete, high-performance CSV package for Dart. Read, write, stream, manipulate, validate — with maximum speed and type safety.

**Zero dependencies. Pure Dart. Works on VM, Web, and AOT.**

---

## Features

| Category | Highlights |
|----------|-----------|
| **Performance** | Dual-path: byte-level batch (`codeUnits`) and chunked streaming |
| **Type inference** | Auto-detects `int`, `double`, `bool`, `null`, `String` from raw CSV |
| **CsvTable** | 2D data with filtering, sorting, grouping, aggregation (50+ methods) |
| **Validation** | Schema definitions with type, nullability, pattern, and custom constraints |
| **Streaming** | Memory-efficient `StreamTransformer` for large files |
| **dart:convert** | `CsvCodecAdapter` integrates with Dart's codec pipeline and `.fuse()` |
| **Auto-detection** | Delimiter detection, BOM handling, Excel `sep=` hint support |
| **Presets** | CSV, TSV, Excel (semicolons + BOM), pipe-separated |
| **File I/O** | Read, write, stream, append CSV files (via `CsvFile`) |
| **Flexible decoding** | Lenient mode: trims whitespace, handles unmatched quotes |

---

## Getting Started

```yaml
dependencies:
  csv_plus: ^0.0.1
```

```dart
import 'package:csv_plus/csv_plus.dart';
```

---

## Quick Start

```dart
final codec = CsvCodec();

// Encode
final csv = codec.encode([
  ['name', 'age', 'score'],
  ['Alice', 30, 95.5],
  ['Bob', 25, 88.0],
]);

// Decode (types are automatically inferred)
final rows = codec.decode(csv);
// rows[1] == ['Alice', 30, 95.5]  — int and double preserved

// Decode with header-aware rows
final headerRows = codec.decodeWithHeaders(csv);
print(headerRows.first['name']); // Alice
print(headerRows.first['age']);  // 30
```

---

## API Reference

### CsvConfig

Immutable configuration for all encode/decode operations. All parameters have sensible RFC 4180 defaults.

```dart
const config = CsvConfig(
  fieldDelimiter: ',',       // Single or multi-character
  lineDelimiter: '\r\n',     // Row separator for encoding
  quoteCharacter: '"',       // Must be single character
  escapeCharacter: '"',      // Defaults to quoteCharacter (RFC 4180 doubling)
  quoteMode: QuoteMode.necessary,
  addBom: false,             // UTF-8 BOM for Excel compatibility
  autoDetect: true,          // Auto-detect delimiter from input
  skipEmptyLines: true,
  hasHeader: false,          // Treat first row as headers
  dynamicTyping: true,       // Parse numbers and booleans
  decoderTransform: null,    // Post-decode field transform
  encoderTransform: null,    // Pre-encode field transform
);
```

**Named presets:**

| Constructor | Delimiter | BOM | Auto-detect |
|------------|-----------|-----|-------------|
| `CsvConfig()` | `,` | No | Yes |
| `CsvConfig.excel()` | `;` | Yes | No |
| `CsvConfig.tsv()` | `\t` | No | No |
| `CsvConfig.pipe()` | `\|` | No | No |

**`copyWith()`** — Create a modified copy with specific overrides:

```dart
final tsv = config.copyWith(fieldDelimiter: '\t');
```

### QuoteMode

Controls when fields are quoted during encoding.

| Value | Behavior |
|-------|---------|
| `QuoteMode.necessary` | Quote only when field contains delimiter, newline, quote, or leading/trailing spaces |
| `QuoteMode.always` | Quote every field unconditionally |
| `QuoteMode.strings` | Quote only `String`-typed fields; numbers, bools, null stay unquoted |

---

### CsvCodec

Main facade wrapping all encode/decode operations with shared `CsvConfig`.

```dart
final codec = CsvCodec();             // Standard CSV
final excel = CsvCodec.excel();        // Excel preset
final tsv = CsvCodec.tsv();            // Tab-separated
final pipe = CsvCodec.pipe();          // Pipe-separated
```

**Global convenience instances:**

```dart
csvPlus   // CsvCodec()         — standard
csvExcel  // CsvCodec.excel()   — Excel
csvTsv    // CsvCodec.tsv()     — TSV
```

#### Decode Methods

| Method | Return Type | Description |
|--------|------------|-------------|
| `decode(input)` | `List<List<dynamic>>` | Decode with automatic type inference |
| `decodeWithHeaders(input)` | `List<CsvRow>` | Decode with first row as headers; returns header-aware rows |
| `decodeStrings(input)` | `List<List<String>>` | Decode all fields as strings (no type inference) |
| `decodeFlexible(input)` | `List<List<dynamic>>` | Lenient: trims whitespace, unmatched quotes as literals |
| `decodeIntegers(input)` | `List<List<int>>` | Parse all fields as integers |
| `decodeDoubles(input)` | `List<List<double>>` | Parse all fields as doubles |
| `decodeBooleans(input)` | `List<List<bool>>` | Parse as booleans (`"true"` → `true`, else → `false`) |
| `decodeToTable(input)` | `CsvTable` | Decode into a full CsvTable with headers |
| `decodeMap(input)` | `Map<String, dynamic>` | Decode two-column CSV into a Map |

#### Encode Methods

| Method | Return Type | Description |
|--------|------------|-------------|
| `encode(rows)` | `String` | Encode mixed-type rows with automatic quoting |
| `encodeStrings(rows)` | `String` | Optimized for all-string data |
| `encodeGeneric<T>(rows)` | `String` | Optimized for uniform-typed data (no quoting) |
| `encodeMap(map)` | `String` | Encode Map as two-column CSV (key, value) |

#### Streaming & Codec

| Method/Property | Type | Description |
|----------------|------|-------------|
| `decoder` | `CsvDecoder` | Streaming decoder for `Stream.transform()` |
| `encoder` | `CsvEncoder` | Streaming encoder for `Stream.transform()` |
| `asCodec()` | `CsvCodecAdapter` | dart:convert `Codec` for `.fuse()` pipelines |

---

### CsvRow

Header-aware row extending `List<dynamic>`. Supports dual-mode access by integer index or header name.

```dart
final row = CsvRow(['Alice', 30, 'NYC'], {'name': 0, 'age': 1, 'city': 2});

// Positional access
row[0]           // 'Alice'

// Named access
row['age']       // 30
row['missing']   // null (no throw)

// Named write
row.set('age', 31);
```

| Member | Type | Description |
|--------|------|-------------|
| `operator [](key)` | `dynamic` | Access by `int` index or `String` header |
| `operator []=(index, value)` | `void` | Set by index |
| `set(header, value)` | `void` | Set by header name |
| `headerMap` | `Map<String, int>?` | Header-to-index mapping (null if no headers) |
| `hasHeaders` | `bool` | Whether this row carries header information |
| `headers` | `List<String>` | Header names in column order |
| `containsHeader(name)` | `bool` | Check if a header exists |
| `toMap()` | `Map<String, dynamic>` | Convert to `{header: value}` map |
| `getHeaderName(index)` | `String?` | Get header name for a column index |

---

### CsvTable

Full-featured 2D data structure with headers, querying, manipulation, and aggregation.

#### Constructors

```dart
// From raw 2D data (no headers)
CsvTable(rows)

// First row is headers
CsvTable.withHeaders(rows)

// Explicit headers + data
CsvTable.fromData(headers: ['a', 'b'], rows: [[1, 2]])

// From list of Maps
CsvTable.fromMaps([{'a': 1, 'b': 2}])

// Parse from CSV string
CsvTable.parse(csvString, config: CsvConfig())

// Empty table with columns
CsvTable.empty(headers: ['a', 'b'])
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `headers` | `List<String>` | Column headers (unmodifiable) |
| `hasHeaders` | `bool` | Whether headers are defined |
| `rowCount` | `int` | Number of data rows |
| `columnCount` | `int` | Number of columns |
| `isEmpty` / `isNotEmpty` | `bool` | Check emptiness |
| `rows` | `List<CsvRow>` | All rows as header-aware CsvRow list |
| `first` / `last` | `CsvRow` | First/last row |
| `iterator` | `Iterator<CsvRow>` | Iterate over rows |

#### Cell & Column Access

```dart
table[0]                     // Row at index as CsvRow
table.cell(0, 1)             // Cell at (row, col)
table.cellByName(0, 'age')   // Cell by row index + column name
table.setCell(0, 1, 99)      // Set cell value
table.setCellByName(0, 'age', 99)

table.column('age')           // All values in column by name
table.columnAt(1)             // All values in column by index
table.getColumn('age')        // CsvColumn descriptor with metadata
table.getColumnAt(1)          // CsvColumn descriptor by index
```

#### Row Manipulation

```dart
table.addRow([val1, val2])
table.addRowFromMap({'name': 'Alice', 'age': 30})
table.addRows([[...], [...]])
table.insertRow(index, [val1, val2])
table.removeRow(index)           // Returns removed CsvRow
table.removeWhere((row) => ...)  // Returns count removed
```

#### Column Manipulation

```dart
table.addColumn('active', defaultValue: true)
table.insertColumn(1, 'id', defaultValue: 0)
table.removeColumn('temp')       // Returns removed values
table.removeColumnAt(3)
table.renameColumn('age', 'years')
table.reorderColumns(['name', 'city', 'age'])
```

#### Querying & Filtering

```dart
table.where((row) => row['age'] > 25)   // Returns new CsvTable
table.firstWhere((row) => ...)           // Returns CsvRow? or null
table.any((row) => ...)                  // true if any match
table.every((row) => ...)                // true if all match
table.range(2, 5)                        // Rows 2..4 as new CsvTable
table.take(10)                           // First 10 rows
table.skip(5)                            // Skip first 5
table.distinct()                         // Remove duplicates (all fields)
table.distinct(columns: ['name'])        // Remove duplicates by specific columns
```

#### Sorting

```dart
table.sortBy('age', ascending: true)
table.sortByIndex(1)
table.sortByMultiple([('name', true), ('age', false)])
table.sort((a, b) => ...)               // Custom comparator
```

#### Transformation

```dart
table.transformColumn('price', (v) => (v as num) * 1.1)
table.map((row) => ...)                  // Returns new CsvTable
table.fold<int>(0, (acc, row) => ...)    // Reduce to single value
```

#### Aggregation

```dart
table.count('age')     // Count of non-null values
table.sum('price')     // Sum of numeric values
table.avg('score')     // Average of numeric values
table.min('age')       // Minimum value
table.max('age')       // Maximum value
table.groupBy('city')  // Map<dynamic, CsvTable>
```

#### Conversion & Export

```dart
table.toList()                        // List<List<dynamic>>
table.toList(includeHeaders: true)    // With header row
table.toMaps()                        // List<Map<String, dynamic>>
table.toCsv()                         // Encoded CSV string
table.toCsv(config: CsvConfig.tsv())  // TSV export
table.toString()                      // Summary string
table.toFormattedString()             // Pretty-printed aligned table
table.copy()                          // Deep copy
```

#### Schema & Validation

```dart
table.validate(schema)      // List<CsvValidationException>
table.conformsTo(schema)    // bool
table.inferSchema()         // CsvSchema inferred from data
```

---

### CsvSchema & ColumnDef

Define and validate CSV table structure.

```dart
final schema = CsvSchema(
  columns: [
    ColumnDef(
      name: 'name',
      type: String,
      required: true,
      nullable: false,
      pattern: r'^[A-Z]',         // Regex pattern
      validator: (v) => v != '',  // Custom check
    ),
    ColumnDef(name: 'age', type: int, required: true, nullable: false),
    ColumnDef(name: 'email', type: String, nullable: true),
  ],
  allowExtraColumns: true,     // Allow columns not in schema
  allowMissingColumns: false,  // Require all defined columns
);

// Validate
final errors = schema.validate(headers, dataRows);
for (final e in errors) {
  print('${e.columnName} row ${e.rowIndex}: ${e.message}');
}

// Infer schema from actual data
final inferred = CsvSchema.infer(headers, dataRows);
```

**ColumnDef fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | Column header name |
| `type` | `Type?` | Expected runtime type (`String`, `int`, `double`, `bool`) |
| `required` | `bool` | Column must be present (default: `true`) |
| `nullable` | `bool` | Allows null values (default: `true`) |
| `pattern` | `String?` | Regex pattern for value validation |
| `validator` | `bool Function(dynamic)?` | Custom validation function |

---

### CsvColumn

Column descriptor returned by `CsvTable.getColumn()` / `getColumnAt()`.

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Column header name |
| `index` | `int` | Column index (0-based) |
| `values` | `List<dynamic>` | All values in this column |
| `inferredType` | `Type` | Dominant type (`String`, `int`, etc.) or `dynamic` if mixed |
| `nonNullCount` | `int` | Count of non-null values |
| `nullCount` | `int` | Count of null values |
| `uniqueCount` | `int` | Count of unique values (including null) |

---

### DelimiterDetector

Auto-detects the field delimiter, BOM, and Excel `sep=` hint from CSV input.

```dart
const detector = DelimiterDetector();

detector.detectDelimiter(sample)  // ',', ';', '\t', or '|'
detector.stripBom(input)          // (stripped, hadBom)
detector.checkSepHint(input)      // (remaining, delimiter?)
```

**Algorithm:** Scores candidates `[, ; \t |]` by frequency and consistency across the first 10 lines; `sep=` hint takes priority.

---

### Streaming (CsvDecoder / CsvEncoder)

Memory-efficient processing via `StreamTransformer`.

```dart
// Decode stream
final decoder = CsvDecoder(config);
Stream<List<dynamic>> rows = decoder.bind(csvStringStream);

// Encode stream
final encoder = CsvEncoder(config);
Stream<String> csvChunks = encoder.bind(rowStream);

// dart:convert chunked conversion
final sink = decoder.startChunkedConversion(outputSink);
sink.add('partial,data\n');
sink.add('more,data\n');
sink.close();
```

**Batch conversion** is also available:

```dart
final rows = CsvDecoder(config).convert('a,b\n1,2');
final csv = CsvEncoder(config).convert([[1, 2], [3, 4]]);
```

---

### CsvCodecAdapter (dart:convert)

Standard `Codec<List<List<dynamic>>, String>` for pipeline integration.

```dart
final codec = CsvCodecAdapter();
final rows = codec.decode('a,b\n1,2');
final csv = codec.encode([[1, 2], [3, 4]]);

// Fuse with other codecs
final pipeline = codec.fuse(utf8);
```

---

### FastDecoder / FastEncoder

Low-level batch encode/decode with maximum performance. Used internally by `CsvCodec`.

**FastDecoder** uses `codeUnits` array indexing, labeled loops, and first-byte type detection:

```dart
const decoder = FastDecoder();
decoder.decode(input, config)         // List<List<dynamic>> with type inference
decoder.decodeStrings(input, config)  // List<List<String>>
decoder.decodeFlexible(input, config) // Lenient mode
decoder.decodeIntegers(input, config) // List<List<int>>
decoder.decodeDoubles(input, config)  // List<List<double>>
decoder.decodeBooleans(input, config) // List<List<bool>>
```

**FastEncoder** uses per-call `StringBuffer` (thread-safe):

```dart
const encoder = FastEncoder();
encoder.encode(data, config)          // Mixed types
encoder.encodeStrings(data, config)   // All-string optimized
encoder.encodeGeneric<T>(data, config)// Uniform type (no quoting)
encoder.encodeMap(map, config)        // Map as two-column CSV
```

---

### CsvFile (dart:io)

File operations isolated from core library for platform independence.

**Import separately** (not in barrel export):

```dart
import 'package:csv_plus/src/io/csv_file.dart';
```

| Method | Description |
|--------|-------------|
| `CsvFile.read(path)` | Read file to CsvTable (async) |
| `CsvFile.readSync(path)` | Read file to CsvTable (sync) |
| `CsvFile.stream(path)` | Stream rows from file (memory-efficient) |
| `CsvFile.write(path, table)` | Write CsvTable to file (async) |
| `CsvFile.writeSync(path, table)` | Write CsvTable to file (sync) |
| `CsvFile.writeRows(path, rows)` | Write raw rows to file |
| `CsvFile.writeStream(path, stream)` | Write from stream |
| `CsvFile.append(path, rows)` | Append rows to existing file |

```dart
// Read
final table = await CsvFile.read('data.csv');

// Write
await CsvFile.write('output.csv', table);

// Stream large files
await for (final row in CsvFile.stream('huge.csv')) {
  // process row by row — constant memory
}

// Append
await CsvFile.append('data.csv', [['Charlie', 35, 72.3]]);
```

---

### Exceptions

| Class | Use |
|-------|-----|
| `CsvException` | Base exception for all CSV operations |
| `CsvParseException` | Parsing errors with optional `row`, `column`, `offset` location |
| `CsvValidationException` | Schema violations with `columnName`, `rowIndex`, `value`, `constraint` |

---

## Architecture

```
lib/
  csv_plus.dart           ← barrel export (all public API)
  src/
    core/                 ← CsvConfig, QuoteMode, CsvException hierarchy
    codec/                ← CsvCodec (facade), CsvCodecAdapter (dart:convert)
    encoder/              ← FastEncoder (batch), CsvEncoder (streaming)
    decoder/              ← FastDecoder (batch), CsvDecoder (streaming), DelimiterDetector
    table/                ← CsvTable, CsvRow, CsvColumn, CsvSchema
    io/                   ← CsvFile (dart:io, isolated for platform independence)
```

- **Batch path**: `FastEncoder` / `FastDecoder` use `codeUnits` byte arrays for maximum throughput
- **Streaming path**: `CsvEncoder` / `CsvDecoder` implement `StreamTransformer` for constant-memory processing
- `dart:io` is isolated in `io/csv_file.dart` — core library compiles on VM, Web, and AOT

---

## License

MIT
