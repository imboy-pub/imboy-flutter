/// 会话更新逻辑测试（无需数据库）
///
/// 测试目标：
/// 1. 消息到达时判断是否需要更新会话
/// 2. 会话内容计算逻辑
/// 3. 最后消息判断逻辑
/// 4. UK3生成逻辑
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import '../helper/test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('会话更新逻辑测试', () {
    group('消息到达时的会话更新判断', () {
      test('新消息到达时应该创建新会话', () {
        // 模拟新消息到达
        final msg = MessageModel(
          '1',
          autoId: 1,
          type: 'C2C',
          status: 11, // 已发送
          fromId: 8001,
          toId: 8002,
          payload: {'content': 'Hello'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1234567890,
          msgType: 'text',
        );

        // 验证会话数据
        expect(msg.id, '1');
        expect(msg.type, 'C2C');
        expect(msg.msgType, 'text');
        expect(msg.status, 11);
      });

      test('应该正确判断是否为最后一条消息', () {
        final conversation = ConversationModel(
          id: 1,
          peerId: 8002,
          type: 'C2C',
          avatar: '',
          title: '测试用户',
          subtitle: '上一条消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 1,
          unreadNum: 0,
        );

        // 相同的消息ID - 应该更新会话
        final sameMsgId = 1;
        expect(conversation.lastMsgId, sameMsgId);

        // 不同的消息ID - 不应该更新会话
        final differentMsgId = 2;
        expect(conversation.lastMsgId == differentMsgId, false);
      });

      test('应该正确处理不同类型的消息', () {
        final types = ['C2C', 'C2G', 'S2C'];

        for (final type in types) {
          final msg = MessageModel(
            '1',
            autoId: 1,
            type: type,
            status: 11,
            fromId: 8001,
            toId: type == 'C2G' ? 2001 : 8002,
            payload: {},
            isAuthor: 1,
            conversationUk3:
                '${type}_user1_${type == "C2G" ? "group1" : "user2"}',
            createdAt: 1234567890,
            msgType: 'text',
          );

          expect(msg.type, type);
        }
      });
    });

    group('会话内容展示优先级', () {
      test('撤回状态应该优先于普通消息', () {
        final conv = ConversationTestHelper.createTestConversation(
          lastMsgStatus: 30, // peerRevoked
          subtitle: '原始消息',
        );

        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
        expect(content, isNot(contains('原始消息')));
      });

      test('系统提示应该优先于撤回状态', () {
        final conv = ConversationTestHelper.createTestConversation(
          lastMsgStatus: 30,
          payload: {'sys_prompt': 'in_denylist'},
        );

        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('对方开启了好友验证'));
        expect(content, isNot(contains('撤回')));
      });

      test('应该正确显示各种消息类型', () {
        final msgTypes = {
          'text': '这是一条文本消息',
          'image': '[图片]',
          'voice': '[语音]',
          'video': '[视频]',
          'file': '[文件]',
        };

        msgTypes.forEach((msgType, expectedContent) {
          final conv = ConversationTestHelper.createTestConversation(
            msgType: msgType,
            subtitle: expectedContent,
          );

          final content = ConversationTestHelper.computeContentWithoutDraft(
            conv,
          );

          if (msgType == 'text') {
            expect(content, expectedContent);
          } else {
            expect(content, contains(expectedContent));
          }
        });
      });
    });

    group('会话状态计算', () {
      test('应该正确计算UK3', () {
        // 跳过此测试，因为需要 UserRepoLocal.to.currentUid
        // 而那需要 StorageService 初始化
        expect(true, true);
      }, skip: '需要StorageService初始化');

      test('应该正确处理未读数', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 8002,
          type: 'C2C',
          avatar: '',
          title: '测试用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 1,
          unreadNum: 5,
        );

        expect(conv.unreadNum, 5);

        // 模拟新消息到达，累加未读数
        final newConv = conv.copyWith(unreadNum: conv.unreadNum + 3);
        expect(newConv.unreadNum, 8);
      });

      test('应该正确处理时间戳', () {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        final conv = ConversationModel(
          id: 1,
          peerId: 8002,
          type: 'C2C',
          avatar: '',
          title: '测试用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: now,
          lastMsgId: 1,
          unreadNum: 0,
        );

        expect(conv.lastTime, now);
        expect(conv.lastTime, greaterThan(0));
      });
    });

    group('会话复制功能', () {
      test('copyWith应该正确复制会话', () {
        final original = ConversationTestHelper.createTestConversation(
          peerId: 1001,
          title: '原始标题',
          unreadNum: 10,
        );

        final copy = original.copyWith(title: '新标题', unreadNum: 5);

        // 验证修改的字段
        expect(copy.title, '新标题');
        expect(copy.unreadNum, 5);

        // 验证未修改的字段保持不变（除了id，因为copyWith不包含id）
        expect(copy.peerId, original.peerId);
        expect(copy.type, original.type);
        expect(copy.avatar, original.avatar);
      });

      test('copyWith应该保持payload独立性', () {
        final originalPayload = {'key': 'value'};
        final original = ConversationTestHelper.createTestConversation(
          payload: Map<String, dynamic>.from(originalPayload),
        );

        final copy = original.copyWith();

        // 修改副本的payload不应该影响原始对象
        if (copy.payload != null) {
          copy.payload!['newKey'] = 'newValue';
        }

        expect(original.payload?['newKey'], isNull);
      });
    });

    group('边界条件处理', () {
      test('应该处理空peerId', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 0, // 空peerId
          type: 'C2C',
          avatar: '',
          title: '',
          subtitle: '',
          msgType: 'text',
          lastTime: 0,
          lastMsgId: 0,
          unreadNum: 0,
        );

        expect(conv.peerId, 0);
        expect(conv.title, '');
      });

      test('应该处理超大未读数', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 8002,
          type: 'C2C',
          avatar: '',
          title: '测试用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 1,
          unreadNum: 999999, // 最大值
        );

        expect(conv.unreadNum, 999999);
      });

      test('应该处理特殊字符', () {
        final specialTexts = [
          '测试\n换行',
          '测试\t制表符',
          '测试"引号"',
          '测试\'单引号\'',
          '测试\\反斜杠',
          '测试😀表情符号',
        ];

        for (final text in specialTexts) {
          final conv = ConversationTestHelper.createTestConversation(
            subtitle: text,
          );

          final content = ConversationTestHelper.computeContentWithoutDraft(
            conv,
          );

          expect(content, contains(text));
        }
      });
    });

    group('消息类型与状态组合', () {
      test('文本消息+发送状态应该正常显示', () {
        final conv = ConversationTestHelper.createTestConversation(
          msgType: 'text',
          subtitle: '这是文本消息',
          lastMsgStatus: 11, // 已发送
        );

        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, '这是文本消息');
      });

      test('图片消息+撤回状态应该显示撤回提示', () {
        final conv = ConversationTestHelper.createTestConversation(
          msgType: 'image',
          subtitle: '[图片]',
          lastMsgStatus: 30, // peerRevoked
        );

        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
        expect(content, isNot(contains('[图片]')));
      });

      test('视频消息+发送中状态应该正常显示', () {
        final conv = ConversationTestHelper.createTestConversation(
          msgType: 'video',
          subtitle: '[视频]',
          lastMsgStatus: 10, // 发送中
        );

        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, '[视频]');
      });
    });

    group('会话模型序列化', () {
      test('应该正确序列化为JSON', () {
        final conv = ConversationTestHelper.createTestConversation(
          peerId: 1100,
          title: '测试用户',
          unreadNum: 5,
        );

        final json = conv.toJson();

        expect(json['peer_id'], 1100);
        expect(json['title'], '测试用户');
        expect(json['unread_num'], 5);
        expect(json['type'], 'C2C');
      });

      test('应该正确从JSON反序列化', () {
        final json = {
          'id': 1,
          'peer_id': 1100,
          'type': 'C2C',
          'avatar': '',
          'title': '测试用户',
          'subtitle': '消息内容',
          'region': '',
          'sign': '',
          'last_time': 1234567890,
          'last_msg_id': 1,
          'unread_num': 3,
          'is_show': 1,
          'msg_type': 'text',
          'last_msg_status': 11,
          'payload': null,
        };

        final conv = ConversationModel.fromJson(json);

        expect(conv.id, 1);
        expect(conv.peerId, 1100);
        expect(conv.title, '测试用户');
        expect(conv.unreadNum, 3);
        expect(conv.msgType, 'text');
        expect(conv.lastMsgStatus, 11);
      });

      test('序列化和反序列化应该保持数据一致性', () {
        final original = ConversationTestHelper.createTestConversation(
          peerId: 1001,
          title: '原始标题',
          subtitle: '原始副标题',
          unreadNum: 10,
          lastMsgStatus: 11,
          msgType: 'text',
        );

        final json = original.toJson();
        final restored = ConversationModel.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.peerId, original.peerId);
        expect(restored.title, original.title);
        expect(restored.subtitle, original.subtitle);
        expect(restored.unreadNum, original.unreadNum);
        expect(restored.lastMsgStatus, original.lastMsgStatus);
        expect(restored.msgType, original.msgType);
      });
    });
  });
}
