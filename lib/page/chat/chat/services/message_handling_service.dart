import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:logger/logger.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:xid/xid.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

// 日志记录器
final _msgLogger = Logger(printer: PrettyPrinter(methodCount: 0));

/// 消息处理服务
///
/// 负责消息的发送、上传、状态管理等功能
/// 从 MessageHandlingMixin 迁移而来，改为独立的 Service 类
///
/// 注意：这个 Service 是无状态的纯逻辑服务，不依赖任何 Provider
/// 所有需要的状态（如 ref、conversation）都通过方法参数传递
class MessageHandlingService {
  const MessageHandlingService();

  // ===== 辅助方法：获取上下文信息 =====

  /// 获取当前用户信息
  User getCurrentUser() {
    return User(
      id: UserRepoLocal.to.currentUid,
      name: UserRepoLocal.to.current.nickname,
      imageSource: UserRepoLocal.to.current.avatar,
    );
  }

  // ===== 消息发送相关方法 =====

  /// 发送文本消息
  /// 注意：这个方法只创建消息对象，实际的发送由调用者处理
  Future<TextMessage> createTextMessage({
    required String peerId,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = getCurrentUser();
    return TextMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      text: text,
      metadata: {'peer_id': peerId, ...?metadata},
    );
  }

  /// 发送引用消息
  /// 注意：这个方法只创建消息对象，实际的发送由调用者处理
  Future<CustomMessage> createQuoteMessage({
    required String peerId,
    required String peerTitle,
    required String text,
    required Message? quoteMessage,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    if (quoteMessage == null) {
      throw ArgumentError('quoteMessage cannot be null');
    }

    final currentUser = getCurrentUser();
    String quoteMsgAuthorName = quoteMessage.authorId == peerId
        ? peerTitle
        : UserRepoLocal.to.current.nickname;

    final metadata = {
      'msg_type': 'quote',
      'peer_id': peerId,
      'quote_msg': quoteMessage.toJson(),
      'quote_msg_author_name': quoteMsgAuthorName,
      'quote_text': text,
      ...?additionalMetadata,
    };

    return CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: metadata,
    );
  }

  // ===== 消息重试相关方法 =====

