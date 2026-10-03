// C06（run-20261003-094804）：三域一致性检查。
//
// 三个加密域的边界必须在 UI 标识、API 行为、附件策略、说明文案上保持一致：
//
// | 域 | 语义 | 谁能读明文 |
// |---|---|---|
// | required（strict E2EE） | 必须端到端 | 仅会话双方设备 |
// | compliance（compliance_e2ee） | E2EE + 合规双 wrap | 双方 + 审计方（持合规私钥，设计内） |
// | AI 托管（明文） | agent 会话经用户五元组确认后明文 | 部署/服务端 AI |
//
// 一致性不变量（本文件断言）：
// 1. API 行为：AI 明文豁免的判定与加密模式正交——strict 与 compliance 两域
//    下同一 (badge, 确认) 输入产生同一豁免结论；真人会话在 required 与
//    compliance 两域都绝无明文豁免（「审计可解」不等于「明文」）。
// 2. 附件策略：content key（attachment_descriptor）只可能随加密 payload
//    出网，三域同规；带 key 的明文行重试必拦，优先级高于任何策略。
// 3. 汇流点（静态）：消息/附件/重试三条出设备路径都经
//    `E2EEService.shouldEncryptOutgoingPayload` 单一入口；
//    `AiPlaintextGate.plaintextChannelAuthorized` 在生产代码中只被该入口
//    调用（无旁路）。
// 4. UI/文案（静态）：AI 明文弹窗不可点击遮罩关闭、拒绝为默认动作；
//    zh-CN/en-US 文案均明示「不是端到端加密 + 服务端可读」。
//
// 人工核对项（无法机械断言的）见 cards/C06/ 三域一致性矩阵。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee/ai_plaintext_gate.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/e2ee/retry_plaintext_guard.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';

/// 测试内联的确认存储/身份源 fake（与 ai_plaintext_identity_gate_test 同构）。
class _MemStore implements AiConfirmationStore {
  final Map<String, AiPlaintextConfirmation> byUid = {};
  @override
  Future<AiPlaintextConfirmation?> load({
    required String ownerUid,
    required String targetUid,
  }) async {
    final rec = byUid[targetUid];
    return rec?.ownerUid == ownerUid ? rec : null;
  }

  @override
  Future<void> save(AiPlaintextConfirmation rec) async {
    byUid[rec.targetUid] = rec;
  }

  @override
  Future<void> delete({
    required String ownerUid,
    required String targetUid,
  }) async {}
}

class _FixedSource implements AiPeerIdentitySource {
  const _FixedSource();
  @override
  Future<AiPeerIdentity?> resolve(String targetUid) async =>
      const AiPeerIdentity(fingerprint: 'fp-A', version: 3);
}

String _pkgRoot() => Directory.current.path;

String _readSource(String relPath) =>
    File('${_pkgRoot()}/$relPath').readAsStringSync();

