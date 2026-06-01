/// TDD Test Suite for MessageModel.toTypeMessage() - msg_type Validation
///
/// 测试目标：验证 S2C 消息的 msg_type 验证逻辑
///
/// 问题背景：
/// - 服务端返回的 S2C 消息中 msg_type 为空字符串（符合 WebSocket API v2.0 规范）
/// - 客户端验证逻辑过于严格，未正确处理 S2C 消息的特殊性
/// - S2C 消息应该由 action 字段驱动，msg_type 可以为空
///
/// 修复方案：
/// - 区分 S2C 和非 S2C 消息的验证规则
/// - S2C 消息：如果 action 有效，msg_type 可以为空
/// - 非 S2C 消息：msg_type 必须非空

library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helper/sqflite_test_helper.dart';

void main() {
  // 初始化测试环境
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock SharedPreferences - 单元测试中需要
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // 设置测试用户 ID
    await StorageService.to.setString(Keys.currentUid, 'user1');
    // 设置测试用户数据（避免 UserRepoLocal.current 抛出异常）
    // UserModel 需要的字段：uid, nickname (必填), account, email, mobile, avatar, role, gender, region, sign, setting
    await StorageService.to.setString(
      Keys.currentUser,
      '{"uid": "user1", "nickname": "测试用户", "account": "", "email": "", "mobile": "", "avatar": "", "role": null, "gender": 0, "region": "", "sign": "", "setting": {}}',
    );
  });

  // Mock sqflite_sqlcipher before each test (handlers reset between tests)
  setUp(() => mockSqfliteSqlcipher());

  group('TDD: MessageModel.toTypeMessage() - S2C msg_type 验证', () {
    group('S2C 消息 - action 有效时 msg_type 可以为空', () {
      test('应该接受 S2C 消息的空 msg_type 当 action 为 pull_offline_msg 时', () async {
        // GIVEN: 一个 S2C 消息，action 有效，msg_type 为空
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'S2C',
          status: 21, // seen
          fromId: 8001, // 设置为当前用户 ID 以避免 ContactRepo 查询
          toId: 8001,
          msgType: '', // 空 msg_type
          action: S2CAction.pullOfflineMsg, // 有效的 action
          payload: {'count': 10},
          isAuthor: 0,
          conversationUk3: 'S2C_user1',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换，不是错误消息
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['error'], isNull);
        expect(message.metadata?['action'], equals(S2CAction.pullOfflineMsg));
      });

      test('应该接受 S2C 消息的空 msg_type 当 action 为 c2c_revoke 时', () async {
        // GIVEN: 一个 S2C 撤回消息，action 有效，msg_type 为空
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'S2C',
          status: 30, // peer_revoked
          fromId: 8001, // 设置为当前用户 ID 以避免 ContactRepo 查询
          toId: 8001,
          msgType: '', // 空 msg_type
          action: S2CAction.c2cRevoke, // 有效的 action
          payload: {'msg_id': 'original_msg_id', 'operator_id': 'user2'},
          isAuthor: 0,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换，不是错误消息
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['error'], isNull);
        expect(message.metadata?['action'], equals(S2CAction.c2cRevoke));
      });

      test('应该接受 S2C 消息的空 msg_type 当 action 为 apply_friend 时', () async {
        // GIVEN: 一个 S2C 好友申请消息，action 有效，msg_type 为空
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'S2C',
          status: 21,
          fromId: 8001, // 设置为当前用户 ID 以避免 ContactRepo 查询
          toId: 8001,
          msgType: '', // 空 msg_type
          action: S2CAction.applyFriend, // 有效的 action
          payload: {'remark': '我是张三', 'extra': '请加我好友'},
          isAuthor: 0,
          conversationUk3: 'S2C_user1',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换，不是错误消息
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['error'], isNull);
        expect(message.metadata?['action'], equals(S2CAction.applyFriend));
      });

      test('应该接受 S2C 消息的空 msg_type 当 action 为 group_member_join 时', () async {
        // GIVEN: 一个 S2C 群成员加入消息，action 有效，msg_type 为空
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'S2C',
          status: 21,
          fromId: 8001, // 设置为当前用户 ID 以避免 ContactRepo 查询
          toId: 8001,
          msgType: '', // 空 msg_type
          action: S2CAction.groupMemberJoin, // 有效的 action
          payload: {
            'group_id': 'group123',
            'member_id': 'new_user',
            'member_nickname': '新成员',
          },
          isAuthor: 0,
          conversationUk3: 'C2G_group123',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换，不是错误消息
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['error'], isNull);
        expect(message.metadata?['action'], equals(S2CAction.groupMemberJoin));
      });

      test('应该拒绝 S2C 消息当 action 为空且 msg_type 为空时', () async {
        // GIVEN: 一个 S2C 消息，action 和 msg_type 都为空
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'S2C',
          status: 21,
          fromId: 8001, // 设置为当前用户 ID 以避免 ContactRepo 查询
          toId: 8001,
          msgType: '', // 空 msg_type
          action: '', // 空 action
          payload: <String, dynamic>{}, // 明确指定类型
          isAuthor: 0,
          conversationUk3: 'S2C_user1',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该返回错误消息
        expect(message, isA<TextMessage>());
        final textMessage = message as TextMessage;
        expect(textMessage.text, equals('[无效消息类型]'));
        expect(textMessage.metadata?['error'], equals('invalid_msg_type'));
      });

      test('应该拒绝 S2C 消息当 action 为 null 且 msg_type 为空时', () async {
        // GIVEN: 一个 S2C 消息，action 为 null，msg_type 为空
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'S2C',
          status: 21,
          fromId: 8001, // 设置为当前用户 ID 以避免 ContactRepo 查询
          toId: 8001,
          msgType: '', // 空 msg_type
          action: null, // null action
          payload: {'data': 'test'}, // 添加一些数据以避免 payload 验证失败
          isAuthor: 0,
          conversationUk3: 'S2C_user1',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该返回错误消息
        expect(message, isA<TextMessage>());
        final textMessage = message as TextMessage;
        expect(textMessage.text, equals('[无效消息类型]'));
        expect(textMessage.metadata?['error'], equals('invalid_msg_type'));
      });

      test('应该接受 S2C 消息当 msg_type 和 action 都有效时', () async {
        // GIVEN: 一个 S2C 消息，msg_type 和 action 都有效
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'S2C',
          status: 21,
          fromId: 8001, // 设置为当前用户 ID 以避免 ContactRepo 查询
          toId: 8001,
          msgType: 'text', // 有效的 msg_type
          action: S2CAction.pullOfflineMsg, // 有效的 action
          payload: {'text': '系统通知'},
          isAuthor: 0,
          conversationUk3: 'S2C_user1',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换
        expect(message, isA<TextMessage>());
        expect(message.metadata?['error'], isNull);
      });
    });

    group('非 S2C 消息 - msg_type 必须非空', () {
      test('应该拒绝 C2C 消息的空 msg_type', () async {
        // GIVEN: 一个 C2C 消息，msg_type 为空
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 8002,
          msgType: '', // 空 msg_type
          payload: {'text': 'Hello'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该返回错误消息
        expect(message, isA<TextMessage>());
        final textMessage = message as TextMessage;
        expect(textMessage.text, equals('[无效消息类型]'));
        expect(textMessage.metadata?['error'], equals('invalid_msg_type'));
      });

      test('应该拒绝 C2C 消息的 null msg_type', () async {
        // GIVEN: 一个 C2C 消息，msg_type 为 null
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 8002,
          msgType: null, // null msg_type
          payload: {'text': 'Hello'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该返回错误消息
        expect(message, isA<TextMessage>());
        final textMessage = message as TextMessage;
        expect(textMessage.text, equals('[无效消息类型]'));
        expect(textMessage.metadata?['error'], equals('invalid_msg_type'));
      });

      test('应该正确处理 C2C 消息的有效 msg_type (text)', () async {
        // GIVEN: 一个 C2C 消息，msg_type 有效
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 8002,
          msgType: MessageType.text, // 有效的 msg_type
          payload: {'text': 'Hello World'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换为 TextMessage
        expect(message, isA<TextMessage>());
        final textMessage = message as TextMessage;
        expect(textMessage.text, equals('Hello World'));
        expect(textMessage.metadata?['error'], isNull);
      });

      test('应该正确处理 C2C 消息的有效 msg_type (image)', () async {
        // GIVEN: 一个 C2C 图片消息
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 8002,
          msgType: MessageType.image,
          payload: {'uri': 'https://example.com/image.jpg', 'size': 102400},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换为 ImageMessage
        expect(message, isA<ImageMessage>());
        expect(message.metadata?['error'], isNull);
      });

      test('应该正确处理 C2C 消息的有效 msg_type (custom - location)', () async {
        // GIVEN: 一个 C2C 自定义消息（location 类型）
        // 注意：location 需要自定义 UI builder，在 flutter_chat_ui 中被视为 custom 类型
        // 代码会将其标记为 unknown_msg_type，这是预期行为
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 8002,
          msgType: MessageType.location,
          payload: {'latitude': 39.9042, 'longitude': 116.4074},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换为 CustomMessage（location 使用自定义 builder）
        expect(message, isA<CustomMessage>());
        // location 被视为未知类型，因为代码中没有显式处理
        expect(message.metadata?['msg_type'], equals(MessageType.location));
      });

      test('应该正确处理 C2C 消息的 visitCard 类型 (小驼峰)', () async {
        // GIVEN: 一个 C2C 名片消息（visitCard 类型）
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 8002,
          msgType: 'visitCard',
          payload: {
            'uid': 'user123',
            'title': '张三',
            'avatar': 'https://example.com/avatar.jpg',
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换为 CustomMessage
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['effective_msg_type'], equals('visitCard'));
      });

      test('应该拒绝 C2C 消息的下划线类型 (visit_card)', () async {
        // GIVEN: 一个 C2C 消息，msg_type=visit_card（非标准命名）
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 8002,
          msgType: 'visit_card',
          payload: {
            'uid': 'user123',
            'title': '张三',
            'avatar': 'https://example.com/avatar.jpg',
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该落入 unsupported 分支
        expect(message, isA<CustomMessage>());
        expect(
          message.metadata?['effective_msg_type'],
          equals('unsupported'),
          reason: 'visit_card 不应再被归一化',
        );
        expect(message.metadata?['error'], equals('unknown_msg_type'));
      });
    });

    group('C2G 消息 - msg_type 必须非空', () {
      test('应该拒绝 C2G 消息的空 msg_type', () async {
        // GIVEN: 一个 C2G 消息，msg_type 为空
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2G',
          status: 11,
          fromId: 8001,
          toId: 123,
          msgType: '', // 空 msg_type
          payload: {'text': 'Hello group'},
          isAuthor: 1,
          conversationUk3: 'C2G_group123',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该返回错误消息
        expect(message, isA<TextMessage>());
        final textMessage = message as TextMessage;
        expect(textMessage.text, equals('[无效消息类型]'));
        expect(textMessage.metadata?['error'], equals('invalid_msg_type'));
      });

      test('应该正确处理 C2G 消息的有效 msg_type', () async {
        // GIVEN: 一个 C2G 消息，msg_type 有效
        final model = MessageModel(
          '123',
          autoId: 1,
          type: 'C2G',
          status: 11,
          fromId: 8001,
          toId: 123,
          msgType: MessageType.text,
          payload: {'text': 'Hello group'},
          isAuthor: 1,
          conversationUk3: 'C2G_group123',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该成功转换为 TextMessage
        expect(message, isA<TextMessage>());
        final textMessage = message as TextMessage;
        expect(textMessage.text, equals('Hello group'));
        expect(textMessage.metadata?['error'], isNull);
      });
    });
  });
}
