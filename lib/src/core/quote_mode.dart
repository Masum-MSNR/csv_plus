/// When to quote fields during CSV encoding.
enum QuoteMode {
  /// Quote only when field contains delimiter, newline, quote char,
  /// or has leading/trailing spaces.
  necessary,

  /// Quote every field unconditionally.
  always,

  /// Quote only fields of type [String]. Numbers, bools, null remain unquoted.
  strings,
}
