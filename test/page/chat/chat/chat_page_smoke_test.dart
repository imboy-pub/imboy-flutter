import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/chat/chat_page.dart';

/// ChatPage 类型契约 + 构造参数 smoke test
///
/// 完整 widget mount 测试因 ChatPage 复杂度极高（1808 行 + 2 个 mixin
/// + ChatNotifier.build 链 + UserRepoLocal/SqliteService/WebSocket/EventBus
/// 多源副作用）超出本轮范围，留待专门 sprint 用 fake 全面注入测试。
///
/// 本文件目标：
///   - 钉死 ChatPage 构造参数契约：type / peerId / peerTitle / peerAvatar / peerSign
///     / msgId / options 字段类型 + 默认值
///   - 钉死 type 默认值 'C2C'
///   - 钉死 msgId 默认空字符串
///   - 钉死 options 默认 null
///   - 钉死 必填字段不能省（编译期强制）
///   - widget 是 [StatefulWidget]（含 mixin state）
///
/// 这些断言保证未来重构 ChatPage 不会无意破坏 Hero / 路由 / 调用方契约。
void main() {
  group('ChatPage construction contract', () {
    test('default type is "C2C"', () {
      const page = ChatPage(
        peerId: 'peer_1',
        peerTitle: 'Alice',
        peerAvatar: '',
        peerSign: '',
      );
      expect(page.type, 'C2C');
    });

    test('default msgId is empty string', () {
      const page = ChatPage(
        peerId: 'peer_1',
        peerTitle: 'Alice',
        peerAvatar: '',
        peerSign: '',
      );
      expect(page.msgId, '');
    });

    test('default options is null', () {
      const page = ChatPage(
        peerId: 'peer_1',
        peerTitle: 'Alice',
        peerAvatar: '',
        peerSign: '',
      );
      expect(page.options, isNull);
    });

    test('accepts type=C2G group chat scenario', () {
      const page = ChatPage(
        type: 'C2G',
        peerId: 'group_42',
        peerTitle: 'Family Group',
        peerAvatar: 'avatar.png',
        peerSign: 'family chat',
      );
      expect(page.type, 'C2G');
      expect(page.peerId, 'group_42');
      expect(page.peerTitle, 'Family Group');
    });

    test('accepts type=C2S service chat scenario', () {
      const page = ChatPage(
        type: 'C2S',
        peerId: 'service_kefu',
        peerTitle: 'Customer Service',
        peerAvatar: '',
        peerSign: '',
      );
      expect(page.type, 'C2S');
    });

    test('accepts msgId for jumping to specific message', () {
      const page = ChatPage(
        peerId: 'peer_1',
        peerTitle: 'Alice',
        peerAvatar: '',
        peerSign: '',
        msgId: 'xid_msg_12345',
      );
      expect(page.msgId, 'xid_msg_12345');
    });

    test('accepts options map (memberCount / popTime / showConversation)', () {
      const page = ChatPage(
        type: 'C2G',
        peerId: 'group_1',
        peerTitle: 'Test Group',
        peerAvatar: '',
        peerSign: '',
        options: {
          'memberCount': 12,
          'popTime': 2,
          'showConversation': false,
        },
      );
      expect(page.options, isNotNull);
      expect(page.options?['memberCount'], 12);
      expect(page.options?['popTime'], 2);
      expect(page.options?['showConversation'], false);
    });

    test('ChatPage is a StatefulWidget (has mixin state)', () {
      const page = ChatPage(
        peerId: 'peer_1',
        peerTitle: 'Alice',
        peerAvatar: '',
        peerSign: '',
      );
      // ConsumerStatefulWidget extends StatefulWidget
      expect(page, isA<StatefulWidget>());
      // 不能用 const Widget 类型去 cast 成 ChatPage 之外的类型
      expect(page, isA<ChatPage>());
    });
  });
}
