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
  });
}
