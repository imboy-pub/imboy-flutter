/// 钉住 `evaluateNotification` 纯函数的决策契约 —— RED 阶段。
///
/// 优先级（从高到低）：
///   1. isFromSelf=true → Suppressed('from_self')（压过所有其他条件）
///   2. isUserInChat=true → Suppressed('in_chat')
///   3. msgId 在 recentlyNotifiedMsgIds 中 → Suppressed('duplicate')
///   4. isMuted>0 且 !isMentioned → Suppressed('muted')
///   5. isMuted>0 且 isMentioned → Allow（@ 穿透免打扰）
///   6. 其余 → Allow
///
/// 本测试不依赖 Flutter / sqflite / 任何平台组件，纯 Dart。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/notification_gateway.dart';

void main() {
  group('evaluateNotification — 通知决策契约', () {
    // ------------------------------------------------------------------ //
    // 1. isFromSelf=true → Suppressed('from_self')
    // ------------------------------------------------------------------ //
    test('isFromSelf=true → NotifySuppressed(from_self)', () {
      final result = evaluateNotification(
        msgId: 'msg-1',
        isFromSelf: true,
        isUserInChat: false,
        isMuted: 0,
        isMentioned: false,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifySuppressed>());
      expect((result as NotifySuppressed).reason, 'from_self');
    });

    // ------------------------------------------------------------------ //
    // 2. isUserInChat=true → Suppressed('in_chat')
    // ------------------------------------------------------------------ //
    test('isUserInChat=true → NotifySuppressed(in_chat)', () {
      final result = evaluateNotification(
        msgId: 'msg-2',
        isFromSelf: false,
        isUserInChat: true,
        isMuted: 0,
        isMentioned: false,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifySuppressed>());
      expect((result as NotifySuppressed).reason, 'in_chat');
    });

    // ------------------------------------------------------------------ //
    // 3. isMuted>0, isMentioned=false → Suppressed('muted')
    // ------------------------------------------------------------------ //
    test('isMuted>0 + isMentioned=false → NotifySuppressed(muted)', () {
      final result = evaluateNotification(
        msgId: 'msg-3',
        isFromSelf: false,
        isUserInChat: false,
        isMuted: 1,
        isMentioned: false,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifySuppressed>());
      expect((result as NotifySuppressed).reason, 'muted');
    });

    // ------------------------------------------------------------------ //
    // 4. isMuted>0, isMentioned=true → Allow（@ 穿透免打扰）
    // ------------------------------------------------------------------ //
    test('isMuted>0 + isMentioned=true → NotifyAllow（@ 穿透）', () {
      final result = evaluateNotification(
        msgId: 'msg-4',
        isFromSelf: false,
        isUserInChat: false,
        isMuted: 1,
        isMentioned: true,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifyAllow>());
    });

    // ------------------------------------------------------------------ //
    // 5. 正常消息（全 false, isMuted=0）→ Allow
    // ------------------------------------------------------------------ //
    test('普通消息（无任何抑制条件）→ NotifyAllow', () {
      final result = evaluateNotification(
        msgId: 'msg-5',
        isFromSelf: false,
        isUserInChat: false,
        isMuted: 0,
        isMentioned: false,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifyAllow>());
    });

    // ------------------------------------------------------------------ //
    // 6. msgId 在 recentlyNotifiedMsgIds 中 → Suppressed('duplicate')
    // ------------------------------------------------------------------ //
    test('msgId 已在 recentlyNotifiedMsgIds 中 → NotifySuppressed(duplicate)', () {
      final result = evaluateNotification(
        msgId: 'msg-6',
        isFromSelf: false,
        isUserInChat: false,
        isMuted: 0,
        isMentioned: false,
        recentlyNotifiedMsgIds: {'msg-6'},
      );

      expect(result, isA<NotifySuppressed>());
      expect((result as NotifySuppressed).reason, 'duplicate');
    });

    // ------------------------------------------------------------------ //
    // 7. isFromSelf=true 压过 isMentioned=true
    // ------------------------------------------------------------------ //
    test('isFromSelf=true 优先级高于 isMentioned=true → Suppressed(from_self)', () {
      final result = evaluateNotification(
        msgId: 'msg-7',
        isFromSelf: true,
        isUserInChat: false,
        isMuted: 0,
        isMentioned: true,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifySuppressed>());
      expect((result as NotifySuppressed).reason, 'from_self');
    });

    // ------------------------------------------------------------------ //
    // 8. isUserInChat=true 压过 isMuted>0（优先级验证）
    // ------------------------------------------------------------------ //
    test('isUserInChat=true 优先级高于 isMuted>0 → Suppressed(in_chat)', () {
      final result = evaluateNotification(
        msgId: 'msg-8',
        isFromSelf: false,
        isUserInChat: true,
        isMuted: 999,
        isMentioned: false,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifySuppressed>());
      expect((result as NotifySuppressed).reason, 'in_chat');
    });

    // ------------------------------------------------------------------ //
    // 9. isMuted=0, isMentioned=false, 正常 → Allow
    // ------------------------------------------------------------------ //
    test('isMuted=0 且 isMentioned=false → NotifyAllow', () {
      final result = evaluateNotification(
        msgId: 'msg-9',
        isFromSelf: false,
        isUserInChat: false,
        isMuted: 0,
        isMentioned: false,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifyAllow>());
    });

    // ------------------------------------------------------------------ //
    // 10. 空 msgId + 空 recentlyNotifiedMsgIds → 不崩溃
    // ------------------------------------------------------------------ //
    test('空 msgId + 空 recentlyNotifiedMsgIds → 不崩溃', () {
      expect(
        () => evaluateNotification(
          msgId: '',
          isFromSelf: false,
          isUserInChat: false,
          isMuted: 0,
          isMentioned: false,
          recentlyNotifiedMsgIds: {},
        ),
        returnsNormally,
      );
    });

    // ------------------------------------------------------------------ //
    // 11. NotifyAllow 是值类型，不携带 title/body（内容由上层负责）
    // ------------------------------------------------------------------ //
    test('正常消息 → NotifyAllow（网关只决策，不携带通知内容）', () {
      final result = evaluateNotification(
        msgId: 'msg-11',
        isFromSelf: false,
        isUserInChat: false,
        isMuted: 0,
        isMentioned: false,
        recentlyNotifiedMsgIds: {},
      );

      // 网关职责：决策 allow/suppress，title/body 由调用侧补充
      expect(result, isA<NotifyAllow>());
    });

    // ------------------------------------------------------------------ //
    // 12. sealed 类型穷尽验证
    // ------------------------------------------------------------------ //
    test('sealed NotifyDecision — switch 必须穷尽', () {
      String describe(NotifyDecision d) => switch (d) {
            NotifyAllow() => 'allow',
            NotifySuppressed(:final reason) => 'suppressed:$reason',
          };

      expect(describe(const NotifyAllow()), 'allow');
      expect(
        describe(const NotifySuppressed('from_self')),
        'suppressed:from_self',
      );
    });

    // ------------------------------------------------------------------ //
    // 13. isFromSelf=true 压过 isUserInChat=true（优先级最高）
    // ------------------------------------------------------------------ //
    test('isFromSelf=true 优先级高于 isUserInChat=true → Suppressed(from_self)', () {
      final result = evaluateNotification(
        msgId: 'msg-13',
        isFromSelf: true,
        isUserInChat: true,
        isMuted: 0,
        isMentioned: false,
        recentlyNotifiedMsgIds: {},
      );

      expect(result, isA<NotifySuppressed>());
      expect((result as NotifySuppressed).reason, 'from_self');
    });

    // ------------------------------------------------------------------ //
    // 14. duplicate 优先级高于 muted（优先级 3 > 优先级 4）
    // ------------------------------------------------------------------ //
    test('msgId 在 recentlyNotifiedMsgIds 中 且 isMuted>0 → Suppressed(duplicate) 非 muted', () {
      final result = evaluateNotification(
        msgId: 'msg-14',
        isFromSelf: false,
        isUserInChat: false,
        isMuted: 999,
        isMentioned: false,
        recentlyNotifiedMsgIds: {'msg-14'},
      );

      expect(result, isA<NotifySuppressed>());
      // duplicate 优先级高于 muted，必须返回 'duplicate'
      expect((result as NotifySuppressed).reason, 'duplicate');
    });
  });
}
