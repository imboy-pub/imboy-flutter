/// E2EE-061 Slice 4 —— 封装判定闸门验收
///
/// ⚠️ 本组防的是一个**比现状更糟**的失效：在 payload 不加密的会话里封装附件，
/// 会让 descriptor（含 content key）明文出网——既上传了密文让用户以为受保护，
/// 又把钥匙贴在旁边。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';

SealDecision decide({
  bool enc = true,
  String m = 'msg-1',
  String c = 'c2c:1:2',
  String s = '1001',
}) => AttachmentSealPolicy.decide(
  payloadWillBeEncrypted: enc,
  messageId: m,
  conversationId: c,
  senderUid: s,
);

void main() {
  group('1. 正向可用性：条件齐备时必须封装', () {
    // 恒 skip 的实现在下面所有负向用例上满分，这条是它的反面锚点。
    test('payload 会加密 + 三项绑定输入齐备 → 封装', () {
      expect(decide(), isA<SealApproved>());
      expect(
        AttachmentSealPolicy.shouldSeal(
          payloadWillBeEncrypted: true,
          messageId: 'msg-1',
          conversationId: 'c2c:1:2',
          senderUid: '1001',
        ),
        isTrue,
      );
    });
  });

  group('2. ⚠️ 核心闸门：payload 不加密时绝不封装', () {
    test('payload 不加密 → 跳过，原因是 payloadNotEncrypted', () {
      final d = decide(enc: false);
      expect(d, isA<SealSkipped>());
      expect((d as SealSkipped).reason, SealSkipReason.payloadNotEncrypted);
    });

    test('⚠️ 即使绑定输入齐备，payload 不加密仍必须跳过', () {
      // 这条单独存在是因为「输入齐备」很容易被误当成放行条件。
      expect(
        AttachmentSealPolicy.shouldSeal(
          payloadWillBeEncrypted: false,
          messageId: 'msg-1',
          conversationId: 'c2c:1:2',
          senderUid: '1001',
        ),
        isFalse,
      );
    });

    test('payload 不加密的判定**优先于**绑定缺失（不因缺输入而误报原因）', () {
      final d = decide(enc: false, m: '');
      expect((d as SealSkipped).reason, SealSkipReason.payloadNotEncrypted);
    });
  });

  group('3. fail-closed：绑定输入缺任一项都不封装', () {
    test('message_id 为空 → 跳过', () {
      final d = decide(m: '');
      expect((d as SealSkipped).reason, SealSkipReason.missingBinding);
    });

    test('conversation_id 为空 → 跳过', () {
      final d = decide(c: '');
      expect((d as SealSkipped).reason, SealSkipReason.missingBinding);
    });

    test('sender_uid 为空 → 跳过', () {
      final d = decide(s: '');
      expect((d as SealSkipped).reason, SealSkipReason.missingBinding);
    });

    test('跳过意味着退回今天已知的明文行为，而不是拒绝上传', () {
      // 语义断言：本闸门只决定「要不要加密」，不决定「能不能传」。
      // 若将来有人把它改成抛异常，附件功能会在非 E2EE 会话里整体失效。
      expect(() => decide(enc: false), returnsNormally);
      expect(() => decide(m: ''), returnsNormally);
    });
  });
}
