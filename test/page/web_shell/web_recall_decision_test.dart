/// Phase 2.1.b-5c RED — Web Shell 长按"撤回"菜单项可见性决策
///
/// 复用项目既有 [canRevokeMessage] 时间窗策略 + 加 "author == currentUid" 判断。
/// 仅决定"是否在菜单显示撤回项"，不做实际撤回（留待后续切片接
/// MessageActionHandler.revokeMessage）。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_message_actions.dart';

const _now = 1714291200000; // 2026-04-28 任意时刻
const _windowMs = 2 * 60 * 1000;

TextMessage _msg({
  required String authorId,
  required int createdAtMs,
  String text = 'hi',
}) {
  return TextMessage(
    authorId: authorId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
    id: 'm',
    text: text,
  );
}

void main() {
  group('canShowRecallAction — 自己发的消息', () {
    test('在窗口内 → true', () {
      final msg = _msg(authorId: 'me', createdAtMs: _now - 30 * 1000);
      expect(
        canShowRecallAction(
          message: msg,
          currentUserId: 'me',
          nowMs: _now,
        ),
        isTrue,
      );
    });

    test('刚发出（边界包含 0ms）→ true', () {
      final msg = _msg(authorId: 'me', createdAtMs: _now);
      expect(
        canShowRecallAction(message: msg, currentUserId: 'me', nowMs: _now),
        isTrue,
      );
    });

    test('窗口边界（恰好 windowMs）→ true', () {
      final msg = _msg(authorId: 'me', createdAtMs: _now - _windowMs);
      expect(
        canShowRecallAction(message: msg, currentUserId: 'me', nowMs: _now),
        isTrue,
      );
    });

    test('超出窗口 → false', () {
      final msg = _msg(authorId: 'me', createdAtMs: _now - _windowMs - 1);
      expect(
        canShowRecallAction(message: msg, currentUserId: 'me', nowMs: _now),
        isFalse,
      );
    });

    test('时钟漂移（来自未来）→ true（与 canRevokeMessage 语义一致）', () {
      final msg = _msg(authorId: 'me', createdAtMs: _now + 5 * 1000);
      expect(
        canShowRecallAction(message: msg, currentUserId: 'me', nowMs: _now),
        isTrue,
      );
    });
  });

  group('canShowRecallAction — 对方发的消息', () {
    test('窗口内但 author != currentUserId → false', () {
      final msg = _msg(authorId: 'other', createdAtMs: _now - 30 * 1000);
      expect(
        canShowRecallAction(message: msg, currentUserId: 'me', nowMs: _now),
        isFalse,
        reason: '只能撤回自己的消息',
      );
    });
  });

  group('canShowRecallAction — 边界', () {
    test('currentUserId 为空 → false（未登录态防御）', () {
      final msg = _msg(authorId: '', createdAtMs: _now - 30 * 1000);
      expect(
        canShowRecallAction(message: msg, currentUserId: '', nowMs: _now),
        isFalse,
      );
    });

    test('createdAtMs <= 0（数据损坏）→ false', () {
      final msg = _msg(authorId: 'me', createdAtMs: 0);
      expect(
        canShowRecallAction(message: msg, currentUserId: 'me', nowMs: _now),
        isFalse,
      );
    });
  });
}
