import 'dart:async';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('CsvDecoder (streaming)', () {
    const decoder = CsvDecoder();

    group('convert (batch)', () {
      test('simple CSV', () {
        final rows = decoder.convert('a,b\n1,2');
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('empty input', () {
        expect(decoder.convert(''), isEmpty);
      });

      test('single field', () {
        final rows = decoder.convert('hello');
        expect(rows, [
          ['hello'],
        ]);
      });

      test('quoted fields', () {
        final rows = decoder.convert('"a,b",c\n"d""e",f');
        expect(rows, [
          ['a,b', 'c'],
          ['d"e', 'f'],
        ]);
      });

      test('CRLF line endings', () {
        final rows = decoder.convert('a,b\r\n1,2\r\n3,4');
        expect(rows, [
          ['a', 'b'],
          [1, 2],
          [3, 4],
        ]);
      });

      test('dynamic typing', () {
        final rows = decoder.convert('1,2.5,true,false,hello,');
        expect(rows, [
          [1, 2.5, true, false, 'hello', null],
        ]);
      });

      test('with hasHeader config', () {
        final d = CsvDecoder(const CsvConfig(hasHeader: true));
        final rows = d.convert('name,age\nAlice,30');
        expect(rows, [
          ['Alice', 30],
        ]);
      });

      test('BOM stripped', () {
        final rows = decoder.convert('\uFEFFa,b\n1,2');
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('skipEmptyLines', () {
        final rows = decoder.convert('a,b\n\n1,2');
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });
    });

    group('bind (stream)', () {
      test('simple stream', () async {
        final stream = Stream.fromIterable(['a,b\n', '1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('chunk splitting mid-field', () async {
        final stream = Stream.fromIterable(['a,hel', 'lo\n1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a', 'hello'],
          [1, 2],
        ]);
      });

      test('chunk splitting mid-CRLF', () async {
        final stream = Stream.fromIterable(['a,b\r', '\n1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('chunk splitting mid-quoted field', () async {
        final stream = Stream.fromIterable(['"hel', 'lo",b\n1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['hello', 'b'],
          [1, 2],
        ]);
      });

      test('chunk splitting mid-escape', () async {
        final stream = Stream.fromIterable(['"a"', '"b",c\n1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a"b', 'c'],
          [1, 2],
        ]);
      });

      test('single character chunks', () async {
        final input = 'a,b\n1,2';
        final stream = Stream.fromIterable(input.split(''));
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('empty stream', () async {
        final rows = await decoder.bind(const Stream<String>.empty()).toList();
        expect(rows, isEmpty);
      });

      test('multi-char delimiter in stream', () async {
        final d = CsvDecoder(const CsvConfig(fieldDelimiter: '::'));
        final stream = Stream.fromIterable(['a::b\n', '1::2']);
        final rows = await d.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });
    });
  });
}
