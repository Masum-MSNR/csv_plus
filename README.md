<p align="center">
  <img src="https://raw.githubusercontent.com/Masum-MSNR/csv_plus/main/assets/csv_plus_icon.png" width="160" alt="csv_plus logo" />
</p>

<h1 align="center">csv_plus</h1>

<p align="center">
  <strong>The fastest, most complete CSV package for Dart.</strong><br/>
  Encode · Decode · Stream · Query · Transform · Validate
</p>

<p align="center">
  <a href="https://pub.dev/packages/csv_plus"><img src="https://img.shields.io/pub/v/csv_plus.svg" alt="pub version"></a>
  <a href="https://pub.dev/packages/csv_plus/score"><img src="https://img.shields.io/pub/points/csv_plus" alt="pub points"></a>
  <a href="https://pub.dev/packages/csv_plus/score"><img src="https://img.shields.io/pub/likes/csv_plus" alt="pub likes"></a>
  <a href="https://pub.dev/packages/csv_plus/score"><img src="https://img.shields.io/pub/popularity/csv_plus" alt="popularity"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
</p>

<p align="center">
  <em>Zero dependencies · Pure Dart · VM, Web & AOT</em>
</p>

---

## Why csv_plus?

Most CSV libraries only do basic parsing. **csv_plus** gives you a complete toolkit — from raw byte-level decoding to full table operations — in a single, zero-dependency package.

| | What you get |
|---|---|
| **Blazing fast** | Byte-level (`codeUnits`) batch parser — no regex, no string ops in hot paths |
| **Type-smart** | Auto-infers `int`, `double`, `bool`, `null`, `String` from raw CSV data |
| **Stream-ready** | Chunked `StreamTransformer` for processing files of any size with constant memory |
| **50+ table methods** | Filter, sort, group, aggregate, transform — like a DataFrame for CSV |
| **Schema validation** | Define column types, nullability, patterns, custom validators |
| **dart:convert** | Drop-in `Codec` adapter with `.fuse()` pipeline support |
| **Auto-detection** | Delimiter sniffing, BOM handling, Excel `sep=` hint |
| **Presets built-in** | CSV, TSV, Excel (`;` + BOM), pipe-delimited — one line setup |
| **File I/O** | Read, write, stream, append CSV files with `CsvFile` |
| **Flexible parsing** | Lenient mode for messy real-world data: trims whitespace, recovers unmatched quotes |

---

## Installation

```yaml
dependencies:
  csv_plus: ^0.0.1
```

```dart
import 'package:csv_plus/csv_plus.dart';
```

---

## Quick Start

### Encode & Decode

```dart
final codec = CsvCodec();

// Encode
final csv = codec.encode([
  ['name', 'age', 'score'],
  ['Alice', 30, 95.5],
  ['Bob', 25, 88.0],
]);

// Decode — types are automatically inferred
final rows = codec.decode(csv);
// rows[1] == ['Alice', 30, 95.5]  ← int and double preserved
```

### Header-Aware Rows

```dart
final people = codec.decodeWithHeaders(csv);
print(people.first['name']); // Alice
print(people.first['age']);  // 30 (int, not String)
```

### CsvTable — Query & Transform

```dart
final table = CsvTable.parse('name,age,city\nAlice,30,NYC\nBob,25,LA\nEve,35,NYC');

// Filter
final nyc = table.where((row) => row['city'] == 'NYC');

// Sort
table.sortBy('age');

// Aggregate
final avgAge = table.avg('age'); // 30.0

// Group
final byCity = table.groupBy('city'); // {NYC: CsvTable, LA: CsvTable}

// Export
print(table.toCsv());
print(table.toFormattedString()); // Pretty-printed aligned table
```

### Stream Large Files

```dart
import 'package:csv_plus/io.dart';

// Stream — constant memory, any file size
await for (final row in CsvFile.stream('huge.csv')) {
  process(row);
}
```

---

## Features

### Dual-Path Architecture

csv_plus uses two optimized paths for every operation:

- **Batch path** — `FastEncoder` / `FastDecoder` use `codeUnits` byte arrays, labeled loops, and first-byte type detection for maximum throughput
- **Streaming path** — `CsvEncoder` / `CsvDecoder` implement `StreamTransformer` with a chunked state machine for constant-memory processing

### Automatic Type Inference

Raw CSV strings are parsed into native Dart types automatically:

```dart
final rows = codec.decode('name,age,active\nAlice,30,true');
// rows[0] == ['name', 'age', 'active']  (String)
// rows[1] == ['Alice', 30, true]         (String, int, bool)
```

