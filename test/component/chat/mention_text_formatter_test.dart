/// Tests for `MentionTextEditorHelper` (输入框 @ 触发与候选插入).
///
/// ## 变更记录
///
/// - **slice-B-2 (refactor-cleaner)**：移除对 `MentionTextFormatter.isRemovedMember`
///   和 `buildHighlightedText` 的测试组 —— 那条链路（parseMentions +
///   buildHighlightedText + isRemovedMember）在生产代码中零调用，随
///   `mention_text_formatter.dart` 的大幅瘦身一并被删除。消息气泡 @ 渲染
///   现走 `mention_text_reducer.dart` → markdown 方案，其覆盖见
///   `mention_text_reducer_test.dart`。
///
/// - 保留：C5 `@ 触发字符白名单`（email-like `a@b` 不弹候选）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/mention_text_formatter.dart';

void main() {
  group('MentionTextEditorHelper.detectMentionTrigger — prefix whitelist (C5)',
      () {
    (bool, String) detect(String text, {int? cursor}) {
      final sel = TextSelection.collapsed(offset: cursor ?? text.length);
      return MentionTextEditorHelper.detectMentionTrigger(text, sel);
    }

    test('triggers when @ is at start of line', () {
      expect(detect('@'), (true, ''));
    });

    test('triggers after a regular space', () {
      expect(detect('hello @'), (true, ''));
    });

    test('triggers after a newline', () {
      expect(detect('line1\n@'), (true, ''));
    });

    test('triggers after English punctuation (.)', () {
      expect(detect('end.@'), (true, ''));
    });

    test('triggers after Chinese comma (，)', () {
      expect(detect('你好，@'), (true, ''));
    });

    test('returns typed keyword after @ prefix', () {
      expect(detect('hi @al'), (true, 'al'));
    });

    // Core C5 bugfix: email-like text must NOT trigger
    test('does NOT trigger inside email "a@b.com" at letter after @', () {
      // cursor right after the "b" in a@b.com
      final res = detect('a@b.com', cursor: 3);
      expect(res, (false, ''));
    });

    test('does NOT trigger right after a letter (a@)', () {
      expect(detect('a@'), (false, ''));
    });

    test('does NOT trigger right after a digit (1@)', () {
      expect(detect('1@'), (false, ''));
    });

    test('does NOT trigger right after underscore (_@)', () {
      expect(detect('name_@'), (false, ''));
    });

    test('triggers when preceding token is a ) bracket', () {
      expect(detect('(done)@'), (true, ''));
    });

    test('does NOT trigger when @ was completed with a space already', () {
      // existing behavior must be preserved
      expect(detect('hi @foo '), (false, ''));
    });
  });
}
