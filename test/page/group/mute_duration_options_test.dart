// test/page/group/mute_duration_options_test.dart
//
// RED (slice-10a): MuteDurationOption 纯函数契约
// - 验证时长列表结构、排序、典型值
// - 零外部依赖（不依赖 i18n / Widget / Provider）
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_member/mute_duration_rules.dart';

void main() {
  group('muteDurationOptions', () {
    test('返回非空列表', () {
      expect(muteDurationOptions, isNotEmpty);
    });

    test('所有秒数 > 0', () {
      for (final opt in muteDurationOptions) {
        expect(opt.seconds, greaterThan(0));
      }
    });

    test('按秒数升序排列', () {
      final seconds = muteDurationOptions.map((o) => o.seconds).toList();
      for (var i = 0; i < seconds.length - 1; i++) {
        expect(seconds[i], lessThan(seconds[i + 1]),
            reason: 'index $i (${seconds[i]}) should be < index ${i + 1} (${seconds[i + 1]})');
      }
    });

    test('包含 5 分钟选项', () {
      expect(muteDurationOptions.any((o) => o.seconds == 300), isTrue);
    });

    test('包含 1 小时选项', () {
      expect(muteDurationOptions.any((o) => o.seconds == 3600), isTrue);
    });

    test('包含 1 天选项', () {
      expect(muteDurationOptions.any((o) => o.seconds == 86400), isTrue);
    });

    test('labelKey 非空', () {
      for (final opt in muteDurationOptions) {
        expect(opt.labelKey, isNotEmpty,
            reason: 'seconds=${opt.seconds} has empty labelKey');
      }
    });

    test('labelKey 唯一', () {
      final keys = muteDurationOptions.map((o) => o.labelKey).toList();
      expect(keys.toSet().length, equals(keys.length));
    });

    test('seconds 唯一', () {
      final secs = muteDurationOptions.map((o) => o.seconds).toList();
      expect(secs.toSet().length, equals(secs.length));
    });
  });

  group('MuteDurationOption', () {
    test('const 构造器 equality 基于值', () {
      const a = MuteDurationOption(seconds: 300, labelKey: 'mute5Min');
      const b = MuteDurationOption(seconds: 300, labelKey: 'mute5Min');
      expect(a, equals(b));
    });

    test('seconds 不同则不等', () {
      const a = MuteDurationOption(seconds: 300, labelKey: 'x');
      const b = MuteDurationOption(seconds: 600, labelKey: 'x');
      expect(a, isNot(equals(b)));
    });
  });
}
