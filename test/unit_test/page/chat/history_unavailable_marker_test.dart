/// BUG#119（批次72 真机复现）闭环测试：归档回填「成功但 0 条」且会话有
/// lastMsgId 时，必须标记「历史不可用」，而不是落进误导性的「暂无数据」。
///
/// 真机证据链：
/// 1. syncHistoryBackfill 对全部会话（C2C/C2G）都打出
///    `fetched=0, nextSeq=0, hasMore=false`——服务端 msg_store 归档为空
///    （生产未开启 msg_archive_enabled），history 接口正常返回空，不抛异常；
/// 2. 会话列表却显示摘要（「1 天前 qa-batch25-pin」），会话行 lastMsgId > 0
///    ——消息存在，只是不可取；
/// 3. 旧逻辑：不抛异常就不置任何标记 → 空态走 `!hasMoreMessage && isEmpty`
///    → 「暂无数据」——与「新会话真的没有消息」无法区分，误导用户。
///
/// 修复：`ChatNotifier.shouldMarkHistoryUnavailable` 判定 + ChatState 新增
/// `historyUnavailable` 位；聊天页空态据此显示「历史消息暂不可用」。
///
/// 反证：把判定改成恒 false（或删掉 ChatState 字段）→ 本文件用例必红。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/chat/chat_provider.dart';

void main() {
  group('BUG#119 shouldMarkHistoryUnavailable 判定', () {
    test('归档回填 0 条 + 会话行有 lastMsgId（消息存在但不可取）→ 标记', () {
      expect(
        ChatNotifier.shouldMarkHistoryUnavailable(
          anyFetched: false,
          lastMsgId: 105862178307049472,
        ),
        isTrue,
        reason: '服务端归档为空但会话确认有消息，必须标记「历史不可用」',
      );
    });

    test('归档拉到消息（anyFetched=true）→ 不标记（历史可取，正常渲染）', () {
      expect(
        ChatNotifier.shouldMarkHistoryUnavailable(
          anyFetched: true,
          lastMsgId: 105862178307049472,
        ),
        isFalse,
        reason: '归档有数据时历史可取，不得展示「历史不可用」',
      );
    });

    test('新会话 lastMsgId=0（服务端确认无消息）→ 不标记（真·暂无数据）', () {
      expect(
        ChatNotifier.shouldMarkHistoryUnavailable(
          anyFetched: false,
          lastMsgId: 0,
        ),
        isFalse,
        reason: '新会话确实没有消息，「暂无数据」才是正确语义',
      );
    });

    test('归档有消息 + lastMsgId=0（理论不可能组合）→ 不标记', () {
      expect(
        ChatNotifier.shouldMarkHistoryUnavailable(
          anyFetched: true,
          lastMsgId: 0,
        ),
        isFalse,
      );
    });
  });

  group('BUG#119 ChatState.historyUnavailable 状态传播', () {
    test('copyWith 置位/复位正常，不传则保留旧值', () {
      const initial = ChatState();
      expect(initial.historyUnavailable, isFalse);

      final marked = initial.copyWith(historyUnavailable: true);
      expect(marked.historyUnavailable, isTrue);
      expect(marked.historySyncFailed, isFalse, reason: '不可用与失败是两个独立状态位，互不串扰');

      // copyWith 不传该字段 → 保留
      final kept = marked.copyWith(hasMoreMessage: false);
      expect(kept.historyUnavailable, isTrue);

      final cleared = marked.copyWith(historyUnavailable: false);
      expect(cleared.historyUnavailable, isFalse);
    });

    test('字段参与 == 与 hashCode（防止未来漏字段导致状态判断失真）', () {
      final a = const ChatState().copyWith(historyUnavailable: true);
      final b = const ChatState().copyWith(historyUnavailable: true);
      final c = const ChatState().copyWith(historyUnavailable: false);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)), reason: 'unavailable 状态不同必须判定不相等');
    });

    test('不可用标记与失败标记互不覆盖（空态按优先级各显其态）', () {
      final both = const ChatState().copyWith(
        historySyncFailed: true,
        historyUnavailable: true,
      );
      expect(both.historySyncFailed, isTrue);
      expect(both.historyUnavailable, isTrue);

      final failedOnly = const ChatState().copyWith(historySyncFailed: true);
      expect(failedOnly.historySyncFailed, isTrue);
      expect(failedOnly.historyUnavailable, isFalse);
    });
  });
}
