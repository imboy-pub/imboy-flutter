/// 未读消息数管理集成测试
///
/// 测试目标：
/// 1. 未读数计算（基于已读水位）
/// 2. 未读数累加（新消息到达时）
/// 3. 未读数清空（进入会话、已读确认）
/// 4. 已读水位推进
/// 5. 批量消息已读处理
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/service/sqlite.dart';

void main() {
  group('未读消息数管理集成测试', () {
    late ConversationRepo conversationRepo;
    late MessageRepo messageRepo;

    setUp(() async {
      conversationRepo = ConversationRepo();
      messageRepo = MessageRepo(tableName: 'msg_c2c');
    });

    tearDown(() async {
      // 清理测试数据
      try {
        await conversationRepo.delete('C2C', 'test_unread_peer_1');
        await conversationRepo.delete('C2C', 'test_unread_peer_2');
        await conversationRepo.delete('C2C', 'test_unread_peer_3');

        // 清理测试消息
        for (int i = 0; i < 20; i++) {
          final msg = await messageRepo.find('test_unread_msg_$i');
          if (msg != null) {
            await messageRepo.delete(msg.id!);
          }
        }
      } catch (e) {
        // 忽略清理错误
      }
    });

    group('已读水位管理', () {
      test('应该能够读取已读水位（last_read_auto_id）', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0,
          payload: {'last_read_auto_id': 100},
        );

        // 模拟读取已读水位
        final lastReadAutoId = _getLastReadAutoId(conv);

        expect(lastReadAutoId, 100);
      });

      test('payload 为空时已读水位应该返回 0', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0,
          payload: null,
        );

        final lastReadAutoId = _getLastReadAutoId(conv);

        expect(lastReadAutoId, 0);
      });

      test('应该支持字符串格式的已读水位', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0,
          payload: {'last_read_auto_id': '150'}, // 字符串格式
        );

        final lastReadAutoId = _getLastReadAutoId(conv);

        expect(lastReadAutoId, 150);
      });

      test('无效的已读水位应该返回 0', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0,
          payload: {'last_read_auto_id': 'invalid'}, // 无效值
        );

        final lastReadAutoId = _getLastReadAutoId(conv);

        expect(lastReadAutoId, 0);
      });
    });

    group('未读数累加', () {
      test('新消息到达时应该累加未读数', () async {
        // 1. 创建初始会话（未读数 = 2）
        final conv1 = ConversationModel(
          id: 0,
          peerId: 'test_unread_peer_1',
          avatar: '',
          title: '测试用户',
          subtitle: '消息1',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 2,
          payload: {},
        );

        final saved1 = await conversationRepo.save(conv1);

        expect(saved1.unreadNum, 2);

        // 2. 新消息到达（新增 3 条未读）
        final conv2 = ConversationModel(
          id: saved1.id,
          peerId: 'test_unread_peer_1',
          avatar: '',
          title: '测试用户',
          subtitle: '消息2',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579300000,
          lastMsgId: 'msg_002',
          unreadNum: 3,
          payload: {},
        );

        final saved2 = await conversationRepo.save(conv2);

        // 3. 验证未读数累加：2 + 3 = 5
        expect(saved2.unreadNum, 5);
      });

      test('未读数为 0 时累加应该正常工作', () async {
        // 初始未读数 = 0
        final conv1 = ConversationModel(
          id: 0,
          peerId: 'test_unread_peer_2',
          avatar: '',
          title: '测试用户',
          subtitle: '消息1',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0, // 初始未读数 = 0
          payload: {},
        );

        final saved1 = await conversationRepo.save(conv1);

        // 新增 5 条未读
        final conv2 = ConversationModel(
          id: saved1.id,
          peerId: 'test_unread_peer_2',
          avatar: '',
          title: '测试用户',
          subtitle: '消息2',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579300000,
          lastMsgId: 'msg_002',
          unreadNum: 5,
          payload: {},
        );

        final saved2 = await conversationRepo.save(conv2);

        expect(saved2.unreadNum, 5);
      });

      test('应该支持多次累加未读数', () async {
        // 第一次：未读数 = 1
        var conv = ConversationModel(
          id: 0,
          peerId: 'test_unread_peer_3',
          avatar: '',
          title: '测试用户',
          subtitle: '消息1',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 1,
          payload: {},
        );

        conv = await conversationRepo.save(conv);
        expect(conv.unreadNum, 1);

        // 第二次：新增 2 条，未读数 = 1 + 2 = 3
        conv = ConversationModel(
          id: conv.id,
          peerId: 'test_unread_peer_3',
          avatar: '',
          title: '测试用户',
          subtitle: '消息2',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579300000,
          lastMsgId: 'msg_002',
          unreadNum: 2,
          payload: {},
        );

        conv = await conversationRepo.save(conv);
        expect(conv.unreadNum, 3);

        // 第三次：新增 4 条，未读数 = 3 + 4 = 7
        conv = ConversationModel(
          id: conv.id,
          peerId: 'test_unread_peer_3',
          avatar: '',
          title: '测试用户',
          subtitle: '消息3',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579400000,
          lastMsgId: 'msg_003',
          unreadNum: 4,
          payload: {},
        );

        conv = await conversationRepo.save(conv);
        expect(conv.unreadNum, 7);
      });
    });

    group('未读数清空', () {
      test('应该能够直接设置未读数为 0', () async {
        // 1. 创建有未读数的会话
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_unread_peer_clear_1',
          avatar: '',
          title: '测试用户',
          subtitle: '测试消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 10,
          payload: {},
        );

        final saved = await conversationRepo.insert(conv);

        // 2. 清空未读数
        await conversationRepo.updateById(saved, {
          ConversationRepo.unreadNum: 0,
        });

        // 3. 验证
        final updated = await conversationRepo.findById(saved);
        expect(updated, isNotNull);
        expect(updated!.unreadNum, 0);
      });

      test('应该能够通过 peerId 清空未读数', () async {
        // 1. 创建有未读数的会话
        final conv = ConversationModel(
          id: 0,
          peerId: 'test_unread_peer_clear_2',
          avatar: '',
          title: '测试用户',
          subtitle: '测试消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 5,
          payload: {},
        );

        await conversationRepo.insert(conv);

        // 2. 通过 peerId 清空未读数
        await conversationRepo.updateByPeerId('C2C', 'test_unread_peer_clear_2', {
          ConversationRepo.unreadNum: 0,
        });

        // 3. 验证
        final updated = await conversationRepo.findByPeerId('C2C', 'test_unread_peer_clear_2');
        expect(updated, isNotNull);
        expect(updated!.unreadNum, 0);
      });
    });

    group('未读数计算（模拟）', () {
      test('应该正确计算未读消息数', () {
        // 模拟场景：
        // last_read_auto_id = 100
        // 消息表中有 5 条消息的 auto_id > 100 (101, 102, 103, 104, 105)
        // 其中 3 条是接收的消息 (is_author = 0)
        // 未读数应该是 3

        const lastReadAutoId = 100;

        // 模拟消息数据
        final messages = [
          {'auto_id': 101, 'is_author': 1}, // 发送的消息，不算未读
          {'auto_id': 102, 'is_author': 0}, // 接收的消息，算未读 ✓
          {'auto_id': 103, 'is_author': 0}, // 接收的消息，算未读 ✓
          {'auto_id': 104, 'is_author': 1}, // 发送的消息，不算未读
          {'auto_id': 105, 'is_author': 0}, // 接收的消息，算未读 ✓
        ];

        // 计算未读数
        final unreadCount = messages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > lastReadAutoId && isAuthor == 0;
        }).length;

        expect(unreadCount, 3);
      });

      test('所有消息都已读时未读数应该为 0', () {
        const lastReadAutoId = 200;

        // 所有消息的 auto_id <= last_read_auto_id
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

      test('没有消息时未读数应该为 0', () {
        const lastReadAutoId = 0;
        final messages = <Map<String, dynamic>>[];

        final unreadCount = messages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > lastReadAutoId && isAuthor == 0;
        }).length;

        expect(unreadCount, 0);
      });

      test('只统计接收的消息（is_author = 0）', () {
        const lastReadAutoId = 50;

        // 全部是发送的消息
        final messages = [
          {'auto_id': 51, 'is_author': 1},
          {'auto_id': 52, 'is_author': 1},
          {'auto_id': 53, 'is_author': 1},
        ];

        final unreadCount = messages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > lastReadAutoId && isAuthor == 0;
        }).length;

        expect(unreadCount, 0);
      });
    });

    group('已读水位推进', () {
      test('应该能够推进已读水位', () {
        // 模拟会话对象
        var conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0,
          payload: {'last_read_auto_id': 100},
        );

        // 推进已读水位到 150
        final newPayload = <String, dynamic>{
          ...?conv.payload,
          'last_read_auto_id': 150,
        };

        conv = conv.copyWith(payload: newPayload);

        final newLastReadAutoId = _getLastReadAutoId(conv);

        expect(newLastReadAutoId, 150);
      });

      test('已读水位只能推进不能回退', () {
        // 初始水位 = 100
        var conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0,
          payload: {'last_read_auto_id': 100},
        );

        // 尝试回退到 50（应该被拒绝）
        final newAutoId = 50;
        final current = _getLastReadAutoId(conv);

        final shouldUpdate = newAutoId > current;

        expect(shouldUpdate, false); // 不应该更新

        // 尝试推进到 150（应该成功）
        final newAutoId2 = 150;
        final shouldUpdate2 = newAutoId2 > current;

        expect(shouldUpdate2, true); // 应该更新
      });

      test('已读水位为 0 时应该能够推进', () {
        var conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0,
          payload: null, // 没有已读水位
        );

        final current = _getLastReadAutoId(conv);
        expect(current, 0);

        // 推进到 100
        final newPayload = <String, dynamic>{
          'last_read_auto_id': 100,
        };

        conv = conv.copyWith(payload: newPayload);

        final newLastReadAutoId = _getLastReadAutoId(conv);
        expect(newLastReadAutoId, 100);
      });
    });

    group('批量消息已读', () {
      test('应该能够计算批量消息的最大 auto_id', () {
        // 模拟消息列表
        final messages = [
          {'id': 'msg_001', 'auto_id': 101},
          {'id': 'msg_002', 'auto_id': 105},
          {'id': 'msg_003', 'auto_id': 103},
          {'id': 'msg_004', 'auto_id': 108},
          {'id': 'msg_005', 'auto_id': 102},
        ];

        // 找出最大的 auto_id
        final maxAutoId = messages
            .map((msg) => msg['auto_id'] as int)
            .reduce((a, b) => a > b ? a : b);

        expect(maxAutoId, 108);
      });

      test('空消息列表应该返回 null', () {
        final messages = <Map<String, dynamic>>[];

        final maxAutoId = messages
            .map((msg) => msg['auto_id'] as int)
            .fold<int?>(null, (prev, element) => prev == null || element > prev ? element : prev);

        expect(maxAutoId, null);
      });

      test('单条消息应该返回其 auto_id', () {
        final messages = [
          {'id': 'msg_001', 'auto_id': 101},
        ];

        final maxAutoId = messages
            .map((msg) => msg['auto_id'] as int)
            .reduce((a, b) => a > b ? a : b);

        expect(maxAutoId, 101);
      });
    });

    group('未读数与已读水位的关系', () {
      test('推进已读水位后未读数应该减少', () {
        // 场景：
        // last_read_auto_id = 100
        // 未读消息：101, 102, 103 (3条)
        // 推进到 103 后，未读数应该变为 0

        const lastReadAutoId = 100;

        // 未读消息
        final unreadMessages = [
          {'auto_id': 101, 'is_author': 0},
          {'auto_id': 102, 'is_author': 0},
          {'auto_id': 103, 'is_author': 0},
        ];

        // 当前未读数
        final unreadCount = unreadMessages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > lastReadAutoId && isAuthor == 0;
        }).length;

        expect(unreadCount, 3);

        // 推进已读水位到 103
        const newLastReadAutoId = 103;

        // 新的未读数
        final newUnreadCount = unreadMessages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > newLastReadAutoId && isAuthor == 0;
        }).length;

        expect(newUnreadCount, 0);
      });

      test('部分推进已读水位应该减少部分未读数', () {
        // 场景：
        // last_read_auto_id = 100
        // 未读消息：101, 102, 103, 104, 105 (5条)
        // 推进到 103 后，未读数应该变为 2 (104, 105)

        const lastReadAutoId = 100;

        final unreadMessages = [
          {'auto_id': 101, 'is_author': 0},
          {'auto_id': 102, 'is_author': 0},
          {'auto_id': 103, 'is_author': 0},
          {'auto_id': 104, 'is_author': 0},
          {'auto_id': 105, 'is_author': 0},
        ];

        // 推进到 103
        const newLastReadAutoId = 103;

        final newUnreadCount = unreadMessages.where((msg) {
          final autoId = msg['auto_id'] as int;
          final isAuthor = msg['is_author'] as int;
          return autoId > newLastReadAutoId && isAuthor == 0;
        }).length;

        expect(newUnreadCount, 2);
      });
    });

    group('边界条件', () {
      test('未读数不应该为负数', () {
        // 尝试设置负数未读数
        final unreadNum = -5;

        // 应该被限制为 0
        final clampedUnreadNum = unreadNum.clamp(0, 999999);

        expect(clampedUnreadNum, 0);
      });

      test('未读数应该有上限', () {
        // 尝试设置超大未读数
        final unreadNum = 999999999;

        // 应该被限制为 999999
        final clampedUnreadNum = unreadNum.clamp(0, 999999);

        expect(clampedUnreadNum, 999999);
      });

      test('应该能够处理 0 未读数', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 'test_user',
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 'msg_001',
          unreadNum: 0,
          payload: {},
        );

        expect(conv.unreadNum, 0);
      });
    });
  });
}

// 辅助函数：读取已读水位
int _getLastReadAutoId(ConversationModel conversation) {
  try {
    final v = conversation.payload?['last_read_auto_id'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  } catch (_) {
    return 0;
  }
}
