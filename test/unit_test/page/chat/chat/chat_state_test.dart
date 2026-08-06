/// ChatState / ChatType / MessageSendStatus 契约测试
///
/// CS-1  ChatState 默认值与 copyWith 字段覆盖语义
/// CS-2  ChatState ==/hashCode 契约（注意：messages 不参与相等判定）
/// CS-3  ChatState.hasConversation getter
/// CS-4  ChatType.fromCode 解析（大小写不敏感 + 未知值回退 c2c）
/// CS-5  MessageSendStatus 枚举完整性
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_state.dart';

void main() {
  // ── CS-1  默认值与 copyWith ────────────────────────────────────────────────
  group('CS-1 ChatState 默认值与 copyWith', () {
    test('默认值符合契约', () {
      const state = ChatState();
      expect(state.pageSize, 16);
      expect(state.connected, isTrue);
      expect(state.hasMoreMessage, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingNewer, isFalse);
      expect(state.nextAutoId, 0);
      expect(state.prevAutoId, 0);
      expect(state.memberCount, 0);
      expect(state.composerHeight, 52.0);
      expect(state.currentConversationId, '');
      expect(state.lastHistorySeq, 0);
      expect(state.historyHasMore, isTrue);
      expect(state.messages, isEmpty);
    });

    test('initial 常量等价于默认构造', () {
      expect(ChatState.initial, const ChatState());
    });

    test('copyWith 覆盖部分字段，其余保持不变', () {
      const state = ChatState();
      final updated = state.copyWith(
        isLoading: true,
        nextAutoId: 100,
        currentConversationId: 'c2c:1:2',
      );
      expect(updated.isLoading, isTrue);
      expect(updated.nextAutoId, 100);
      expect(updated.currentConversationId, 'c2c:1:2');
      // 未覆盖字段保持默认
      expect(updated.pageSize, 16);
      expect(updated.connected, isTrue);
      expect(updated.memberCount, 0);
    });

    test('copyWith 不传字段时保持原值（?? 语义，非清空）', () {
      const state = ChatState(memberCount: 5, lastHistorySeq: 99);
      final copy = state.copyWith(isLoading: true);
      expect(copy.memberCount, 5);
      expect(copy.lastHistorySeq, 99);
    });

    test('copyWith 不传 messages 时保持原列表引用', () {
      const original = ChatState();
      final copy = original.copyWith(isLoading: true);
      expect(identical(copy.messages, original.messages), isTrue);
    });
  });

  // ── CS-2  ==/hashCode ──────────────────────────────────────────────────────
  group('CS-2 ChatState ==/hashCode', () {
    test('字段全等的两个实例相等且 hashCode 相同', () {
      const a = ChatState(memberCount: 3, currentConversationId: 'x');
      const b = ChatState(memberCount: 3, currentConversationId: 'x');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('任一参与判定的字段不同则不相等', () {
      const a = ChatState(memberCount: 3);
      const b = ChatState(memberCount: 4);
      expect(a, isNot(equals(b)));
    });

    test('identical 短路：自身与自身相等', () {
      const a = ChatState();
      expect(a == a, isTrue);
    });

    test('messages 不参与相等判定（镜像字段语义）', () {
      // == 与 hashCode 均未纳入 messages，故仅 messages 不同的两个状态仍相等
      const a = ChatState();
      final b = a.copyWith(messages: const []);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  // ── CS-3  hasConversation ──────────────────────────────────────────────────
  group('CS-3 hasConversation', () {
    test('currentConversationId 为空 → false', () {
      expect(const ChatState().hasConversation, isFalse);
    });

    test('currentConversationId 非空 → true', () {
      expect(
        const ChatState(currentConversationId: 'c2g:1').hasConversation,
        isTrue,
      );
    });
  });

  // ── CS-4  ChatType.fromCode ────────────────────────────────────────────────
  group('CS-4 ChatType.fromCode', () {
    test('标准大写码解析', () {
      expect(ChatType.fromCode('C2C'), ChatType.c2c);
      expect(ChatType.fromCode('C2G'), ChatType.c2g);
      expect(ChatType.fromCode('C2S'), ChatType.c2s);
    });

    test('小写/混合大小写不敏感', () {
      expect(ChatType.fromCode('c2c'), ChatType.c2c);
      expect(ChatType.fromCode('c2g'), ChatType.c2g);
      expect(ChatType.fromCode('c2s'), ChatType.c2s);
    });

    test('未知码回退到 c2c', () {
      expect(ChatType.fromCode('unknown'), ChatType.c2c);
      expect(ChatType.fromCode(''), ChatType.c2c);
    });

    test('枚举 code 字段映射正确', () {
      expect(ChatType.c2c.code, 'C2C');
      expect(ChatType.c2g.code, 'C2G');
      expect(ChatType.c2s.code, 'C2S');
    });
  });

  // ── CS-5  MessageSendStatus ────────────────────────────────────────────────
  group('CS-5 MessageSendStatus', () {
    test('包含 sending/sent/failed/seen 四种状态', () {
      expect(MessageSendStatus.values, hasLength(4));
      expect(
        MessageSendStatus.values,
        containsAll(<MessageSendStatus>[
          MessageSendStatus.sending,
          MessageSendStatus.sent,
          MessageSendStatus.failed,
          MessageSendStatus.seen,
        ]),
      );
    });
  });
}
