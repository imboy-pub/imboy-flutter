import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/mine/user_collect/user_collect_logic.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/chat/message_status_indicator.dart';
import 'package:xid/xid.dart';

/// 消息处理相关的Mixin
/// 负责消息的发送、上传、状态管理等功能
mixin MessageHandlingMixin<T extends StatefulWidget> on State<T> {
  // 获取当前聊天页面逻辑对象
  ChatLogic get logic => getx.Get.find<ChatLogic>();
  
  // 获取当前会话逻辑对象
  ConversationLogic get conversationLogic => getx.Get.find<ConversationLogic>();
  
  // 获取当前用户信息
  User get currentUser => User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );
  
  // 获取当前会话对象
  ConversationModel get conversation => widget is MessageHandlingMixinState 
      ? (widget as MessageHandlingMixinState).conversation 
      : throw UnimplementedError('conversation must be provided');
  
  // 获取聊天类型
  String get chatType => widget is MessageHandlingMixinState 
      ? (widget as MessageHandlingMixinState).chatType 
      : throw UnimplementedError('chatType must be provided');
  
  // 获取对方ID
  String get peerId => widget is MessageHandlingMixinState 
      ? (widget as MessageHandlingMixinState).peerId 
      : throw UnimplementedError('peerId must be provided');
  
  // 获取对方头像
  String get peerAvatar => widget is MessageHandlingMixinState 
      ? (widget as MessageHandlingMixinState).peerAvatar 
      : throw UnimplementedError('peerAvatar must be provided');
  
  // 获取对方标题
  String get peerTitle => widget is MessageHandlingMixinState 
      ? (widget as MessageHandlingMixinState).peerTitle 
      : throw UnimplementedError('peerTitle must be provided');

  /// 标记消息为已读
  Future<void> markMessagesAsRead(List<Message> items) async {
    final unreadMsgIds = items
        .where(
          (msg) =>
              msg.authorId != UserRepoLocal.to.currentUid &&
              msg.status != MessageStatus.seen,
        )
        .map((msg) => msg.id)
        .toList();
    if (unreadMsgIds.isEmpty) {
      conversationLogic.recalculateConversationRemind(conversation);
    } else {
      await logic.markAsRead(chatType, peerId, unreadMsgIds);
    }
  }

  /// 添加消息
  Future<bool> addMessage(Message message) async {
    try {
      await logic.addMessage(
        UserRepoLocal.to.currentUid,
        peerId,
        peerAvatar,
        peerTitle,
        chatType == 'null' ? 'C2C' : chatType,
        message,
      );
      final chatController = logic.chatController;
      if (chatController != null) {
        await chatController.insertMessage(
          message,
          index: chatController.messages.length,
        );
      }
      return true;
    } catch (e, stack) {
      debugPrint("addMessage error: $e : $stack");
      return false;
    }
  }

  /// 消息重试回调
  Future<void> onMessageRetry(String messageId) async {
    try {
      debugPrint('开始重试消息: $messageId');
      
      // 显示加载状态
      EasyLoading.show(status: '正在重试发送...');
      
      final success = await logic.retryMessage(messageId, chatType);
      
      EasyLoading.dismiss();
      
      if (success) {
        EasyLoading.showSuccess('重试成功');
      } else {
        EasyLoading.showError('重试失败，请检查网络连接');
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('重试异常: $e');
      debugPrint('消息重试异常: $e');
    }
  }

  /// 转换消息状态
  MessageStatusType convertMessageStatus(MessageStatus? status) {
    if (status == null) return MessageStatusType.sending;
    
    // 根据 flutter_chat_core 的 MessageStatus 转换为本地的 MessageStatusType
    switch (status) {
      case MessageStatus.sending:
        return MessageStatusType.sending;
      case MessageStatus.sent:
        return MessageStatusType.sent;
      case MessageStatus.delivered:
        return MessageStatusType.delivered;
      case MessageStatus.seen:
        return MessageStatusType.seen;
      case MessageStatus.error:
        return MessageStatusType.failed;
      default:
        return MessageStatusType.sending;
    }
  }

  /// 发送文本消息
  Future<bool> sendTextMessage(String text) async {
    final textMessage = TextMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      text: text,
      metadata: {'peer_id': peerId},
    );
    return await addMessage(textMessage);
  }

  /// 发送引用消息
  Future<bool> sendQuoteMessage(String text, Message? quoteMessage) async {
    if (quoteMessage == null) return false;
    
    String quoteMsgAuthorName = quoteMessage.authorId == peerId
        ? peerTitle
        : UserRepoLocal.to.current.nickname;
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: {
        'custom_type': 'quote',
        'peer_id': peerId,
        'quote_msg': quoteMessage.toJson(),
        'quote_msg_author_name': quoteMsgAuthorName,
        'quote_text': text,
      },
    );
    bool res = await addMessage(message);
    if (res) {
      // 清除引用消息
      if (widget is MessageHandlingMixinState) {
        (widget as MessageHandlingMixinState).updateQuoteMessage?.call(null);
      }
    }
    return res;
  }

  /// 处理发送文本消息
  Future<bool> handleSendPressed(String text, {Message? quoteMessage}) async {
    iPrint('handleSendPressed: $text');
    if (quoteMessage == null) {
      return await sendTextMessage(text);
    } else {
      return await sendQuoteMessage(text, quoteMessage);
    }
  }

  /// 消息状态点击事件
  void onMessageStatusTap(BuildContext ctx, Message msg) {
    if (msg.status != MessageStatus.sent && msg.status != MessageStatus.sending) {
      return;
    }
    int diff =
        DateTimeHelper.millisecond() - msg.createdAt!.millisecondsSinceEpoch;
    if (diff > 1000) {
      logic.sendWsMsg(logic.getMsgFromTMsg(chatType, conversation.uk3, msg));
    }
  }

  /// 删除消息(仅自己)
  Future<void> deleteMessageForMe(
      BuildContext context,
      Message msg, {
        bool pop = true,
      }) async {
    iPrint('deleteMessageForMe - 开始删除消息(仅自己): ${msg.id}, 聊天类型: $chatType');
    try {
      EasyLoading.show(status: '正在删除...');

      // 发送删除通知（群聊需要通知服务器）
      if (chatType == 'C2G') {
        await sendDeleteForMeMessage(msg);
      }

      // 从本地删除消息
      iPrint('deleteMessageForMe - 开始从本地删除消息: ${msg.id}');
      bool res = await logic.removeMessage(conversation, msg);
      iPrint('deleteMessageForMe - 数据库删除结果: $res, 消息ID: ${msg.id}');
      
      if (res) {
        // UI移除已在logic.removeMessage中完成
        iPrint('deleteMessageForMe - 删除完成: ${msg.id}');
        EasyLoading.showSuccess('删除成功');
      } else {
        iPrint('deleteMessageForMe - 删除失败: ${msg.id}');
        EasyLoading.showError('删除失败，请重试');
      }

    } catch (e, stack) {
      iPrint('deleteMessageForMe - 删除消息异常: $e\n$stack');
      EasyLoading.showError('删除操作异常，请重试');
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 发送删除消息请求(仅自己)
  Future<void> sendDeleteForMeMessage(Message msg) async {
    try {
      final msg2 = {
        'id': Xid().toString(),
        'from': msg.authorId,
        'to': msg.metadata?['peer_id'],
        'type': 'S2C',
        'payload': {
          'old_msg_id': msg.id,
          'to': msg.metadata?['peer_id'],
          'msg_type': '${chatType}_DEL_FOR_ME',
        },
        'created_at': DateTimeHelper.millisecond(),
      };
      await logic.sendMessage(msg2);
    } catch (e) {
      iPrint('发送删除消息通知失败: $e');
    }
  }

  /// 删除消息(所有人)
  Future<void> deleteMessageForEveryone(
      BuildContext context,
      Message msg,
      ) async {
    try {
      EasyLoading.show(status: '正在删除...');

      // 发送删除通知
      final msg2 = {
        'id': Xid().toString(),
        'from': msg.authorId,
        'to': msg.metadata?['peer_id'],
        'type': 'S2C',
        'payload': {
          'old_msg_id': msg.id,
          'to': msg.metadata?['peer_id'],
          'msg_type': '${chatType}_DEL_EVERYONE',
        },
        'created_at': DateTimeHelper.millisecond(),
      };

      bool sendResult = await logic.sendMessage(msg2);
      iPrint('deleteMessageForEveryone - 发送删除通知结果: $sendResult, 消息ID: ${msg.id}');

      if (sendResult) {
        // 从本地删除消息
        bool res = await logic.removeMessage(conversation, msg);
        iPrint('deleteMessageForEveryone - 数据库删除结果: $res, 消息ID: ${msg.id}');
        
        if (res) {// UI移除已在logic.removeMessage中完成
          iPrint('deleteMessageForEveryone - 删除完成: ${msg.id}');
          EasyLoading.showSuccess('删除成功');
        } else {
          EasyLoading.showError('本地删除失败，请重试');
        }
      } else {
        // 即使发送失败，也询问用户是否仅删除本地消息
        if (context.mounted) {
          _showDeleteLocalOnlyDialog(context, msg);
        } else {
          EasyLoading.showError('删除失败，请检查网络连接');
        }
      }
    } catch (e, stack) {
      iPrint('删除消息异常: $e\n$stack');
      EasyLoading.showError('删除操作异常，请重试');
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 显示仅删除本地消息的对话框
  void _showDeleteLocalOnlyDialog(BuildContext context, Message msg) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除失败'),
          content: const Text('网络连接失败，是否仅删除本地消息？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('仅删除本地'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteLocalMessageOnly(context, msg);
              },
            ),
          ],
        );
      },
    );
  }

  /// 仅删除本地消息
  Future<void> _deleteLocalMessageOnly(BuildContext context, Message msg) async {
    try {
      EasyLoading.show(status: '正在删除本地消息...');
      
      // 从本地删除消息
      bool res = await logic.removeMessage(conversation, msg);
      iPrint('_deleteLocalMessageOnly - 数据库删除结果: $res, 消息ID: ${msg.id}');
      
      if (res) {
        // UI移除已在logic.removeMessage中完成
        iPrint('_deleteLocalMessageOnly - 删除完成: ${msg.id}');
        EasyLoading.showSuccess('本地删除成功');
      } else {
        EasyLoading.showError('本地删除失败');
      }
    } catch (e, stack) {
      iPrint('仅删除本地消息异常: $e\n$stack');
      EasyLoading.showError('删除操作异常，请重试');
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 复制消息文本
  void copyMessageText(TextMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    EasyLoading.showToast('copied'.tr);
  }

  /// 保存消息内容
  Future<void> saveMessageContent(Message msg) async {
    if (msg is CustomMessage) {
      await logic.saveFile(msg.metadata!['md5'], msg.metadata!['uri']);
    } else if (msg is ImageMessage) {
      await logic.saveFile(msg.text ?? Xid().toString(), msg.source);
    } else if (msg is FileMessage) {
      await logic.saveFile(msg.name, msg.source);
    }
  }

  /// 收藏消息
  Future<void> collectMessage(Message msg) async {
    debugPrint("collectMessage: 开始收藏消息 ${msg.id}, 类型: ${msg.runtimeType}");
    
    String tb = MessageRepo.getTableName(chatType);
    debugPrint("collectMessage: 获取表名: $tb");
    
    final collectLogic = UserCollectLogic();
    bool res = await collectLogic.add(tb: tb, msg: msg);
    
    debugPrint("collectMessage: 收藏结果: $res");
    
    EasyLoading.showToast(
      res ? 'collected'.tr : 'operationFailedAgainLater'.tr,
    );
  }

  /// 撤回消息（使用新的action机制）
  Future<void> revokeMessage(Message msg) async {
    try {
      iPrint('=== 开始撤回消息流程（新action机制） ===');
      EasyLoading.show(status: '正在撤回...');

      // 参数验证
      if (msg.id.isEmpty) {
        throw Exception('消息ID为空，无法撤回');
      }

      iPrint('🔍 撤回消息追踪: 使用新的action机制');
      iPrint('🔍 消息ID: ${msg.id}');
      iPrint('🔍 聊天类型: $chatType');

      // 使用新的MessageService发送撤回请求
      bool result = await MessageService.to.sendRevokeMessage(msg.id, chatType);
      iPrint('🔍 撤回消息发送结果: $result');

      if (result) {
        EasyLoading.dismiss();
        iPrint('=== 撤回请求发送完成 ===');

        // 确保UI更新完成后再显示成功提示
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          EasyLoading.showSuccess('撤回成功');
        }
      } else {
        EasyLoading.dismiss();
        EasyLoading.showError('撤回失败，请检查网络连接');
      }
    } catch (e, stack) {
      iPrint('撤回消息异常: $e\n$stack');
      EasyLoading.dismiss();
      EasyLoading.showError('撤回操作异常，请重试');
    }
  }

  /// 更新消息为撤回状态
  Future<void> _updateMessageAsRevoked(Message originalMessage) async {
    try {
      // 保存原始消息内容（如果是文本消息）
      final originalText = (originalMessage is TextMessage) ? originalMessage.text : '';
      
      // 构建新的payload
      final newPayload = <String, dynamic>{
        'msg_type': 'custom',
        'custom_type': 'my_revoked',
        'text': originalText, // 保留原始文本内容
        'original_type': originalMessage.runtimeType.toString(),
        'revoke_time': DateTimeHelper.millisecond(),
        'revoke_user': UserRepoLocal.to.currentUid,
      };

      // 更新数据库中的消息状态
      final tb = MessageRepo.getTableName(chatType);
      final repo = MessageRepo(tableName: tb);

      final updateResult = await repo.update({
        'id': originalMessage.id,
        'payload': json.encode(newPayload),
        'status': IMBoyMessageStatus.sent, // 使用标准状态值
      });

      iPrint('数据库更新结果: $updateResult, 消息ID: ${originalMessage.id}');

      // 重新获取更新后的消息
      final updatedMsg = await repo.find(originalMessage.id);
      if (updatedMsg != null) {
        iPrint('重新获取更新后的消息成功: ${updatedMsg.toJson()}');
        
        final updatedMessage = await updatedMsg.toTypeMessage();
        iPrint('my_revoked消息转换结果: ${updatedMessage.runtimeType}');
        
        // 更新UI中的消息
        if (mounted) {
          try {
            final chatController = logic.chatController;
            if (chatController != null) {
              final index = chatController.messages.indexWhere((e) => e.id == originalMessage.id);
              if (index > -1) {
                iPrint('更新UI撤回消息: ${originalMessage.id}');
                chatController.updateMessage(
                  chatController.messages[index],
                  updatedMessage
                );
              } else {
                iPrint('未在当前消息列表中找到要撤回的消息: ${originalMessage.id}');
              }
            }
          } catch (e, stack) {
            iPrint('更新UI消息异常: $e\n$stack');
          }
        }
        
        // 更新会话状态（如果撤回的是最后一条消息）
        if (conversation.lastMsgId == originalMessage.id) {
          iPrint('更新会话状态: ${originalMessage.id} 是会话的最后一条消息');
          // 使用ChatLogic中的方法更新会话
          await logic.updateConversationAfterRevoke(conversation, updatedMessage, 'my_revoked');
        }
      }

      iPrint('本地消息撤回状态更新完成: ${originalMessage.id}');
    } catch (e, stack) {
      iPrint('更新消息撤回状态失败: $e\n$stack');
      // 即使更新失败也不影响主要功能
    }
  }

  /// 转发消息
  void forwardMessage(Message msg) {
    getx.Get.bottomSheet(
      backgroundColor: getx.Get.isDarkMode
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      // 替换 n.Padding
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: _getSendToPage(msg),
      ),
      isScrollControlled: true,
    );
  }

  /// 获取发送到页面
  Widget _getSendToPage(Message msg) {
    // 动态导入避免循环依赖
    // 这里需要根据实际情况调整
    return Container(); // 临时返回空容器
  }

  /// 发送收藏消息
  Future<void> sendCollectMessage(UserCollectModel collect) async {
    final data = collect.info
      ..addAll({
        MessageRepo.id: Xid().toString(),
        MessageRepo.from: UserRepoLocal.to.currentUid,
        MessageRepo.to: peerId,
        MessageRepo.status: 10,
        MessageRepo.conversationUk3: conversation.uk3,
        MessageRepo.createdAt: DateTimeHelper.millisecond(),
      });
    final msg = await MessageModel.fromJson(data).toTypeMessage();
    final res = await addMessage(msg);
    if (res) {
      getx.Get.find<UserCollectLogic>().change(collect.kindId);
      EasyLoading.showSuccess('tipSuccess'.tr);
    } else {
      EasyLoading.showError('tipFailed'.tr);
    }
  }

  /// 发送个人名片消息
  Future<void> sendVisitCardMessage(dynamic contact) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: {
        'custom_type': 'visit_card',
        'peer_id': peerId,
        'uid': contact.peerId,
        'title': contact.title,
        'avatar': contact.avatar,
      },
    );
    final res = await addMessage(message);
    if (res) {
      EasyLoading.showSuccess('tipSuccess'.tr);
    } else {
      EasyLoading.showError('tipFailed'.tr);
    }
  }

  /// 编辑消息（使用新的action机制）
  Future<void> editMessage(Message msg, String newContent) async {
    try {
      iPrint('=== 开始编辑消息流程（新action机制） ===');
      EasyLoading.show(status: '正在编辑...');

      // 参数验证
      if (msg.id.isEmpty) {
        throw Exception('消息ID为空，无法编辑');
      }

      if (newContent.trim().isEmpty) {
        throw Exception('编辑内容不能为空');
      }

      iPrint('🔍 编辑消息追踪: 使用新的action机制');
      iPrint('🔍 消息ID: ${msg.id}');
      iPrint('🔍 聊天类型: $chatType');
      iPrint('🔍 新内容: $newContent');

      // 使用新的MessageService发送编辑请求
      bool result = await MessageService.to.sendEditMessage(msg.id, chatType, newContent.trim());
      iPrint('🔍 编辑消息发送结果: $result');

      if (result) {
        EasyLoading.dismiss();
        iPrint('=== 编辑请求发送完成 ===');

        // 确保UI更新完成后再显示成功提示
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          EasyLoading.showSuccess('编辑成功');
        }
      } else {
        EasyLoading.dismiss();
        EasyLoading.showError('编辑失败，请检查网络连接');
      }
    } catch (e, stack) {
      iPrint('编辑消息异常: $e\n$stack');
      EasyLoading.dismiss();
      EasyLoading.showError('编辑操作异常，请重试');
    }
  }

  /// 检查消息是否可以编辑
  bool canEditMessage(Message message) {
    if (message.authorId != UserRepoLocal.to.currentUid) return false;
    if (message is! TextMessage) return false;
    
    // 检查时间限制（15分钟内可编辑，与后端保持一致）
    final now = DateTime.now();
    final messageTime = message.createdAt ?? now;
    final timeDiff = now.difference(messageTime);
    
    return timeDiff.inMinutes < 15;
  }

  /// 检查消息是否可以保存
  bool canSaveMessage(Message message) {
    if (message is ImageMessage) {
      return true;
    } else if (message is FileMessage) {
      return true;
    } else if (message is CustomMessage) {
      final customType = message.metadata?['custom_type'] ?? '';
      return customType == 'video' || customType == 'audio';
    }
    return false;
  }

  /// 检查消息是否可以收藏
  bool canCollectMessage(Message message) {
    return UserCollectLogic.getCollectKind(message) > 0;
  }
}

/// 消息处理Mixin状态接口
/// 用于提供必要的状态信息给MessageHandlingMixin
abstract class MessageHandlingMixinState {
  ConversationModel get conversation;
  String get chatType;
  String get peerId;
  String get peerAvatar;
  String get peerTitle;
  void Function(Message?)? get updateQuoteMessage;
}