import 'dart:io';

import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/datetime.dart';

void main() {
  group('local display of an instant', () {
    const expectedByZone = {
      'UTC': '2020-09-13 12:26',
      'Asia/Shanghai': '2020-09-13 20:26',
      'Asia/Kathmandu': '2020-09-13 18:11',
      'America/New_York': '2020-09-13 08:26',
    };
    final expected = expectedByZone[Platform.environment['TZ']];
    final utc = DateTime.parse('2020-09-13T12:26:40Z');

    test('explicit absolute display uses device local civil time', () {
      final localExpected =
          expected ?? DateFormat('yyyy-MM-dd HH:mm').format(utc.toLocal());
      expect(
        DateTimeHelper.dateTimeFmt(
          utc,
          relative: false,
          pattern: 'yyyy-MM-dd HH:mm',
        ),
        localExpected,
      );
      expect(
        DateTimeHelper.dateTimeFmt(
          DateTime.parse('2020-09-13T20:26:40+08:00'),
          relative: false,
          pattern: 'yyyy-MM-dd HH:mm',
        ),
        localExpected,
      );
    });

    test(
      'old relative fallback and chat formatter agree with local display',
      () {
        final localExpected =
            expected ?? DateFormat('y-MM-dd HH:mm').format(utc.toLocal());
        expect(DateTimeHelper.dateTimeFmt(utc), localExpected);
        expect(DateTimeHelper.dateTimeFmt(utc.toLocal()), localExpected);
        expect(RelativeDateFormat().format(utc), localExpected);
      },
    );

    test('two-to-seven-day fallback uses local fields', () {
      final instant = DateTime.now().toUtc().subtract(const Duration(days: 3));
      expect(
        DateTimeHelper.dateTimeFmt(instant),
        DateFormat('MM-dd HH:mm').format(instant.toLocal()),
      );
    });

    test('recent elapsed display is representation independent', () {
      final instant = DateTime.now().toUtc().subtract(
        const Duration(minutes: 10),
      );
      expect(
        DateTimeHelper.dateTimeFmt(instant),
        DateTimeHelper.dateTimeFmt(instant.toLocal()),
      );
    });
  });

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
      final expected = DateTime.utc(
        2026,
        4,
        4,
        12,
        0,
        0,
      ).millisecondsSinceEpoch;
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
      final expected = DateTime.utc(
        2026,
        4,
        4,
        12,
        0,
        0,
      ).millisecondsSinceEpoch;
      expect(
        DateTimeHelper.rfc3339ToMillisecond('2026-04-04T12:00:00Z'),
        expected,
      );
    });

    test('handles timezone offset in RFC3339', () {
      final result = DateTimeHelper.rfc3339ToMillisecond(
        '2026-04-04T20:00:00+08:00',
      );
      final expected = DateTime.utc(
        2026,
        4,
        4,
        12,
        0,
        0,
      ).millisecondsSinceEpoch;
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

    test('R21-B：毫秒不丢失（209ms 输出 .209xxx，不是 .000209）', () {
      // 计划 6.1 T1 瞬间 + 209ms 37µs。
      final dt = DateTime.utc(2026, 9, 16, 23, 6, 40, 209, 37);
      final result = DateTimeHelper.toRfc3339(dt, isUtc: true);
      expect(result, startsWith('2026-09-16 23:06:40.209037'));
      expect(result, endsWith('Z'));
      // 旧 bug 形态（microsecond 顶到小数位）不可再出现。
      expect(result, isNot(contains('.000209')));
    });

    test('R21-B：整秒输出 .000000，与毫秒位无歧义', () {
      final dt = DateTime.utc(2026, 9, 16, 23, 6, 40);
      expect(
        DateTimeHelper.toRfc3339(dt, isUtc: true),
        '2026-09-16 23:06:40.000000Z',
      );
    });
  });

  group('ApiTime.parseEpochSeconds / parseEpochMillis (R21-2)', () {
    // 计划 6.1 T1 瞬间：秒 1789600000 == 2026-09-16T23:06:40.000Z
    test('seconds are converted to millis by contract', () {
      expect(ApiTime.parseEpochSeconds(1789600000), 1789600000000);
      expect(ApiTime.parseEpochSeconds('1789600000'), 1789600000000);
      expect(ApiTime.parseEpochSeconds(1789600000.0), 1789600000000);
    });

    test('millis are used as-is, never multiplied', () {
      expect(ApiTime.parseEpochMillis(1789600000000), 1789600000000);
      expect(ApiTime.parseEpochMillis('1789600000000'), 1789600000000);
    });

    test('zero and negative epochs are valid instants', () {
      expect(ApiTime.parseEpochSeconds(0), 0);
      expect(ApiTime.parseEpochSeconds(-1), -1000);
      expect(ApiTime.parseEpochMillis(0), 0);
      expect(ApiTime.parseEpochMillis(-1000), -1000);
    });

    test('overflowing seconds return null instead of wrapping', () {
      expect(ApiTime.parseEpochSeconds(9223372036854775807), isNull);
      expect(ApiTime.parseEpochSeconds(-9223372036854775807), isNull);
    });
  });

  group('ApiTime failure semantics (R21-1)', () {
    test('null / empty / invalid inputs return null, never now', () {
      final nowMs = DateTimeHelper.millisecond();
      expect(ApiTime.parseEpochSeconds(null), isNull);
      expect(ApiTime.parseEpochSeconds(''), isNull);
      expect(ApiTime.parseEpochSeconds('abc'), isNull);
      expect(ApiTime.parseEpochSeconds(3.5), isNull);
      expect(ApiTime.parseEpochSeconds(true), isNull);
      expect(ApiTime.parseEpochSeconds(<Object?>[]), isNull);

      expect(ApiTime.parseEpochMillis(null), isNull);
      expect(ApiTime.parseEpochMillis('1e3'), isNull);

      expect(ApiTime.parseIsoZoned(''), isNull);
      expect(ApiTime.parseIsoZoned('not-a-date'), isNull);

      expect(ApiTime.parseDateOnly('2026-9-16'), isNull);
      expect(ApiTime.parseDateOnly('2026-09-16T00:00:00Z'), isNull);
      expect(ApiTime.parseDateOnly('2026-02-30'), isNull);

      expect(ApiTime.parseDurationSeconds(null), isNull);
      expect(ApiTime.parseDurationMillis('abc'), isNull);
      // 显式哨兵：调用方按合同用 ?? 0 表达"未知"，与 now 无关
      expect(ApiTime.parseEpochSeconds(null) ?? 0, 0);
      expect(ApiTime.parseEpochSeconds(null) ?? 0, isNot(nowMs));
    });

    test('pure digit strings never enter the ISO parser', () {
      expect(ApiTime.parseIsoZoned('1789600000000'), isNull);
      expect(ApiTime.parseIsoZoned('1789600000'), isNull);
      expect(ApiTime.parseIsoZoned('20260916T230640Z'), isNull);
    });
  });

  group('ApiTime.parseIsoZoned (R21-3)', () {
    test('Z and +08:00 offset denote the same instant (T1)', () {
      final zonedZ = ApiTime.parseIsoZoned('2026-09-16T23:06:40.000Z');
      final zonedOffset = ApiTime.parseIsoZoned('2026-09-17T07:06:40+08:00');
      expect(zonedZ, isNotNull);
      expect(zonedOffset, isNotNull);
      expect(zonedZ!.millisecondsSinceEpoch, 1789600000000);
      expect(zonedOffset!.millisecondsSinceEpoch, 1789600000000);
      expect(zonedZ, zonedOffset);
    });

    test('all explicit entries agree on the same instant (T1)', () {
      const instantMs = 1789600000000;
      expect(ApiTime.parseEpochSeconds(1789600000), instantMs);
      expect(ApiTime.parseEpochMillis(instantMs), instantMs);
      expect(
        ApiTime.parseIsoZoned('2026-09-16T23:06:40.000Z')!
            .millisecondsSinceEpoch,
        instantMs,
      );
      expect(
        ApiTime.parseIsoZoned('2026-09-17T07:06:40+08:00')!
            .millisecondsSinceEpoch,
        instantMs,
      );
    });

    test('offset without colon is accepted; fractional seconds preserved', () {
      final dt = ApiTime.parseIsoZoned('2026-09-17T07:06:40.500+0800');
      expect(dt, isNotNull);
      expect(dt!.millisecondsSinceEpoch, 1789600000500);
    });

    test('space-separated local RFC3339 form with offset is accepted', () {
      // 本仓 toRfc3339 生成的 'yyyy-MM-dd HH:mm:ss.SSSSSS±HH:MM' 形态
      final dt = ApiTime.parseIsoZoned('2026-09-17 07:06:40.000+08:00');
      expect(dt, isNotNull);
      expect(dt!.millisecondsSinceEpoch, 1789600000000);
    });

    test('input without zone returns null, never guesses local time', () {
      expect(ApiTime.parseIsoZoned('2026-09-16T23:06:40'), isNull);
      expect(ApiTime.parseIsoZoned('2026-09-16 23:06:40'), isNull);
      expect(ApiTime.parseIsoZoned('2026-09-16'), isNull);
    });
  });

  group('ApiTime.parseDateOnly (R21-4)', () {
    test('plain calendar date parses to UTC midnight, TZ-independent', () {
      final dt = ApiTime.parseDateOnly('2026-09-16');
      expect(dt, DateTime.utc(2026, 9, 16));
      expect(dt!.isUtc, isTrue);
      expect(dt.hour, 0);
      expect(dt.minute, 0);
    });

    test('leap day validity follows the calendar', () {
      expect(ApiTime.parseDateOnly('2024-02-29'), isNotNull);
      expect(ApiTime.parseDateOnly('2026-02-29'), isNull);
      expect(ApiTime.parseDateOnly('2000-02-29'), isNotNull);
      expect(ApiTime.parseDateOnly('1900-02-29'), isNull);
    });

    test('same DateOnly input is stable across zones', () {
      // 值由 UTC 构造，与进程 TZ 无关；两个入口重读结果一致（不变性）
      expect(
        ApiTime.parseDateOnly('2026-09-16'),
        ApiTime.parseDateOnly('2026-09-16'),
      );
    });
  });

  group('ApiTime.parseDurationSeconds / parseDurationMillis', () {
    test('durations carry their contracted unit', () {
      expect(ApiTime.parseDurationSeconds(90), const Duration(seconds: 90));
      expect(ApiTime.parseDurationSeconds('90'), const Duration(seconds: 90));
      expect(
        ApiTime.parseDurationMillis(1500),
        const Duration(milliseconds: 1500),
      );
      expect(
        ApiTime.parseDurationMillis('1500'),
        const Duration(milliseconds: 1500),
      );
      // 同一数值按不同单位入口得到不同 duration，不按量级猜
      expect(
        ApiTime.parseDurationSeconds(1500),
        isNot(ApiTime.parseDurationMillis(1500)),
      );
    });

    test('invalid duration inputs return null', () {
      expect(ApiTime.parseDurationSeconds(null), isNull);
      expect(ApiTime.parseDurationSeconds(''), isNull);
      expect(ApiTime.parseDurationMillis(true), isNull);
      expect(ApiTime.parseDurationSeconds(1.5), isNull);
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
      final result = DateTimeHelper.formatDateTime(
        seconds,
        pattern: 'yyyy/MM/dd',
      );
      expect(result, '2026/04/04');
    });
  });
}
