/// Characterization tests for message bubble visibility decision functions.
///
/// slice-C-7: `chat_page.dart` L1956-1963 内联的两个布尔决策
/// `shouldShowAvatar` / `shouldShowUsername` 依赖 isSystemMessage /
/// isLastInGroup / isFirstInGroup / isRemoved 四个布尔输入，
/// 零 Widget 依赖，可独立单测钉死所有分支。
///
/// 契约（钉死）：
///   shouldShowMessageAvatar:
///   - 非系统消息 + 组尾 + 未删除 → true
///   - 系统消息 → false（压过其他条件）
///   - 非组尾 → false
///   - isRemoved=true → false
///   shouldShowMessageUsername:
///   - 非系统消息 + 组首 + 未删除 → true
///   - 系统消息 → false（压过其他条件）
///   - 非组首 → false
///   - isRemoved=true → false
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/policy/message_bubble_rules.dart';

void main() {
  // ─────────────────────────────────────────────────────────
  // shouldShowMessageAvatar
  // ─────────────────────────────────────────────────────────
  group('shouldShowMessageAvatar', () {
    test('非系统消息 + 组尾 + 未删除 → true', () {
      expect(
        shouldShowMessageAvatar(
          isSystemMessage: false,
          isLastInGroup: true,
          isRemoved: false,
        ),
        isTrue,
      );
    });

    test('系统消息 + 组尾 + 未删除 → false', () {
      expect(
        shouldShowMessageAvatar(
          isSystemMessage: true,
          isLastInGroup: true,
          isRemoved: false,
        ),
        isFalse,
      );
    });

    test('非系统消息 + 非组尾 + 未删除 → false', () {
      expect(
        shouldShowMessageAvatar(
          isSystemMessage: false,
          isLastInGroup: false,
          isRemoved: false,
        ),
        isFalse,
      );
    });

    test('非系统消息 + 组尾 + 已删除 → false', () {
      expect(
        shouldShowMessageAvatar(
          isSystemMessage: false,
          isLastInGroup: true,
          isRemoved: true,
        ),
        isFalse,
      );
    });

    test('系统消息 + 非组尾 + 已删除 → false', () {
      expect(
        shouldShowMessageAvatar(
          isSystemMessage: true,
          isLastInGroup: false,
          isRemoved: true,
        ),
        isFalse,
      );
    });

    test('isRemoved=null 视为未删除 → 按其他条件决定', () {
      expect(
        shouldShowMessageAvatar(
          isSystemMessage: false,
          isLastInGroup: true,
          isRemoved: null,
        ),
        isTrue,
      );
    });
  });

  // ─────────────────────────────────────────────────────────
  // shouldShowMessageUsername
  // ─────────────────────────────────────────────────────────
  group('shouldShowMessageUsername', () {
    test('非系统消息 + 组首 + 未删除 → true', () {
      expect(
        shouldShowMessageUsername(
          isSystemMessage: false,
          isFirstInGroup: true,
          isRemoved: false,
        ),
        isTrue,
      );
    });

    test('系统消息 + 组首 + 未删除 → false', () {
      expect(
        shouldShowMessageUsername(
          isSystemMessage: true,
          isFirstInGroup: true,
          isRemoved: false,
        ),
        isFalse,
      );
    });

    test('非系统消息 + 非组首 + 未删除 → false', () {
      expect(
        shouldShowMessageUsername(
          isSystemMessage: false,
          isFirstInGroup: false,
          isRemoved: false,
        ),
        isFalse,
      );
    });

    test('非系统消息 + 组首 + 已删除 → false', () {
      expect(
        shouldShowMessageUsername(
          isSystemMessage: false,
          isFirstInGroup: true,
          isRemoved: true,
        ),
        isFalse,
      );
    });

    test('系统消息 + 组首 + 已删除 → false', () {
      expect(
        shouldShowMessageUsername(
          isSystemMessage: true,
          isFirstInGroup: true,
          isRemoved: true,
        ),
        isFalse,
      );
    });

    test('isRemoved=null 视为未删除 → 按其他条件决定', () {
      expect(
        shouldShowMessageUsername(
          isSystemMessage: false,
          isFirstInGroup: true,
          isRemoved: null,
        ),
        isTrue,
      );
    });
  });
}
