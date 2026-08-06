// PolicyGate 可用性硬中断修复的守护测试。
//
// 缺陷：EncryptionModeService.refresh() 只在 App 启动时调用一次，失败即
// _initialized=false 且无人重试 → PolicyGate 对 C2C/C2G 永久 fail-closed 拒发，
// 用户在本进程生命周期内完全发不出消息（必须杀进程重启）。
//
// 修复方向不是放开闸门（严禁 fail-open / 静默降级明文），而是消除无谓阻断：
// 拉取失败进入有界退避重试，被拒的发送尝试按需触发重拉。
//
// 本文件覆盖两条关键路径：
//   1. 拉取失败 → 重试成功 → 可以发送；
//   2. 持续失败 → 仍然拒发，且 reason 明确（policy_not_initialized）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/service/encryption_mode.dart';

void main() {
  setUp(() {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  tearDown(() {
    EncryptionModeService.debugFetcher = null;
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  group('policy 拉取失败后重试成功 → 可以发送', () {
    test('首次失败拒发，重拉成功后 strict 部署返回 EncryptRequired', () async {
      var attempts = 0;
      EncryptionModeService.debugFetcher = () async {
        attempts++;
        if (attempts == 1) throw StateError('network down');
        return <String, dynamic>{'e2ee_mode': 'required'};
      };

      // 启动时那一次拉取失败。
      await EncryptionModeService.refresh();
      expect(attempts, 1);
      expect(EncryptionModeService.isInitialized, isFalse);

      // 此时发送被 fail-closed 拒掉（不是静默明文放行）。
      expect(
        () => PolicyGate.requireReadyForSend('C2C'),
        throwsA(isA<E2eeSecurityException>()),
      );

      // 重试成功后策略就绪，同一次发送尝试即可通过门。
      await EncryptionModeService.refresh();
      expect(attempts, 2);
      expect(EncryptionModeService.isInitialized, isTrue);

      final decision = PolicyGate.requireReadyForSend('C2C');
      expect(decision, isA<EncryptRequired>());
      expect((decision as EncryptRequired).mode, EncryptionMode.strictE2ee);
    });

    test('明文部署：重拉成功后 C2C 才允许明文（拉取成功前一律拒发）', () async {
      var attempts = 0;
      EncryptionModeService.debugFetcher = () async {
        attempts++;
        if (attempts == 1) throw StateError('policy endpoint 502');
        return <String, dynamic>{'e2ee_mode': 'optional'};
      };

      await EncryptionModeService.refresh();
      expect(
        () => PolicyGate.requireReadyForSend('C2C'),
        throwsA(isA<E2eeSecurityException>()),
        reason: '未确认部署为明文之前不得放行明文',
      );

      await EncryptionModeService.refresh();
      expect(PolicyGate.requireReadyForSend('C2C'), isA<PlaintextAllowed>());
    });

    test('被拒的发送尝试会触发按需重拉（不必等下一次冷启动）', () async {
      var attempts = 0;
      EncryptionModeService.debugFetcher = () async {
        attempts++;
        if (attempts == 1) throw StateError('network down');
        return <String, dynamic>{'e2ee_mode': 'required'};
      };

      await EncryptionModeService.refresh();
      expect(attempts, 1);

      // 退避首档 1s，尚未到期：这次拒发不会立刻再打端点（防止离线时刷爆）。
      expect(
        () => PolicyGate.requireReadyForSend('C2C'),
        throwsA(isA<E2eeSecurityException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(attempts, 1, reason: '退避窗口内不应重复请求');

      // 退避到期后，下一次被拒的发送尝试触发重拉并成功。
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(
        () => PolicyGate.requireReadyForSend('C2C'),
        throwsA(isA<E2eeSecurityException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(attempts, 2);
      expect(EncryptionModeService.isInitialized, isTrue);

      // 用户再点一次发送即可发出。
      expect(PolicyGate.requireReadyForSend('C2C'), isA<EncryptRequired>());
    });
  });

  group('policy 持续拉取失败 → 仍然拒发且错误明确', () {
    test('连续 5 次失败后 C2C/C2G 依旧抛 policy_not_initialized', () async {
      var attempts = 0;
      EncryptionModeService.debugFetcher = () async {
        attempts++;
        throw StateError('still offline');
      };

      for (var i = 0; i < 5; i++) {
        await EncryptionModeService.refresh(); // force: true，绕过退避
      }
      expect(attempts, 5);
      expect(EncryptionModeService.isInitialized, isFalse);
      expect(
        EncryptionModeService.current,
        EncryptionMode.plaintext,
        reason: '内部默认值可以是 plaintext，但绝不能因此被当作"已确认明文部署"',
      );

      for (final chatType in <String>['C2C', 'C2G']) {
        expect(
          () => PolicyGate.requireReadyForSend(chatType),
          throwsA(
            isA<E2eeSecurityException>().having(
              (e) => e.reason,
              'reason',
              'policy_not_initialized',
            ),
          ),
        );
      }
    });

    test('持续失败也不阻断非聊天类型（action/系统消息）', () async {
      EncryptionModeService.debugFetcher = () async {
        throw StateError('still offline');
      };
      await EncryptionModeService.refresh();

      expect(PolicyGate.requireReadyForSend('C2S'), isA<PlaintextAllowed>());
    });

    test('HTTP 拉取失败不会把已生效的 strict 策略降级为明文', () async {
      EncryptionModeService.debugFetcher = () async => <String, dynamic>{
        'e2ee_mode': 'required',
      };
      await EncryptionModeService.refresh();
      expect(EncryptionModeService.isInitialized, isTrue);

      EncryptionModeService.debugFetcher = () async {
        throw StateError('network down');
      };
      await EncryptionModeService.refresh();

      expect(EncryptionModeService.current, EncryptionMode.strictE2ee);
      expect(PolicyGate.requireReadyForSend('C2C'), isA<EncryptRequired>());
    });
  });

  group('并发去重', () {
    test('同时发起的多次 refresh 只打一次 policy 端点', () async {
      var attempts = 0;
      EncryptionModeService.debugFetcher = () async {
        attempts++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return <String, dynamic>{'e2ee_mode': 'required'};
      };

      await Future.wait(<Future<void>>[
        EncryptionModeService.refresh(),
        EncryptionModeService.refresh(),
        EncryptionModeService.refresh(),
      ]);

      expect(attempts, 1);
      expect(EncryptionModeService.isInitialized, isTrue);
    });
  });
}
