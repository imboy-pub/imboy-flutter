import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/utils/tsid_helper.dart';

void main() {
  group('TsidHelper.parseIdAsString', () {
    test('int 转 String', () {
      expect(TsidHelper.parseIdAsString(123456789012345), '123456789012345');
    });

    test('String 原样返回', () {
      expect(TsidHelper.parseIdAsString('abc123'), 'abc123');
    });

    test('null 返回空字符串', () {
      expect(TsidHelper.parseIdAsString(null), '');
    });

    test('TSID 大数字转 String', () {
      // 模拟 19 位 TSID
      const tsid = 1234567890123456789;
      expect(TsidHelper.parseIdAsString(tsid), '1234567890123456789');
    });
  });

  group('TsidHelper.parseIdAsInt', () {
    test('int 直接返回', () {
      expect(TsidHelper.parseIdAsInt(42), 42);
    });

    test('纯数字 String 转 int', () {
      expect(TsidHelper.parseIdAsInt('12345'), 12345);
    });

    test('hashids 格式返回 null', () {
      expect(TsidHelper.parseIdAsInt('abc123xyz'), null);
    });

    test('null 返回 null', () {
      expect(TsidHelper.parseIdAsInt(null), null);
    });

    test('空字符串返回 null', () {
      expect(TsidHelper.parseIdAsInt(''), null);
    });
  });

  group('TsidHelper.isTsid', () {
    test('int 是 TSID', () {
      expect(TsidHelper.isTsid(123), true);
    });

    test('纯数字 String 是 TSID', () {
      expect(TsidHelper.isTsid('123456'), true);
    });

    test('hashids 格式不是 TSID', () {
      expect(TsidHelper.isTsid('aB3xYz'), false);
    });

    test('空字符串不是 TSID', () {
      expect(TsidHelper.isTsid(''), false);
    });

    test('null 不是 TSID', () {
      expect(TsidHelper.isTsid(null), false);
    });
  });

  group('TsidHelper.extractTimestamp', () {
    test('从有效 TSID 提取时间戳', () {
      // 构造一个已知的 TSID:
      // timestamp_offset = 1000ms, node = 1, sequence = 0
      // id = (1000 << 21) | (1 << 11) | 0
      final id = (1000 << 21) | (1 << 11);
      final ts = TsidHelper.extractTimestamp(id);
      // 期望: 1735689600000 + 1000 = 1735689601000
      expect(ts, 1735689601000);
    });

    test('null 返回 null', () {
      expect(TsidHelper.extractTimestamp(null), null);
    });

    test('0 返回 null', () {
      expect(TsidHelper.extractTimestamp(0), null);
    });

    test('从 String TSID 提取时间戳', () {
      final id = (5000 << 21) | (2 << 11) | 100;
      final ts = TsidHelper.extractTimestamp(id.toString());
      expect(ts, 1735689605000);
    });
  });

  group('TsidHelper.extractDateTime', () {
    test('从 TSID 提取 DateTime', () {
      final id = (1000 << 21);
      final dt = TsidHelper.extractDateTime(id);
      expect(dt, isNotNull);
      expect(dt!.isUtc, true);
      expect(dt.millisecondsSinceEpoch, 1735689601000);
    });

    test('null 返回 null', () {
      expect(TsidHelper.extractDateTime(null), null);
    });
  });

  group('TsidHelper.idsEqual', () {
    test('相同 int 相等', () {
      expect(TsidHelper.idsEqual(123, 123), true);
    });

    test('相同 String 相等', () {
      expect(TsidHelper.idsEqual('abc', 'abc'), true);
    });

    test('int 和对应 String 相等', () {
      expect(TsidHelper.idsEqual(123, '123'), true);
    });

    test('不同值不相等', () {
      expect(TsidHelper.idsEqual(123, 456), false);
    });

    test('null 不等于任何值', () {
      expect(TsidHelper.idsEqual(null, 123), false);
      expect(TsidHelper.idsEqual(123, null), false);
    });

    test('两个 null 相等', () {
      expect(TsidHelper.idsEqual(null, null), true);
    });
  });
}
