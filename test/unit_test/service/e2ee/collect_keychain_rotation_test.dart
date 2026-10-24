/// C2t —— 收藏密钥链状态机测试（PLAN §6.5，v7.1）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/collect_keychain.dart';

void main() {
  CollectKeychainState boot() => CollectKeychainLogic.bootstrap();

  group('§6.5 轮换状态机', () {
    test('bootstrap：CKv1 存在，seal 允许', () {
      final s = boot();
      expect(s.activeVersion, 1);
      expect(CollectKeychainLogic.sealAllowed(s), isTrue);
    });

    test('beginRotation：立即停产 vN seal（ROTATING 门槛）', () {
      var s = boot();
      s = CollectKeychainLogic.beginRotation(s);
      expect(s.activeVersion, 2);
      // ROTATING 后（实现直接进入 rewrapRunning 分页阶段）不允许新 seal
      expect(CollectKeychainLogic.sealAllowed(s), isFalse);
      // 回 NORMAL（轮换完成）后恢复
      s = s.copyWith(phase: CollectRotationPhase.normal);
      expect(CollectKeychainLogic.sealAllowed(s), isTrue);
    });

    test('状态顺序违规 fail-closed', () {
      final s = boot();
      expect(
        () => CollectKeychainLogic.beginVerify(s),
        throwsA(isA<StateError>()),
      );
      final r = CollectKeychainLogic.beginRotation(s);
      expect(
        () => CollectKeychainLogic.peersConfirmed(r),
        throwsA(isA<StateError>()),
      );
    });

    test('VERIFY 掉队行回 RUNNING；完成后 PEERS_CONFIRMED', () {
      var s = CollectKeychainLogic.beginRotation(boot());
      s = CollectKeychainLogic.beginVerify(s);
      expect(s.phase, CollectRotationPhase.rewrapVerify);
      s = CollectKeychainLogic.backToRunning(s);
      expect(s.phase, CollectRotationPhase.rewrapRunning);
      s = CollectKeychainLogic.beginVerify(s);
      s = CollectKeychainLogic.peersConfirmed(s);
      expect(s.phase, CollectRotationPhase.peersConfirmed);
    });
  });

  group('§6.5 清除四前置', () {
    test('缺一不可：任一 false 不得清除', () {
      var s = CollectKeychainLogic.peersConfirmed(
        CollectKeychainLogic.beginVerify(
          CollectKeychainLogic.beginRotation(boot()),
        ),
      );
      final allTrue = ClearEligibility(
        verifyPassed: true,
        replicatedElsewhere: true,
        allPeersAcked: true,
        serverGateProven: true,
      );
      // 全成立 → 清除 v1
      final cleared = CollectKeychainLogic.clearOldVersion(s, 1, allTrue);
      expect(cleared.keys.map((k) => k.version), [2]);
      // 逐一缺项 → 原样保留
      for (var i = 0; i < 4; i++) {
        final flags = <bool>[true, true, true, true]..[i] = false;
        final kept = CollectKeychainLogic.clearOldVersion(
          s,
          1,
          ClearEligibility(
            verifyPassed: flags[0],
            replicatedElsewhere: flags[1],
            allPeersAcked: flags[2],
            serverGateProven: flags[3],
          ),
        );
        expect(kept.keys.length, 2, reason: '前置 $i 缺失时不得清除');
      }
    });

    test('拒绝清除当前活跃版本', () {
      var s = CollectKeychainLogic.peersConfirmed(
        CollectKeychainLogic.beginVerify(
          CollectKeychainLogic.beginRotation(boot()),
        ),
      );
      expect(
        () => CollectKeychainLogic.clearOldVersion(
          s,
          2,
          ClearEligibility(
            verifyPassed: true,
            replicatedElsewhere: true,
            allPeersAcked: true,
            serverGateProven: true,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('持久化 roundtrip（中断可恢复）', () {
    test('toJson/fromJson 状态无损', () {
      var s = CollectKeychainLogic.beginRotation(boot());
      s = CollectKeychainLogic.markPeerAck(s, 1, true);
      s = CollectKeychainLogic.beginVerify(s);
      final restored = CollectKeychainState.fromJson(
        Map<String, dynamic>.from(
          (s.toJson() as Map).map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
      expect(restored.activeVersion, s.activeVersion);
      expect(restored.phase, s.phase);
      expect(restored.peerAckedVersions[1], isTrue);
      expect(restored.keys.first.ckB64, s.keys.first.ckB64);
    });

    test('未知 phase 字段降级 normal（前向兼容）', () {
      final s = CollectKeychainState.fromJson(<String, dynamic>{
        'keys': <Object>[],
        'phase': 'future-x',
      });
      expect(s.phase, CollectRotationPhase.normal);
    });
  });
}
