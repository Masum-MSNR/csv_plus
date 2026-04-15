## 0.0.1

- Initial development release
- **Core**: `CsvConfig` with presets (default, excel, tsv, pipe), `QuoteMode`, `CsvException` hierarchy
- **Batch encoding**: `FastEncoder` with `encode`, `encodeStrings`, `encodeGeneric<T>`, `encodeMap`
- **Batch decoding**: `FastDecoder` with `decode` (type inference), `decodeStrings`, `decodeFlexible`, `decodeIntegers`, `decodeDoubles`, `decodeBooleans`
- **Streaming**: `CsvEncoder` and `CsvDecoder` as `StreamTransformer` implementations with `startChunkedConversion` sinks
- **Facade**: `CsvCodec` wrapping all encode/decode operations with shared config
- **dart:convert**: `CsvCodecAdapter` extending `Codec<List<List<dynamic>>, String>`
- **CsvTable**: Full 2D data structure with headers, filtering (`where`, `firstWhere`, `distinct`), sorting (`sortBy`, `sortByMultiple`), aggregation (`sum`, `avg`, `min`, `max`, `groupBy`), column manipulation (`addColumn`, `removeColumn`, `renameColumn`, `reorderColumns`), schema validation, `iterator`, `inferSchema`
- **CsvRow**: Header-aware row with dual access (index and name)
- **CsvColumn**: Column metadata with `inferredType`, `uniqueCount`, null stats
- **CsvSchema**: Schema definition with `validate`, `infer` factory
- **DelimiterDetector**: Auto-detection via frequency/consistency scoring, BOM, `sep=` hint
- **CsvFile**: File I/O with `read`, `readSync`, `stream`, `write`, `writeSync`, `writeRows`, `writeStream`, `append`
