import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('CsvEncoder (streaming)', () {
    const encoder = CsvEncoder();

    group('convert (batch)', () {
      test('simple rows', () {
        final csv = encoder.convert([
          ['a', 'b'],
          [1, 2],
        ]);
        expect(csv, 'a,b\r\n1,2');
      });

      test('empty rows', () {
        expect(encoder.convert([]), '');
      });

      test('with BOM', () {
        final e = CsvEncoder(const CsvConfig(addBom: true));
        final csv = e.convert([
          ['a'],
        ]);
        expect(csv.codeUnitAt(0), 0xFEFF);
        expect(csv.substring(1), 'a');
      });

      test('quoting necessary', () {
        final csv = encoder.convert([
          ['hello, world', 'normal'],
        ]);
        expect(csv, '"hello, world",normal');
      });

      test('null values', () {
        final csv = encoder.convert([
          [null, 'b'],
        ]);
        expect(csv, ',b');
      });

      test('quote mode always', () {
        final e = CsvEncoder(const CsvConfig(quoteMode: QuoteMode.always));
        final csv = e.convert([
          ['a', 1],
        ]);
        expect(csv, '"a","1"');
      });
    });

    group('bind (stream)', () {
      test('streams rows', () async {
        final stream = Stream.fromIterable([
          ['a', 'b'],
          [1, 2],
          [3, 4],
        ]);
        final chunks = await encoder.bind(stream).toList();
        expect(chunks.length, 3);
        expect(chunks[0], 'a,b');
        expect(chunks[1], '\r\n1,2');
        expect(chunks[2], '\r\n3,4');
      });

      test('empty stream', () async {
        final chunks =
            await encoder.bind(const Stream<List<dynamic>>.empty()).toList();
        expect(chunks, isEmpty);
      });
    });
  });
}
