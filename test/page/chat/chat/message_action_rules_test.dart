/// Characterization tests for [resolveLongPressCapabilities].
///
/// slice-C-3c: `_onMessageLongPress` 中 `isSentByMe` 依赖
/// `UserRepoLocal.to.currentUid` 单例，`canRetry` 为两条件组合，
/// 提取为纯函数后可注入 currentUid 进行单测，无需 Widget / Singleton。
///
/// 契约(钉死):
///   - isSentByMe = (messageAuthorId == currentUid)
///   - canRetry   = isSentByMe && status == MessageStatus.error
///   - canRevoke  = isSentByMe  (derived getter)
///   - canDeleteForEveryone = isSentByMe  (derived getter)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/modules/messaging/domain/policy/message_action_rules.dart';

void main() {
  const me = 'user_me_001';
  const other = 'user_other_999';

  // ─────────────────────────────────────────────────────────
  // isSentByMe
  // ─────────────────────────────────────────────────────────
  group('isSentByMe', () {
    test('authorId == currentUid → isSentByMe=true', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: me,
        currentUid: me,
        messageStatus: MessageStatus.sent,
      );
      expect(caps.isSentByMe, isTrue);
    });

    test('authorId != currentUid → isSentByMe=false', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: other,
        currentUid: me,
        messageStatus: MessageStatus.sent,
      );
      expect(caps.isSentByMe, isFalse);
    });

    test('空 id 相等 → isSentByMe=true(边界)', () {
      // 钉死:空串相等仍返回 true(调用方应保证非空,此处不校验)
      final caps = resolveLongPressCapabilities(
        messageAuthorId: '',
        currentUid: '',
        messageStatus: MessageStatus.sent,
      );
      expect(caps.isSentByMe, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────
  // canRetry = isSentByMe && status == error
  // ─────────────────────────────────────────────────────────
  group('canRetry', () {
    test('自己发送 + status=error → canRetry=true', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: me,
        currentUid: me,
        messageStatus: MessageStatus.error,
      );
      expect(caps.canRetry, isTrue);
    });

    test('自己发送 + status=sent → canRetry=false', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: me,
        currentUid: me,
        messageStatus: MessageStatus.sent,
      );
      expect(caps.canRetry, isFalse);
    });

    test('他人发送 + status=error → canRetry=false(不是自己的消息)', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: other,
        currentUid: me,
        messageStatus: MessageStatus.error,
      );
      expect(caps.canRetry, isFalse);
    });

    test('他人发送 + status=sent → canRetry=false', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: other,
        currentUid: me,
        messageStatus: MessageStatus.sent,
      );
      expect(caps.canRetry, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────
  // 派生 getter:canRevoke / canDeleteForEveryone
  // ─────────────────────────────────────────────────────────
  group('canRevoke (derived = isSentByMe)', () {
    test('自己发送 → canRevoke=true', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: me,
        currentUid: me,
        messageStatus: MessageStatus.sent,
      );
      expect(caps.canRevoke, isTrue);
    });

    test('他人发送 → canRevoke=false', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: other,
        currentUid: me,
        messageStatus: MessageStatus.sent,
      );
      expect(caps.canRevoke, isFalse);
    });
  });

  group('canDeleteForEveryone (derived = isSentByMe)', () {
    test('自己发送 → canDeleteForEveryone=true', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: me,
        currentUid: me,
        messageStatus: MessageStatus.sent,
      );
      expect(caps.canDeleteForEveryone, isTrue);
    });

    test('他人发送 → canDeleteForEveryone=false', () {
      final caps = resolveLongPressCapabilities(
        messageAuthorId: other,
        currentUid: me,
        messageStatus: MessageStatus.sent,
      );
      expect(caps.canDeleteForEveryone, isFalse);
    });
  });
}
