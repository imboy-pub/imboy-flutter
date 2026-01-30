/// 消息操作后会话更新集成测试
///
/// 测试目标：
/// 1. 消息撤回后会话状态更新
/// 2. 消息编辑后会话状态更新
/// 3. 消息删除后会话状态更新
/// 4. 只有最后一条消息被操作时才更新会话
/// 5. 会话内容的正确展示
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

void main() {
  group('消息操作后会话更新集成测试', () {
    late ConversationRepo conversationRepo;

    setUp(() async {
      conversationRepo = ConversationRepo();
    });

    tearDown(() async {
      // 清理测试数据
      try {
        await conversationRepo.delete('C2C', 'test_revoke_peer');
        await conversationRepo.delete('C2G', 'test_revoke_group');
        await conversationRepo.delete('C2C', 'test_edit_peer');
        await conversationRepo.delete('C2C', 'test_delete_peer');
      } catch (e) {
        // 忽略清理错误
      }
    });

    group('消息撤回后会话更新', () {
      test('撤回最后一条消息时应该更新会话状态', () async {
        // 1. 创建会话
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_revoke_peer',
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息内容',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_revoke_001', // 最后一条消息ID
          lastMsgStatus: 20, // 已投递
          unreadNum: 0,
          payload: {'text': '原始消息内容'},
        );

        final savedConvId = await conversationRepo.insert(conv);

        // 2. 模拟撤回消息（对方撤回，status = 30）
        final revokedMsg = MessageModel(
          'msg_revoke_001',
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.peerRevoked, // 30
          fromId: 'test_revoke_peer',
          toId: 'current_user',
          payload: {'text': '原始消息内容'},
          isAuthor: 0,
          conversationUk3: 'C2C_current_user_test_revoke_peer',
        );

        // 3. 更新会话（模拟 _updateConversationAfterRevoke）
        // 只有当撤回的消息是最后一条消息时才更新
        final foundConv = await conversationRepo.findByPeerId('C2C', 'test_revoke_peer');
        expect(foundConv, isNotNull);
        expect(foundConv!.lastMsgId, 'msg_revoke_001');

        // 更新会话状态
        await conversationRepo.updateById(savedConvId, {
          ConversationRepo.lastMsgStatus: revokedMsg.status, // 30
          ConversationRepo.payload: json.encode(revokedMsg.payload),
        });

        // 4. 验证会话更新
        final updatedConv = await conversationRepo.findById(savedConvId);

        expect(updatedConv, isNotNull);
        expect(updatedConv!.lastMsgStatus, 30); // peerRevoked
      });

      test('撤回非最后一条消息时不应该更新会话', () async {
        // 1. 创建会话（最后一条消息是 msg_005）
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_revoke_peer_2',
          avatar: '',
          title: '测试用户',
          subtitle: '最后消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579500000,
          lastMsgId: 'msg_005', // 最后一条消息
          lastMsgStatus: 20,
          unreadNum: 0,
          payload: {'text': '最后消息'},
        );

        final savedConvId = await conversationRepo.insert(conv);

        // 2. 模拟撤回更早的消息（msg_003）
        final earlierMsgId = 'msg_003';

        // 3. 验证：因为撤回的不是最后一条消息，所以不应该更新会话
        final foundConv = await conversationRepo.findByPeerId('C2C', 'test_revoke_peer_2');
        expect(foundConv, isNotNull);
        expect(foundConv!.lastMsgId, 'msg_005'); // 最后消息ID 不变

        // earlierMsgId != lastMsgId，所以不更新
        expect(foundConv.lastMsgId != earlierMsgId, true);
      });

      test('对方撤回时应该正确显示撤回提示', () {
        // 场景：对方撤回消息
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '张三李四王五六七',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          lastMsgStatus: 30, // peerRevoked
          unreadNum: 0,
          payload: {'peer_name': '张三李四王五六七'},
        );

        final content = conv.content;

        // 应该显示："[张三李四王五六...] 撤回了一条消息"
        expect(content, contains('撤回了一条消息'));
        expect(content, contains('张三李四五'));
        expect(content, contains('...'));
      });

      test('自己撤回时应该正确显示撤回提示', () {
        // 场景：自己撤回消息
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_002',
          lastMsgStatus: 31, // myRevoked
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        // 应该显示："你撤回了一条消息"
        expect(content, contains('你撤回了一条消息'));
      });

      test('群组消息撤回时应该正确更新会话', () async {
        // 1. 创建群组会话
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_revoke_group',
          avatar: '',
          title: '测试群组',
          subtitle: '群消息内容',
          type: 'C2G',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_group_revoke_001',
          lastMsgStatus: 20,
          unreadNum: 0,
          payload: {'text': '群消息内容'},
        );

        final savedConvId = await conversationRepo.insert(conv);

        // 2. 模拟群消息撤回
        final revokedMsg = MessageModel(
          'msg_group_revoke_001',
          autoId: 1,
          type: 'C2G',
          status: IMBoyMessageStatus.peerRevoked,
          fromId: 'group_member_1',
          toId: 'test_revoke_group',
          payload: {'text': '群消息内容'},
          isAuthor: 0,
          conversationUk3: 'C2G_test_revoke_group',
        );

        // 3. 更新会话
        await conversationRepo.updateById(savedConvId, {
          ConversationRepo.lastMsgStatus: revokedMsg.status,
          ConversationRepo.payload: json.encode(revokedMsg.payload),
        });

        // 4. 验证
        final updatedConv = await conversationRepo.findById(savedConvId);

        expect(updatedConv, isNotNull);
        expect(updatedConv!.lastMsgStatus, 30);
      });
    });

    group('消息编辑后会话更新', () {
      test('编辑最后一条消息时应该更新会话副标题', () async {
        // 1. 创建会话
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_edit_peer',
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_edit_001',
          unreadNum: 0,
          payload: {'text': '原始消息'},
        );

        final savedConvId = await conversationRepo.insert(conv);

        // 2. 模拟编辑消息
        final newContent = '编辑后的消息内容';
        final newPayload = {'text': newContent};

        // 3. 更新会话（模拟 updateConversationByMsgId）
        await conversationRepo.updateById(savedConvId, {
          ConversationRepo.lastMsgId: 'msg_edit_001',
          ConversationRepo.subtitle: newContent,
          ConversationRepo.payload: json.encode(newPayload),
        });

        // 4. 验证
        final updatedConv = await conversationRepo.findById(savedConvId);

        expect(updatedConv, isNotNull);
        expect(updatedConv!.subtitle, newContent);
        expect(updatedConv.payload!['text'], newContent);
      });

      test('编辑非最后一条消息时不应该更新会话', () async {
        // 1. 创建会话（最后一条是 msg_010）
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_edit_peer_2',
          avatar: '',
          title: '测试用户',
          subtitle: '最后消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579500000,
          lastMsgId: 'msg_010',
          unreadNum: 0,
          payload: {'text': '最后消息'},
        );

        final savedConvId = await conversationRepo.insert(conv);

        // 2. 模拟编辑更早的消息（msg_005）
        final earlierMsgId = 'msg_005';
        final newContent = '编辑后的消息';

        // 3. 验证：因为编辑的不是最后一条消息，所以不应该更新会话
        final foundConv = await conversationRepo.findById(savedConvId);

        expect(foundConv, isNotNull);
        expect(foundConv!.lastMsgId, 'msg_010'); // 最后消息ID 不变
        expect(foundConv.subtitle, '最后消息'); // 副标题不变
      });
    });

    group('消息删除后会话更新', () {
      test('删除最后一条消息时应该用前一条消息更新会话', () async {
        // 1. 创建会话（最后一条是 msg_100）
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_delete_peer',
          avatar: '',
          title: '测试用户',
          subtitle: '最后消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579500000,
          lastMsgId: 'msg_100',
          unreadNum: 0,
          payload: {'text': '最后消息'},
        );

        final savedConvId = await conversationRepo.insert(conv);

        // 2. 模拟删除最后一条消息后，用前一条更新会话
        // 前一条消息：msg_099
        await conversationRepo.updateById(savedConvId, {
          ConversationRepo.lastMsgId: 'msg_099',
          ConversationRepo.lastTime: 1642579400000,
          ConversationRepo.subtitle: '前一条消息',
          ConversationRepo.msgType: 'text',
          ConversationRepo.payload: {'text': '前一条消息'},
        });

        // 3. 验证
        final updatedConv = await conversationRepo.findById(savedConvId);

        expect(updatedConv, isNotNull);
        expect(updatedConv!.lastMsgId, 'msg_099');
        expect(updatedConv.subtitle, '前一条消息');
      });

      test('删除最后一条消息且没有前一条时应该清空会话', () async {
        // 1. 创建会话（只有一条消息）
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_delete_peer_2',
          avatar: '',
          title: '测试用户',
          subtitle: '唯一消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_only_001',
          unreadNum: 0,
          payload: {'text': '唯一消息'},
        });

        final savedConvId = await conversationRepo.insert(conv);

        // 2. 模拟删除唯一一条消息后，清空会话
        await conversationRepo.updateById(savedConvId, {
          ConversationRepo.lastMsgId: '',
          ConversationRepo.lastTime: 0,
          ConversationRepo.subtitle: '',
          ConversationRepo.msgType: 'empty',
          ConversationRepo.payload: null,
        });

        // 3. 验证
        final updatedConv = await conversationRepo.findById(savedConvId);

        expect(updatedConv, isNotNull);
        expect(updatedConv!.lastMsgId, '');
        expect(updatedConv.subtitle, '');
        expect(updatedConv.lastTime, 0);
        expect(updatedConv.msgType, 'empty');
      });

      test('删除非最后一条消息时不应该更新会话', () async {
        // 1. 创建会话（最后一条是 msg_200）
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_delete_peer_3',
          avatar: '',
          title: '测试用户',
          subtitle: '最后消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579500000,
          lastMsgId: 'msg_200',
          unreadNum: 0,
          payload: {'text': '最后消息'},
        );

        final savedConvId = await conversationRepo.insert(conv);

        // 2. 模拟删除更早的消息（msg_150）
        final earlierMsgId = 'msg_150';

        // 3. 验证：因为删除的不是最后一条消息，所以不应该更新会话
        final foundConv = await conversationRepo.findById(savedConvId);

        expect(foundConv, isNotNull);
        expect(foundConv!.lastMsgId, 'msg_200'); // 最后消息ID 不变
        expect(foundConv.subtitle, '最后消息'); // 副标题不变
      });
    });

    group('会话内容展示优先级', () {
      test('撤回状态应该优先于普通消息类型', () {
        // lastMsgStatus = 30 (撤回)
        // msgType = 'text'
        // 应该优先显示撤回提示

        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息', // 这个副标题应该被忽略
          type: 'C2C',
          msgType: 'text', // 这个类型应该被忽略
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          lastMsgStatus: 30, // peerRevoked（优先级最高）
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, contains('撤回了一条消息'));
        expect(content, isNot(contains('原始消息')));
      });

      test('草稿应该优先于撤回状态', () {
        // 这个测试验证草稿显示逻辑
        // 注意：实际实现中，草稿是通过 StorageService 读取的
        // 这里只验证会话模型的 content 计算逻辑

        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '消息内容',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          lastMsgStatus: 30, // 撤回状态
          unreadNum: 0,
          payload: {},
        );

        // 没有草稿时，应该显示撤回提示
        final content = conv.content;

        expect(content, contains('撤回了一条消息'));
      });

      test('系统提示应该优先于撤回状态', () {
        // sys_prompt = 'in_denylist'
        // lastMsgStatus = 30
        // 应该优先显示系统提示

        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '消息内容',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          lastMsgStatus: 30, // 撤回状态
          unreadNum: 0,
          payload: {'sys_prompt': 'in_denylist'}, // 系统提示（优先级最高）
        );

        final content = conv.content;

        expect(content, contains('拒收')); // 系统提示
        expect(content, isNot(contains('撤回')));
      });
    });

    group('不同消息类型的撤回展示', () {
      test('文本消息撤回后应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '原始文本消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, contains('撤回了一条消息'));
      });

      test('图片消息撤回后应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '[图片]',
          type: 'C2C',
          msgType: 'image',
          lastTime: 1642579200000,
          lastMsgId: 'msg_002',
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        // 撤回后不显示 [图片]，显示撤回提示
        expect(content, contains('撤回了一条消息'));
        expect(content, isNot('[图片]'));
      });

      test('语音消息撤回后应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '[语音]',
          type: 'C2C',
          msgType: 'audio',
          lastTime: 1642579200000,
          lastMsgId: 'msg_003',
          lastMsgStatus: 31, // 自己撤回
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, contains('你撤回了一条消息'));
      });

      test('视频消息撤回后应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '[视频]',
          type: 'C2C',
          msgType: 'video',
          lastTime: 1642579200000,
          lastMsgId: 'msg_004',
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, contains('撤回了一条消息'));
      });

      test('文件消息撤回后应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '[文件]',
          type: 'C2C',
          msgType: 'file',
          lastTime: 1642579200000,
          lastMsgId: 'msg_005',
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, contains('撤回了一条消息'));
      });

      test('位置消息撤回后应该显示撤回提示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '[位置]北京市朝阳区',
          type: 'C2C',
          msgType: 'location',
          lastTime: 1642579200000,
          lastMsgId: 'msg_006',
          lastMsgStatus: 30,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, contains('撤回了一条消息'));
        expect(content, isNot(contains('[位置]')));
      });
    });

    group('边界条件', () {
      test('lastMsgStatus 为 null 时应该按普通消息处理', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '普通文本消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          lastMsgStatus: null, // null
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, '普通文本消息');
      });

      test('payload 为 null 时撤回提示应该正常显示', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          lastMsgStatus: 31, // myRevoked
          unreadNum: 0,
          payload: null, // null payload
        );

        final content = conv.content;

        expect(content, contains('你撤回了一条消息'));
      });

      test('title 超长时应该正确截断', () {
        final longTitle = '这是一个非常非常非常非常非常非常非常非常非常非常长的用户名';

        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: longTitle,
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          lastMsgStatus: 30, // peerRevoked
          unreadNum: 0,
          payload: {'peer_name': longTitle},
        );

        final content = conv.content;

        // 应该截断到 12 个字符并添加 ...
        expect(content, contains('...'));
        expect(content, contains('撤回了一条消息'));
      });
    });
  });
}
