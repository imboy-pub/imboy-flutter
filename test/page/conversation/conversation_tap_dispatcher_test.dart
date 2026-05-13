/// Step 1 RED — 会话点击派发决策纯函数
///
/// 决策语义：
/// - kIsWeb=true → 派发 WebSelectChat（Web Shell 内嵌右栏渲染，不离开页面）
/// - 其他平台 → 派发 MobilePushChat（携带 title/avatar/sign 等 metadata 跳路由）
/// - type 为 null/空字符串 → 默认 'C2C'（保持与既有 conversation_page.dart:365-367 兼容）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/conversation_tap_dispatcher.dart';

void main() {
  group('resolveConversationTap — Web 分支', () {
    test('isWeb=true → WebSelectChat 携带 peerId + chatType', () {
      final action = resolveConversationTap(
        useSplitView: true,
        peerId: 'u-001',
        type: 'C2C',
      );
      expect(action, isA<WebSelectChat>());
      action as WebSelectChat;
      expect(action.peerId, 'u-001');
      expect(action.chatType, 'C2C');
    });

    test('isWeb=true + type=C2G → WebSelectChat chatType=C2G', () {
      final action = resolveConversationTap(
        useSplitView: true,
        peerId: 'g-001',
        type: 'C2G',
      );
      expect(action, isA<WebSelectChat>());
      expect((action as WebSelectChat).chatType, 'C2G');
    });

    test(
      'isWeb=true + type=null → 默认 C2C（与 conversation_page.dart:365-367 兼容）',
      () {
        final action = resolveConversationTap(
          useSplitView: true,
          peerId: 'u-002',
          type: null,
        );
        expect((action as WebSelectChat).chatType, 'C2C');
      },
    );

    test('isWeb=true + type=空字符串 → 默认 C2C', () {
      final action = resolveConversationTap(
        useSplitView: true,
        peerId: 'u-003',
        type: '',
      );
      expect((action as WebSelectChat).chatType, 'C2C');
    });

    test('isWeb=true 不携带 title/avatar/sign（Web Shell 自己解析）', () {
      final action = resolveConversationTap(
        useSplitView: true,
        peerId: 'u-004',
        type: 'C2C',
        title: '应被忽略',
        avatar: 'http://x',
        sign: '签名',
      );
      // WebSelectChat 仅暴露 peerId + chatType
      expect(action, isA<WebSelectChat>());
      // 钉死契约：sealed 类无 title/avatar/sign 字段（编译器层面隐式钉）
    });
  });

  group('resolveConversationTap — Mobile 分支', () {
    test('isWeb=false → MobilePushChat 携带全 metadata', () {
      final action = resolveConversationTap(
        useSplitView: false,
        peerId: 'u-005',
        type: 'C2C',
        title: '张三',
        avatar: 'http://avatar',
        sign: '在线',
      );
      expect(action, isA<MobilePushChat>());
      action as MobilePushChat;
      expect(action.peerId, 'u-005');
      expect(action.chatType, 'C2C');
      expect(action.title, '张三');
      expect(action.avatar, 'http://avatar');
      expect(action.sign, '在线');
    });

    test('isWeb=false + type=null → MobilePushChat 默认 C2C', () {
      final action = resolveConversationTap(
        useSplitView: false,
        peerId: 'u-006',
        type: null,
      );
      expect((action as MobilePushChat).chatType, 'C2C');
    });

    test('isWeb=false 携带 type=C2G → 透传', () {
      final action = resolveConversationTap(
        useSplitView: false,
        peerId: 'g-002',
        type: 'C2G',
      );
      expect((action as MobilePushChat).chatType, 'C2G');
    });

    test('MobilePushChat title/avatar/sign 可全为 null', () {
      final action = resolveConversationTap(
        useSplitView: false,
        peerId: 'u-007',
        type: 'C2C',
      );
      action as MobilePushChat;
      expect(action.title, isNull);
      expect(action.avatar, isNull);
      expect(action.sign, isNull);
    });
  });

  group('sealed exhaustiveness', () {
    test('switch 必须穷尽 WebSelectChat / MobilePushChat 两个变体', () {
      String describe(ConversationTapAction action) {
        return switch (action) {
          WebSelectChat() => 'web',
          MobilePushChat() => 'mobile',
        };
      }

      expect(
        describe(
          resolveConversationTap(useSplitView: true, peerId: 'x', type: 'C2C'),
        ),
        'web',
      );
      expect(
        describe(
          resolveConversationTap(useSplitView: false, peerId: 'x', type: 'C2C'),
        ),
        'mobile',
      );
    });
  });

  group('== / hashCode', () {
    test('WebSelectChat 同字段相等', () {
      const a = WebSelectChat(peerId: 'p1', chatType: 'C2C');
      const b = WebSelectChat(peerId: 'p1', chatType: 'C2C');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('WebSelectChat 字段不同则不相等', () {
      const a = WebSelectChat(peerId: 'p1', chatType: 'C2C');
      const b = WebSelectChat(peerId: 'p1', chatType: 'C2G');
      expect(a, isNot(b));
    });

    test('MobilePushChat 同字段相等', () {
      const a = MobilePushChat(
        peerId: 'p1',
        chatType: 'C2C',
        title: 't',
        avatar: 'a',
        sign: 's',
      );
      const b = MobilePushChat(
        peerId: 'p1',
        chatType: 'C2C',
        title: 't',
        avatar: 'a',
        sign: 's',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
