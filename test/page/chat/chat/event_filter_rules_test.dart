/// Characterization tests for [isRelevantChatError] and
/// [muteEventMatchesConversation].
///
/// slice-C-3b: `_setupEventListeners` 中两个内联过滤决策提取为纯函数,
/// 与 EventBus / Widget / AppErrorEvent 类型解耦,可独立单测钉死契约。
///
/// **isRelevantChatError** 契约:
///   - errorType = 'not_a_friend' 或 'in_denylist' → true (errorType 优先)
///   - message 包含 '非好友' 或 '黑名单' → true (fallback 字符串匹配)
///   - 其他 → false
///
/// **muteEventMatchesConversation** 契约:
///   - eventConversationId = null → true (广播,无作用域限制)
///   - eventConversationId = '' → true (广播)
///   - eventConversationId = currentConversationId → true (精确匹配)
///   - eventConversationId ≠ currentConversationId → false (属于其他会话)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/policy/event_filter_rules.dart';

void main() {
  // ─────────────────────────────────────────────────────────
  // isRelevantChatError
  // ─────────────────────────────────────────────────────────
  group('isRelevantChatError — errorType 优先路径', () {
    test('errorType=not_a_friend → true (message 可为空)', () {
      expect(
        isRelevantChatError(errorType: 'not_a_friend', message: ''),
        isTrue,
      );
    });

    test('errorType=in_denylist → true (message 可为空)', () {
      expect(
        isRelevantChatError(errorType: 'in_denylist', message: ''),
        isTrue,
      );
    });

    test('errorType 匹配时 message 无关紧要', () {
      expect(
        isRelevantChatError(errorType: 'not_a_friend', message: '完全不相关的消息'),
        isTrue,
      );
    });
  });

  group('isRelevantChatError — message fallback 路径', () {
    test('message 含 "非好友" → true', () {
      // 后端实际错误消息示例:非好友关系不能发送
      expect(
        isRelevantChatError(errorType: 'other_error', message: '发送失败，非好友关系'),
        isTrue,
      );
    });

    test('message 含 "黑名单" → true', () {
      expect(
        isRelevantChatError(errorType: 'other_error', message: '你在对方的黑名单中'),
        isTrue,
      );
    });
  });

  group('isRelevantChatError — false 路径', () {
    test('无关 errorType + 无关 message → false', () {
      expect(
        isRelevantChatError(
          errorType: 'server_error',
          message: '服务器内部错误，请稍后重试',
        ),
        isFalse,
      );
    });

    test('空 errorType + 空 message → false', () {
      expect(isRelevantChatError(errorType: '', message: ''), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────
  // muteEventMatchesConversation
  // ─────────────────────────────────────────────────────────
  group('muteEventMatchesConversation — 广播路径(无作用域限制)', () {
    const current = 'conv_abc123';

    test('eventConversationId=null → true (广播禁言)', () {
      expect(
        muteEventMatchesConversation(
          eventConversationId: null,
          currentConversationId: current,
        ),
        isTrue,
      );
    });

    test('eventConversationId=空串 → true (广播禁言)', () {
      expect(
        muteEventMatchesConversation(
          eventConversationId: '',
          currentConversationId: current,
        ),
        isTrue,
      );
    });
  });

  group('muteEventMatchesConversation — 精确匹配路径', () {
    const current = 'conv_abc123';

    test('eventConversationId == currentConversationId → true', () {
      expect(
        muteEventMatchesConversation(
          eventConversationId: current,
          currentConversationId: current,
        ),
        isTrue,
      );
    });
  });

  group('muteEventMatchesConversation — 不匹配路径(属于其他会话)', () {
    const current = 'conv_abc123';

    test('eventConversationId != currentConversationId → false', () {
      expect(
        muteEventMatchesConversation(
          eventConversationId: 'conv_xyz999',
          currentConversationId: current,
        ),
        isFalse,
      );
    });

    test('currentConversationId=空 + eventConversationId 非空 → false', () {
      // 钉死:即使 current 为空,有作用域的事件也不能泛化匹配
      expect(
        muteEventMatchesConversation(
          eventConversationId: 'conv_xyz999',
          currentConversationId: '',
        ),
        isFalse,
      );
    });
  });
}
