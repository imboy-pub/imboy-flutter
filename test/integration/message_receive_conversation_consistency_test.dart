/// 消息接收会话一致性场景测试（Mock 仓储）
///
/// 目标：
/// 1. C2C 自回显消息应归并到对端会话，不应创建“自己和自己”的会话
/// 2. 用户处于活跃会话时，接收消息不应增加未读
/// 3. 后台接收消息时，未读每条只增加 1，提醒同步只更新内存
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/message_conversation_utils.dart';
import 'package:imboy/store/model/conversation_model.dart';

import '../helper/mock_services.dart';

void main() {
  const currentUid = 'ut_me';
  const peerUid = 'ut_peer';

  late MockConversationRepository conversationRepo;

  Future<ConversationModel> saveConversationLikeSqlite(
    ConversationModel incoming,
  ) async {
    final oldObj = await conversationRepo.findByPeerId(
      incoming.type,
      incoming.peerId,
    );
    final oldUnread = oldObj?.unreadNum ?? 0;

    final merged = incoming.copyWith(unreadNum: incoming.unreadNum + oldUnread);

    if (oldObj == null) {
      final id = await conversationRepo.insert(merged);
      return (await conversationRepo.findById(id))!;
    }

    final data = merged.toJson();
    data.remove('id');
    await conversationRepo.updateById(oldObj.id, data);
    return (await conversationRepo.findByPeerId(merged.type, merged.peerId))!;
  }

  Future<ConversationModel> simulateReceiveAndSaveConversation({
    required String msgType,
    required String from,
    required String to,
    required String msgId,
    required int lastTime,
    required bool isUserInChat,
  }) async {
    final data = <String, dynamic>{'from': from, 'to': to};
    final peerId = resolveConversationPeerId(
      msgType: msgType,
      data: data,
      currentUid: currentUid,
    );
    final unreadIncrement = computeConversationUnreadIncrement(
      isFromCurrentUser: from == currentUid,
      isUserInChat: isUserInChat,
    );

    final conv = ConversationModel(
      id: 0,
      peerId: peerId,
      avatar: '',
      title: 'test-$peerId',
      subtitle: 'msg-$msgId',
      type: msgType,
      msgType: 'text',
      lastMsgId: msgId,
      lastTime: lastTime,
      unreadNum: unreadIncrement,
    );

    return saveConversationLikeSqlite(conv);
  }

  setUp(() {
    conversationRepo = MockConversationRepository();
  });

  tearDown(() {
    conversationRepo.clear();
  });

  group('消息接收会话一致性', () {
    test('C2C 自回显应归并到对端会话，不创建自会话', () async {
      final savedIncoming = await simulateReceiveAndSaveConversation(
        msgType: 'C2C',
        from: peerUid,
        to: currentUid,
        msgId: 'msg_in_1',
        lastTime: 1001,
        isUserInChat: false,
      );
      expect(savedIncoming.peerId, peerUid);
      expect(savedIncoming.unreadNum, 1);

      final savedEcho = await simulateReceiveAndSaveConversation(
        msgType: 'C2C',
        from: currentUid,
        to: peerUid,
        msgId: 'msg_echo_1',
        lastTime: 1002,
        isUserInChat: false,
      );

      expect(savedEcho.peerId, peerUid);
      expect(savedEcho.unreadNum, 1); // 自回显 unreadIncrement=0，不应新增未读
      expect(savedEcho.lastMsgId, 'msg_echo_1');

      final peerConv = await conversationRepo.findByPeerId('C2C', peerUid);
      final selfConv = await conversationRepo.findByPeerId('C2C', currentUid);
      expect(peerConv, isNotNull);
      expect(peerConv!.unreadNum, 1);
      expect(selfConv, isNull);
    });

    test('活跃会话内接收对端消息不增加未读', () async {
      final first = await simulateReceiveAndSaveConversation(
        msgType: 'C2C',
        from: 'ut_peer_active',
        to: currentUid,
        msgId: 'msg_bg_1',
        lastTime: 2001,
        isUserInChat: false,
      );
      expect(first.unreadNum, 1);

      final second = await simulateReceiveAndSaveConversation(
        msgType: 'C2C',
        from: 'ut_peer_active',
        to: currentUid,
        msgId: 'msg_fg_2',
        lastTime: 2002,
        isUserInChat: true,
      );

      expect(second.unreadNum, 1); // 前台消息 unreadIncrement=0

      final conv = await conversationRepo.findByPeerId('C2C', 'ut_peer_active');
      expect(conv, isNotNull);
      expect(conv!.unreadNum, 1);
      expect(conv.lastMsgId, 'msg_fg_2');
    });

    test('后台每条消息只增 1，提醒使用内存同步不写回 DB', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(conversationProvider.notifier);

      final first = await simulateReceiveAndSaveConversation(
        msgType: 'C2C',
        from: 'ut_peer_bg',
        to: currentUid,
        msgId: 'msg_bg_1',
        lastTime: 3001,
        isUserInChat: false,
      );

      const remindKey = 'C2C_ut_peer_bg';
      notifier.setConversationRemindLocal(remindKey, first.unreadNum);
      expect(first.unreadNum, 1);
      expect(
        container.read(conversationProvider).conversationRemind[remindKey],
        1,
      );

      final second = await simulateReceiveAndSaveConversation(
        msgType: 'C2C',
        from: 'ut_peer_bg',
        to: currentUid,
        msgId: 'msg_bg_2',
        lastTime: 3002,
        isUserInChat: false,
      );
      notifier.setConversationRemindLocal(remindKey, second.unreadNum);

      expect(second.unreadNum, 2); // 只应从 1 -> 2，不应双增
      expect(
        container.read(conversationProvider).conversationRemind[remindKey],
        2,
      );

      final conv = await conversationRepo.findByPeerId('C2C', 'ut_peer_bg');
      expect(conv, isNotNull);
      expect(conv!.unreadNum, 2); // 内存提醒同步不会额外修改 DB 未读
    });
  });
}
