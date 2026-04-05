import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/datetime.dart';

void main() {
  group('DateTimeHelper.parseTimestamp', () {
    test('returns int value directly', () {
      expect(DateTimeHelper.parseTimestamp(1700000000), 1700000000);
      expect(DateTimeHelper.parseTimestamp(0), 0);
    });

    test('returns DateTime millisecondsSinceEpoch', () {
      final dt = DateTime.utc(2026, 4, 4, 12, 0, 0);
      expect(DateTimeHelper.parseTimestamp(dt), dt.millisecondsSinceEpoch);
    });

    test('parses ISO 8601 string', () {
      final result = DateTimeHelper.parseTimestamp('2026-04-04T12:00:00Z');
      final expected = DateTime.utc(2026, 4, 4, 12, 0, 0).millisecondsSinceEpoch;
      expect(result, expected);
    });

    test('returns explicit defaultValue for null input', () {
      expect(DateTimeHelper.parseTimestamp(null, defaultValue: 42), 42);
    });

    test('returns explicit defaultValue for invalid string', () {
      expect(DateTimeHelper.parseTimestamp('not-a-date', defaultValue: 99), 99);
    });
  });

  group('DateTimeHelper.fromRfc3339', () {
    test('parses UTC string to UTC DateTime', () {
      final dt = DateTimeHelper.fromRfc3339('2026-04-04T12:00:00Z');
      expect(dt.isUtc, isTrue);
      expect(dt.year, 2026);
      expect(dt.month, 4);
      expect(dt.day, 4);
      expect(dt.hour, 12);
    });

    test('parses with toUtc=false returns local', () {
      final dt = DateTimeHelper.fromRfc3339(
        '2026-04-04T12:00:00Z',
        toUtc: false,
      );
      expect(dt.isUtc, isFalse);
    });

    test('parses offset timezone string', () {
      final dt = DateTimeHelper.fromRfc3339('2026-04-04T20:00:00+08:00');
      expect(dt.isUtc, isTrue);
      expect(dt.hour, 12); // 20:00+08:00 = 12:00 UTC
    });
  });

  group('DateTimeHelper.millisecondToDateTime', () {
    test('converts millis to UTC DateTime', () {
      final millis = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      final dt = DateTimeHelper.millisecondToDateTime(millis);
      expect(dt.isUtc, isTrue);
      expect(dt.year, 2026);
      expect(dt.month, 1);
      expect(dt.day, 1);
    });

    test('converts millis to local DateTime', () {
      final millis = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      final dt = DateTimeHelper.millisecondToDateTime(millis, isUtc: false);
      expect(dt.isUtc, isFalse);
    });

    test('handles zero millis', () {
      final dt = DateTimeHelper.millisecondToDateTime(0);
      expect(dt.year, 1970);
      expect(dt.month, 1);
      expect(dt.day, 1);
    });
  });

  group('DateTimeHelper.rfc3339ToMillisecond', () {
    test('converts RFC3339 to milliseconds', () {
      final expected = DateTime.utc(2026, 4, 4, 12, 0, 0).millisecondsSinceEpoch;
      expect(DateTimeHelper.rfc3339ToMillisecond('2026-04-04T12:00:00Z'), expected);
    });

    test('handles timezone offset in RFC3339', () {
      final result = DateTimeHelper.rfc3339ToMillisecond('2026-04-04T20:00:00+08:00');
      final expected = DateTime.utc(2026, 4, 4, 12, 0, 0).millisecondsSinceEpoch;
      expect(result, expected);
    });
  });

  group('DateTimeHelper.millisecondToRfc3339', () {
    test('converts millis to UTC RFC3339 string', () {
      final millis = DateTime.utc(2026, 4, 4, 12, 0, 0).millisecondsSinceEpoch;
      final result = DateTimeHelper.millisecondToRfc3339(millis);
      expect(result, contains('2026-04-04'));
      expect(result, endsWith('Z'));
    });

    test('converts millis to local RFC3339 string', () {
      final millis = DateTime.utc(2026, 4, 4, 12, 0, 0).millisecondsSinceEpoch;
      final result = DateTimeHelper.millisecondToRfc3339(millis, isUtc: false);
      expect(result, contains('2026'));
      // Local time should have offset like +08:00 or -05:00, not Z
      expect(result.endsWith('Z'), isFalse);
    });
  });

  group('DateTimeHelper.toRfc3339', () {
    test('formats UTC DateTime with Z suffix', () {
      final dt = DateTime.utc(2026, 4, 4, 12, 30, 45);
      final result = DateTimeHelper.toRfc3339(dt, isUtc: true);
      expect(result, startsWith('2026-04-04 12:30:45'));
      expect(result, endsWith('Z'));
    });

    test('formats local DateTime with offset', () {
      final dt = DateTime(2026, 4, 4, 12, 30, 45);
      final result = DateTimeHelper.toRfc3339(dt, isUtc: false);
      expect(result, contains('2026-04-04'));
      // Should contain timezone offset like +08:00
      expect(RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(result), isTrue);
    });
  });

  group('DateTimeHelper.formatDateTime', () {
    test('formats seconds timestamp with default pattern', () {
      // 2026-04-04 00:00:00 UTC in seconds
      final seconds = DateTime(2026, 4, 4).millisecondsSinceEpoch ~/ 1000;
      final result = DateTimeHelper.formatDateTime(seconds);
      expect(result, contains('2026'));
      expect(result, contains('04-04'));
    });

    test('formats with custom pattern', () {
      final seconds = DateTime(2026, 4, 4).millisecondsSinceEpoch ~/ 1000;
      final result = DateTimeHelper.formatDateTime(seconds, pattern: 'yyyy/MM/dd');
      expect(result, '2026/04/04');
    });
  });
}
