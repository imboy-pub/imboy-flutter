/// ADR 08 §4 威胁—守护测试可追溯矩阵（客户端骨架）。
///
/// B.2.1 建立的**映射骨架**：ADR 08 §4 的每个防御点绑定一个守护测试。
/// 已实现的在本文件跑真实断言；未实现的以 `skip` 占位并标注归属 Slice，
/// PR 删除守护测试时 review 立即可见。后端 grep 类守护（Erlang）不在 Dart
/// 测试内，用下表注明其 CI 位置。
///
/// | 防御点 | 威胁 | 守护测试 | 位置 / 状态 |
/// |---|---|---|---|
/// | 服务端零密码学 | T1,T3 | grep elib_cipher decrypt | 后端 CI(Erlang)，非本文件 |
/// | 私钥永不落 DB | T3 | private_key_encrypted DROP | 后端 migration，已落地 |
/// | Per-message PFS (Olm DR) | T5 | olm_pfs_old_session_cannot_decrypt | skip: B.1 真机/vodozemac 运行时 |
/// | Post-Compromise Security | T5 | olm_pcs_recovery | skip: B.1 真机 |
/// | AEAD (AES-256-GCM) | T4 | aes_gcm_tamper_fails | skip: B.5 |
/// | Ed25519 身份键签名 | T2,T4 | device_identity_signature_verify | skip: B.3 |
/// | Safety Number | T2,T8 | e2ee_safety_number | skip: B.3 (ADR06) |
/// | Signed Capabilities | T2 | capability_signature_forgery_fails | capability_negotiator_test ✅ |
/// | 本地降级告警 | T2 | capability_shrink_triggers_tofu_alert | skip: B.2 发送侧 |
/// | OTK 原子 claim | T7 | otk_concurrent_claim_uniqueness | 后端 EUnit，已落地(B.3) |
/// | room key 域一致性 | T7 | c2g_room_key_relayed_opaque | 后端 EUnit，已落地 |
/// | 消息重放/乱序 | T7 | message_replay_rejected | skip: B.5 (ADR05) |
/// | KDF 可迁移 | T6 | backup_kdf_version_migration | skip: B.5 |
/// | Trust State 审计 | T2,T8 | device_trust_state_change_audit_log | skip: B.3 |
/// | Device identity 版本单调 | T9 | device_identity_rollback_rejected | skip: B.3 |
/// | Megolm session rotate 单调 | T9 | megolm_old_session_rejected | skip: B.5 |
/// | **[B.2.1 新增] Olm pickle key CSPRNG** | T5 | olm_pickle_key_csprng | 本文件 ✅ |
/// | **[B.2.1 新增] Registry 路由完整性/无 fallback** | T2 | registry_routing_completeness | 本文件 ✅ |
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/olm_session_service.dart';

void main() {
  // ===== T5 — Olm pickle key CSPRNG（B.2.1，ADR 07 §2 / 08 T5）=====
  // pickle key 是解锁所有 Olm pickle 的主钥（Critical）。旧实现用时间戳低字节
  // 派生 → 可预测 → 设备攻陷时 pickle 静态加密可被暴力破解。守护其为 CSPRNG。
  group('olm_pickle_key_csprng (T5)', () {
    test('产出请求长度且两次调用不同（非可预测源）', () {
      final a = OlmSessionService.to.debugSecureBytes(32);
      final b = OlmSessionService.to.debugSecureBytes(32);
      expect(a.length, 32);
      expect(b.length, 32);
      // CSPRNG 两次 32 字节碰撞概率 2^-256；时间戳派生会高度相关
      expect(a, isNot(equals(b)));
    });

    test('字节分布跨越全域（时间戳低字节实现会大量重复）', () {
      final bytes = OlmSessionService.to.debugSecureBytes(256);
      // 时间戳 microsecondsSinceEpoch & 0xFF 生成 256 字节几乎同值；
      // CSPRNG 应有丰富取值（阈值宽松，仅防退化回时间戳源）
      expect(bytes.toSet().length, greaterThan(64));
    });
  });

  // ===== T2 — Registry 路由完整性 / 无静默 fallback（B.2.1，ADR 02 §4.3/§9）=====
  group('registry_routing_completeness (T2)', () {
    setUp(() {
      E2eeBootstrap.resetForTest();
      E2eeBootstrap.ensureRegistered();
    });
    tearDown(E2eeBootstrap.resetForTest);

    test('三套件 legacy 字符串各解析到已注册实现', () {
      for (final s in const [
        'OLM.V1',
        'MEGOLM.V1',
        'RSA-OAEP-256+AES-256-GCM',
      ]) {
        expect(
          E2eeProtocolRegistry.resolve({'e2ee_suite': s}).suite.protocol,
          isNotEmpty,
        );
      }
    });

    test('未注册套件(mls 占位)抛 StateError，不静默 fallback 到 RSA', () {
      expect(
        () => E2eeProtocolRegistry.resolve({'protocol': 'mls', 'version': '0'}),
        throwsA(isA<StateError>()),
      );
    });

    test('all() 恰含三套件，不含 MLS 占位', () {
      final protos = E2eeProtocolRegistry.all().map((s) => s.protocol).toSet();
      expect(protos, {'olm', 'megolm', 'rsa-oaep'});
    });
  });

  // ===== ADR 08 §4 其余客户端防御点占位（实现后转真实断言）=====
  group('pending threat guards (skeleton)', () {
    test(
      'olm_pfs_old_session_cannot_decrypt (T5)',
      () {},
      skip: 'B.1 真机/vodozemac 运行时',
    );
    test('olm_pcs_recovery (T5)', () {}, skip: 'B.1 真机');
    test('aes_gcm_tamper_fails (T4)', () {}, skip: 'B.5');
    test('device_identity_signature_verify (T2,T4)', () {}, skip: 'B.3');
    test('e2ee_safety_number (T2,T8)', () {}, skip: 'B.3 (ADR06)');
    test('capability_shrink_triggers_tofu_alert (T2)', () {}, skip: 'B.2 发送侧');
    test('message_replay_rejected (T7)', () {}, skip: 'B.5 (ADR05)');
    test('backup_kdf_version_migration (T6)', () {}, skip: 'B.5');
    test('device_trust_state_change_audit_log (T2,T8)', () {}, skip: 'B.3');
    test('device_identity_rollback_rejected (T9)', () {}, skip: 'B.3');
    test('megolm_old_session_rejected (T9)', () {}, skip: 'B.5');
  });
}
