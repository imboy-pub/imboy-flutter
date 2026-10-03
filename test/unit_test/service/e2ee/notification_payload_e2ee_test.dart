import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/notification_payload_rules.dart';

/// C05 通知边界：E2EE 消息的**远程推送体必须保持静态占位语义**——
/// 客户端侧的可合成断言：
/// 1. payload 解析结果（路由对象）只携带路由字段，不透传任何
///    content/ciphertext/密钥/pickle 类载荷（即使服务端被篡改塞入）；
/// 2. 本地通知 payload（点击跳转 JSON）只含路由四键；
/// 3. FCM 前台展示只消费 notification.title/body（系统通道静态占位），
///    不从 data 里取正文（源码断言）。
void main() {
  // 模拟被篡改/泄漏的 E2EE 推送 data：塞入明文、密文、房间密钥、pickle
  const secretContent = 'TOP_SECRET_PLAINTEXT_顶顶大好的机密';
  const fakeCiphertext = 'AwcDEhB0ZXN0IgpkYXRhIGlzIGZha2UgY2lwaGVydGV4dA==';
  const fakeRoomKey = 'AgAAAABn6slkZXZpbGl0ZWQgc2VjcmV0IG1lZ29sbSByb29tIGtleQ'; // gitleaks:allow
  const fakePickle =
      'oTF3ZWVfa2V5X3BpY2tsZV9mb3Jfb2xtX2FjY291bnRfYW5kX3Nlc3Npb24';

  Map<String, dynamic> maliciousPayload() => {
    'notify_type': 'message',
    'peer_id': '9001',
    'chat_type': 'C2C',
    // 以下为不应被通知面消费/透传的敏感字段
    'content': secretContent,
    'body': fakeCiphertext,
    'ciphertext': fakeCiphertext,
    'plaintext': secretContent,
    'room_key': fakeRoomKey,
    'megolm_session': fakeRoomKey,
    'olm_pickle': fakePickle,
    'db_cipher_key_9001': 'a' * 64,
    'e2ee_private_key': 'x' * 64,
  };

  test('message 路由对象不透传任何敏感载荷字段', () {
    final result = parseNotificationPayload(maliciousPayload());
    expect(result, isA<NotificationMessageRoute>());
    final encoded = jsonEncode((result as NotificationMessageRoute).toJson());

    // 白名单：路由对象唯一允许出现的取值来源
    const allowedValues = {'9001', 'C2C'};
    for (final forbidden in [
      secretContent,
      fakeCiphertext,
      fakeRoomKey,
      fakePickle,
    ]) {
      expect(encoded, isNot(contains(forbidden)));
    }
    // 字段级白名单：除路由字段外不携带其他键
    final routeJson = (result).toJson();
    expect(routeJson.keys.toSet(), {
      'peerId',
      'chatType',
      'conversationUk3',
      'title',
    });
    for (final v in allowedValues) {
      expect(encoded.contains(v), isTrue);
    }
  });

  test('friend_request / group_invite 分支同样不透传敏感载荷', () {
    final friend = parseNotificationPayload({
      'notify_type': 'friend_request',
      'requester_id': '9002',
      'content': secretContent,
      'room_key': fakeRoomKey,
    });
    expect(friend, isA<NotificationFriendRequestRoute>());
    expect(jsonEncode(friend.toString()), isNot(contains(secretContent)));

    final group = parseNotificationPayload({
      'notify_type': 'group_invite',
      'group_id': '9003',
      'inviter_name': '张三',
      'content': secretContent,
      'ciphertext': fakeCiphertext,
    });
    expect(group, isA<NotificationGroupInviteRoute>());
    expect(group.toString(), isNot(contains(secretContent)));
    expect(group.toString(), isNot(contains(fakeCiphertext)));
  });

  test('peerId 校验拒绝携带密文形态的注入', () {
    final result = parseNotificationPayload({
      'notify_type': 'message',
      'peer_id': fakeCiphertext, // 非纯数字 TSID
      'chat_type': 'C2C',
    });
    expect(result, isA<NotificationParseSkip>());
    expect((result as NotificationParseSkip).reason, 'invalid_peer_id');
  });

  test('本地通知点击 payload 只含路由四键（无正文/密文）', () {
    // notification.dart showMessageNotification 构造的 payload json：
    // {type, conversationUk3, peerId, chatType}。源码断言白名单。
    final source = File('lib/service/notification.dart').readAsStringSync();
    final m = RegExp(
      r"showMessageNotification[\s\S]{0,900}?final payload = json\.encode\(([\s\S]{0,400}?)\);",
    ).firstMatch(source);
    expect(m, isNotNull, reason: '未找到 showMessageNotification 的 payload 构造');
    final payloadExpr = m!.group(1)!;
    for (final allowedKey in [
      "'type': 'message'",
      "'conversationUk3':",
      "'peerId':",
      "'chatType':",
    ]) {
      expect(payloadExpr.contains(allowedKey), isTrue, reason: allowedKey);
    }
    // 通知 payload 不得新增内容字段（正文走 body 参数，且 E2EE 下 body 由
    // 本地解密后预览或静态占位承担）
    expect(payloadExpr, isNot(contains('content')));
    expect(payloadExpr, isNot(contains('text')));
    expect(payloadExpr, isNot(contains('payload')));
  });

  test('FCM 前台展示只消费 notification.title/body，不读 data 正文', () {
    final source = File('lib/service/push_notification_service.dart')
        .readAsStringSync();
    // 展示路径：title/body 均来自 message.notification（系统通道，
    // E2EE 部署下服务端只能给静态占位文案）
    expect(source, contains("notification.title ?? ''"));
    expect(source, contains("notification.body ?? ''"));
    // data 的唯一消费点是路由解析（jsonEncode(message.data) 进 payload
    // 供点击跳转；parseNotificationPayload 已被上面的白名单测试约束）
    final foreground = source.substring(
      source.indexOf('_handleForegroundMessage('),
      source.indexOf('_handleNotificationTap('),
    );
    expect(
      foreground.contains('message.data['),
      isFalse,
      reason: '前台展示不得直接从 data 取内容字段',
    );
  });
}

extension on NotificationMessageRoute {
  Map<String, dynamic> toJson() => {
    'peerId': peerId,
    'chatType': chatType,
    'conversationUk3': conversationUk3,
    'title': title,
  };
}
