import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 12: comment reply primitives.
///
/// Backend already accepts `reply_to_uid` on POST /moments/comments. UI had
/// no reply surface. We provide two pure primitives so the detail page can
/// keep i18n decisions at the UI layer (no Chinese literals baked into the
/// logic module).
void main() {
  group('extractCommentReplyTarget', () {
    test('returns reply_to_uid when present', () {
      final comment = {'reply_to_uid': 'u_5', 'user_id': 'u_1'};
      expect(extractCommentReplyTarget(comment), 'u_5');
    });

    test('returns empty string when reply_to_uid is missing', () {
      expect(extractCommentReplyTarget(const {}), '');
    });

    test('trims whitespace around the uid', () {
      expect(extractCommentReplyTarget({'reply_to_uid': '  u_5  '}), 'u_5');
    });

    test('returns empty string when reply_to_uid is whitespace-only', () {
      expect(extractCommentReplyTarget({'reply_to_uid': '   '}), '');
    });

    test('ignores non-string reply_to_uid (defensive)', () {
      expect(extractCommentReplyTarget({'reply_to_uid': 0}), '');
      expect(extractCommentReplyTarget({'reply_to_uid': null}), '');
    });
  });

  group('composeReplyDisplay', () {
    test('returns raw content when replyToName is empty', () {
      expect(
        composeReplyDisplay(
          content: 'hello',
          replyToName: '',
          prefix: 'Reply @',
          separator: ': ',
        ),
        'hello',
      );
    });

    test('composes prefix + name + separator + content', () {
      expect(
        composeReplyDisplay(
          content: 'hello',
          replyToName: 'Wang',
          prefix: 'Reply @',
          separator: ': ',
        ),
        'Reply @Wang: hello',
      );
    });

    test('trims replyToName whitespace', () {
      expect(
        composeReplyDisplay(
          content: 'hello',
          replyToName: '  Wang  ',
          prefix: 'Reply @',
          separator: ': ',
        ),
        'Reply @Wang: hello',
      );
    });

    test('whitespace-only replyToName is treated as empty (no prefix)', () {
      expect(
        composeReplyDisplay(
          content: 'hello',
          replyToName: '   ',
          prefix: 'Reply @',
          separator: ': ',
        ),
        'hello',
      );
    });

    test('works for the zh-CN prefix style "回复 @"', () {
      expect(
        composeReplyDisplay(
          content: '好的',
          replyToName: '老王',
          prefix: '回复 @',
          separator: '：',
        ),
        '回复 @老王：好的',
      );
    });
  });
}