Disable with `dynamicTyping: false` to get all strings, or use specialized decoders:

```dart
codec.decodeStrings(csv)   // List<List<String>>
codec.decodeIntegers(csv)  // List<List<int>>
codec.decodeDoubles(csv)   // List<List<double>>
codec.decodeBooleans(csv)  // List<List<bool>>
codec.decodeFlexible(csv)  // Lenient: trims whitespace, recovers bad quotes
```

### Configuration & Presets

```dart
final codec = CsvCodec();            // Standard CSV (auto-detect on)
final excel = CsvCodec.excel();       // Semicolons + BOM for Excel
final tsv = CsvCodec.tsv();           // Tab-separated
final pipe = CsvCodec.pipe();         // Pipe-separated

// Or customize fully
final custom = CsvCodec(CsvConfig(
  fieldDelimiter: '::',
  quoteMode: QuoteMode.always,
  skipEmptyLines: true,
));
```

### Schema Validation

```dart
final schema = CsvSchema(columns: [
  ColumnDef(name: 'email', type: String, required: true, pattern: r'@'),
  ColumnDef(name: 'age', type: int, nullable: false),
]);

final errors = table.validate(schema);
final isValid = table.conformsTo(schema);
```

### dart:convert Integration

```dart
final adapter = codec.asCodec();    // Codec<List<List<dynamic>>, String>
final rows = adapter.decode(csv);

// Fuse with other codecs
final pipeline = adapter.fuse(utf8);
```

---

## API Overview

### CsvCodec — Main Facade

| Decode | Encode |
|--------|--------|
| `decode()` — typed rows | `encode()` — mixed types |
| `decodeWithHeaders()` — `CsvRow` list | `encodeStrings()` — string-only |
| `decodeStrings()` — all strings | `encodeGeneric<T>()` — uniform type |
| `decodeToTable()` — `CsvTable` | `encodeMap()` — map → 2-col CSV |
| `decodeMap()` — 2-col → map | |
| `decodeFlexible()` — lenient mode | |

### CsvTable — 50+ Methods

| Category | Methods |
|----------|---------|
| **Access** | `cell()`, `cellByName()`, `column()`, `rows`, `first`, `last` |
| **Rows** | `addRow()`, `addRowFromMap()`, `insertRow()`, `removeRow()`, `removeWhere()` |
| **Columns** | `addColumn()`, `insertColumn()`, `removeColumn()`, `renameColumn()`, `reorderColumns()` |
| **Query** | `where()`, `firstWhere()`, `any()`, `every()`, `distinct()`, `range()`, `take()`, `skip()` |
| **Sort** | `sortBy()`, `sortByIndex()`, `sortByMultiple()`, `sort()` |
| **Aggregate** | `sum()`, `avg()`, `min()`, `max()`, `count()`, `groupBy()` |
| **Transform** | `transformColumn()`, `map()`, `fold()` |
| **Export** | `toCsv()`, `toMaps()`, `toList()`, `toFormattedString()`, `copy()` |
| **Validate** | `validate()`, `conformsTo()`, `inferSchema()` |

### CsvFile — File I/O

| Method | Description |
|--------|-------------|
| `read()` / `readSync()` | File → `CsvTable` |
| `write()` / `writeSync()` | `CsvTable` → file |
| `stream()` | Row-by-row streaming (constant memory) |
| `writeStream()` | Stream → file |
| `append()` | Append rows to existing file |

---

## Modular Imports

Import everything with one line, or pick only what you need:

```dart
import 'package:csv_plus/csv_plus.dart';     // Everything
import 'package:csv_plus/codec.dart';         // Just CsvCodec
import 'package:csv_plus/table.dart';         // Just CsvTable
import 'package:csv_plus/io.dart';            // File I/O (dart:io)
```

---

## Platform Support

| Platform | Status |
|----------|--------|
| Dart VM | ✅ Full support |
| Flutter | ✅ Full support |
| Web (dart2js / WASM) | ✅ Core (no `CsvFile`) |
| AOT compiled | ✅ Full support |

> `dart:io` is isolated in `io.dart` — core encode/decode/table works everywhere.

---

## Additional Information

- **Documentation**: [API Reference](https://pub.dev/documentation/csv_plus/latest/)
- **Issues**: [Report a bug](https://github.com/Masum-MSNR/csv_plus/issues)
- **Changelog**: See [CHANGELOG.md](CHANGELOG.md) for version history

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Masum-MSNR">Masum</a>
</p>
