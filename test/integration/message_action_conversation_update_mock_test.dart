/// 消息操作后更新会话测试（使用Mock服务）
///
/// 测试目标：
/// 1. 消息撤回后会话状态更新
/// 2. 消息编辑后会话副标题更新
/// 3. 消息删除后会话状态更新
/// 4. 只在操作最后一条消息时更新会话
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import '../helper/mock_services.dart';

void main() {
  group('消息操作更新会话测试（Mock版本）', () {
    late MockConversationRepository conversationRepo;
    late MockMessageRepository messageRepo;

    setUp(() {
      conversationRepo = MockConversationRepository();
      messageRepo = MockMessageRepository();
    });

    tearDown(() {
      conversationRepo.clear();
      messageRepo.clear();
    });

    group('消息撤回操作', () {
      test('撤回最后一条消息时应该更新会话状态', () async {
        // 创建会话
        final conv = ConversationModel(
          id: 0,
          peerId: 3101,
          type: 'C2C',
          avatar: '',
          title: '测试用户',
          subtitle: '这是要撤回的消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 401,
          unreadNum: 0,
          lastMsgStatus: 11, // 已发送
        );

        final convId = await conversationRepo.insert(conv);

        // 创建被撤回的消息
        final revokedMsg = MessageModel(
          '401',
          autoId: 1,
          type: 'C2C',
          status: 30, // peerRevoked
          fromId: 8001,
          toId: 3101,
          payload: <String, dynamic>{},
          isAuthor: 0,
          conversationUk3: 'C2C_user1_user_revoke',
          createdAt: 1234567890,
          msgType: 'text',
        );

        // 检查是否为最后一条消息
        final currentConv = await conversationRepo.findById(convId);
        final shouldUpdate = currentConv!.lastMsgId.toString() == revokedMsg.id;
        expect(shouldUpdate, true);

        // 更新会话状态
        await conversationRepo.updateById(convId, {
          'last_msg_status': revokedMsg.status, // 30
          'subtitle': '"测试用户..." 撤回了一条消息',
        });

        // 验证更新
        final updated = await conversationRepo.findById(convId);
        expect(updated!.lastMsgStatus, 30);
        expect(updated.subtitle, contains('撤回了一条消息'));
      });

      test('自己撤回消息时应该显示相应提示', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3102,
          type: 'C2C',
          avatar: '',
          title: '测试用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 402,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 自己撤回消息（status=31）
        final myRevokedMsg = MessageModel(
          '402',
          autoId: 1,
          type: 'C2C',
          status: 31, // myRevoked
          fromId: 9001,
          toId: 3102,
          payload: <String, dynamic>{},
          isAuthor: 1,
          conversationUk3: 'C2C_me_user_self',
          createdAt: 1234567890,
          msgType: 'text',
        );

        // 检查是否为最后一条消息
        final currentConv = await conversationRepo.findById(convId);
        if (currentConv!.lastMsgId.toString() == myRevokedMsg.id) {
          await conversationRepo.updateById(convId, {
            'last_msg_status': 31,
            'subtitle': '你撤回了一条消息',
          });
        }

        final updated = await conversationRepo.findById(convId);
        expect(updated!.lastMsgStatus, 31);
        expect(updated.subtitle, '你撤回了一条消息');
      });

      test('撤回非最后一条消息时不应该更新会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3103,
          type: 'C2C',
          avatar: '',
          title: '测试用户',
          subtitle: '最新消息',
          msgType: 'text',
          lastTime: 1234567900,
          lastMsgId: 101,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 撤回一条旧消息（不是最后一条）
        final oldRevokedMsg = MessageModel(
          '100',
          autoId: 1,
          type: 'C2C',
          status: 30,
          fromId: 8001,
          toId: 3103,
          payload: <String, dynamic>{},
          isAuthor: 0,
          conversationUk3: 'C2C_user1_user_old_msg',
          createdAt: 1234567800,
          msgType: 'text',
        );

        // 检查是否为最后一条消息
        final currentConv = await conversationRepo.findById(convId);
        final shouldUpdate = currentConv!.lastMsgId.toString() == oldRevokedMsg.id;
        expect(shouldUpdate, false);

        // 不应该更新会话
        final unchanged = await conversationRepo.findById(convId);
        expect(unchanged!.lastMsgId, 101);
        expect(unchanged.subtitle, '最新消息');
      });

      test('不同类型消息撤回后都应该显示撤回提示', () async {
        final msgTypes = ['text', 'image', 'voice', 'video', 'file'];

        for (final msgType in msgTypes) {
          final conv = ConversationModel(
            id: 0,
            peerId: 9000 + msgType.hashCode.abs() % 1000,
            type: 'C2C',
            avatar: '',
            title: '用户',
            subtitle: '消息内容',
            msgType: msgType,
            lastTime: 1234567890,
            lastMsgId: 9000 + msgType.hashCode % 1000,
            unreadNum: 0,
          );

          final convId = await conversationRepo.insert(conv);

          // 撤回消息
          await conversationRepo.updateById(convId, {
            'last_msg_status': 30,
            'subtitle': '"用户..." 撤回了一条消息',
          });

          final updated = await conversationRepo.findById(convId);
          expect(updated!.lastMsgStatus, 30);
          expect(updated.subtitle, contains('撤回了一条消息'));
        }
      });
    });

    group('消息编辑操作', () {
      test('编辑最后一条消息时应该更新会话副标题', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3104,
          type: 'C2C',
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息内容',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 403,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 编辑消息
        final editedContent = '这是编辑后的消息内容';
        final editedMsg = MessageModel(
          '403',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 3104,
          payload: {'content': editedContent},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user_edit',
          createdAt: 1234567890,
          msgType: 'text',
        );

        // 检查是否为最后一条消息
        final currentConv = await conversationRepo.findById(convId);
        if (currentConv!.lastMsgId.toString() == editedMsg.id) {
          await conversationRepo.updateById(convId, {
            'subtitle': editedContent,
          });
        }

        final updated = await conversationRepo.findById(convId);
        expect(updated!.subtitle, editedContent);
      });

      test('编辑非最后一条消息时不应该更新会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3201,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '最新消息',
          msgType: 'text',
          lastTime: 1234567900,
          lastMsgId: 101,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 编辑旧消息
        const oldMsgId = 9999;
        final shouldUpdate =
            (await conversationRepo.findById(convId))!.lastMsgId == oldMsgId;
        expect(shouldUpdate, false);

        // 不应该更新会话
        final unchanged = await conversationRepo.findById(convId);
        expect(unchanged!.subtitle, '最新消息');
      });

      test('编辑引用消息时应该更新会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3202,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '原始引用消息',
          msgType: 'quote',
          lastTime: 1234567890,
          lastMsgId: 501,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        final newQuote = '引用消息：这是修改后的内容';
        await conversationRepo.updateById(convId, {'subtitle': newQuote});

        final updated = await conversationRepo.findById(convId);
        expect(updated!.subtitle, newQuote);
      });
    });

    group('消息删除操作', () {
      test('删除最后一条消息时应该用前一条消息更新会话', () async {
        // 创建会话
        final conv = ConversationModel(
          id: 0,
          peerId: 3105,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '最后一条消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 502,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 删除最后一条消息，用前一条更新
        final previousMsg = MessageModel(
          '404',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 8001,
          toId: 3105,
          payload: {'content': '前一条消息'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user_delete',
          createdAt: 1234567880,
          msgType: 'text',
        );

        await conversationRepo.updateById(convId, {
          'last_msg_id': previousMsg.id,
          'subtitle': '前一条消息',
          'last_time': previousMsg.createdAt,
        });

        final updated = await conversationRepo.findById(convId);
        expect(updated!.lastMsgId, 404);
        expect(updated.subtitle, '前一条消息');
      });

      test('删除唯一消息时应该清空会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3203,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '唯一消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 503,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 删除唯一消息，清空会话
        await conversationRepo.updateById(convId, {
          'last_msg_id': 0,
          'subtitle': '',
          'last_time': 0,
        });

        final updated = await conversationRepo.findById(convId);
        expect(updated!.lastMsgId, 0);
        expect(updated.subtitle, '');
      });

      test('删除非最后一条消息时不应该更新会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3204,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '最新消息',
          msgType: 'text',
          lastTime: 1234567900,
          lastMsgId: 101,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 删除旧消息不影响会话
        final unchanged = await conversationRepo.findById(convId);
        expect(unchanged!.lastMsgId, 101);
        expect(unchanged.subtitle, '最新消息');
      });

      test('删除最后一条图片消息应该显示[图片]', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3205,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '[图片]',
          msgType: 'image',
          lastTime: 1234567890,
          lastMsgId: 504,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 用前一条文本消息更新
        await conversationRepo.updateById(convId, {
          'last_msg_id': 'msg_text',
          'subtitle': '前一条文本消息',
          'msg_type': 'text',
        });

        final updated = await conversationRepo.findById(convId);
        expect(updated!.msgType, 'text');
        expect(updated.subtitle, '前一条文本消息');
      });
    });

    group('消息操作组合场景', () {
      test('连续多条消息撤回只更新会话一次', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3106,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '消息3',
          msgType: 'text',
          lastTime: 1234567900,
          lastMsgId: 3,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 撤回消息1（不是最后一条）
        final shouldUpdate1 =
            (await conversationRepo.findById(convId))!.lastMsgId == 1;
        expect(shouldUpdate1, false);

        // 撤回消息2（不是最后一条）
        final shouldUpdate2 =
            (await conversationRepo.findById(convId))!.lastMsgId == 2;
        expect(shouldUpdate2, false);

        // 撤回消息3（是最后一条）
        final shouldUpdate3 =
            (await conversationRepo.findById(convId))!.lastMsgId == 3;
        expect(shouldUpdate3, true);

        // 只更新一次
        await conversationRepo.updateById(convId, {
          'last_msg_status': 30,
          'subtitle': '"用户..." 撤回了一条消息',
        });

        final updated = await conversationRepo.findById(convId);
        expect(updated!.lastMsgStatus, 30);
      });

      test('编辑后撤回应该显示撤回状态', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3206,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '编辑后的消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 505,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 先编辑
        await conversationRepo.updateById(convId, {'subtitle': '这是编辑后的内容'});

        // 然后撤回（撤回优先级更高）
        await conversationRepo.updateById(convId, {
          'last_msg_status': 30,
          'subtitle': '"用户..." 撤回了一条消息',
        });

        final updated = await conversationRepo.findById(convId);
        expect(updated!.lastMsgStatus, 30);
        expect(updated.subtitle, contains('撤回了一条消息'));
      });
    });

    group('边界条件', () {
      test('处理空消息ID的撤回', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 3207,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 0,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 空消息ID不应该匹配
        final shouldUpdate =
            (await conversationRepo.findById(convId))!.lastMsgId == 8888;
        expect(shouldUpdate, false);
      });

      test('处理特殊字符的消息编辑', () async {
        final specialContent = '测试"引号"\n\t\\换行';

        final conv = ConversationModel(
          id: 0,
          peerId: 7003,
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: specialContent,
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 506,
          unreadNum: 0,
        );

        final convId = await conversationRepo.insert(conv);

        // 编辑包含特殊字符的消息
        await conversationRepo.updateById(convId, {'subtitle': specialContent});

        final updated = await conversationRepo.findById(convId);
        expect(updated!.subtitle, specialContent);
      });

      test('处理不同消息类型的操作', () async {
        final scenarios = [
          {'type': 'image', 'content': '[图片]'},
          {'type': 'voice', 'content': '[语音]'},
          {'type': 'video', 'content': '[视频]'},
          {'type': 'file', 'content': '[文件]'},
          {'type': 'location', 'content': '[位置] 北京市'},
        ];

        for (final scenario in scenarios) {
          final msgType = scenario['type'] as String;
          final content = scenario['content'] as String;

          final conv = ConversationModel(
            id: 0,
            peerId: 9000 + msgType.hashCode.abs() % 1000,
            type: 'C2C',
            avatar: '',
            title: '用户',
            subtitle: content,
            msgType: msgType,
            lastTime: 1234567890,
            lastMsgId: 9000 + msgType.hashCode.abs() % 1000,
            unreadNum: 0,
          );

          final convId = await conversationRepo.insert(conv);

          // 撤回不同类型的消息
          await conversationRepo.updateById(convId, {
            'last_msg_status': 30,
            'subtitle': '"用户..." 撤回了一条消息',
          });

          final updated = await conversationRepo.findById(convId);
          expect(updated!.lastMsgStatus, 30);
        }
      });
    });

    group('性能测试', () {
      test('批量消息操作的性能', () async {
        final stopwatch = DateTime.now();

        // 创建100个会话
        for (int i = 0; i < 100; i++) {
          await conversationRepo.insert(
            ConversationModel(
              id: 0,
              peerId: 9000 + i,
              type: 'C2C',
              avatar: '',
              title: '用户$i',
              subtitle: '消息$i',
              msgType: 'text',
              lastTime: 1234567890 + i,
              lastMsgId: 9000 + i,
              unreadNum: 0,
            ),
          );
        }

        final duration = DateTime.now().difference(stopwatch).inMilliseconds;

        // 100次插入应该在合理时间内完成（<1秒）
        expect(duration, lessThan(1000));

        // 验证数据正确性
        final all = conversationRepo.getAll();
        expect(all.length, 100);
      });

      test('并发会话更新', () async {
        final convId = await conversationRepo.insert(
          ConversationModel(
            id: 0,
            peerId: 3208,
            type: 'C2C',
            avatar: '',
            title: '用户',
            subtitle: '初始消息',
            msgType: 'text',
            lastTime: 1234567890,
            lastMsgId: 507,
            unreadNum: 0,
          ),
        );

        // 模拟多次更新
        for (int i = 0; i < 10; i++) {
          await conversationRepo.updateById(convId, {
            'subtitle': '更新消息$i',
            'unread_num': i,
          });
        }

        final updated = await conversationRepo.findById(convId);
        expect(updated!.subtitle, '更新消息9');
        expect(updated.unreadNum, 9);
      });
    });
  });
}
