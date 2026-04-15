## 0.0.1

### Core
- `CsvConfig` — immutable configuration with presets: `CsvConfig()`, `.excel()`, `.tsv()`, `.pipe()`
- `CsvConfig.copyWith()` — create modified copies
- `QuoteMode` enum — `necessary`, `always`, `strings`
- `CsvException`, `CsvParseException`, `CsvValidationException` — typed error hierarchy

### Encoding
- `FastEncoder` — high-performance batch encoder with `encode()`, `encodeStrings()`, `encodeGeneric<T>()`, `encodeMap()`
- `CsvEncoder` — streaming encoder as `StreamTransformer` with `bind()`, `convert()`, `startChunkedConversion()`
- `CsvEncoder.encodeField()` — static helper for single-field quoting
- codeUnit-based `_needsQuoting()` for multi-char delimiter support

### Decoding
- `FastDecoder` — byte-level batch decoder with `codeUnits` parsing, labeled-loop control flow, first-byte type inference
- Decode variants: `decode()`, `decodeStrings()`, `decodeFlexible()`, `decodeIntegers()`, `decodeDoubles()`, `decodeBooleans()`
- `CsvDecoder` — chunked state-machine streaming decoder with `bind()`, `convert()`, `startChunkedConversion()`
- Handles chunk boundaries splitting mid-field, mid-escape, mid-CRLF
- `DelimiterDetector` — frequency/consistency scoring across candidates `[, ; \t |]`, BOM strip, `sep=` hint

### Facade
- `CsvCodec` — main API with all decode/encode methods, presets, auto-detection
- `CsvCodec.decodeToTable()`, `decodeMap()`, `encodeMap()`
- `CsvCodec.decoder` / `encoder` — streaming transformer getters
- `CsvCodecAdapter` — `Codec<List<List<dynamic>>, String>` for `dart:convert` pipelines and `.fuse()`
- `csvPlus`, `csvExcel`, `csvTsv` — global convenience instances

### CsvTable (50+ methods)
- **Constructors:** `CsvTable()`, `.withHeaders()`, `.fromData()`, `.fromMaps()`, `.parse()`, `.empty()`
- **Access:** `operator []`, `cell()`, `cellByName()`, `setCell()`, `setCellByName()`, `column()`, `columnAt()`, `getColumn()`, `getColumnAt()`
- **Row ops:** `addRow()`, `addRowFromMap()`, `addRows()`, `insertRow()`, `removeRow()`, `removeWhere()`
- **Column ops:** `addColumn()`, `insertColumn()`, `removeColumn()`, `removeColumnAt()`, `renameColumn()`, `reorderColumns()`
- **Query:** `where()`, `firstWhere()`, `any()`, `every()`, `range()`, `take()`, `skip()`, `distinct()`
- **Sort:** `sortBy()`, `sortByIndex()`, `sortByMultiple()`, `sort()`
- **Transform:** `transformColumn()`, `map()`, `fold<T>()`
- **Aggregate:** `count()`, `sum()`, `avg()`, `min()`, `max()`, `groupBy()`
- **Export:** `toList()`, `toMaps()`, `toCsv()`, `toString()`, `toFormattedString()`, `copy()`
- **Validation:** `validate()`, `conformsTo()`, `inferSchema()`

### CsvRow
- Dual-mode access: `row[0]` (int) and `row['name']` (String)
- `set()`, `headerMap`, `hasHeaders`, `headers`, `containsHeader()`, `toMap()`, `getHeaderName()`, `toString()`

### CsvColumn
- Column descriptor with `name`, `index`, `values`, `inferredType`, `nonNullCount`, `nullCount`, `uniqueCount`

### CsvSchema & ColumnDef
- Schema definition with `columns`, `allowExtraColumns`, `allowMissingColumns`
- `CsvSchema.infer()` — infer types and nullability from data
- `validate()` — check required columns, types, nullability, patterns, custom validators
- `ColumnDef` with `name`, `type`, `required`, `nullable`, `pattern`, `validator`

### CsvFile (dart:io)
- Static methods: `read()`, `readSync()`, `stream()`, `write()`, `writeSync()`, `writeRows()`, `writeStream()`, `append()`
- Uses `utf8.decoder` for stream operations
- Isolated in `io/csv_file.dart` — core library stays platform-independent
