import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

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
  
  // 添加缺失的属性
  final TextEditingController searchController = TextEditingController();
  final RxList<ConversationModel> searchResults = <ConversationModel>[].obs;
  final RxList<ConversationModel> selectedContacts = <ConversationModel>[].obs;

  /// 最近聊天
  Future<void> conversationsList() async {
    state.conversations.value = await (ConversationRepo()).list(limit: 100);
  }

  /// type
  Future<bool> sendMsg(ConversationModel conversation, Message msg) async {
    try {
      Map<String, dynamic> metadata = Map<String, dynamic>.from(msg.metadata ?? {});
      metadata['peer_id'] = conversation.peerId;
      Message msg2 = msg.copyWith(
        id: Xid().toString(),
        authorId: UserRepoLocal.to.currentUid,
        status: MessageStatus.sending,
        createdAt: DateTimeHelper.now(),
        metadata: metadata,
        // roomId: msg.roomId,
        // status: msg.status ?? MessageStatus.sending,
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
    } catch (e, s) {
      debugPrint("> on sendMsg ${e.toString()} ${s.toString()}");
    }
    return false;
  }
  
  // 添加缺失的方法
  void search(String query) {
    // 实现搜索逻辑
    if (query.isEmpty) {
      searchResults.assignAll(state.conversations);
    } else {
      searchResults.assignAll(
        state.conversations.where((contact) {
          return contact.title.toLowerCase().contains(query.toLowerCase());
        }).toList(),
      );
    }
  }

  void toggleContactSelection(ConversationModel contact) {
    if (selectedContacts.any((element) => element.id == contact.id)) {
      selectedContacts.removeWhere((element) => element.id == contact.id);
    } else {
      selectedContacts.add(contact);
    }
  }
}