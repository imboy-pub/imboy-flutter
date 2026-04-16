/// channel_edit_page 纯函数契约测试（CE-1 ~ CE-3）
///
/// 覆盖从 channel_edit_page.dart 提取的 3 个纯决策函数：
///   CE-1  normalizeTags    — 标签规范化（去空白 / 去重 / 排序）
///   CE-2  channelTagsEqual — 两组标签语义相等判断
///   CE-3  isChannelUpdateApplied — 编辑表单是否与现有 channel 完全一致
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_edit_rules.dart';
import 'package:imboy/store/model/channel_model.dart';

// ─── 辅助构造 ChannelModel ────────────────────────────────────────────────────
final _epoch = DateTime(2025, 1, 1);

ChannelModel _ch({
  String name = 'ch',
  String? description,
  String? avatar,
  List<String>? tags,
}) =>
    ChannelModel(
      id: 1,
      name: name,
      type: ChannelType.public,
      creatorId: 0,
      createdAt: _epoch,
      updatedAt: _epoch,
      description: description,
      avatar: avatar,
      tags: tags,
    );

void main() {
  // ─── CE-1  normalizeTags ────────────────────────────────────────────────────
  group('CE-1 normalizeTags', () {
    test('null → 空列表', () {
      expect(normalizeTags(null), isEmpty);
    });

    test('空列表 → 空列表', () {
      expect(normalizeTags([]), isEmpty);
    });

    test('纯空白标签被过滤', () {
      expect(normalizeTags(['  ', '\t', '']), isEmpty);
    });

    test('标签两端空白被 trim', () {
      expect(normalizeTags(['  dart  ', 'flutter']),
          containsAll(['dart', 'flutter']));
    });

    test('重复标签去重', () {
      final result = normalizeTags(['a', 'a', 'b']);
      expect(result, hasLength(2));
      expect(result, containsAll(['a', 'b']));
    });

    test('结果已排序', () {
      final result = normalizeTags(['z', 'a', 'm']);
      expect(result, orderedEquals(['a', 'm', 'z']));
    });

    test('trim + 去重 + 排序联合', () {
      final result = normalizeTags([' b ', 'a', ' b', 'C']);
      // 去重：'b' == ' b'.trim(); 'C' 保留大写
      expect(result, orderedEquals(['C', 'a', 'b']));
    });
  });

  // ─── CE-2  channelTagsEqual ──────────────────────────────────────────────────
  group('CE-2 channelTagsEqual', () {
    test('两者均 null → 相等', () {
      expect(channelTagsEqual(null, null), isTrue);
    });

    test('null 与空列表 → 相等（归一化后均为空）', () {
      expect(channelTagsEqual(null, []), isTrue);
      expect(channelTagsEqual([], null), isTrue);
    });

    test('相同标签不同顺序 → 相等', () {
      expect(channelTagsEqual(['b', 'a'], ['a', 'b']), isTrue);
    });

    test('标签值相同但有空白差异 → 相等', () {
      expect(channelTagsEqual([' a '], ['a']), isTrue);
    });

    test('内容不同 → 不相等', () {
      expect(channelTagsEqual(['a'], ['b']), isFalse);
    });

    test('长度不同 → 不相等', () {
      expect(channelTagsEqual(['a', 'b'], ['a']), isFalse);
    });
  });

  // ─── CE-3  isChannelUpdateApplied ────────────────────────────────────────────
  group('CE-3 isChannelUpdateApplied', () {
    test('name/description/tags 完全一致，无 avatar → true', () {
      final ch = _ch(name: 'n', description: 'desc', tags: ['a']);
      expect(
        isChannelUpdateApplied(
          channel: ch,
          name: 'n',
          description: 'desc',
          tags: ['a'],
        ),
        isTrue,
      );
    });

    test('name 不同 → false', () {
      final ch = _ch(name: 'old');
      expect(
        isChannelUpdateApplied(channel: ch, name: 'new', description: ''),
        isFalse,
      );
    });

    test('description null → 等价于空字符串', () {
      final ch = _ch(description: null);
      expect(
        isChannelUpdateApplied(channel: ch, name: 'ch', description: ''),
        isTrue,
      );
    });

    test('avatar null（未传）→ 忽略 avatar 比较', () {
      final ch = _ch(avatar: 'https://example.com/img.png');
      expect(
        isChannelUpdateApplied(
          channel: ch,
          name: 'ch',
          description: '',
          // avatar 不传 → 默认 null，忽略比较
        ),
        isTrue,
      );
    });

    test('avatar 传入且与 channel 不同 → false', () {
      final ch = _ch(avatar: 'old.png');
      expect(
        isChannelUpdateApplied(
          channel: ch,
          name: 'ch',
          description: '',
          avatar: 'new.png',
        ),
        isFalse,
      );
    });

    test('avatar 传入且与 channel 相同 → true', () {
      final ch = _ch(avatar: 'same.png');
      expect(
        isChannelUpdateApplied(
          channel: ch,
          name: 'ch',
          description: '',
          avatar: 'same.png',
        ),
        isTrue,
      );
    });

    test('tags null（未传）→ 忽略 tags 比较', () {
      final ch = _ch(tags: ['x', 'y']);
      expect(
        isChannelUpdateApplied(channel: ch, name: 'ch', description: ''),
        isTrue,
      );
    });

    test('tags 传入且内容不同 → false', () {
      final ch = _ch(tags: ['a']);
      expect(
        isChannelUpdateApplied(
          channel: ch,
          name: 'ch',
          description: '',
          tags: ['b'],
        ),
        isFalse,
      );
    });
  });
}
