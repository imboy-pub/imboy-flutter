import 'package:flutter/widgets.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:xid/xid.dart';

import '../chat/chat_logic.dart';
import 'send_to_state.dart';

class SendToLogic extends GetxController {
  final SendToState state = SendToState();

  /// 最近聊天
  Future<void> conversationsList() async {
    state.conversations.value = await (ConversationRepo()).list(limit: 100);
  }

  /// type
  Future<bool> sendMsg(
    ConversationModel conversation,
    types.Message msg,
  ) async {
    try {
      types.Message msg2 = msg.copyWith(
        id: Xid().toString(),
        author: types.User(
          id: UserRepoLocal.to.currentUid,
          firstName: UserRepoLocal.to.current.nickname,
          imageUrl: UserRepoLocal.to.current.avatar,
        ),
        status: types.Status.sending,
        createdAt: DateTimeHelper.currentTimeMillis(),
        metadata: msg.metadata,
        remoteId: conversation.peerId,
        roomId: msg.roomId,
        showStatus: msg.showStatus,
      );
      await ChatLogic().addMessage(
        UserRepoLocal.to.currentUid,
        conversation.peerId,
        conversation.avatar,
        conversation.title,
        conversation.type,
        msg2,
      );
      return true;
    } catch (e) {
      debugPrint("> on sendMsg ${e.toString()}");
    }
    return false;
  }
}