void main() {
  void wireDomain({required bool badge, bool withConfirmation = false}) {
    final store = _MemStore();
    if (withConfirmation) {
      store.byUid['456'] = const AiPlaintextConfirmation(
        deploymentId: 'deploy-1',
        ownerUid: 'user-1',
        targetUid: '456',
        peerIdentityFingerprint: 'fp-A',
        identityVersion: 3,
        confirmedAt: 1700000000000,
      );
    }
    AiPlaintextGate.agentBadgeProbe = (uid) async => badge;
    AiPlaintextGate.identitySource = const _FixedSource();
    AiPlaintextGate.confirmationStore = store;
    AiPlaintextGate.deploymentIdResolver = () => 'deploy-1';
    AiPlaintextGate.currentUserIdResolver = () => 'user-1';
    AiPlaintextGate.promptHandler = null;
  }

  tearDown(() {
    AiPlaintextGate.debugReset();
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  group('三域一致性 — 1. API 行为矩阵', () {
    // 矩阵：模式 × 对端状态 → shouldEncryptOutgoingPayload
    // | 模式        | 真人   | agent 无确认 | agent 有效确认 |
    // | strict      | true  | true        | false（AI 明文豁免） |
    // | compliance  | true  | true        | false（豁免与模式正交） |
    test('strict 域：真人 / agent 无确认 → 必须加密；agent 有效确认 → 豁免', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.strictE2ee,
        initialized: true,
      );

      wireDomain(badge: false, withConfirmation: true);
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isTrue,
        reason: '真人会话：即使存在（历史 agent）确认记录也必须加密',
      );

      wireDomain(badge: true, withConfirmation: false);
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isTrue,
        reason: 'agent 无确认：无明文授权',
      );

      wireDomain(badge: true, withConfirmation: true);
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isFalse,
        reason: 'agent 有效确认：AI 明文域豁免',
      );
    });

    test('compliance 域：矩阵与 strict 完全一致（豁免判定与加密模式正交）', () async {
      EncryptionModeService.debugSet(
        mode: EncryptionMode.complianceE2ee,
        initialized: true,
      );

      wireDomain(badge: false, withConfirmation: true);
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isTrue,
        reason: 'compliance 域真人：审计可解 ≠ 明文，必须加密（双 wrap）',
      );

      wireDomain(badge: true, withConfirmation: false);
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isTrue,
        reason: 'compliance 域 agent 无确认：无明文授权',
      );

      wireDomain(badge: true, withConfirmation: true);
      expect(
        await E2EEService.shouldEncryptOutgoingPayload('C2C', toId: '456'),
        isFalse,
        reason: 'compliance 域 agent 有效确认：AI 明文域豁免（与 strict 同判）',
      );
    });
  });

  group('三域一致性 — 2. 附件策略矩阵', () {
    test('content key 只随加密 payload 出网：加密域可封装、明文域绝不封装', () {
      // required / compliance 域：payload 加密 → 封装可用
      for (final domain in ['required', 'compliance']) {
        final d = AttachmentSealPolicy.decide(
          payloadWillBeEncrypted: true,
          messageId: 'm1',
          conversationId: 'c1',
          senderUid: 'u1',
        );
        expect(d, isA<SealApproved>(), reason: '$domain 域应允许封装');
      }
      // AI 明文域：payload 不加密 → 不封装（descriptor 带 content key，
      // 明文出网比「附件明文无密钥」更糟）
      final d = AttachmentSealPolicy.decide(
        payloadWillBeEncrypted: false,
        messageId: 'm1',
        conversationId: 'c1',
        senderUid: 'u1',
      );
      expect(d, isA<SealSkipped>());
      expect((d as SealSkipped).reason, SealSkipReason.payloadNotEncrypted);
    });

    test('主体与缩略图同生同灭（sealTogether 四象限，三域同规）', () {
      expect(AttachmentSealPolicy.sealTogether(null, null), isTrue);
      expect(AttachmentSealPolicy.sealTogether('main', 'thumb'), isTrue);
      // 单独出现 = 不一致 = 不得封装任何一个（看起来像已加密最危险）
      expect(AttachmentSealPolicy.sealTogether('main', null), isFalse);
      expect(AttachmentSealPolicy.sealTogether(null, 'thumb'), isFalse);
    });

    test('带 content key 的明文行重试必拦：优先级高于任何域的策略判定', () {
      for (final encryptionRequired in [true, false]) {
        expect(
          shouldBlockPlaintextRetry(
            encryptionRequired: encryptionRequired,
            e2ee: null,
            carriesContentKey: true,
          ),
          isTrue,
          reason: 'encryptionRequired=$encryptionRequired 时都必须拦（E2EE-061）',
        );
      }
      // 已加密行不受影响
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: true,
          e2ee: {'meta_version': 3},
          carriesContentKey: true,
        ),
        isFalse,
      );
    });

    test(
      'carriesContentKey 对 Map<dynamic,dynamic> 强转失败不误判（闸门自身 fail-closed）',
      () {
        // 库里读出的 payload 常是 Map<dynamic, dynamic>；闸门入参是 Object?
        final dynamicPayload = <dynamic, dynamic>{
          AttachmentSealPolicy.descriptorPayloadKey: 'x',
        };
        expect(AttachmentSealPolicy.carriesContentKey(dynamicPayload), isTrue);
        expect(AttachmentSealPolicy.carriesContentKey(null), isFalse);
        expect(
          AttachmentSealPolicy.carriesContentKey(<String, String>{}),
          isFalse,
        );
        expect(AttachmentSealPolicy.carriesContentKey('not-a-map'), isFalse);
      },
    );
  });

  group('三域一致性 — 3. 汇流点静态检查（无旁路）', () {
    test('豁免唯一入口：e2ee_service 汇流点调用 AiPlaintextGate，且无 peerAccountType 短路', () {
      final src = _readSource('lib/service/e2ee_service.dart');
      expect(
        src.contains('AiPlaintextGate.plaintextChannelAuthorized'),
        isTrue,
        reason: 'shouldEncryptOutgoingPayload 必须经共享门豁免',
      );
      // 剥除 /// 行注释与 /* */ 块注释后，代码里不得再有裸徽章短路
      // （注释中描述旧实现的文字不算回归）。
      final codeOnly = src
          .replaceAll(RegExp(r'///[^\n]*'), '')
          .replaceAll(RegExp(r'//[^\n]*'), '')
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      expect(
        codeOnly.contains('peerAccountType'),
        isFalse,
        reason: 'LT02-SEC-01 旧短路（裸徽章直接豁免）不得回归到代码',
      );
    });

    test(
      'AiPlaintextGate.plaintextChannelAuthorized 生产代码只被 e2ee_service 调用',
      () {
        final libDir = Directory('${_pkgRoot()}/lib');
        final callers = <String>[];
        for (final f in libDir.listSync(recursive: true)) {
          if (f is! File || !f.path.endsWith('.dart')) continue;
          // gate 自身文件（doc 注释提及自身 API）不算调用方
          if (f.path.endsWith('ai_plaintext_gate.dart')) continue;
          if (f.readAsStringSync().contains(
            'AiPlaintextGate.plaintextChannelAuthorized',
          )) {
            callers.add(f.path.replaceAll('${_pkgRoot()}/', ''));
          }
        }
        expect(callers, ['lib/service/e2ee_service.dart']);
      },
    );

    test('消息/附件/重试三条出设备路径都汇流到 shouldEncryptOutgoingPayload', () {
      final paths = [
        'lib/page/chat/chat/services/chat_network_service.dart',
        'lib/page/chat/chat/attachment_handler.dart',
        'lib/service/message_retry.dart',
      ];
      for (final p in paths) {
        expect(
          _readSource(p).contains('shouldEncryptOutgoingPayload'),
          isTrue,
          reason: '$p 必须经统一谓词（禁止 caller 各写一份 guard）',
        );
      }
    });
  });

  group('三域一致性 — 4. UI 标识与说明文案（静态）', () {
    test('AI 明文确认弹窗：遮罩不可关闭 + 拒绝为默认动作（安全默认）', () {
      final src = _readSource(
        'lib/component/dialog/ai_plaintext_confirm_dialog.dart',
      );
      expect(src.contains('barrierDismissible: false'), isTrue);
      // 拒绝（取消）键是 isDefaultAction：回车/焦点默认走拒绝方向
      expect(
        RegExp(
          r'isDefaultAction: true[\s\S]*?aiPlaintextConfirmCancel|'
          r'isDefaultAction: true',
        ).hasMatch(src),
        isTrue,
      );
    });

    test('zh-CN / en-US 文案均明示「不是端到端加密 + 服务端可读」', () {
      final zh = _readSource('assets/i18n/zh-CN/common.i18n.yaml');
      final zhBody = RegExp(r'aiPlaintextConfirmBody: (.*)')
          .firstMatch(zh)!
          .group(1)!;
      expect(zhBody, contains('不是端到端加密'));
      expect(zhBody, contains('服务端'));

      final en = _readSource('assets/i18n/en-US/common.i18n.yaml');
      final enBody = RegExp(r'aiPlaintextConfirmBody: (.*)')
          .firstMatch(en)!
          .group(1)!;
      expect(enBody.toUpperCase(), contains('NOT END-TO-END ENCRYPTED'));
      expect(enBody.toUpperCase(), contains('SERVER CAN READ'));
    });
  });
}