  /// 消息重试回调
  /// 注意：这个方法需要调用者传入重试函数
  Future<void> onMessageRetry({
    required String messageId,
    required String chatType,
    required Future<bool> Function(String messageId, String chatType) retryFn,
  }) async {
    try {
      _msgLogger.d('开始重试消息: $messageId');

      // 显示加载状态
      EasyLoading.show(status: t.common.retryingSend);

      final success = await retryFn(messageId, chatType);

      EasyLoading.dismiss();

      if (success) {
        EasyLoading.showSuccess(t.common.retrySuccess);
      } else {
        EasyLoading.showError(t.common.retryFailedPleaseCheckNetwork);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('${t.common.retryAbnormal}: $e');
      _msgLogger.e('消息重试异常: $e');
    }
  }

  // ===== 消息删除相关方法 =====

  /// 删除消息(仅自己)
  /// 注意：这个方法需要调用者传入删除函数
  Future<void> deleteMessageForMe(
    BuildContext context,
    ConversationModel conversation,
    Message msg, {
    required Future<bool> Function(ConversationModel, Message) deleteFn,
    bool pop = true,
  }) async {
    iPrint(
      'deleteMessageForMe - 开始删除消息(仅自己): ${msg.id}, 聊天类型: ${conversation.type}',
    );
    try {
      EasyLoading.show(status: t.chat.deletingMessage);

      // 群聊通知由调用方 MessageActionHandler.deleteMessageForMe 处理
      // （判断 c2g 类型后调用 _sendDeleteForMeMessage），此方法只负责本地删除
      // 从本地删除消息
      iPrint('deleteMessageForMe - 开始从本地删除消息: ${msg.id}');
      bool res = await deleteFn(conversation, msg);
      iPrint('deleteMessageForMe - 数据库删除结果: $res, 消息ID: ${msg.id}');

      if (res) {
        iPrint('deleteMessageForMe - 删除完成: ${msg.id}');
        EasyLoading.showSuccess(t.common.deleteSuccess);
      } else {
        iPrint('deleteMessageForMe - 删除失败: ${msg.id}');
        EasyLoading.showError(t.common.deleteFailedPleaseTryAgain);
      }
    } catch (e, stack) {
      iPrint('deleteMessageForMe - 删除消息异常: $e\n$stack');
      EasyLoading.showError(t.common.deleteOperationAbnormal);
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 发送删除消息请求(仅自己)
  /// 注意：这个方法需要调用者传入发送函数
  Future<void> sendDeleteForMeMessage({
    required ConversationModel conversation,
    required Message msg,
    required Future<bool> Function(Map<String, dynamic>) sendFn,
  }) async {
    try {
      final msg2 = {
        'id': Xid().toString(),
        'from': msg.authorId,
        'to': msg.metadata?['peer_id'],
        'type': 'S2C',
        'payload': {
          'old_msg_id': msg.id,
          'to': msg.metadata?['peer_id'],
          'msg_type': '${conversation.type}_DEL_FOR_ME',
        },
        'created_at': DateTimeHelper.millisecond(),
      };
      await sendFn(msg2);
    } catch (e) {
      iPrint('发送删除消息通知失败: $e');
    }
  }

  /// 删除消息(所有人)
  /// 注意：这个方法需要调用者传入删除和发送函数
  Future<void> deleteMessageForEveryone(
    BuildContext context,
    ConversationModel conversation,
    Message msg, {
    required Future<bool> Function(ConversationModel, Message) deleteFn,
    required Future<bool> Function(Map<String, dynamic>) sendFn,
  }) async {
    try {
      EasyLoading.show(status: t.chat.deletingMessage);

      // 发送删除通知
      final msg2 = {
        'id': Xid().toString(),
        'from': msg.authorId,
        'to': msg.metadata?['peer_id'],
        'type': 'S2C',
        'payload': {
          'old_msg_id': msg.id,
          'to': msg.metadata?['peer_id'],
          'msg_type': '${conversation.type}_DEL_EVERYONE',
        },
        'created_at': DateTimeHelper.millisecond(),
      };

      bool sendResult = await sendFn(msg2);
      iPrint(
        'deleteMessageForEveryone - 发送删除通知结果: $sendResult, 消息ID: ${msg.id}',
      );

      if (sendResult) {
        // 从本地删除消息
        bool res = await deleteFn(conversation, msg);
        iPrint('deleteMessageForEveryone - 数据库删除结果: $res, 消息ID: ${msg.id}');

        if (res) {
          iPrint('deleteMessageForEveryone - 删除完成: ${msg.id}');
          EasyLoading.showSuccess(t.common.deleteSuccess);
        } else {
          EasyLoading.showError(
            t.common.localDeleteFailed + t.chat.pleaseTryAgainLater,
          );
        }
      } else {
        // 即使发送失败，也询问用户是否仅删除本地消息
        if (context.mounted) {
          _showDeleteLocalOnlyDialog(context, conversation, msg, deleteFn);
        } else {
          EasyLoading.showError(t.common.deleteFailedPleaseCheckNetwork);
        }
      }
    } catch (e, stack) {
      iPrint('删除消息异常: $e\n$stack');
      EasyLoading.showError(t.common.deleteOperationAbnormal);
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 显示仅删除本地消息的对话框
  void _showDeleteLocalOnlyDialog(
    BuildContext context,
    ConversationModel conversation,
    Message msg,
    Future<bool> Function(ConversationModel, Message) deleteFn,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.common.chatDeleteFailed),
          content: Text(t.common.chatNetworkErrorDeleteLocal),
          actions: <Widget>[
            TextButton(
              child: Text(t.common.buttonCancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(t.common.chatDeleteLocalOnly),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteLocalMessageOnly(
                  context,
                  conversation,
                  msg,
                  deleteFn,
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// 仅删除本地消息
  Future<void> _deleteLocalMessageOnly(
    BuildContext context,
    ConversationModel conversation,
    Message msg,
    Future<bool> Function(ConversationModel, Message) deleteFn,
  ) async {
    try {
      EasyLoading.show(status: t.chat.deletingLocalMessage);

      // 从本地删除消息
      bool res = await deleteFn(conversation, msg);
      iPrint('_deleteLocalMessageOnly - 数据库删除结果: $res, 消息ID: ${msg.id}');

      if (res) {
        iPrint('_deleteLocalMessageOnly - 删除完成: ${msg.id}');
        EasyLoading.showSuccess(t.common.localDeleteSuccess);
      } else {
        EasyLoading.showError(t.common.localDeleteFailed);
      }
    } catch (e, stack) {
      iPrint('仅删除本地消息异常: $e\n$stack');
      EasyLoading.showError(t.common.deleteOperationAbnormal);
    } finally {
      EasyLoading.dismiss();
    }
  }

  // ===== 消息操作相关方法 =====

  /// 复制消息文本
  void copyMessageText(TextMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    EasyLoading.showToast(t.main.copied);
  }

  /// 保存消息内容
  /// 注意：这个方法需要调用者传入保存函数
  Future<void> saveMessageContent(
    Message msg, {
    required Future<void> Function(String, String) saveFileFn,
  }) async {
    if (msg is CustomMessage) {
      await saveFileFn(
        msg.metadata!['md5'] as String,
        msg.metadata!['uri'] as String,
      );
    } else if (msg is ImageMessage) {
      await saveFileFn(msg.text ?? Xid().toString(), msg.source);
    } else if (msg is FileMessage) {
      await saveFileFn(msg.name, msg.source);
    }
  }

  /// 收藏消息
  Future<void> collectMessage(String chatType, Message msg) async {
    _msgLogger.d("collectMessage: 开始收藏消息 ${msg.id}, 类型: ${msg.runtimeType}");

    String tb = MessageRepo.getTableName(chatType);
    _msgLogger.d("collectMessage: 获取表名: $tb");

    bool res = await UserCollectHelper.add(tb: tb, msg: msg);

    _msgLogger.d("collectMessage: 收藏结果: $res");

    EasyLoading.showToast(
      res ? t.main.collected : t.common.operationFailedAgainLater,
    );
  }

  /// 撤回消息（使用新的action机制）
  Future<void> revokeMessage(String chatType, Message msg) async {
    try {
      iPrint('${t.common.startRevokeMessageFlow} (新action机制)');
      EasyLoading.show(status: t.common.revoking);

      // 参数验证
      if (msg.id.isEmpty) {
        throw Exception(t.common.messageIdCannotBeEmpty);
      }

      iPrint(
        '🔍 ${t.common.revokeMessageTracking}: ${t.common.useNewActionMechanism}',
      );
      iPrint('🔍 ${t.chat.messageId}: ${msg.id}');
      iPrint('🔍 ${t.chat.chatType}: $chatType');

      // 通过 messaging module 公共边界发送撤回请求。
      bool result = await MessagingFacade.instance.sendRevokeMessage(
        msg.id,
        chatType,
      );
      iPrint('🔍 ${t.common.revokeMessageSendResult}: $result');

      if (result) {
        EasyLoading.dismiss();
        iPrint('=== ${t.common.revokeRequestSendComplete} ===');

        // 确保UI更新完成后再显示成功提示
        await Future<dynamic>.delayed(const Duration(milliseconds: 300));
        EasyLoading.showSuccess(t.common.revokeSuccess);
      } else {
        EasyLoading.dismiss();
        EasyLoading.showError(
          '${t.common.revokeFailed}, ${t.common.pleaseCheckNetworkConnection}',
        );
      }
    } catch (e, stack) {
      iPrint('${t.common.revokeMessageException}: $e\n$stack');
      EasyLoading.dismiss();
      EasyLoading.showError(
        '${t.common.revokeOperationAbnormal}, ${t.main.pleaseTryAgain}',
      );
    }
  }

  /// 编辑消息（使用新的action机制）
  Future<void> editMessage(
    String chatType,
    Message msg,
    String newContent,
  ) async {
    try {
      iPrint('${t.common.startEditMessageFlow} (新action机制)');
      EasyLoading.show(status: t.common.editing);

      // 参数验证
      if (msg.id.isEmpty) {
        throw Exception(t.common.messageIdCannotBeEmpty);
      }

      if (newContent.trim().isEmpty) {
        throw Exception(t.common.editContentCannotBeEmpty);
      }

      iPrint(
        '🔍 ${t.common.editMessageTracking}: ${t.common.useNewActionMechanism}',
      );
      iPrint('🔍 ${t.chat.messageId}: ${msg.id}');
      iPrint('🔍 ${t.chat.chatType}: $chatType');
      iPrint('🔍 ${t.common.newContent}: $newContent');

      // 通过 messaging module 公共边界发送编辑请求。
      bool result = await MessagingFacade.instance.sendEditMessage(
        msg.id,
        chatType,
        newContent.trim(),
      );
      iPrint('🔍 ${t.common.editMessageSendResult}: $result');

      if (result) {
        EasyLoading.dismiss();
        iPrint('=== ${t.common.editRequestSendComplete} ===');

        // 确保UI更新完成后再显示成功提示
        await Future<dynamic>.delayed(const Duration(milliseconds: 300));
        EasyLoading.showSuccess(t.common.editSuccess);
      } else {
        EasyLoading.dismiss();
        EasyLoading.showError(
          '${t.common.editFailed}, ${t.common.pleaseCheckNetworkConnection}',
        );
      }
    } catch (e, stack) {
      iPrint('${t.common.editMessageException}: $e\n$stack');
      EasyLoading.dismiss();
      EasyLoading.showError(
        '${t.common.editOperationAbnormal}, ${t.main.pleaseTryAgain}',
      );
    }
  }

  // ===== 消息检查相关方法 =====

  /// 检查消息是否可以保存
  bool canSaveMessage(Message message) {
    if (message is ImageMessage) {
      return true;
    } else if (message is FileMessage) {
      return true;
    } else if (message is CustomMessage) {
      final msgType = message.metadata?['msg_type'] ?? '';
      return msgType == MessageType.video || msgType == MessageType.voice;
    }
    return false;
  }

  /// 检查消息是否可以收藏
  bool canCollectMessage(Message message) {
    return UserCollectHelper.getCollectKind(message) > 0;
  }

  /// 发送收藏消息
  /// 注意：这个方法创建收藏消息对象，实际的发送由调用者处理
  Future<Message> createCollectMessage({
    required String peerId,
    required ConversationModel conversation,
    required UserCollectModel collect,
  }) async {
    final data = collect.info
      ..addAll({
        MessageRepo.id: Xid().toString(),
        MessageRepo.from: UserRepoLocal.to.currentUid,
        MessageRepo.to: peerId,
        MessageRepo.status: 10,
        MessageRepo.conversationUk3: conversation.uk3,
        MessageRepo.createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
      });
    final msg = await MessageModel.fromJson(data).toTypeMessage();
    return msg;
  }

  /// 发送个人名片消息
  /// 注意：这个方法创建名片消息对象，实际的发送由调用者处理
  Future<CustomMessage> createVisitCardMessage({
    required String peerId,
    required Map<String, dynamic> contact,
  }) async {
    final currentUser = getCurrentUser();
    return CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: {
        'msg_type': 'visitCard',
        'peer_id': peerId,
        'uid': contact['peerId'],
        'title': contact['title'],
        'avatar': contact['avatar'],
      },
    );
  }
}
