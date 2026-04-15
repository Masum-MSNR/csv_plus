## Project Context
- This is a **pure Dart package** (`csv_plus`) for reading, writing, streaming, and manipulating CSV data.
- NOT a Flutter app. No UI, no state management, no networking.
- Must work on all Dart platforms: VM, Web, AOT.
- Zero external dependencies — pure Dart only.
- The library entry point is `lib/csv_plus.dart` (barrel export).

---

## 1. Architecture (Layered Package Structure)
- Follow layered architecture within `lib/src/`:

```
lib/src/
  core/        → CsvConfig, QuoteMode enum, CsvException hierarchy
  codec/       → CsvCodec (main facade), codec adapter for dart:convert
  encoder/     → CsvEncoder (stream), FastEncoder (batch, StringBuffer-based)
  decoder/     → CsvDecoder (stream, chunked state machine), FastDecoder (batch, byte-level), DelimiterDetector
  table/       → CsvTable (2D data structure), CsvRow (header-aware), CsvColumn, CsvSchema
  query/       → Filtering (where, firstWhere, distinct), sorting (sortBy, sortByMultiple)
  transform/   → Column/row manipulation (add, remove, rename, reorder), aggregation (sum, avg, groupBy)
  io/          → CsvFile (file read/write/stream/append) — dart:io isolated here
```

- Each file is a standalone Dart file with its own imports — do NOT use `part of` / `part` directives.
- Keep layers separate: encoder should not depend on decoder logic and vice versa.
- Decoder and encoder layers have two paths each: fast batch (maximum speed) and streaming (chunked, memory-efficient).

---

## 2. Performance & Memory
- **Dual-path architecture**: Batch operations use byte-level (`codeUnits`) parsing for speed; streaming uses chunked state machine for memory efficiency.
- Use `codeUnits` array indexing and ASCII constants in FastDecoder — no string ops in hot loops.
- Use labeled loops (`row_loop:`, `cell_loop:`) for efficient control flow in FastDecoder.
- Type inference by first-byte detection: `"` → string, `t`/`f` → bool, digit → number, `,`/`\n` → null.
- Per-call `StringBuffer` in encoder (not global) for thread safety.
- No `tryParse()` in hot loops — detect int vs double by scanning for `.` in byte array.
- No regex in decoder hot paths — direct codeUnit comparison only.
- Prefer `StringBuffer` over string concatenation (`+`) everywhere.
- Pre-size row lists when column count is known.
- Profile before optimizing — focus on measurable bottlenecks.

---

## 3. Naming Conventions
- Variables: camelCase
- Files: snake_case.dart
- Classes: PascalCase
- Constants: UPPER_SNAKE_CASE
- Private members: prefix with `_`

---

## 4. Code Style
- Avoid unnecessary comments.
- Only add comments for complex logic, important notes, or public API docs.
- Keep code clean and readable.
- Avoid over-engineering.
- `dynamic` is allowed in CSV cell values (mixed-type rows are expected), but avoid elsewhere.
- Public API classes and methods should have dartdoc comments (`///`).

---

## 5. Dependencies
- **Zero external dependencies** — this is a pure Dart library.
- Only dev dependencies: `lints`, `test`.
- Add dev packages using terminal: `dart pub add --dev <package_name>`
- Do NOT manually edit pubspec.yaml to add dependencies.

---

## 6. Error Handling
- Throw typed exceptions: `CsvException`, `CsvParseException`, `CsvValidationException`.
- Never silently swallow errors — at minimum log them.
- Validate input at public API boundaries only (CsvCodec, CsvTable constructors, CsvFile).
- Graceful handling of malformed CSV: unmatched quotes treated as literal characters (PapaParse behavior).

---

## 7. Modularity & File Size
- Keep code modular.
- Avoid large files.
- Maximum file length: 400–500 lines.
- Split large classes across multiple files if needed.

---

## 8. Testing
- All public API changes must have corresponding tests.
- Cover encode/decode round-trips for all types (String, int, double, bool, null).
- Test edge cases: BOM, Excel sep=, CRLF splits, escaped quotes, multi-char delimiters, empty input.
- Test streaming with chunk boundaries that split mid-field, mid-escape, mid-CRLF.
- Run `dart test` before committing.
- Run `dart analyze` after any code change and fix all issues before proceeding.
- Commit after every meaningful change with a clear, descriptive message.

---

## 9. Platform Compatibility
- Package must compile on all Dart platforms (VM, Web, AOT).
- `dart:io` usage must be isolated in `io/csv_file.dart` only.
- Core encode/decode/table functionality must not import `dart:io`.

---

## 10. General Rules
- Do not mix architecture styles.
- Avoid hardcoded values — use constants from `core/csv_config.dart`.
- Remove unused code.
- Keep code production-ready and scalable.
- Maintain backward compatibility for public API changes.