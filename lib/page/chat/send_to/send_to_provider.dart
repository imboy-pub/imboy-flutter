import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:xid/xid.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/message_type_constants.dart';

import 'package:imboy/service/events/events.dart';

/// 发送给 页面状态
class SendToState {
  final List<ConversationModel> conversations;
  final List<ConversationModel> searchResults;
  final List<ConversationModel> selectedContacts;

  const SendToState({
    this.conversations = const [],
    this.searchResults = const [],
    this.selectedContacts = const [],
  });

  SendToState copyWith({
    List<ConversationModel>? conversations,
    List<ConversationModel>? searchResults,
    List<ConversationModel>? selectedContacts,
  }) {
    return SendToState(
      conversations: conversations ?? this.conversations,
      searchResults: searchResults ?? this.searchResults,
      selectedContacts: selectedContacts ?? this.selectedContacts,
    );
  }
}

/// 发送消息逻辑控制器
class SendToNotifier extends Notifier<SendToState> {
  @override
  SendToState build() => const SendToState();

  String _normalizeConversationType(String? type) {
    return MessageFlowType.normalize(type);
  }

  /// 最近聊天
  Future<void> conversationsList() async {
    final conversations = await (ConversationRepo()).list(limit: 100);
    state = state.copyWith(
      conversations: conversations,
      searchResults: List.from(conversations),
    );
  }

  /// 构造转发消息的 payload。
  ///
  /// 源消息 metadata 必须**先**展开、再被目标会话字段覆盖。反过来（原实现把
  /// `...metadata` 放在最后）会让源会话的 `peer_id` / `conversation_uk3`
  /// 盖掉目标值 —— 真机实测：从群里转发到单聊，发出的 payload 仍带
  /// `peer_id: <群 gid>` 与 `conversation_uk3: C2G_...`，消息归属错乱。
  @visibleForTesting
  static Map<String, dynamic> buildForwardPayload({
    required Map<String, dynamic>? sourceMetadata,
    required String text,
    required int peerId,
    required String conversationUk3,
  }) {
    return <String, dynamic>{
      ...?sourceMetadata,
      'text': text,
      'peer_id': peerId,
      'conversation_uk3': conversationUk3,
    };
  }

  /// 推导转发消息的顶层 msg_type。
  ///
  /// 顶层 msg_type 为空时服务端直接回 `action=invalid_message`，客户端
  /// `toTypeMessage` 也判为「msg_type 为空或无效」→ 消息显示「[无效消息类型]」
  /// 并进入无限重试（真机实测每 5~10s 重发一次，服务端每次都拒）。
  @visibleForTesting
  static String resolveForwardMsgType(Map<String, dynamic>? sourceMetadata) {
    final raw = parseModelString(sourceMetadata?['msg_type']);
    return raw.isEmpty ? 'text' : raw;
  }

  /// 发送消息
  Future<bool> sendMsg(ConversationModel conversation, Message msg) async {
    try {
      // 获取并归一化会话类型，历史脏值统一按 C2C 处理
      final chatType = _normalizeConversationType(conversation.type);

      final payload = buildForwardPayload(
        sourceMetadata: msg.metadata,
        text: msg is TextMessage ? msg.text : '',
        peerId: conversation.peerId,
        conversationUk3: conversation.uk3,
      );
      final msgType = resolveForwardMsgType(msg.metadata);

      // 创建 MessageModel
      final msgModel = MessageModel(
        Xid().toString(),
        autoId: 0,
        type: chatType,
        status: 10, // 发送中
        fromId: int.tryParse(UserRepoLocal.to.currentUid) ?? 0,
        toId: conversation.peerId,
        payload: payload,
        createdAt: DateTimeHelper.millisecond(),
        isAuthor: 1,
        conversationUk3: conversation.uk3,
        msgType: msgType,
      );

      // 添加消息到数据库
      final msgRepo = MessageRepo(
        tableName: MessageRepo.getTableName(chatType),
      );
      await msgRepo.insert(msgModel);

      // 通过事件总线触发消息发送
      AppEventBus.fire(
        MessageSendRequestedEvent(
          message: msgModel,
          conversationUk3: conversation.uk3,
        ),
      );

      return true;
    } on Exception catch (e) {
      debugPrint('[send_to_provider] block error: $e');
    }
    return false;
  }

  /// 转发给所有已选联系人，返回失败数量
  Future<int> sendToSelected(Message msg) async {
    final targets = state.selectedContacts;
    var failCount = 0;
    for (final contact in targets) {
      final ok = await sendMsg(contact, msg);
      if (!ok) failCount++;
    }
    return failCount;
  }

  /// 搜索
  void search(String query) {
    final results = query.isEmpty
        ? List<ConversationModel>.from(state.conversations)
        : state.conversations
              .where(
                (contact) =>
                    // 同 send_to_page：按 displayTitle 匹配。裸 title 对群会话
                    // 可能是空串，那样用户搜群名永远搜不出来。
                    contact.displayTitle.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();
    state = state.copyWith(searchResults: results);
  }

  /// 切换联系人选择
  void toggleContactSelection(ConversationModel contact) {
    final selected = List<ConversationModel>.from(state.selectedContacts);
    final exists = selected.any((element) => element.id == contact.id);
    if (exists) {
      selected.removeWhere((element) => element.id == contact.id);
    } else {
      selected.add(contact);
    }
    state = state.copyWith(selectedContacts: selected);
  }
}

/// 发送消息 Provider
final sendToProvider = NotifierProvider<SendToNotifier, SendToState>(
  SendToNotifier.new,
);
