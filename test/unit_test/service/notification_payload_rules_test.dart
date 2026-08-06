// 通知 payload 解析纯函数测试
//
// 钉死 [parseNotificationPayload] 与 [resolveNotificationType] 的契约：
// - 多键兼容（snake_case / camelCase / 旧 FCM 键 `conversation_id`）
// - 各分支路径生成（c2c / c2g / friend_request / group_invite / unknown）
// - 缺关键字段 → Skip 而非 throw / null pointer
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/notification_payload_rules.dart';

void main() {
  group('resolveNotificationType', () {
    test('显式 notify_type=message 返回 message', () {
      expect(
        resolveNotificationType({'notify_type': 'message'}),
        NotificationType.message,
      );
    });

    test('显式 notify_type=friend_request', () {
      expect(
        resolveNotificationType({'notify_type': 'friend_request'}),
        NotificationType.friendRequest,
      );
    });

    test('显式 notify_type=group_invite', () {
      expect(
        resolveNotificationType({'notify_type': 'group_invite'}),
        NotificationType.groupInvite,
      );
    });

    test('本地通知 type=message 兼容', () {
      expect(
        resolveNotificationType({'type': 'message'}),
        NotificationType.message,
      );
    });

    test('旧 FCM payload 仅含 conversation_id 兜底为 message', () {
      expect(
        resolveNotificationType({
          'conversation_id': '12345',
          'type': 'C2C', // 注意此 type 是 chatType 不是 notify_type
        }),
        NotificationType.message,
      );
    });

    test('空 payload 返回 unknown', () {
      expect(resolveNotificationType({}), NotificationType.unknown);
    });

    test('未知 notify_type 且无 conversation 字段 返回 unknown', () {
      expect(
        resolveNotificationType({'notify_type': 'system_alert'}),
        NotificationType.unknown,
      );
    });
  });

  group('parseNotificationPayload — message 分支', () {
    test('c2c 本地通知（camelCase）→ NotificationMessageRoute', () {
      final result = parseNotificationPayload({
        'type': 'message',
        'peerId': '1838294017982465',
        'chatType': 'C2C',
        'conversationUk3': 'c2c:100:200',
      });
      expect(result, isA<NotificationMessageRoute>());
      final r = result as NotificationMessageRoute;
      expect(r.peerId, '1838294017982465');
      expect(r.chatType, 'C2C');
      expect(r.conversationUk3, 'c2c:100:200');
      expect(r.toRoutePath(), '/chat/1838294017982465?type=C2C');
    });

    test('c2g FCM 推送（snake_case）→ NotificationMessageRoute', () {
      final result = parseNotificationPayload({
        'notify_type': 'message',
        'peer_id': '999888777',
        'chat_type': 'C2G',
        'conversation_uk3': 'c2g:777',
        'title': '测试群',
      });
      expect(result, isA<NotificationMessageRoute>());
      final r = result as NotificationMessageRoute;
      expect(r.peerId, '999888777');
      expect(r.chatType, 'C2G');
      expect(r.conversationUk3, 'c2g:777');
      expect(r.title, '测试群');
      expect(r.toRoutePath(), '/chat/999888777?type=C2G');
    });

    test('旧 FCM payload（conversation_id + type=C2C）兼容', () {
      final result = parseNotificationPayload({
        'conversation_id': '1838294017982465',
        'type': 'C2C',
      });
      expect(result, isA<NotificationMessageRoute>());
      final r = result as NotificationMessageRoute;
      expect(r.peerId, '1838294017982465');
      expect(r.chatType, 'C2C');
    });

    test('message 缺 peer_id 返回 Skip(missing_peer_id)', () {
      final result = parseNotificationPayload({
        'notify_type': 'message',
        'chat_type': 'C2C',
      });
      expect(result, isA<NotificationParseSkip>());
      expect((result as NotificationParseSkip).reason, 'missing_peer_id');
    });

    test('message 缺 chat_type 时默认 C2C', () {
      final result = parseNotificationPayload({
        'notify_type': 'message',
        'peer_id': '12345',
      });
      expect(result, isA<NotificationMessageRoute>());
      expect((result as NotificationMessageRoute).chatType, 'C2C');
    });
  });

  group('parseNotificationPayload — friend_request 分支', () {
    test('友请求通知（camelCase）', () {
      final result = parseNotificationPayload({
        'type': 'friend_request',
        'requesterId': '1001',
      });
      expect(result, isA<NotificationFriendRequestRoute>());
      final r = result as NotificationFriendRequestRoute;
      expect(r.requesterId, '1001');
      expect(r.toRoutePath(), '/contact/new_friend');
    });

    test('好友请求通知（snake_case + 缺 requester_id）仍返回路由', () {
      final result = parseNotificationPayload({
        'notify_type': 'friend_request',
      });
      expect(result, isA<NotificationFriendRequestRoute>());
      expect((result as NotificationFriendRequestRoute).requesterId, isNull);
      expect(result.toRoutePath(), '/contact/new_friend');
    });
  });

  group('parseNotificationPayload — group_invite 分支', () {
    test('群邀请（camelCase + 完整字段）', () {
      final result = parseNotificationPayload({
        'type': 'group_invite',
        'peerId': '500',
        'inviterName': 'Alice',
        'groupName': '产品讨论',
      });
      expect(result, isA<NotificationGroupInviteRoute>());
      final r = result as NotificationGroupInviteRoute;
      expect(r.groupId, '500');
      expect(r.inviterName, 'Alice');
      expect(r.groupName, '产品讨论');
      expect(r.toRoutePath(), '/group/detail/500');
    });

    test('群邀请（snake_case + group_id 优先于 peer_id）', () {
      final result = parseNotificationPayload({
        'notify_type': 'group_invite',
        'group_id': '777',
        'peer_id': '888', // 兜底，不应被采用
      });
      expect(result, isA<NotificationGroupInviteRoute>());
      expect((result as NotificationGroupInviteRoute).groupId, '777');
      expect(result.toRoutePath(), '/group/detail/777');
    });

    test('群邀请缺 group_id 返回 Skip(missing_group_id)', () {
      final result = parseNotificationPayload({'notify_type': 'group_invite'});
      expect(result, isA<NotificationParseSkip>());
      expect((result as NotificationParseSkip).reason, 'missing_group_id');
    });
  });

  group('parseNotificationPayload — 异常分支', () {
    test('空 payload 返回 Skip(empty_payload)', () {
      final result = parseNotificationPayload({});
      expect(result, isA<NotificationParseSkip>());
      expect((result as NotificationParseSkip).reason, 'empty_payload');
    });

    test('未知 type 返回 Skip(unknown_type)', () {
      final result = parseNotificationPayload({
        'notify_type': 'system_alert',
        'foo': 'bar',
      });
      expect(result, isA<NotificationParseSkip>());
      expect((result as NotificationParseSkip).reason, 'unknown_type');
    });

    test('字段值含空白被 trim 后视为缺失', () {
      final result = parseNotificationPayload({
        'notify_type': 'message',
        'peer_id': '   ',
      });
      expect(result, isA<NotificationParseSkip>());
      expect((result as NotificationParseSkip).reason, 'missing_peer_id');
    });

    test('数值类型 peer_id 自动 toString', () {
      final result = parseNotificationPayload({
        'notify_type': 'message',
        'peer_id': 1838294017982465,
        'chat_type': 'C2C',
      });
      expect(result, isA<NotificationMessageRoute>());
      expect((result as NotificationMessageRoute).peerId, '1838294017982465');
    });
  });

  group('N-02 peerId 格式校验', () {
    test('isValidNotificationPeerId: 合法纯数字 TSID 通过', () {
      expect(isValidNotificationPeerId('1838294017982465'), isTrue);
      expect(isValidNotificationPeerId('1'), isTrue);
    });

    test('isValidNotificationPeerId: 空/超长/含非数字字符拒绝', () {
      expect(isValidNotificationPeerId(''), isFalse);
      expect(
        isValidNotificationPeerId('123456789012345678901'),
        isFalse,
      ); // 21位
      expect(isValidNotificationPeerId('12a45'), isFalse);
      expect(isValidNotificationPeerId('c2c:1:2'), isFalse);
      expect(isValidNotificationPeerId('../../etc'), isFalse);
      expect(isValidNotificationPeerId('123 456'), isFalse);
    });

    test('parseNotificationPayload: 非法 peerId 降级为 invalid_peer_id Skip', () {
      final result = parseNotificationPayload({
        'notify_type': 'message',
        'peer_id': '../../malicious',
        'chat_type': 'C2C',
      });
      expect(result, isA<NotificationParseSkip>());
      expect((result as NotificationParseSkip).reason, 'invalid_peer_id');
    });

    test('parseNotificationPayload: 合法 peerId 仍正常路由', () {
      final result = parseNotificationPayload({
        'notify_type': 'message',
        'peer_id': '1838294017982465',
        'chat_type': 'C2C',
      });
      expect(result, isA<NotificationMessageRoute>());
      expect((result as NotificationMessageRoute).peerId, '1838294017982465');
    });
  });
}
