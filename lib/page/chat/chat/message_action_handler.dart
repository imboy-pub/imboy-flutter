/// 聊天消息操作处理器
///
/// 负责处理消息的各种操作（编辑、删除、复制、收藏、转发等）
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/page/chat/chat/message_revoke_policy.dart';
import 'package:imboy/page/chat/send_to/send_to_page.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';

/// 消息操作处理器
///
/// 封装消息的编辑、删除、复制、收藏、转发等操作逻辑
class MessageActionHandler {
  /// 构造函数
  const MessageActionHandler({
    required this.type,
    required this.peerId,
    required this.conversation,
    required this.ref,
    required this.chatInputKey,
    required this.onEditingMessageIdChanged,
  });

  /// 聊天类型 [C2C | C2G | C2S]
  final String type;

  /// 对方 ID
  final String peerId;

  /// 当前会话
  final ConversationModel conversation;

  /// Riverpod WidgetRef
  final WidgetRef ref;

  /// 聊天输入框的 GlobalKey
  final GlobalKey<ChatInputState> chatInputKey;

  /// 编辑消息ID变更回调
  final void Function(String?) onEditingMessageIdChanged;

  /// 获取归一化后的聊天类型，非法值统一回落到 C2C
  String get _chatType => MessageFlowType.normalize(type);

  /// 编辑消息
  Future<void> editMessage(Message message) async {
    if (message is TextMessage) {
      iPrint(
        '✅ editMessage 被调用: messageId=${message.id}, text="${message.text}"',
      );

      // 通知父组件更新编辑状态
      onEditingMessageIdChanged(message.id);

      iPrint('✅ _editingMessageId 已设置为: ${message.id}');

      // 将消息文本填充到输入框
      chatInputKey.currentState?.setText(message.text);

      // 聚焦输入框
      chatInputKey.currentState?.inputFocusNode.requestFocus();

      iPrint('✅ editMessage 完成');
    }
  }

  /// 添加消息反应
  Future<void> addReaction(
    BuildContext context,
    Message message,
    String emoji,
  ) async {
    try {
      // ignore: deprecated_member_use
      HapticFeedback.lightImpact();
      final res = await ref
          .read(chatProvider.notifier)
          .toggleReaction(
            chatType: _chatType,
            peerId: peerId,
            messageId: message.id,
            emoji: emoji,
          );
      if (!context.mounted) return;
      if (res == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res ? '${t.reactionAdded} $emoji' : '${t.reactionCancelled} $emoji',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[MessageActionHandler] action failed: $e');
    }
  }

  /// 删除消息（仅自己）
  Future<void> deleteMessageForMe(
    BuildContext context,
    Message msg, {
    bool pop = true,
  }) async {
    final nav = Navigator.of(context);
    if (_chatType == MessageFlowType.c2g) {
      await _sendDeleteForMeMessage(msg);
    }
    bool res = await ref
        .read(chatProvider.notifier)
        .removeMessage(conversation, msg);
    if (res) {
      await ref
          .read(chatProvider.notifier)
          .chatService
          ?.removeMessageById(msg.id);
    }
    if (pop && nav.mounted) {
      nav.pop();
    }
  }

  /// 发送删除消息请求（仅自己）
  Future<void> _sendDeleteForMeMessage(Message msg) async {
    final msg2 = {
      'id': Xid().toString(),
      'from': UserRepoLocal.to.currentUid,
      'to': msg.metadata?['peer_id'],
      'type': 'S2C',
      'payload': {
        'old_msg_id': msg.id,
        'to': msg.metadata?['peer_id'],
        'msg_type': '${_chatType}_DEL_FOR_ME',
      },
      'created_at': DateTimeHelper.millisecond(),
    };
    await ref.read(chatProvider.notifier).sendMessage(msg2);
  }

  /// 删除消息（所有人）- 使用 message_revoke action
  Future<void> deleteMessageForEveryone(
    BuildContext context,
    Message msg,
  ) async {
    final nav = Navigator.of(context);
    final currentUid = UserRepoLocal.to.currentUid;

    // WebSocket API v2.0: 使用 message_revoke action 撤回消息
    final revokeMsg = {
      'id': Xid().toString(),
      'type': _chatType, // C2C, C2G, etc.
      'from': currentUid,
      'to': msg.metadata?['peer_id'],
      // v2.0: 字段提升到顶层
      'msg_type': 'custom',
      'action': 'message_revoke',
      'e2ee': '',
      'payload': {'original_msg_id': msg.id},
      'created_at': DateTimeHelper.millisecond(),
    };

    iPrint('🔄 发送撤回消息请求 (deleteMessageForEveryone): ${json.encode(revokeMsg)}');

    // 发送撤回消息
    await ref.read(chatProvider.notifier).sendMessage(revokeMsg);

    // 从本地删除消息
    bool res = await ref
        .read(chatProvider.notifier)
        .removeMessage(conversation, msg);
    if (res) {
      await ref
          .read(chatProvider.notifier)
          .chatService
          ?.removeMessageById(msg.id);
    }
    if (nav.mounted) {
      nav.pop();
    }
  }

  /// 复制消息文本
  void copyMessageText(TextMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    EasyLoading.showToast(t.copied);
  }

  /// 保存消息内容
  Future<void> saveMessageContent(Message msg) async {
    if (msg is CustomMessage) {
      await ref
          .read(chatProvider.notifier)
          .saveFile(msg.metadata!['md5'], msg.metadata!['uri']);
    } else if (msg is ImageMessage) {
      await ref
          .read(chatProvider.notifier)
          .saveFile(msg.text ?? Xid().toString(), msg.source);
    } else if (msg is FileMessage) {
      await ref.read(chatProvider.notifier).saveFile(msg.name, msg.source);
    }
  }

  /// 收藏消息
  Future<void> collectMessage(Message msg) async {
    String tb = MessageRepo.getTableName(_chatType);
    final collectNotifier = UserCollectNotifier();
    bool res = await collectNotifier.add(tb: tb, msg: msg);
    EasyLoading.showToast(res ? t.collected : t.operationFailedAgainLater);
  }

  /// 撤回消息
  Future<void> revokeMessage(Message msg) async {
    // S1: 前端 2 分钟窗口短路。超期消息不必走一轮网络，给即时 UX 反馈。
    final createdAtMs = msg.createdAt?.millisecondsSinceEpoch ?? 0;
    if (!canRevokeMessage(
      createdAtMs: createdAtMs,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    )) {
      EasyLoading.showError(t.revokeExpired);
      return;
    }

    try {
      // 显示加载状态
      EasyLoading.show(status: t.revoking);

      iPrint('🔍 撤回消息: msgId=${msg.id}, type=$_chatType');

      // 通过 messaging module 公共边界发送撤回动作。
      bool result = await MessagingFacade.instance.sendRevokeMessage(
        msg.id,
        _chatType,
      );
      iPrint('🔍 撤回消息发送结果: $result');

      EasyLoading.dismiss();

      if (result) {
        EasyLoading.showSuccess(t.revokeSuccess);
        iPrint('🔍 撤回请求发送完成，等待服务端确认');
      } else {
        EasyLoading.showError(
          '${t.revokeFailed}, ${t.pleaseCheckNetworkConnection}',
        );
      }
    } catch (e, stack) {
      EasyLoading.dismiss();
      EasyLoading.showError(t.operationFailedAgainLater);
      debugPrint('撤回消息异常: $e\n$stack');
    }
  }

  /// 转发消息
  void forwardMessage(BuildContext context, Message msg) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SendToPage(msg: msg),
      ),
    );
  }
}
