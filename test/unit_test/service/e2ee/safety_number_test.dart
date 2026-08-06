/// S4: Safety Number（安全码）— TDD 测试
///
/// Signal 风格带外验证：双方各算 60 位数字指纹，面对面/电话比对。
/// 验证：
/// - 确定性：相同输入 → 相同输出
/// - 对称性：A 算 B == B 算 A（排序保证）
/// - 变化检测：任一方 identity 变化 → 安全码变化
/// - 格式：60 位纯数字，12 组 × 5 位
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee/safety_number.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 测试用 identity keys（合法 base64，32 字节）
  const aliceUid = '100';
  const alicePub = 'YWxpY2UtaWRlbnRpdHktcHViLWtleS0zMg==';
  const bobUid = '200';
  const bobPub = 'Ym9iLWlkZW50aXR5LXB1Yi1rZXktMzIwMA==';

  group('SafetyNumber 格式', () {
    test('输出 60 位纯数字', () {
      final sn = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );

      expect(sn.length, equals(60));
      expect(RegExp(r'^\d{60}$').hasMatch(sn), isTrue);
    });

    test('formatGroups 返回 12 组 × 5 位', () {
      final sn = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );
      final groups = SafetyNumber.formatGroups(sn);

      expect(groups.length, equals(12));
      for (final g in groups) {
        expect(g.length, equals(5));
        expect(RegExp(r'^\d{5}$').hasMatch(g), isTrue);
      }
    });
  });

  group('SafetyNumber 确定性', () {
    test('相同输入 → 相同输出（多次调用）', () {
      final sn1 = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );
      final sn2 = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );

      expect(sn1, equals(sn2));
    });
  });

  group('SafetyNumber 对称性', () {
    test('A 算 B == B 算 A（UID 排序保证）', () {
      final fromAlice = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );
      final fromBob = SafetyNumber.generate(
        localUid: bobUid,
        localIdentityPub: bobPub,
        remoteUid: aliceUid,
        remoteIdentityPub: alicePub,
      );

      expect(fromAlice, equals(fromBob));
    });
  });

  group('SafetyNumber 变化检测', () {
    test('远端 identity 变化 → 安全码变化', () {
      final original = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );

      // Bob 换机：新 identity key
      const bobNewPub = 'Ym9iLW5ldy1kZXZpY2Uta2V5LTMwMjA=';
      final changed = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobNewPub,
      );

      expect(changed, isNot(equals(original)));
    });

    test('本端 identity 变化 → 安全码变化', () {
      final original = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );

      const aliceNewPub = 'YWxpY2UtcmVpbnN0YWxsLWtleS0zMDIw';
      final changed = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: aliceNewPub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );

      expect(changed, isNot(equals(original)));
    });

    test('UID 变化 → 安全码变化（防身份冒充）', () {
      final original = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );

      final changed = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: '999', // 不同 UID
        remoteIdentityPub: bobPub,
      );

      expect(changed, isNot(equals(original)));
    });
  });

  group('SafetyNumber 边界', () {
    test('空 UID 抛 ArgumentError（fail-closed）', () {
      expect(
        () => SafetyNumber.generate(
          localUid: '',
          localIdentityPub: alicePub,
          remoteUid: bobUid,
          remoteIdentityPub: bobPub,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('空 identity key 抛 ArgumentError（fail-closed）', () {
      expect(
        () => SafetyNumber.generate(
          localUid: aliceUid,
          localIdentityPub: '',
          remoteUid: bobUid,
          remoteIdentityPub: bobPub,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
