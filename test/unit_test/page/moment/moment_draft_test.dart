import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Slice A: 发布失败草稿的序列化 / 反序列化纯函数。
///
/// 完整草稿恢复需要 storage 层 IO，本切片只做"草稿快照 ↔ map"的纯函数，
/// 让 UI 层在 publish 失败时调 `buildMomentDraft` 持久化、下次进发布页时
/// 调 `restoreMomentDraft` 还原。
void main() {
  group('buildMomentDraft', () {
    test('完整字段往返一致', () {
      final draft = buildMomentDraft(
        content: 'hello world',
        mediaUrls: const ['https://a/x.jpg', 'https://a/y.jpg'],
        visibility: momentVisibilityFriends,
        allowUids: const ['u1', 'u2'],
        denyUids: const [],
        savedAt: DateTime.utc(2026, 4, 15, 10, 30),
      );

      expect(draft['content'], 'hello world');
      expect(draft['media_urls'], ['https://a/x.jpg', 'https://a/y.jpg']);
      expect(draft['visibility'], momentVisibilityFriends);
      expect(draft['allow_uids'], ['u1', 'u2']);
      expect(draft['deny_uids'], <String>[]);
      expect(draft['saved_at'], '2026-04-15T10:30:00.000Z');
    });

    test('空 content + 空 media + 空名单 → 仍合法序列化', () {
      final draft = buildMomentDraft(
        content: '',
        mediaUrls: const [],
        visibility: momentVisibilityPublic,
        allowUids: const [],
        denyUids: const [],
        savedAt: DateTime.utc(2026, 1, 1),
      );
      expect(draft['content'], '');
      expect(draft['media_urls'], <String>[]);
      expect(draft['visibility'], 0);
    });
  });

  group('restoreMomentDraft', () {
    test('正常 map → 完整 MomentDraft', () {
      final restored = restoreMomentDraft(<String, dynamic>{
        'content': 'hi',
        'media_urls': ['url1'],
        'visibility': momentVisibilityAllowList,
        'allow_uids': ['u1'],
        'deny_uids': <String>[],
        'saved_at': '2026-04-15T10:30:00.000Z',
      });
      expect(restored, isNotNull);
      expect(restored!.content, 'hi');
      expect(restored.mediaUrls, ['url1']);
      expect(restored.visibility, momentVisibilityAllowList);
      expect(restored.allowUids, ['u1']);
      expect(restored.savedAt, DateTime.utc(2026, 4, 15, 10, 30));
    });

    test('null / 空 map → null（无草稿）', () {
      expect(restoreMomentDraft(null), isNull);
      expect(restoreMomentDraft(const {}), isNull);
    });

    test('完全空内容（无 content / 无 media）→ null（无意义草稿）', () {
      expect(
        restoreMomentDraft(<String, dynamic>{
          'content': '',
          'media_urls': <String>[],
          'visibility': 0,
          'saved_at': '2026-04-15T10:30:00.000Z',
        }),
        isNull,
      );
    });

    test('content 非 string / media_urls 非 list → 安全降级', () {
      final restored = restoreMomentDraft(<String, dynamic>{
        'content': 'ok',
        'media_urls': 'not a list',
        'visibility': 'not int',
        'saved_at': 'not a date',
      });
      expect(restored, isNotNull);
      expect(restored!.content, 'ok');
      expect(restored.mediaUrls, <String>[]);
      expect(
        restored.visibility,
        momentVisibilityFriends,
        reason: '坏 visibility 回退到友安全默认',
      );
      expect(restored.savedAt, isNull);
    });

    test('media_urls 中混杂非字符串元素 → 仅保留 string', () {
      final restored = restoreMomentDraft(<String, dynamic>{
        'content': '',
        'media_urls': ['ok', 123, null, 'ok2'],
        'visibility': 0,
      });
      expect(restored, isNotNull);
      expect(restored!.mediaUrls, ['ok', 'ok2']);
    });
  });

  group('build → restore 往返', () {
    test('完整往返保留所有字段', () {
      final ts = DateTime.utc(2026, 4, 15, 12, 0);
      final map = buildMomentDraft(
        content: 'hello',
        mediaUrls: const ['u1', 'u2'],
        visibility: momentVisibilityDenyList,
        allowUids: const [],
        denyUids: const ['blocker'],
        savedAt: ts,
      );
      final restored = restoreMomentDraft(map)!;
      expect(restored.content, 'hello');
      expect(restored.mediaUrls, ['u1', 'u2']);
      expect(restored.visibility, momentVisibilityDenyList);
      expect(restored.denyUids, ['blocker']);
      expect(restored.savedAt, ts);
    });
  });
}
