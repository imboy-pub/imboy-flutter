/// Phase 2.1.b-5a RED — Web Shell 长按消息可用动作决策纯函数
///
/// 决策语义：
/// - TextMessage (非空 text) → 返回 text，可复制
/// - TextMessage (空 / 全空白 text) → null（无可复制内容，菜单不显示复制项）
/// - 其他 Message 类型 (Image / File / Custom 等) → null（本切片暂不支持）
///
/// 设计：纯函数 + 零外部副作用（Clipboard 调用在调用方），便于测试
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_message_actions.dart';

DateTime _t() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

void main() {
  group('resolveCopyableText — TextMessage', () {
    test('非空 text → 返回 text', () {
      final msg = TextMessage(
        authorId: 'u1',
        createdAt: _t(),
        id: 'm1',
        text: 'Hello world',
      );
      expect(resolveCopyableText(msg), 'Hello world');
    });

    test('text 含中文 → 透传', () {
      final msg = TextMessage(
        authorId: 'u1',
        createdAt: _t(),
        id: 'm2',
        text: '你好世界',
      );
      expect(resolveCopyableText(msg), '你好世界');
    });

    test('text 含前后空白 → 透传保留（trim 仅判存）', () {
      final msg = TextMessage(
        authorId: 'u1',
        createdAt: _t(),
        id: 'm3',
        text: '  spaced  ',
      );
      expect(resolveCopyableText(msg), '  spaced  ',
          reason: '复制内容应保留原始空白以便用户粘贴');
    });

    test('text 为空字符串 → null', () {
      final msg = TextMessage(
        authorId: 'u1',
        createdAt: _t(),
        id: 'm4',
        text: '',
      );
      expect(resolveCopyableText(msg), isNull);
    });

    test('text 全空白 → null', () {
      final msg = TextMessage(
        authorId: 'u1',
        createdAt: _t(),
        id: 'm5',
        text: '   \t\n  ',
      );
      expect(resolveCopyableText(msg), isNull);
    });
  });

  group('resolveCopyableText — 其他类型', () {
    test('ImageMessage → null（本切片暂不支持）', () {
      final msg = ImageMessage(
        authorId: 'u1',
        createdAt: _t(),
        id: 'm6',
        source: 'http://example.com/x.jpg',
      );
      expect(resolveCopyableText(msg), isNull);
    });

    test('CustomMessage → null', () {
      final msg = CustomMessage(
        authorId: 'u1',
        createdAt: _t(),
        id: 'm7',
        metadata: const {'kind': 'quote'},
      );
      expect(resolveCopyableText(msg), isNull);
    });
  });
}
