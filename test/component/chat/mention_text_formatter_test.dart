import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/component/chat/mention_text_formatter.dart';

/// MentionTextEditorHelper 纯函数契约测试
///
/// 覆盖：
///   - insertMention：@ 后插入显示名 + 末尾空格 + 光标位置正确
///   - detectMentionTrigger：C5 前缀白名单（行首/空格/标点 → 允许；
///     字母/数字/下划线 → 拒绝，避免邮箱/`name_@` 误识别）
///   - 已完成的 @提及（@xxx 后含空格）→ 不再触发
///   - 空文本 / 光标 0 → 不触发
void main() {
  group('detectMentionTrigger - basic patterns', () {
    test('空文本 → 不触发', () {
      final r = MentionTextEditorHelper.detectMentionTrigger(
        '',
        const TextSelection.collapsed(offset: 0),
      );
      expect(r.$1, false);
      expect(r.$2, '');
    });

    test('光标在 0 → 不触发', () {
      final r = MentionTextEditorHelper.detectMentionTrigger(
        '@hi',
        const TextSelection.collapsed(offset: 0),
      );
      expect(r.$1, false);
    });

    test('行首 @ + 关键词 → 触发，返回 keyword 小写', () {
      const text = '@AliCe';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, true);
      expect(r.$2, 'alice');
    });

    test('行首 @ 后无字符 → 触发，keyword 为空', () {
      const text = '@';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, true);
      expect(r.$2, '');
    });

    test('"hi @bob" 光标在末尾 → 触发，keyword="bob"', () {
      const text = 'hi @bob';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, true);
      expect(r.$2, 'bob');
    });

    test('@后含空格表示已完成 → 不再触发', () {
      const text = '@bob hi';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, false);
    });
  });

  group('detectMentionTrigger - C5 prefix whitelist', () {
    test('email "a@b" 不触发（@ 前是字母 a）', () {
      const text = 'a@b';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(
        r.$1,
        false,
        reason: 'email pattern should not trigger mention list',
      );
    });

    test('"name_@foo" 不触发（@ 前是下划线）', () {
      const text = 'name_@foo';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, false);
    });

    test('"123@abc" 不触发（@ 前是数字）', () {
      const text = '123@abc';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, false);
    });

    test('空格后 @ → 触发', () {
      const text = 'hello @c';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, true);
      expect(r.$2, 'c');
    });

    test('标点后 @ → 触发（如句末逗号）', () {
      const text = '你好,@d';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, true);
      expect(r.$2, 'd');
    });

    test('中文字符后 @ → 触发', () {
      const text = '你好@张';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, true);
      expect(r.$2, '张');
    });

    test('换行后 @ → 触发（行首通用）', () {
      const text = 'line1\n@e';
      final r = MentionTextEditorHelper.detectMentionTrigger(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(r.$1, true);
      expect(r.$2, 'e');
    });
  });

  group('insertMention', () {
    const candidate = MentionCandidate(
      userId: 'u_1',
      displayName: 'Alice',
    );

    test('行首 @al + 候选 → "@Alice " + 光标在 7（after Alice + space）', () {
      const text = '@al';
      final result = MentionTextEditorHelper.insertMention(
        text: text,
        selection: const TextSelection.collapsed(offset: 3),
        candidate: candidate,
      );
      expect(result.text, '@Alice ');
      // atIndex=0 + displayName.length(5) + 2 = 7
      expect(result.selection.extentOffset, 7);
    });

    test('"hi @al" + 候选 → "hi @Alice " + 光标在 10', () {
      const text = 'hi @al';
      final result = MentionTextEditorHelper.insertMention(
        text: text,
        selection: const TextSelection.collapsed(offset: 6),
        candidate: candidate,
      );
      expect(result.text, 'hi @Alice ');
      // atIndex=3 + displayName.length(5) + 2 = 10
      expect(result.selection.extentOffset, 10);
    });

    test('"hi @al world" + 光标在 6（@al 后）→ 替换 @al，保留 " world"', () {
      const text = 'hi @al world';
      final result = MentionTextEditorHelper.insertMention(
        text: text,
        // 光标位置 6 = "hi @al" 后
        selection: const TextSelection.collapsed(offset: 6),
        candidate: candidate,
      );
      // replaceRange(atIndex+1=4, selection=6, "Alice ") → "hi @Alice  world"
      expect(result.text, 'hi @Alice  world');
    });

    test('文本无 @ → 原样返回 + 原光标', () {
      const text = 'no at sign here';
      final result = MentionTextEditorHelper.insertMention(
        text: text,
        selection: const TextSelection.collapsed(offset: 5),
        candidate: candidate,
      );
      expect(result.text, text);
      expect(result.selection.extentOffset, 5);
    });

    test('@所有人 候选 (isAllMention=true) → 插入显示名 "所有人"', () {
      final allCandidate = MentionCandidate.all();
      const text = '@';
      final result = MentionTextEditorHelper.insertMention(
        text: text,
        selection: const TextSelection.collapsed(offset: 1),
        candidate: allCandidate,
      );
      expect(result.text, '@所有人 ');
      // atIndex=0 + displayName.length(3) + 2 = 5
      expect(result.selection.extentOffset, 5);
    });

    test('CJK displayName → 字符长度按 UTF-16 code units 计算', () {
      const cjkCandidate = MentionCandidate(
        userId: 'u_2',
        displayName: '张三',
      );
      const text = '@';
      final result = MentionTextEditorHelper.insertMention(
        text: text,
        selection: const TextSelection.collapsed(offset: 1),
        candidate: cjkCandidate,
      );
      expect(result.text, '@张三 ');
      // displayName='张三' length=2，atIndex=0 + 2 + 2 = 4
      expect(result.selection.extentOffset, 4);
    });
  });
}
