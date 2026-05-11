import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

void main() {
  group('ModelParseUtils', () {
    test('parseModelString no longer rewrites literal null string', () {
      expect(parseModelString('null'), 'null');
      expect(parseModelNullableString('null'), 'null');
      expect(parseModelNullableString(''), isNull);
    });

    test('parseModelInt handles bool/string/num inputs', () {
      expect(parseModelInt(true), 1);
      expect(parseModelInt(false), 0);
      expect(parseModelInt('123'), 123);
      expect(parseModelInt('12.9'), 12);
      expect(parseModelInt('invalid', defaultValue: 7), 7);
    });

    test('parseModelDouble handles bool/string/num inputs', () {
      expect(parseModelDouble(true), 1.0);
      expect(parseModelDouble(false), 0.0);
      expect(parseModelDouble('0.75'), 0.75);
      expect(parseModelDouble(5), 5.0);
      expect(parseModelDouble('bad', defaultValue: 0.5), 0.5);
    });

    test('parseModelBool handles common representations', () {
      expect(parseModelBool(1), isTrue);
      expect(parseModelBool(0), isFalse);
      expect(parseModelBool('yes'), isTrue);
      expect(parseModelBool('off'), isFalse);
      expect(parseModelBool(null, defaultValue: true), isTrue);
    });

    test('parseModelDateTime handles seconds and milliseconds', () {
      final sec = parseModelDateTime(1767225600);
      final ms = parseModelDateTime('1767225600000');
      expect(sec.millisecondsSinceEpoch, 1767225600000);
      expect(ms.millisecondsSinceEpoch, 1767225600000);
    });

    test('parseModelNullableDateTime returns null for invalid values', () {
      expect(parseModelNullableDateTime(null), isNull);
      expect(parseModelNullableDateTime(''), isNull);
      expect(parseModelNullableDateTime('null'), isNull);
    });

    test('parseModelNullableDateTime handles seconds and milliseconds', () {
      final sec = parseModelNullableDateTime(1767225600);
      final ms = parseModelNullableDateTime('1767225600000');
      expect(sec?.millisecondsSinceEpoch, 1767225600000);
      expect(ms?.millisecondsSinceEpoch, 1767225600000);
    });

    test('parseModelJsonMap handles map and json string', () {
      expect(parseModelJsonMap({'a': 1}), {'a': 1});
      expect(parseModelJsonMap('{"a":1,"b":"2"}'), {'a': 1, 'b': '2'});
      expect(parseModelJsonMap('[]'), isNull);
    });

    test('parseModelJsonMap returns null for null/empty/invalid', () {
      expect(parseModelJsonMap(null), isNull);
      expect(parseModelJsonMap(''), isNull);
      expect(parseModelJsonMap('not json'), isNull);
    });

    test('parseModelStringList handles List input', () {
      expect(parseModelStringList([1, 'two', 3]), ['1', 'two', '3']);
      expect(parseModelStringList(<dynamic>[]), isEmpty);
    });

    test('parseModelStringList handles JSON string input', () {
      expect(parseModelStringList('["a","b","c"]'), ['a', 'b', 'c']);
      expect(parseModelStringList('[1,2,3]'), ['1', '2', '3']);
    });

    test('parseModelStringList returns null for null/empty/invalid', () {
      expect(parseModelStringList(null), isNull);
      expect(parseModelStringList(''), isNull);
      expect(parseModelStringList('not json'), isNull);
      expect(parseModelStringList('{"a":1}'), isNull);
    });

    test('parseModelString returns default for null/empty', () {
      expect(parseModelString(null), '');
      expect(parseModelString(null, defaultValue: 'x'), 'x');
      expect(parseModelString(''), '');
    });

    test('parseModelString converts non-string types', () {
      expect(parseModelString(42), '42');
      expect(parseModelString(true), 'true');
      expect(parseModelString(3.14), '3.14');
    });

    test('parseModelInt handles null with default', () {
      expect(parseModelInt(null), 0);
      expect(parseModelInt(null, defaultValue: -1), -1);
    });

    test('parseModelInt handles empty string with default', () {
      expect(parseModelInt(''), 0);
      expect(parseModelInt('', defaultValue: 5), 5);
    });

    test('parseModelInt handles string true/false', () {
      expect(parseModelInt('true'), 1);
      expect(parseModelInt('false'), 0);
      expect(parseModelInt('TRUE'), 1);
    });

    test('parseModelDouble handles null with default', () {
      expect(parseModelDouble(null), 0.0);
      expect(parseModelDouble(null, defaultValue: -1.5), -1.5);
    });

    test('parseModelDouble handles string int', () {
      expect(parseModelDouble('42'), 42.0);
    });

    test('parseModelDouble handles string true/false', () {
      expect(parseModelDouble('true'), 1.0);
      expect(parseModelDouble('false'), 0.0);
    });

    test('parseModelBool handles string variants', () {
      expect(parseModelBool('1'), isTrue);
      expect(parseModelBool('true'), isTrue);
      expect(parseModelBool('TRUE'), isTrue);
      expect(parseModelBool('on'), isTrue);
      expect(parseModelBool('0'), isFalse);
      expect(parseModelBool('false'), isFalse);
      expect(parseModelBool('no'), isFalse);
    });

    test('parseModelBool returns default for unrecognized string', () {
      expect(parseModelBool('maybe'), isFalse);
      expect(parseModelBool('maybe', defaultValue: true), isTrue);
    });

    test('parseModelDateTime handles ISO string', () {
      final dt = parseModelDateTime('2026-04-04T12:00:00Z');
      expect(dt.year, 2026);
      expect(dt.month, 4);
      expect(dt.day, 4);
    });

    test('parseModelDateTime returns default for null', () {
      final defaultDt = DateTime(2000, 1, 1);
      final result = parseModelDateTime(null, defaultValue: defaultDt);
      expect(result, defaultDt);
    });

    test('parseModelNullableDateTime handles ISO string', () {
      final dt = parseModelNullableDateTime('2026-04-04T12:00:00Z');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
    });

    test('parseModelNullableDateTime handles invalid string', () {
      expect(parseModelNullableDateTime('not-a-date'), isNull);
    });

    test('parseModelNullableString returns null for null', () {
      expect(parseModelNullableString(null), isNull);
    });

    test('parseModelNullableString returns string for non-empty', () {
      expect(parseModelNullableString('hello'), 'hello');
      expect(parseModelNullableString(42), '42');
    });
  });
}
