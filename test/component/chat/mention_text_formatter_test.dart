/// Tests for MentionTextFormatter / MentionTextEditorHelper
///
/// Covers:
/// - C5: `@ 触发字符白名单` — email-like `a@b` must NOT pop candidate list
/// - C1: 已退群成员降级显示 — unknown mention id renders as removed-member label
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

  group('MentionTextFormatter.isRemovedMember — active member check (C1)', () {
    test('returns false when activeMemberIds is null (backward compat)', () {
      expect(
        MentionTextFormatter.isRemovedMember('uid_1', null),
        isFalse,
      );
    });

    test('returns false for special "all" id regardless of active set', () {
      expect(
        MentionTextFormatter.isRemovedMember('all', <String>{}),
        isFalse,
      );
    });

    test('returns false when user is in the active set', () {
      expect(
        MentionTextFormatter.isRemovedMember('uid_1', {'uid_1', 'uid_2'}),
        isFalse,
      );
    });

    test('returns true when user is NOT in the active set (removed)', () {
      expect(
        MentionTextFormatter.isRemovedMember('uid_gone', {'uid_1', 'uid_2'}),
        isTrue,
      );
    });
  });

  group('MentionTextFormatter.buildHighlightedText — removed member UI (C1)',
      () {
    const baseStyle = TextStyle(fontSize: 14);

    testWidgets('renders normal highlighted @xxx when member is active',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MentionTextFormatter.buildHighlightedText(
              text: 'hi @uid_1 ok',
              mentionIds: const ['uid_1'],
              style: baseStyle,
              currentUserId: 'uid_me',
              activeMemberIds: const {'uid_1'},
            ),
          ),
        ),
      );

      // The original @uid_1 token should still be rendered as-is.
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final rendered = richText.text.toPlainText();
      expect(rendered.contains('@uid_1'), isTrue);
      expect(rendered.contains('已退群'), isFalse);
    });

    testWidgets(
        'renders fallback label "@已退群成员" when mention target has left group',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MentionTextFormatter.buildHighlightedText(
              text: 'hi @uid_gone ok',
              mentionIds: const ['uid_gone'],
              style: baseStyle,
              currentUserId: 'uid_me',
              activeMemberIds: const {'uid_1'}, // gone is not here
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final rendered = richText.text.toPlainText();
      expect(rendered.contains('@已退群成员'), isTrue,
          reason: 'fallback label should replace the stale mention token');
      expect(rendered.contains('@uid_gone'), isFalse);
    });

    testWidgets(
        'fallback mention has NO tap recognizer (cannot navigate to ghost)',
        (tester) async {
      var tappedUserId = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MentionTextFormatter.buildHighlightedText(
              text: 'hi @uid_gone',
              mentionIds: const ['uid_gone'],
              style: baseStyle,
              currentUserId: 'uid_me',
              onMentionTap: (uid) => tappedUserId = uid,
              activeMemberIds: const {}, // everyone gone
            ),
          ),
        ),
      );

      // Walk spans, ensure no span has a recognizer for "@已退群成员"
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      bool fallbackHasRecognizer = false;
      void visit(InlineSpan span) {
        if (span is TextSpan) {
          final t = span.text ?? '';
          if (t.contains('@已退群成员') && span.recognizer != null) {
            fallbackHasRecognizer = true;
          }
          for (final c in span.children ?? const <InlineSpan>[]) {
            visit(c);
          }
        }
      }

      visit(richText.text);
      expect(fallbackHasRecognizer, isFalse);
      expect(tappedUserId, '');
    });
  });
}
