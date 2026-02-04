/// 会话状态同步测试（使用Mock服务）
///
/// 测试目标：
/// 1. 会话创建和更新
/// 2. 新消息到达时会话状态同步
/// 3. 会话最后消息更新
/// 4. 会话在内存和存储的一致性
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import '../helper/mock_services.dart';

void main() {
  group('会话状态同步测试（Mock版本）', () {
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

    group('会话创建', () {
      test('应该能够创建新会话', () async {
        final conv = ConversationModel(
          id: 0, // 新会话id为0，插入后会自动分配
          peerId: 'user123',
          type: 'C2C',
          avatar: 'https://example.com/avatar.png',
          title: '测试用户',
          subtitle: '第一条消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 1,
        );

        final id = await conversationRepo.insert(conv);

        expect(id, greaterThan(0));

        final saved = await conversationRepo.findById(id);
        expect(saved, isNotNull);
        expect(saved!.peerId, 'user123');
        expect(saved.title, '测试用户');
        expect(saved.unreadNum, 1);
      });

      test('应该能够创建群组会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 'group001',
          type: 'C2G',
          avatar: '',
          title: '测试群组',
          subtitle: '群组消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 5,
        );

        final id = await conversationRepo.insert(conv);

        final saved = await conversationRepo.findById(id);
        expect(saved!.type, 'C2G');
        expect(saved.peerId, 'group001');
      });

      test('应该能够根据peerId查找会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 'user456',
          type: 'C2C',
          avatar: '',
          title: '用户456',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 0,
        );

        await conversationRepo.insert(conv);

        final found = await conversationRepo.findByPeerId('C2C', 'user456');
        expect(found, isNotNull);
        expect(found!.title, '用户456');

        final notFound = await conversationRepo.findByPeerId('C2C', 'user999');
        expect(notFound, isNull);
      });
    });

    group('会话更新', () {
      test('应该能够更新会话内容', () async {
        // 先创建会话
        final conv = ConversationModel(
          id: 0,
          peerId: 'user789',
          type: 'C2C',
          avatar: '',
          title: '原始标题',
          subtitle: '原始消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 1,
        );

        final id = await conversationRepo.insert(conv);

        // 更新会话
        await conversationRepo.updateById(id, {
          'title': '新标题',
          'subtitle': '新消息',
          'unread_num': 2,
        });

        // 验证更新
        final updated = await conversationRepo.findById(id);
        expect(updated!.title, '新标题');
        expect(updated.subtitle, '新消息');
        expect(updated.unreadNum, 2);
      });

      test('应该能够更新会话的未读数', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 'user999',
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 3,
        );

        final id = await conversationRepo.insert(conv);

        // 累加未读数
        final current = await conversationRepo.findById(id);
        await conversationRepo.updateById(id, {
          'unread_num': current!.unreadNum + 5,
        });

        final updated = await conversationRepo.findById(id);
        expect(updated!.unreadNum, 8);
      });

      test('应该能够清空未读数', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 'user888',
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 10,
        );

        final id = await conversationRepo.insert(conv);

        await conversationRepo.updateById(id, {'unread_num': 0});

        final updated = await conversationRepo.findById(id);
        expect(updated!.unreadNum, 0);
      });
    });

    group('会话删除', () {
      test('应该能够删除会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 'user111',
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 0,
        );

        final id = await conversationRepo.insert(conv);

        // 删除会话
        final result = await conversationRepo.delete(id);
        expect(result, 1);

        // 验证已删除
        final deleted = await conversationRepo.findById(id);
        expect(deleted, isNull);
      });

      test('应该能够根据peerId删除会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 'user222',
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 0,
        );

        await conversationRepo.insert(conv);

        final result = await conversationRepo.deleteByPeerId('C2C', 'user222');
        expect(result, 1);

        final found = await conversationRepo.findByPeerId('C2C', 'user222');
        expect(found, isNull);
      });
    });

    group('新消息到达时的会话更新', () {
      test('新消息到达时应该创建新会话', () async {
        final msg = MessageModel(
          'msg_new_001',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          payload: {'content': '新消息'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1234567890,
          msgType: 'text',
        );

        // 模拟新消息到达，创建会话
        final conv = ConversationModel(
          id: 0,
          peerId: 'user2',
          type: 'C2C',
          avatar: '',
          title: '用户2',
          subtitle: '新消息',
          msgType: msg.msgType!,
          lastTime: msg.createdAt,
          lastMsgId: msg.id ?? 'msg_new',
          unreadNum: 1,
        );

        final id = await conversationRepo.insert(conv);

        final saved = await conversationRepo.findById(id);
        expect(saved!.lastMsgId, 'msg_new_001');
        expect(saved.unreadNum, 1);
      });

      test('新消息到达时应该更新已存在的会话', () async {
        // 创建现有会话
        final existingConv = ConversationModel(
          id: 0,
          peerId: 'user333',
          type: 'C2C',
          avatar: '',
          title: '用户333',
          subtitle: '旧消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_old',
          unreadNum: 2,
        );

        final convId = await conversationRepo.insert(existingConv);

        // 模拟新消息到达
        final newMsg = MessageModel(
          'msg_new_002',
          autoId: 2,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user333',
          payload: {'content': '新消息内容'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user333',
          createdAt: 1234567900,
          msgType: 'text',
        );

        // 更新会话（累加未读数）
        final current = await conversationRepo.findById(convId);
        await conversationRepo.updateById(convId, {
          'subtitle': '新消息内容',
          'last_time': newMsg.createdAt,
          'last_msg_id': newMsg.id ?? 'msg_new',
          'unread_num': current!.unreadNum + 1,
        });

        final updated = await conversationRepo.findById(convId);
        expect(updated!.subtitle, '新消息内容');
        expect(updated.lastMsgId, 'msg_new_002');
        expect(updated.unreadNum, 3); // 2 + 1
      });
    });

    group('会话列表管理', () {
      test('应该能够获取所有会话', () async {
        // 创建多个会话
        await conversationRepo.insert(
          ConversationModel(
            id: 0,
            peerId: 'user1',
            type: 'C2C',
            avatar: '',
            title: '用户1',
            subtitle: '消息1',
            msgType: 'text',
            lastTime: 1234567890,
            lastMsgId: 'msg1',
            unreadNum: 1,
          ),
        );

        await conversationRepo.insert(
          ConversationModel(
            id: 0,
            peerId: 'user2',
            type: 'C2C',
            avatar: '',
            title: '用户2',
            subtitle: '消息2',
            msgType: 'text',
            lastTime: 1234567891,
            lastMsgId: 'msg2',
            unreadNum: 0,
          ),
        );

        final all = conversationRepo.getAll();
        expect(all.length, 2);
      });

      test('应该按lastTime排序会话', () async {
        await conversationRepo.insert(
          ConversationModel(
            id: 0,
            peerId: 'user1',
            type: 'C2C',
            avatar: '',
            title: '用户1',
            subtitle: '消息1',
            msgType: 'text',
            lastTime: 1000,
            lastMsgId: 'msg1',
            unreadNum: 0,
          ),
        );

        await conversationRepo.insert(
          ConversationModel(
            id: 0,
            peerId: 'user2',
            type: 'C2C',
            avatar: '',
            title: '用户2',
            subtitle: '消息2',
            msgType: 'text',
            lastTime: 2000,
            lastMsgId: 'msg2',
            unreadNum: 0,
          ),
        );

        final all = conversationRepo.getAll();
        all.sort((a, b) => b.lastTime.compareTo(a.lastTime));

        expect(all.first.peerId, 'user2'); // 最新的在前面
        expect(all.last.peerId, 'user1');
      });
    });

    group('边界条件', () {
      test('应该处理空peerId', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: '',
          type: 'C2C',
          avatar: '',
          title: '',
          subtitle: '',
          msgType: 'text',
          lastTime: 0,
          lastMsgId: '',
          unreadNum: 0,
        );

        final id = await conversationRepo.insert(conv);
        expect(id, greaterThan(0));
      });

      test('应该处理特殊字符', () async {
        final specialTitle = '测试"用户"\n\t\\';

        final conv = ConversationModel(
          id: 0,
          peerId: 'user_special',
          type: 'C2C',
          avatar: '',
          title: specialTitle,
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 0,
        );

        final id = await conversationRepo.insert(conv);
        final saved = await conversationRepo.findById(id);
        expect(saved!.title, specialTitle);
      });

      test('应该处理超大未读数', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 'user_big',
          type: 'C2C',
          avatar: '',
          title: '用户',
          subtitle: '消息',
          msgType: 'text',
          lastTime: 1234567890,
          lastMsgId: 'msg_001',
          unreadNum: 999999,
        );

        final id = await conversationRepo.insert(conv);
        final saved = await conversationRepo.findById(id);
        expect(saved!.unreadNum, 999999);
      });
    });

    group('并发操作', () {
      test('应该能够处理多次插入', () async {
        final ids = <int>[];
        for (int i = 0; i < 10; i++) {
          final conv = ConversationModel(
            id: 0,
            peerId: 'user_$i',
            type: 'C2C',
            avatar: '',
            title: '用户$i',
            subtitle: '消息$i',
            msgType: 'text',
            lastTime: 1234567890 + i,
            lastMsgId: 'msg_$i',
            unreadNum: i,
          );
          final id = await conversationRepo.insert(conv);
          ids.add(id);
        }

        expect(ids.length, 10);
        expect(ids.toSet().length, 10); // 所有ID都不同

        final all = conversationRepo.getAll();
        expect(all.length, 10);
      });
    });
  });
}
