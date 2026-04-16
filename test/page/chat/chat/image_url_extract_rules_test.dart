/// Characterization tests for [extractImageUrlsFromMessages].
///
/// slice-C-6: `_getAllImageUrlsInConversation`（L2415-2462）从消息列表中
/// 提取图片 URL，含三个分支：
///   1. ImageMessage → msg.source
///   2. CustomMessage + effective_msg_type == 'image' → metadata['source'] ?? ['uri']
///   3. CustomMessage + effective_msg_type == 'imageMulti' → metadata['images'][*]['uri']
/// 当前内联在 Widget 方法体，零测试覆盖；提取后可注入消息列表独立单测。
///
/// 契约（钉死）：
///   - ImageMessage 的 source 非空 → 加入结果
///   - ImageMessage 的 source 空串 → 忽略
///   - CustomMessage image 类型：source 优先，uri 次之，两者均空 → 忽略
///   - CustomMessage image_multi：images 列表 uri 字段非空 → 各自加入
///   - 其他 CustomMessage msg_type → 忽略
///   - effective_msg_type 优先于 msg_type（覆写语义）
///   - 空列表 → 空结果
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/utils/image_url_extract_rules.dart';

// ─────────────────────────────────────────────────────────
// 测试辅助工厂
// ─────────────────────────────────────────────────────────
ImageMessage _img(String source) => ImageMessage(
      id: 'img_${source.hashCode}',
      authorId: 'user1',
      createdAt: DateTime(2024),
      source: source,
    );

CustomMessage _custom(Map<String, dynamic> metadata) => CustomMessage(
      id: 'custom_${metadata.hashCode}',
      authorId: 'user1',
      createdAt: DateTime(2024),
      metadata: metadata,
    );

void main() {
  // ─────────────────────────────────────────────────────────
  // 空输入
  // ─────────────────────────────────────────────────────────
  group('空消息列表', () {
    test('空列表 → 空结果', () {
      expect(extractImageUrlsFromMessages([]), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────
  // ImageMessage 分支
  // ─────────────────────────────────────────────────────────
  group('ImageMessage', () {
    test('source 非空 → 加入结果', () {
      final msgs = [_img('https://cdn.example.com/photo.jpg')];
      final urls = extractImageUrlsFromMessages(msgs);
      expect(urls, ['https://cdn.example.com/photo.jpg']);
    });

    test('source 为空串 → 忽略', () {
      final msgs = [_img('')];
      expect(extractImageUrlsFromMessages(msgs), isEmpty);
    });

    test('多个 ImageMessage → 按顺序全部收集', () {
      final msgs = [_img('url_a'), _img('url_b'), _img('url_c')];
      expect(extractImageUrlsFromMessages(msgs), ['url_a', 'url_b', 'url_c']);
    });
  });

  // ─────────────────────────────────────────────────────────
  // CustomMessage image 分支
  // ─────────────────────────────────────────────────────────
  group('CustomMessage — image 类型', () {
    test('msg_type=image + source 存在 → 使用 source', () {
      final msgs = [
        _custom({'msg_type': 'image', 'source': 'https://cdn/img.jpg'}),
      ];
      expect(extractImageUrlsFromMessages(msgs), ['https://cdn/img.jpg']);
    });

    test('msg_type=image + source 缺失 + uri 存在 → 使用 uri', () {
      final msgs = [
        _custom({'msg_type': 'image', 'uri': 'https://cdn/via_uri.jpg'}),
      ];
      expect(extractImageUrlsFromMessages(msgs), ['https://cdn/via_uri.jpg']);
    });

    test('msg_type=image + source 空串 + uri 空串 → 忽略', () {
      final msgs = [
        _custom({'msg_type': 'image', 'source': '', 'uri': ''}),
      ];
      expect(extractImageUrlsFromMessages(msgs), isEmpty);
    });

    test('effective_msg_type=image 优先于 msg_type 其他值', () {
      final msgs = [
        _custom({
          'msg_type': 'custom_other',
          'effective_msg_type': 'image',
          'source': 'https://cdn/effective.jpg',
        }),
      ];
      expect(extractImageUrlsFromMessages(msgs), ['https://cdn/effective.jpg']);
    });
  });

  // ─────────────────────────────────────────────────────────
  // CustomMessage image_multi 分支
  // ─────────────────────────────────────────────────────────
  group('CustomMessage — image_multi 类型', () {
    test('多图 → 按顺序收集所有 uri', () {
      final msgs = [
        _custom({
          'msg_type': 'imageMulti',
          'images': [
            {'uri': 'https://cdn/1.jpg'},
            {'uri': 'https://cdn/2.jpg'},
          ],
        }),
      ];
      expect(extractImageUrlsFromMessages(msgs), [
        'https://cdn/1.jpg',
        'https://cdn/2.jpg',
      ]);
    });

    test('images 列表中 uri 为空串 → 忽略该条', () {
      final msgs = [
        _custom({
          'msg_type': 'imageMulti',
          'images': [
            {'uri': 'https://cdn/ok.jpg'},
            {'uri': ''},
          ],
        }),
      ];
      expect(extractImageUrlsFromMessages(msgs), ['https://cdn/ok.jpg']);
    });

    test('images 字段缺失 → 空结果', () {
      final msgs = [
        _custom({'msg_type': 'imageMulti'}),
      ];
      expect(extractImageUrlsFromMessages(msgs), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────
  // 非图片类型忽略
  // ─────────────────────────────────────────────────────────
  group('非图片 CustomMessage → 忽略', () {
    test('msg_type=text → 忽略', () {
      final msgs = [
        _custom({'msg_type': 'text', 'text': 'hello'}),
      ];
      expect(extractImageUrlsFromMessages(msgs), isEmpty);
    });

    test('msg_type=video → 忽略', () {
      final msgs = [
        _custom({'msg_type': 'video', 'source': 'video.mp4'}),
      ];
      expect(extractImageUrlsFromMessages(msgs), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────
  // 混合消息列表
  // ─────────────────────────────────────────────────────────
  group('混合消息列表', () {
    test('ImageMessage + image + image_multi + text → 仅图片 URL 被收集', () {
      final msgs = [
        _img('https://cdn/a.jpg'),
        _custom({'msg_type': 'text', 'text': 'hello'}),
        _custom({'msg_type': 'image', 'source': 'https://cdn/b.jpg'}),
        _custom({
          'msg_type': 'imageMulti',
          'images': [
            {'uri': 'https://cdn/c.jpg'},
          ],
        }),
      ];
      expect(extractImageUrlsFromMessages(msgs), [
        'https://cdn/a.jpg',
        'https://cdn/b.jpg',
        'https://cdn/c.jpg',
      ]);
    });
  });
}
