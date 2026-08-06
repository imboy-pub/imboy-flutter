import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feed 内联评论预览：parseCommentsPreview 载荷解析 +
/// buildCommentPreviewNameSegment 名字段组装（对标微信时间线卡片）。
void main() {
  group('parseCommentsPreview', () {
    test('missing field → empty list', () {
      expect(parseCommentsPreview(<String, dynamic>{}), isEmpty);
    });

    test('non-list value → empty list (defensive)', () {
      expect(
        parseCommentsPreview(<String, dynamic>{'comments_preview': 'oops'}),
        isEmpty,
      );
      expect(
        parseCommentsPreview(<String, dynamic>{
          'comments_preview': {'id': 'c1'},
        }),
        isEmpty,
      );
    });

    test('keeps map entries and drops dirty items', () {
      final moment = <String, dynamic>{
        'comments_preview': [
          <String, dynamic>{'id': 'c1', 'content': 'hello'},
          'dirty-string',
          42,
          <String, dynamic>{'id': 'c2', 'content': 'world'},
        ],
      };
      final result = parseCommentsPreview(moment);
      expect(result, hasLength(2));
      expect(result[0]['id'], 'c1');
      expect(result[1]['content'], 'world');
    });

    test(
      'returned list is a defensive copy (mutating result maps is safe)',
      () {
        final inner = <String, dynamic>{'id': 'c1', 'content': 'a'};
        final moment = <String, dynamic>{
          'comments_preview': [inner],
        };
        final result = parseCommentsPreview(moment);
        result.first['content'] = 'mutated';
        expect(inner['content'], 'a');
      },
    );
  });

  group('buildCommentPreviewNameSegment', () {
    test('plain comment → display name only', () {
      expect(
        buildCommentPreviewNameSegment(
          displayName: '甲',
          replyToName: '',
          prefix: '回复 @',
        ),
        '甲',
      );
    });

    test('whitespace reply name → treated as plain comment', () {
      expect(
        buildCommentPreviewNameSegment(
          displayName: '甲',
          replyToName: '   ',
          prefix: '回复 @',
        ),
        '甲',
      );
    });

    test("placeholder '?' reply name → treated as plain comment", () {
      expect(
        buildCommentPreviewNameSegment(
          displayName: '甲',
          replyToName: '?',
          prefix: '回复 @',
        ),
        '甲',
      );
    });

    test('reply comment → `甲 回复 @乙`', () {
      expect(
        buildCommentPreviewNameSegment(
          displayName: '甲',
          replyToName: '乙',
          prefix: '回复 @',
        ),
        '甲 回复 @乙',
      );
    });

    test('reply name is trimmed before composing', () {
      expect(
        buildCommentPreviewNameSegment(
          displayName: 'Alice',
          replyToName: ' Bob ',
          prefix: 'Reply @',
        ),
        'Alice Reply @Bob',
      );
    });
  });
}
