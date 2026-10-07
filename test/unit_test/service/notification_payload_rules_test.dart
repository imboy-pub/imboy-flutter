// 通知 payload 解析纯函数测试
//
// 钉死 [parseNotificationPayload] 与 [resolveNotificationType] 的契约：
// - 多键兼容（snake_case / camelCase / 旧 FCM 键 `conversation_id`）
// - 各分支路径生成（c2c / c2g / friend_request / group_invite / unknown）
// - 缺关键字段 → Skip 而非 throw / null pointer
// - C1 隐私不变量（Q09）：服务端聊天推送 Data 为空 → 点击必 Skip（待用户决策）
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

    test('显式 notify_type=org_invite（P1 组织邀请触达）', () {
      expect(
        resolveNotificationType({'notify_type': 'org_invite'}),
        NotificationType.orgInvite,
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

  group('parseNotificationPayload — org_invite 分支（P1 组织邀请触达）', () {
    test('org_invite → NotificationOrgInvitationRoute，路由到我的邀请页', () {
      final result = parseNotificationPayload({
        'notify_type': 'org_invite',
        'organization_id': '7266418340025468930',
      });
      expect(result, isA<NotificationOrgInvitationRoute>());
      // 目标页由服务端按 JWT 解析 target 视角列表，orgId 占位 0
      expect(
        (result as NotificationOrgInvitationRoute).toRoutePath(),
        '/organization/0/invitations?mode=mine',
      );
    });

    test('org_invite 无附加字段也返回路由（mine 页不依赖 payload 字段）', () {
      final result = parseNotificationPayload({'notify_type': 'org_invite'});
      expect(result, isA<NotificationOrgInvitationRoute>());
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

  /// ⚠️ 待用户决策 C1（Q09 / 2026-10-07）——隐私不变量固化（防回归组）。
  ///
  /// 服务端 C2C/C2G 聊天推送 Data **恒为空**（文案恒常量「新消息/
  /// 发来一条消息」，推送 payload 禁止携带 peer_id/chat_type 等动态内容，
  /// 见 imboy push_notification_logic 隐私注释）。因此远程聊天推送点击后
  /// 必然 Skip、不导航到会话；仅 org_invite（notify_type 常量）与本地通知
  /// （App 自建 payload 携带完整坐标）可路由。
  ///
  /// 这与 AC23「点击正确会话」存在合同冲突（CONTRACT_CONFLICT C1）：
  /// (a) 服务端放宽 Data 白名单至 {notify_type, peer_id, chat_type} 常量
  /// 坐标集 / (b) 验收口径改为仅 org_invite 可路由、聊天推送点击降级
  /// 「打开 App」。**决策前任何人不得改变本组断言的现状语义**；若决策
  /// 结果为 (a)，需同步改服务端 Data 构造、本模块无需变化（schema 已备），
  /// 并按新合同重写本组。
  ///
  /// 对应消费链已有覆盖：
  /// - FCM 点击：push_notification_service `_handleNotificationTap` → 本函数；
  /// - JPush 点击：jpush_flutter_binding_test「空 payload → skip 结果（不路由）」。
  group('C1 隐私不变量 — 服务端聊天推送 Data 为空 → 点击必 Skip（待用户决策）', () {
    test('空 data（服务端 C2C/C2G 聊天推送的真实形态）→ Skip(empty_payload)，绝不路由', () {
      final result = parseNotificationPayload(<String, dynamic>{});
      expect(result, isA<NotificationParseSkip>());
      expect((result as NotificationParseSkip).reason, 'empty_payload');
      // 不变量：Skip 不是任何路由类型（不进入 /chat、/group、/contact、
      // /organization 任何一条路径）。
      expect(result, isNot(isA<NotificationMessageRoute>()));
      expect(result, isNot(isA<NotificationFriendRequestRoute>()));
      expect(result, isNot(isA<NotificationGroupInviteRoute>()));
      expect(result, isNot(isA<NotificationOrgInvitationRoute>()));
    });

    test('通知文案非空但 data 无路由键（常量文案 + 空坐标）→ 仍 Skip', () {
      // 服务端推送的 notification 部分（title/body 常量文案）从不进入本
      // 解析器；即便上游把文案字段误塞进 data，只要没有路由坐标，
      // 也必须 Skip——文案不是导航依据。
      final result = parseNotificationPayload(<String, dynamic>{
        'title': '新消息',
        'body': '发来一条消息',
      });
      expect(result, isA<NotificationParseSkip>());
      expect((result as NotificationParseSkip).reason, 'unknown_type');
    });

    test('org_invite（唯一携带 Data 的推送类型）→ 仍可路由（白名单现状固化）', () {
      final result = parseNotificationPayload(<String, dynamic>{
        'notify_type': 'org_invite',
      });
      expect(result, isA<NotificationOrgInvitationRoute>());
    });

    test('本地通知（App 自建 payload 携带完整坐标）→ 正常路由（对照锚点）', () {
      // 对照组：本地通知不受 C1 影响（Data 由 App 侧构造，非服务端推送），
      // 点击正常进入会话——证明本组 Skip 断言针对的是「服务端推送 Data
      // 为空」这一形态，而非解析器整体失效。
      final result = parseNotificationPayload(<String, dynamic>{
        'type': 'message',
        'peerId': '1838294017982465',
        'chatType': 'C2G',
      });
      expect(result, isA<NotificationMessageRoute>());
      expect((result as NotificationMessageRoute).chatType, 'C2G');
    });
  });
}
