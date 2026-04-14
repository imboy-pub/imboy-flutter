/// Tests for MentionTextReducer (C1 Z path — markdown-based downgrade)
///
/// `MentionTextReducer.reduce` scans a chat message body for `@<displayName>`
/// tokens and rewrites those whose target is NOT in the active member set
/// as markdown strikethrough `~~@已退群成员~~`. Rendered by GptMarkdown in
/// the flyer_chat text message widget.
///
/// Safety convention: an empty [activeMemberNames] means "caller has no
/// data yet" — return text untouched rather than striking every mention.
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/mention_text_reducer.dart';

void main() {
  String reduce(String text, Set<String> names) =>
      MentionTextReducer.reduce(text, names);

  group('MentionTextReducer.reduce — base contract', () {
    test('returns text unchanged when activeMemberNames is empty (safety)', () {
      expect(reduce('@Bob eats', const {}), '@Bob eats');
    });

    test('returns text unchanged when text has no @ token', () {
      expect(reduce('hello world', {'Alice'}), 'hello world');
    });
  });

  group('MentionTextReducer.reduce — active vs removed members', () {
    test('keeps @Alice intact when Alice is active', () {
      expect(reduce('@Alice 吃饭', {'Alice'}), '@Alice 吃饭');
    });

    test('rewrites @Bob to markdown strikethrough when Bob is not active', () {
      expect(reduce('@Bob 吃饭', {'Alice'}), '~~@已退群成员~~ 吃饭');
    });

    test('keeps @所有人 intact regardless of active set', () {
      // C1: @全体成员 is never considered "removed"
      expect(reduce('@所有人 通知', {'Alice'}), '@所有人 通知');
      expect(reduce('@所有人 通知', const {}), '@所有人 通知');
    });

    test('handles mix of active / removed / all-mention', () {
      expect(
        reduce('@Alice 和 @Bob 以及 @所有人', {'Alice'}),
        '@Alice 和 ~~@已退群成员~~ 以及 @所有人',
      );
    });

    test('handles two consecutive @ tokens', () {
      expect(
        reduce('@Alice @Bob', {'Alice'}),
        '@Alice ~~@已退群成员~~',
      );
    });

    test('handles @ at start of line (no preceding char)', () {
      expect(reduce('@Bob starts here', {'Alice'}), '~~@已退群成员~~ starts here');
    });
  });

  group('MentionTextReducer.reduce — prefix whitelist (shared with C5)', () {
    test('does NOT treat email a@b.com as a mention', () {
      expect(reduce('联系我 a@b.com', const {}), '联系我 a@b.com');
      expect(reduce('联系我 a@b.com', {'Alice'}), '联系我 a@b.com');
    });

    test('does NOT treat name_@foo as a mention', () {
      expect(reduce('name_@foo', {'Alice'}), 'name_@foo');
    });

    test('triggers after Chinese punctuation', () {
      expect(reduce('你好，@Bob 来啦', {'Alice'}), '你好，~~@已退群成员~~ 来啦');
    });

    test('triggers after a newline', () {
      expect(reduce('line1\n@Bob', {'Alice'}), 'line1\n~~@已退群成员~~');
    });
  });

  group('MentionTextReducer.reduce — preserves surrounding whitespace', () {
    test('preserves the exact character before @ when active', () {
      expect(reduce('hi @Alice!', {'Alice'}), 'hi @Alice!');
    });

    test('preserves the exact character before @ when removed', () {
      expect(reduce('hi @Bob!', {'Alice'}), 'hi ~~@已退群成员~~!');
    });
  });

  group('MentionTextReducer.applyTo — TextMessage projection (Z-2a)', () {
    TextMessage build(String text) => TextMessage(
          id: 'm1',
          authorId: 'uid_sender',
          text: text,
        );

    test('returns same instance when activeMemberNames is empty', () {
      final msg = build('@Bob 吃饭');
      final out = MentionTextReducer.applyTo(msg, const {});
      expect(identical(msg, out), isTrue,
          reason: 'empty set must short-circuit — no copyWith churn');
    });

    test('returns same instance when text has no @ token', () {
      final msg = build('hello world');
      final out = MentionTextReducer.applyTo(msg, {'Alice', 'Bob'});
      expect(identical(msg, out), isTrue);
    });

    test('returns same instance when reduce produces identical text', () {
      final msg = build('@Alice 吃饭');
      final out = MentionTextReducer.applyTo(msg, {'Alice'});
      expect(identical(msg, out), isTrue,
          reason: 'no-op reduce should not allocate a new TextMessage');
    });

    test('returns NEW instance with reduced text when a member has left', () {
      final msg = build('@Alice 和 @Bob 你好');
      final out = MentionTextReducer.applyTo(msg, {'Alice'});

      expect(identical(msg, out), isFalse);
      expect(out.text, '@Alice 和 ~~@已退群成员~~ 你好');
    });

    test('projection preserves id / authorId / non-text fields', () {
      final msg = TextMessage(
        id: 'm42',
        authorId: 'uid_sender_x',
        text: '@Bob hi',
      );
      final out = MentionTextReducer.applyTo(msg, {'Alice'});

      expect(out.id, 'm42');
      expect(out.authorId, 'uid_sender_x');
      expect(out.text, '~~@已退群成员~~ hi');
    });
  });
}
