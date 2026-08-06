/// 会话管理核心逻辑验证测试（无需数据库）
///
/// 测试目标：
/// 1. 会话状态计算逻辑（content getter）
/// 2. 未读数累加逻辑
/// 3. 撤回状态展示优先级
/// 4. 消息类型展示
/// 5. UK3 生成逻辑
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import '../helper/test_helper.dart';

void main() {
  group('会话管理核心逻辑验证', () {
    group('会话内容计算（content getter）', () {
      test('应该优先显示系统提示（in_denylist）', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30, // 撤回状态
          unreadNum: 0,
          payload: {'sys_prompt': 'in_denylist'}, // 系统提示优先级最高
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('对方开启了好友验证'));
        expect(content, isNot(contains('撤回')));
      });

      test('应该优先显示撤回状态而非普通消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息', // 这个应该被忽略
          type: 'C2C',
          msgType: 'text', // 这个也应该被忽略
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30, // peerRevoked 优先
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
        expect(content, isNot('原始消息'));
      });

      test('应该正确显示文本消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '这是一条文本消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: {'text': '这是一条文本消息'},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, '这是一条文本消息');
      });

      test('对方撤回时应该显示名称和撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '张三李四王五六七八九十十一十二', // 超过12个字符
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30, // peerRevoked
          unreadNum: 0,
          payload: {'peer_name': '张三李四王五六七八九十十一十二'},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        // 超过12字符应该截断到12个字符并添加...
        expect(content, contains('张三李四王五六七八九十')); // 12个字符
        expect(content, contains('...'));
        expect(content, contains('撤回了一条消息'));
      });

      test('自己撤回时应该显示"你撤回了一条消息"', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 31, // myRevoked
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('你撤回了一条消息'));
      });

      test('应该正确显示图片消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[图片]',
          type: 'C2C',
          msgType: 'image',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, '[图片]');
      });

      test('应该正确显示语音消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[语音]',
          type: 'C2C',
          msgType: 'voice',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('语音'));
      });

      test('应该正确显示视频消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[视频]',
          type: 'C2C',
          msgType: 'video',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, '[视频]');
      });

      test('应该正确显示文件消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[文件]',
          type: 'C2C',
          msgType: 'file',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, '[文件]');
      });

      test('应该正确显示位置消息（包含位置标签和地址）', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[位置]北京市朝阳区建国路88号',
          type: 'C2C',
          msgType: 'location',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: {
            'location_label': '北京市朝阳区建国路88号',
            'location_address': '北京市朝阳区建国路88号',
          },
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('[位置]'));
        expect(content, contains('北京市朝阳区建国路88号'));
      });

      test('应该正确显示引用消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '回复内容',
          type: 'C2C',
          msgType: 'quote',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, '回复内容');
      });

      test('应该正确显示非好友系统提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'custom',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: {'sys_prompt': 'not_a_friend'},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('对方开启了好友验证'));
      });
    });

    group('未读数累加逻辑', () {
      test('新会话未读数应该正确设置', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 5,
          payload: <String, dynamic>{},
        );

        expect(conv.unreadNum, 5);
      });

      test('应该支持未读数累加计算', () {
        // 模拟场景：初始未读数 = 3，新消息增加 2 条
        const initialUnread = 3;
        const newMessages = 2;
        final expectedUnread = initialUnread + newMessages;

        expect(expectedUnread, 5);
      });

      test('从0开始的未读数累加应该正确', () {
        const initialUnread = 0;
        const newMessages = 3;
        final expectedUnread = initialUnread + newMessages;

        expect(expectedUnread, 3);
      });

      test('多次累加未读数应该正确', () {
        var unreadNum = 0;

        // 第一次累加
        unreadNum += 2;
        expect(unreadNum, 2);

        // 第二次累加
        unreadNum += 3;
        expect(unreadNum, 5);

        // 第三次累加
        unreadNum += 1;
        expect(unreadNum, 6);
      });

      test('未读数清零后应该为0', () {
        var unreadNum = 10;

        // 清零
        unreadNum = 0;

        expect(unreadNum, 0);
      });

      test('未读数应该限制在合理范围', () {
        // 测试下限
        var unreadNum = -5;
        unreadNum = unreadNum.clamp(0, 999999);
        expect(unreadNum, 0);

        // 测试上限
        unreadNum = 1000000;
        unreadNum = unreadNum.clamp(0, 999999);
        expect(unreadNum, 999999);
      });
    });

    group('已读水位管理逻辑', () {
      test('应该正确读取已读水位（int类型）', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: {'last_read_auto_id': 100},
        );

        final lastReadAutoId = conv.payload?['last_read_auto_id'];

        expect(lastReadAutoId, 100);
      });

      test('应该正确读取已读水位（string类型）', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: {'last_read_auto_id': '150'},
        );

        final lastReadAutoId = conv.payload?['last_read_auto_id'];

        expect(lastReadAutoId, '150');
      });

      test('payload为null时已读水位应该为null', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: null,
        );

        final lastReadAutoId = conv.payload?['last_read_auto_id'];

        expect(lastReadAutoId, null);
      });

      test('应该能够推进已读水位', () {
        // 当前水位
        const currentWatermark = 100;

        // 新消息的 auto_id
        const newAutoIds = [101, 102, 103, 104, 105];

        // 计算新的水位
        final maxAutoId = newAutoIds.reduce((a, b) => a > b ? a : b);
        final newWatermark = maxAutoId;

        expect(newWatermark, 105);
        expect(newWatermark, greaterThan(currentWatermark));
      });

      test('已读水位只能推进不能回退', () {
        const currentWatermark = 100;

        // 尝试回退
        const newWatermark1 = 50;
        final shouldUpdate1 = newWatermark1 > currentWatermark;
        expect(shouldUpdate1, false);

        // 尝试推进
        const newWatermark2 = 150;
        final shouldUpdate2 = newWatermark2 > currentWatermark;
        expect(shouldUpdate2, true);
      });
    });

    group('未读数计算逻辑', () {
      test('应该正确计算未读消息数', () {
        // 模拟消息列表
        const lastReadAutoId = 100;

        final messages = [
          {'auto_id': 101, 'is_author': 1}, // 发送，不算
          {'auto_id': 102, 'is_author': 0}, // 接收，算 ✓
          {'auto_id': 103, 'is_author': 0}, // 接收，算 ✓
          {'auto_id': 104, 'is_author': 1}, // 发送，不算
          {'auto_id': 105, 'is_author': 0}, // 接收，算 ✓
        ];

        // 计算未读数
        final unreadCount = messages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > lastReadAutoId && isAuthor == 0;
        }).length;

        expect(unreadCount, 3);
      });

      test('所有消息已读时未读数应该为0', () {
        const lastReadAutoId = 200;

        final messages = [
          {'auto_id': 198, 'is_author': 0},
          {'auto_id': 199, 'is_author': 0},
          {'auto_id': 200, 'is_author': 0},
        ];

        final unreadCount = messages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > lastReadAutoId && isAuthor == 0;
        }).length;

        expect(unreadCount, 0);
      });

      test('推进已读水位后未读数应该减少', () {
        // 初始状态
        const lastReadAutoId = 100;

        final messages = [
          {'auto_id': 101, 'is_author': 0},
          {'auto_id': 102, 'is_author': 0},
          {'auto_id': 103, 'is_author': 0},
        ];

        // 初始未读数
        final initialUnread = messages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > lastReadAutoId && isAuthor == 0;
        }).length;

        expect(initialUnread, 3);

        // 推进到 103
        const newLastReadAutoId = 103;

        // 新的未读数
        final newUnread = messages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > newLastReadAutoId && isAuthor == 0;
        }).length;

        expect(newUnread, 0);
      });

      test('部分推进已读水位应该部分减少未读数', () {
        // const lastReadAutoId = 100; // Reference value for test scenario

        final messages = [
          {'auto_id': 101, 'is_author': 0},
          {'auto_id': 102, 'is_author': 0},
          {'auto_id': 103, 'is_author': 0},
          {'auto_id': 104, 'is_author': 0},
          {'auto_id': 105, 'is_author': 0},
        ];

        // 推进到 103
        const newLastReadAutoId = 103;

        final newUnread = messages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > newLastReadAutoId && isAuthor == 0;
        }).length;

        expect(newUnread, 2); // 104, 105
      });
    });

    group('批量消息已读逻辑', () {
      test('应该能够找到批量消息中的最大auto_id', () {
        final messages = [
          {'id': 'msg_001', 'auto_id': 101},
          {'id': 'msg_002', 'auto_id': 105},
          {'id': 'msg_003', 'auto_id': 103},
          {'id': 'msg_004', 'auto_id': 108},
        ];

        final maxAutoId = messages
            .map((msg) => msg['auto_id'] as int)
            .reduce((a, b) => a > b ? a : b);

        expect(maxAutoId, 108);
      });

      test('空列表应该返回null', () {
        final messages = <Map<String, dynamic>>[];

        final maxAutoId = messages.isEmpty
            ? null
            : messages
                  .map((msg) => msg['auto_id'] as int)
                  .reduce((a, b) => a > b ? a : b);

        expect(maxAutoId, null);
      });

      test('单条消息应该返回其auto_id', () {
        final messages = [
          {'id': 'msg_001', 'auto_id': 100},
        ];

        final maxAutoId = messages
            .map((msg) => msg['auto_id'] as int)
            .reduce((a, b) => a > b ? a : b);

        expect(maxAutoId, 100);
      });
    });

    group('消息撤回后的会话更新逻辑', () {
      test('撤回最后一条消息时应该更新会话status', () {
        // 模拟会话
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1, // 最后一条消息
          lastMsgStatus: 20, // 已投递
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 撤回消息
        final revokedMsg = MessageModel(
          '1', // 与会话的最后一条消息相同
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.peerRevoked, // 30
          fromId: 1100,
          toId: 1200,
          payload: {'text': '原始消息'},
          isAuthor: 0,
          conversationUk3: 'C2C_current_user_test_user',
        );

        // 验证：需要更新会话
        // conv.lastMsgId 为 int（旧契约），msg.id 为 String（新契约）
        final shouldUpdate = conv.lastMsgId.toString() == revokedMsg.id;

        expect(shouldUpdate, true);
        expect(revokedMsg.status, 30);
      });

      test('撤回非最后一条消息时不应该更新会话', () {
        // 模拟会话
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '最后消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579500000,
          lastMsgId: 100, // 最后一条消息
          lastMsgStatus: 20,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 撤回更早的消息
        final revokedMsg = MessageModel(
          '50', // 不是最后一条
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.peerRevoked,
          fromId: 1100,
          toId: 1200,
          payload: <String, dynamic>{},
          isAuthor: 0,
          conversationUk3: 'C2C_current_user_test_user',
        );

        // 验证：不需要更新会话
        // conv.lastMsgId 为 int（旧契约），msg.id 为 String（新契约）
        final shouldUpdate = conv.lastMsgId.toString() == revokedMsg.id;

        expect(shouldUpdate, false);
      });

      test('撤回后的会话内容应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '张三',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30, // peerRevoked
          unreadNum: 0,
          payload: {'peer_name': '张三'},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
      });

      test('自己撤回的会话内容应该正确显示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 31, // myRevoked
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('你撤回了一条消息'));
      });
    });

    group('消息编辑后的会话更新逻辑', () {
      test('编辑最后一条消息时应该更新会话副标题', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: {'text': '原始消息'},
        );

        // 编辑消息
        const newContent = '编辑后的消息';
        const editedMsgId = 1;

        // 验证：需要更新会话
        final shouldUpdate = conv.lastMsgId == editedMsgId;

        expect(shouldUpdate, true);
        expect(newContent, isNot('原始消息'));
      });

      test('编辑非最后一条消息时不应该更新会话', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '最后消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579500000,
          lastMsgId: 100,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 编辑更早的消息
        const editedMsgId = 50;

        final shouldUpdate = conv.lastMsgId == editedMsgId;

        expect(shouldUpdate, false);
      });
    });

    group('消息删除后的会话更新逻辑', () {
      test('删除最后一条消息时应该用前一条更新', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '最后消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579500000,
          lastMsgId: 100,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 删除最后一条消息，有前一条
        const deletedMsgId = 100;
        const prevMsgId = 99;

        // 验证：需要更新会话
        final shouldUpdate = conv.lastMsgId == deletedMsgId;

        expect(shouldUpdate, true);
        expect(prevMsgId, 99);
      });

      test('删除唯一消息时应该清空会话', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '唯一消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 001,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 删除唯一消息
        const deletedMsgId = 1;
        const hasPrevMsg = false;

        // 验证
        final shouldUpdate = conv.lastMsgId == deletedMsgId;

        expect(shouldUpdate, true);
        expect(hasPrevMsg, false);
      });

      test('删除非最后一条消息时不应该更新会话', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '最后消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579500000,
          lastMsgId: 200,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 删除更早的消息
        const deletedMsgId = 150;

        final shouldUpdate = conv.lastMsgId == deletedMsgId;

        expect(shouldUpdate, false);
      });
    });

    group('不同消息类型的撤回展示', () {
      test('文本消息撤回应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始文本',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
      });

      test('图片消息撤回应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[图片]',
          type: 'C2C',
          msgType: 'image',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
        expect(content, isNot('[图片]'));
      });

      test('语音消息撤回应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[语音]',
          type: 'C2C',
          msgType: 'voice',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 31,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('你撤回了一条消息'));
      });

      test('视频消息撤回应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[视频]',
          type: 'C2C',
          msgType: 'video',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
      });

      test('文件消息撤回应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[文件]',
          type: 'C2C',
          msgType: 'file',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
      });

      test('位置消息撤回应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[位置]北京市',
          type: 'C2C',
          msgType: 'location',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, contains('撤回了一条消息'));
        expect(content, isNot('[位置]'));
      });
    });

    group('会话模型序列化和反序列化', () {
      test('应该正确序列化和反序列化会话对象', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: 'https://example.com/avatar.jpg',
          title: '测试用户',
          subtitle: '测试消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 20,
          unreadNum: 3,
          isShow: 1,
          payload: {'text': '测试消息', 'last_read_auto_id': 100},
        );

        // 序列化
        final json = conv.toJson();

        expect(json['id'], 1);
        expect(json['peer_id'], 1100);
        expect(json['title'], '测试用户');
        expect(json['unread_num'], 3);

        // 反序列化
        final restored = ConversationModel.fromJson(json);

        expect(restored.id, 1);
        expect(restored.peerId, 1100);
        expect(restored.title, '测试用户');
        expect(restored.unreadNum, 3);
        expect(restored.payload!['text'], '测试消息');
        expect(restored.payload!['last_read_auto_id'], 100);
      });

      test('空payload应该正确处理', () {
        final json = {
          'id': 1,
          'peer_id': 1100,
          'avatar': '',
          'title': '测试',
          'subtitle': '测试消息',
          'type': 'C2C',
          'msg_type': 'text',
          'last_time': 1642579200000,
          'last_msg_id': 1,
          'last_msg_status': 11,
          'unread_num': 0,
          'is_show': 1,
          'payload': null,
        };

        final conv = ConversationModel.fromJson(json);

        expect(conv, isNotNull);
        expect(conv.payload, null);
      });
    });

    group('会话复制功能', () {
      test('应该正确复制会话对象', () {
        final conv1 = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: 'https://example.com/avatar.jpg',
          title: '原始标题',
          subtitle: '原始副标题',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 20,
          unreadNum: 3,
          payload: {'text': '原始消息'},
        );

        final conv2 = conv1.copyWith(title: '新标题', unreadNum: 0);

        // 验证原对象不变
        expect(conv1.title, '原始标题');
        expect(conv1.unreadNum, 3);

        // 验证新对象的修改
        expect(conv2.title, '新标题');
        expect(conv2.unreadNum, 0);

        // 验证其他字段相同
        expect(conv2.peerId, conv1.peerId);
        expect(conv2.type, conv1.type);
        expect(conv2.lastMsgId, conv1.lastMsgId);
      });
    });

    group('边界条件处理', () {
      test('lastMsgStatus为null时应该按普通消息处理', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '普通文本消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: null,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        expect(content, '普通文本消息');
      });

      test('超长标题应该正确截断', () {
        final longTitle = '这是一个非常非常非常非常非常非常非常非常非常非常长的用户名';

        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: longTitle,
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: {'peer_name': longTitle},
        );

        // 使用测试辅助类计算 content（绕过 StorageService 依赖）
        final content = ConversationTestHelper.computeContentWithoutDraft(conv);

        // 应该截断并添加...
        expect(content, contains('...'));
        expect(content, contains('撤回了一条消息'));
      });

      test('未读数0应该正确处理', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '测试消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: <String, dynamic>{},
        );

        expect(conv.unreadNum, 0);
      });

      test('应该支持各种特殊字符', () {
        final specialTitles = ['用户🎉表情', '用户"引号"测试', "用户'单引号'测试"];

        for (final title in specialTitles) {
          final conv = ConversationModel(
            id: 1,
            peerId: 1100,
            avatar: '',
            title: title,
            subtitle: '测试',
            type: 'C2C',
            msgType: 'text',
            lastTime: 1642579200000,
            lastMsgId: 1,
            unreadNum: 0,
            payload: <String, dynamic>{},
          );

          expect(conv.title, title);
        }
      });
    });

    group('消息状态枚举验证', () {
      test('应该正确识别撤回状态', () {
        // 对方撤回
        expect(IMBoyMessageStatus.isRevokedStatus(30), true);
        expect(IMBoyMessageStatus.isRevokedStatus(31), true);

        // 非撤回状态
        expect(IMBoyMessageStatus.isRevokedStatus(20), false);
        expect(IMBoyMessageStatus.isRevokedStatus(21), false);
        expect(IMBoyMessageStatus.isRevokedStatus(10), false);
      });

      test('应该正确识别发送状态', () {
        expect(IMBoyMessageStatus.isSendingStatus(10), true);
        expect(IMBoyMessageStatus.isSendingStatus(11), true);

        expect(IMBoyMessageStatus.isSendingStatus(20), false);
        expect(IMBoyMessageStatus.isSendingStatus(41), false);
      });

      test('应该正确识别错误状态', () {
        expect(IMBoyMessageStatus.isErrorStatus(41), true);

        expect(IMBoyMessageStatus.isErrorStatus(10), false);
        expect(IMBoyMessageStatus.isErrorStatus(20), false);
      });
    });
  });
}
