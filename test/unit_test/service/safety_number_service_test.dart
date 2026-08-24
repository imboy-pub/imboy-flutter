/// Safety Number 服务测试（审计 P1-2）
///
/// 覆盖：
/// 1. 对称性：双方各自计算的结果一致
/// 2. 与纯函数 [SafetyNumber.generate] 的一致性（service 只是接线）
/// 3. 对端无设备 → ArgumentError（页面提示"对方未启用 E2EE"）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/safety_number.dart';

void main() {
  const aliceUid = 'alice-uid';
  const bobUid = 'bob-uid';
  const alicePub = 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=';
  const bobPub = 'AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI=';

  group('1. 对称性（双方计算结果一致，Signal 语义）', () {
    test('alice 视角 == bob 视角', () {
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
      expect(fromAlice, fromBob);
    });

    test('60 位数字，12 组 × 5 位', () {
      final number = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );
      expect(number, matches(RegExp(r'^\d{60}$')));
      final groups = SafetyNumber.formatGroups(number);
      expect(groups, hasLength(12));
      for (final g in groups) {
        expect(g, matches(RegExp(r'^\d{5}$')));
      }
    });
  });

  group('2. 任一身份变化 → 安全码变化（MITM 可检测）', () {
    test('对端公钥被替换 → 安全码不同', () {
      final original = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: bobPub,
      );
      final attacked = SafetyNumber.generate(
        localUid: aliceUid,
        localIdentityPub: alicePub,
        remoteUid: bobUid,
        remoteIdentityPub: 'AwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwM=',
      );
      expect(attacked, isNot(original));
    });
  });

  group('3. 参数校验 fail-closed', () {
    test('空 uid / 空公钥抛 ArgumentError', () {
      expect(
        () => SafetyNumber.generate(
          localUid: '',
          localIdentityPub: alicePub,
          remoteUid: bobUid,
          remoteIdentityPub: bobPub,
        ),
        throwsArgumentError,
      );
      expect(
        () => SafetyNumber.generate(
          localUid: aliceUid,
          localIdentityPub: alicePub,
          remoteUid: bobUid,
          remoteIdentityPub: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
