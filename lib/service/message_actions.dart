import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';
import 'package:imboy/service/message.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// MessageActions
/// 消息操作功能，包含撤回、编辑等操作
/// Message operations including revoke, edit, etc.
class MessageActions extends GetxService {
  static MessageActions get to => Get.find();

  final MessageRetry _messageRetry = MessageRetry.to;
  // 缓存常用仓库实例，避免重复 new。
  // Cache repository instances to avoid repeated instantiation.
  final ConversationRepo _conversationRepo = ConversationRepo();
  final ContactRepo _contactRepo = ContactRepo();

  @override
  void onInit() {
    super.onInit();
    // 消息操作模块初始化
    // Message actions module initialization
  }

  /// Handle action-based messages
  /// 处理基于action的消息
  Future<void> handleActionMessage(String action, Map data) async {
    iPrint("🔄 处理action消息: action=$action, msgId=${data['id']}, type=${data['type']}");

    try {
      switch (action) {
        case 'message_read':
          await _handleReadAction(data);
          break;
        case 'message_reaction':
          await _handleReactionAction(data);
          break;
        case 'message_revoke':
          await _handleRevokeAction(data, isAck: false);
          break;
        case 'message_revoke_ack':
          await _handleRevokeAction(data, isAck: true);
          break;
        case 'message_edit':
          await _handleEditAction(data, isAck: false);
          break;
        case 'message_edit_ack':
          await _handleEditAction(data, isAck: true);
          break;
        default:
          iPrint('⚠️ [handleActionMessage] 未知的action类型: $action');
      }
    } catch (e, s) {
      iPrint('❌ [handleActionMessage] 处理action消息异常: action=$action, error=$e\nstacktrace=$s');
    }
  }

  Future<void> _handleReadAction(Map data) async {
    try {
      final msgType = data['type'] as String? ?? '';
      final msgId = data['id'] as String? ?? '';
      final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      final fromId = data['from'] as String? ?? '';
      final currentUid = UserRepoLocal.to.currentUid;

      if (fromId == currentUid) return;

      final idsRaw = payload['msg_ids'];
      final ids = idsRaw is List ? idsRaw.map((e) => e.toString()).toList() : <String>[];
      if (ids.isEmpty) {
        AppEventBus.fire(AckSendRequestedEvent(
          messageType: msgType,
          messageId: msgId,
        ));
        return;
      }

      final repo = MessageService.to.getMessageRepo(msgType);
      final updated = <Message>[];
      final chatLogic = Get.find<ChatLogic>();
      final conversationRepo = ConversationRepo();
      final nowMs = DateTimeHelper.millisecond();
      for (final id in ids) {
        // 发布状态更新事件
        AppEventBus.fire(MessageStatusUpdateRequestedEvent(
          messageId: id,
          messageType: msgType,
          newStatus: IMBoyMessageStatus.seen,
        ));
        // 注意：原代码使用了返回值，这里需要从 repo 重新获取
        final m = await repo.find(id);
        if (m != null && m.status == IMBoyMessageStatus.seen) {
          try {
            if (chatLogic.isBurnPayload(m.payload)) {
              final toId = m.toId ?? '';
              if (toId.isNotEmpty) {
                final conversation = await conversationRepo.findByPeerId(msgType, toId);
                if (conversation != null) {
                  await chatLogic.markBurnReadAt(conversation, id, readAtMs: nowMs);
                }
              }
            }
          } catch (e) {
            iPrint('⚠️ [_handleReadAction] 标记阅后即焚失败: msgId=$id, error=$e');
          }
          updated.add(await m.toTypeMessage());
        }
      }
      if (updated.isNotEmpty) {
        AppEventBus.fireData(updated);
      }

      AppEventBus.fire(AckSendRequestedEvent(
        messageType: msgType,
        messageId: msgId,
      ));
    } catch (e, s) {
      iPrint('❌ [_handleReadAction] 处理已读消息失败: error=$e\nstacktrace=$s');
    }
  }

  Future<void> _handleReactionAction(Map data) async {
    try {
      final msgType = data['type'] as String? ?? '';
      final msgId = data['id'] as String? ?? '';
      final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? {};

      final originalMsgId = payload['original_msg_id']?.toString() ?? '';
      final emoji = payload['emoji']?.toString() ?? '';
      final op = payload['op']?.toString() ?? '';
      final reactorId = payload['user_id']?.toString() ?? data['from']?.toString() ?? '';

      if (originalMsgId.isEmpty || emoji.isEmpty || reactorId.isEmpty) {
        AppEventBus.fire(AckSendRequestedEvent(
          messageType: msgType,
          messageId: msgId,
        ));
        return;
      }

      final repo = MessageService.to.getMessageRepo(msgType);
      final msg = await repo.find(originalMsgId);
      if (msg == null) {
        AppEventBus.fire(AckSendRequestedEvent(
          messageType: msgType,
          messageId: msgId,
        ));
        return;
      }

      final newPayload = Map<String, dynamic>.from(msg.payload);
      final reactionsRaw = newPayload['reactions'];
      final reactions = reactionsRaw is Map ? reactionsRaw.cast<String, dynamic>() : <String, dynamic>{};
      final usersRaw = reactions[emoji];
      final users = usersRaw is List ? usersRaw.map((e) => e.toString()).toList() : <String>[];

      if (op == 'remove') {
        users.removeWhere((e) => e == reactorId);
        if (users.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = users;
        }
      } else {
        if (!users.contains(reactorId)) {
          users.add(reactorId);
        }
        reactions[emoji] = users;
      }

      newPayload['reactions'] = reactions;
      await repo.update({
        'id': originalMsgId,
        'payload': json.encode(newPayload),
      });

      final updated = await repo.find(originalMsgId);
      if (updated != null) {
        AppEventBus.fireData([await updated.toTypeMessage()], 'List<Message>');
      }

      AppEventBus.fire(AckSendRequestedEvent(
        messageType: msgType,
        messageId: msgId,
      ));
    } catch (e, s) {
      iPrint('❌ [_handleReactionAction] 处理消息表情失败: error=$e\nstacktrace=$s');
    }
  }

  /// Handle revoke action messages
  /// 处理撤回action消息
  Future<void> _handleRevokeAction(Map data, {required bool isAck}) async {
    final msgType = data['type'] as String? ?? '';
    final msgId = data['id'] as String? ?? '';
    final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final originalMsgId = payload['original_msg_id'] as String? ?? '';
    
    iPrint("🔄 处理撤回action: isAck=$isAck, msgType=$msgType, msgId=$msgId, originalMsgId=$originalMsgId");
    
    if (isAck) {
      // 处理撤回确认
      await _processRevokeAck(data, originalMsgId);
    } else {
      // 处理撤回请求
      await _processRevokeRequest(data, originalMsgId);
    }
  }

  /// Process revoke acknowledgment
  /// 处理撤回确认
  Future<void> _processRevokeAck(Map data, String originalMsgId) async {
    final msgType = data['type'] as String? ?? '';
    final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final currentUid = UserRepoLocal.to.currentUid;

    // 【重要】从重试队列中移除撤回消息
    final revokeMsgId = data['id'] as String? ?? '';
    if (revokeMsgId.isNotEmpty && Get.isRegistered<MessageRetry>()) {
      AppEventBus.fire(RemoveFromRetryQueueRequestedEvent(
        messageId: revokeMsgId,
        messageType: msgType,
        reason: 'revoked',
      ));
      iPrint('✅ [REVOKE_ACK] 已从重试队列移除撤回消息: revokeMsgId=$revokeMsgId');
    }

    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);

    if (originalMsg == null) {
      iPrint('❌ 未找到要确认撤回的原始消息: originalMsgId=$originalMsgId');
      return;
    }

    // 检查是否是我们自己撤回的
    final isMyRevoke = originalMsg.fromId == currentUid;

    if (isMyRevoke) {
      // 自己撤回的确认
      final newPayload = Map<String, dynamic>.from(originalMsg.payload);
      newPayload['msg_type'] = 'custom';
      newPayload['custom_type'] = 'my_revoked';
      newPayload['revoked_at'] = payload['revoked_at'] ?? DateTimeHelper.millisecond();

      await repo.update({
        'id': originalMsgId,
        'payload': json.encode(newPayload),
        'status': IMBoyMessageStatus.sent,
      });

      final updatedMsg = await repo.find(originalMsgId);
      if (updatedMsg != null) {
        final updatedMessage = await updatedMsg.toTypeMessage();
        AppEventBus.fireData([updatedMessage], 'List<Message>');
        await _updateConversationAfterRevoke(updatedMsg, 'my_revoked');
      }
    } else {
      // 对方撤回的通知
      await _processPeerRevoke(originalMsg, repo, data);
    }

    // 发送ACK
    AppEventBus.fire(AckSendRequestedEvent(
      messageType: msgType,
      messageId: data['id'],
    ));
  }

  /// Process revoke request
  /// 处理撤回请求
  Future<void> _processRevokeRequest(Map data, String originalMsgId) async {
    final msgType = data['type'] as String? ?? '';
    final fromId = data['from'] as String? ?? '';
    final currentUid = UserRepoLocal.to.currentUid;
    
    // 只有消息接收者才需要处理撤回请求
    if (fromId == currentUid) {
      iPrint('🔄 这是自己发送的撤回请求，无需处理');
      return;
    }
    
    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);
    
    if (originalMsg == null) {
      iPrint('❌ 未找到要撤回的原始消息: originalMsgId=$originalMsgId');
      return;
    }
    
    // 处理对方撤回
    await _processPeerRevoke(originalMsg, repo, data);
    
    // 发送撤回确认
    final ackMessage = {
      'id': data['id'],
      'type': msgType,
      'from': currentUid,
      'to': fromId,
      'payload': {
        'msg_type': 'custom',
        'action': 'message_revoke_ack',
        'original_msg_id': originalMsgId,
        'revoked_at': DateTimeHelper.millisecond(),
      },
    };
    
    iPrint('🔄 发送撤回确认ACK: ${json.encode(ackMessage)}');
    AppEventBus.fire(WebSocketMessageSendRequestEvent(
      message: json.encode(ackMessage),
      messageId: data['id'],
    ));
  }

  /// Handle edit action messages
  /// 处理编辑action消息
  Future<void> _handleEditAction(Map data, {required bool isAck}) async {
    final msgType = data['type'] as String? ?? '';
    final msgId = data['id'] as String? ?? '';
    final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final originalMsgId = payload['original_msg_id'] as String? ?? '';
    final newContent = payload['content'] as String? ?? '';
    
    iPrint("🔄 处理编辑action: isAck=$isAck, msgType=$msgType, msgId=$msgId, originalMsgId=$originalMsgId");
    
    if (isAck) {
      // 处理编辑确认
      await _processEditAck(data, originalMsgId, newContent);
    } else {
      // 处理编辑请求
      await _processEditRequest(data, originalMsgId, newContent);
    }
  }

  /// Process edit acknowledgment
  /// 处理编辑确认
  Future<void> _processEditAck(Map data, String originalMsgId, String newContent) async {
    final msgType = data['type'] as String? ?? '';
    final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final currentUid = UserRepoLocal.to.currentUid;

    // 【重要】从重试队列中移除编辑消息
    final editMsgId = data['id'] as String? ?? '';
    if (editMsgId.isNotEmpty && Get.isRegistered<MessageRetry>()) {
      AppEventBus.fire(RemoveFromRetryQueueRequestedEvent(
        messageId: editMsgId,
        messageType: msgType,
        reason: 'edited',
      ));
      iPrint('✅ [EDIT_ACK] 已从重试队列移除编辑消息: editMsgId=$editMsgId');
    }

    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);

    if (originalMsg == null) {
      iPrint('❌ 未找到要确认编辑的原始消息: originalMsgId=$originalMsgId');
      return;
    }

    // 检查是否是我们自己编辑的
    final isMyEdit = originalMsg.fromId == currentUid;

    if (isMyEdit) {
      // 自己编辑的确认
      final newPayload = Map<String, dynamic>.from(originalMsg.payload);
      newPayload['text'] = newContent;
      newPayload['edited_at'] = payload['edited_at'] ?? DateTimeHelper.millisecond();
      newPayload['is_edited'] = true;

      await repo.update({
        'id': originalMsgId,
        'payload': json.encode(newPayload),
        'status': IMBoyMessageStatus.sent,
      });

      final updatedMsg = await repo.find(originalMsgId);
      if (updatedMsg != null) {
        final updatedMessage = await updatedMsg.toTypeMessage();
        AppEventBus.fireData([updatedMessage], 'List<Message>');
        await _updateConversationAfterEdit(updatedMsg, newContent);
      }
    } else {
      // 对方编辑的通知
      await _processPeerEdit(originalMsg, repo, data, newContent);
    }

    // 发送ACK
    AppEventBus.fire(AckSendRequestedEvent(
      messageType: msgType,
      messageId: data['id'],
    ));
  }

  /// Process edit request
  /// 处理编辑请求
  Future<void> _processEditRequest(Map data, String originalMsgId, String newContent) async {
    final msgType = data['type'] as String? ?? '';
    final fromId = data['from'] as String? ?? '';
    final currentUid = UserRepoLocal.to.currentUid;
    
    // 只有消息接收者才需要处理编辑请求
    if (fromId == currentUid) {
      iPrint('🔄 这是自己发送的编辑请求，无需处理');
      return;
    }
    
    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);
    
    if (originalMsg == null) {
      iPrint('❌ 未找到要编辑的原始消息: originalMsgId=$originalMsgId');
      return;
    }
    
    // 处理对方编辑
    await _processPeerEdit(originalMsg, repo, data, newContent);
    
    // 发送编辑确认
    final ackMessage = {
      'id': data['id'],
      'type': msgType,
      'from': currentUid,
      'to': fromId,
      'payload': {
        'msg_type': 'text',
        'action': 'message_edit_ack',
        'original_msg_id': originalMsgId,
        'content': newContent,
        'edited_at': DateTimeHelper.millisecond(),
      },
    };
    
    iPrint('🔄 发送编辑确认ACK: ${json.encode(ackMessage)}');
    AppEventBus.fire(WebSocketMessageSendRequestEvent(
      message: json.encode(ackMessage),
      messageId: data['id'],
    ));
  }

  /// Process peer edit
  /// 处理对方编辑
  Future<void> _processPeerEdit(MessageModel msg, MessageRepo repo, Map data, String newContent) async {
    try {
      final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      
      // 构建新的payload
      final newPayload = Map<String, dynamic>.from(msg.payload);
      newPayload['text'] = newContent;
      newPayload['edited_at'] = payload['edited_at'] ?? DateTimeHelper.millisecond();
      newPayload['is_edited'] = true;
      
      iPrint('🔄 处理对方编辑消息: msgId=${msg.id}, newContent=$newContent');
      
      // 更新数据库
      final updateResult = await repo.update({
        'id': msg.id!,
        'status': IMBoyMessageStatus.sent,
        'payload': json.encode(newPayload),
      });
      
      iPrint('🔄 对方编辑更新数据库结果: $updateResult, msgId=${msg.id}');
      
      // 重新获取更新后的消息
      final updatedMsg = await repo.find(msg.id!);
      if (updatedMsg != null) {
        iPrint('🔄 重新获取更新后的消息成功: ${updatedMsg.toJson()}');
        
        final updatedMessage = await updatedMsg.toTypeMessage();
        iPrint('🔄 触发编辑消息更新事件: msgId=${updatedMsg.id}');
        
        // 更新UI
        AppEventBus.fireData([updatedMessage], 'List<Message>');
        
        // 更新会话
        await _updateConversationAfterEdit(updatedMsg, newContent);
      } else {
        iPrint('❌ 重新获取更新后的消息失败');
      }
    } catch (e) {
      iPrint('❌ 处理对方编辑消息异常: $e');
    }
  }

  /// Update conversation after edit
  /// 编辑后同步更新会话列表
  Future<void> _updateConversationAfterEdit(MessageModel msg, String newContent) async {
    try {
      iPrint('更新会话编辑状态: msgId=${msg.id}, type=${msg.type}, newContent=$newContent');
      
      // 确定对话的peerId
      String peerId;
      if (msg.type == 'C2C') {
        peerId = msg.fromId == UserRepoLocal.to.currentUid
            ? msg.toId!
            : msg.fromId!;
      } else if (msg.type == 'C2G') {
        peerId = msg.toId!;
      } else {
        peerId = msg.toId ?? '';
      }
      
      if (peerId.isEmpty) {
        iPrint('无法确定会话peerId，无法更新会话');
        return;
      }
      
      // 查找会话
      final conv = await _conversationRepo.findByPeerId(msg.type!, peerId);
      if (conv == null) {
        iPrint('未找到会话记录: type=${msg.type}, peerId=$peerId');
        return;
      }
      
      // 只有当编辑的消息是会话的最后一条消息时才更新会话
      if (conv.lastMsgId == msg.id) {
        iPrint('更新会话最后消息: conversationId=${conv.id}, lastMsgId=${conv.lastMsgId}');
        
        // 更新会话属性
        conv.msgType = 'text';
        conv.subtitle = newContent;
        
        // 更新会话数据库记录
        final updateResult = await _conversationRepo.updateById(conv.id, {
          ConversationRepo.msgType: 'text',
          ConversationRepo.subtitle: newContent,
        });
        
        iPrint('会话更新结果: $updateResult, conversationId=${conv.id}');
        
        // 重新获取更新后的会话并通知UI更新
        final updatedConv = await _conversationRepo.findById(conv.id);
        if (updatedConv != null) {
          iPrint('触发会话更新事件: ${updatedConv.id}');
          AppEventBus.fireData(updatedConv);
        }
      } else {
        iPrint('编辑的消息不是会话的最后一条消息，无需更新会话');
      }
    } catch (e) {
      iPrint('更新会话编辑状态异常: $e');
    }
  }

  /// 处理对方撤回消息的通用方法
  /// Process peer revoke message
  Future<void> _processPeerRevoke(MessageModel msg, MessageRepo repo, Map data) async {
    try {
      // 保存原始消息内容（如果是文本消息）
      final originalText = msg.payload['text'] ?? '';
      
      // 获取联系人信息
      final contact = await _contactRepo.findByUid(data['from']);
      iPrint("🔄 获取联系人信息: ${contact?.nickname ?? '未知用户'}");
      
      // 构建新的payload
      final newPayload = <String, dynamic>{
        'msg_type': 'custom',
        'custom_type': 'peer_revoked',
        'peer_name': contact?.nickname ?? '',
        'text': originalText, // 保留原始文本内容
        'revoke_time': DateTimeHelper.millisecond(),
        'revoke_user': data['from'], // 记录撤回操作的用户ID
      };
      
      iPrint('🔄 处理对方撤回消息: originalMsgId=${msg.id}, peerName=${contact?.nickname}');
      iPrint('🔄 新的payload: ${json.encode(newPayload)}');
      
      // 更新数据库 - 使用原始消息的ID，而不是撤回确认消息的ID
      final updateResult = await repo.update({
        'id': msg.id, // 使用原始消息的ID
        'status': IMBoyMessageStatus.sent,
        'payload': json.encode(newPayload),
      });
      
      iPrint('🔄 对方撤回更新数据库结果: $updateResult, originalMsgId=${msg.id}');
      
      // 重新获取更新后的消息
      final updatedMsg = await repo.find(msg.id!);
      if (updatedMsg != null) {
        iPrint('🔄 重新获取更新后的消息成功: ${updatedMsg.toJson()}');
        iPrint('🔄 触发peer_revoked消息更新事件: msgId=${updatedMsg.id}');
        
        final updatedMessage = await updatedMsg.toTypeMessage();
        iPrint('🔄 peer_revoked消息转换结果: ${updatedMessage.runtimeType}');
        iPrint('🔄 消息元数据: ${updatedMessage.metadata}');
        iPrint('🔄 customType: ${updatedMessage.metadata?['custom_type']}');
        
        // 更新UI - 这是关键步骤
        iPrint('🔄 准备触发UI更新事件...');
        AppEventBus.fireData([updatedMessage], 'List<Message>');
        iPrint('🔄 UI更新事件已触发');
        
        // 更新会话
        await _updateConversationAfterRevoke(updatedMsg, 'peer_revoked');
      } else {
        iPrint('❌ 重新获取更新后的消息失败');
      }
    } catch (e, s) {
      iPrint('❌ 处理对方撤回消息异常: $e; $s');
    }
  }

  /// Update conversation record after revoke
  /// 撤回后同步更新会话列表
  Future<void> _updateConversationAfterRevoke(
    MessageModel msg,
    String customType,
  ) async {
    try {
      iPrint('更新会话撤回状态: msgId=${msg.id}, type=${msg.type}, customType=$customType');
      
      // 确定对话的peerId
      String peerId;
      if (msg.type == 'C2C') {
        peerId = msg.fromId == UserRepoLocal.to.currentUid
            ? msg.toId!
            : msg.fromId!;
      } else if (msg.type == 'C2G') {
        peerId = msg.toId!;
      } else {
        peerId = msg.toId ?? '';
      }
      
      if (peerId.isEmpty) {
        iPrint('无法确定会话peerId，无法更新会话');
        return;
      }
      
      // 查找会话
      final conv = await _conversationRepo.findByPeerId(msg.type!, peerId);
      if (conv == null) {
        iPrint('未找到会话记录: type=${msg.type}, peerId=$peerId');
        return;
      }
      
      // 只有当撤回的消息是会话的最后一条消息时才更新会话
      if (conv.lastMsgId == msg.id) {
        iPrint('更新会话最后消息: conversationId=${conv.id}, lastMsgId=${conv.lastMsgId}');
        
        // 更新会话属性
        conv.msgType = customType;
        conv.subtitle = '';
        
        // 更新会话数据库记录
        final updateResult = await _conversationRepo.updateById(conv.id, {
          ConversationRepo.msgType: customType,
          ConversationRepo.subtitle: '',
          ConversationRepo.payload: json.encode(msg.payload),
        });
        
        iPrint('会话更新结果: $updateResult, conversationId=${conv.id}');
        
        // 重新获取更新后的会话并通知UI更新
        final updatedConv = await _conversationRepo.findById(conv.id);
        if (updatedConv != null) {
          iPrint('触发会话更新事件: ${updatedConv.id}');
          AppEventBus.fireData(updatedConv);
        }
      } else {
        iPrint('撤回的消息不是会话的最后一条消息，无需更新会话');
      }
    } catch (e, s) {
      iPrint('更新会话撤回状态异常: $e; $s');
    }
  }

  /// 发送撤回消息请求
  /// Send revoke message request.
  Future<bool> sendRevokeMessage(String messageId, String messageType) async {
    try {
      final repo = MessageService.to.getMessageRepo(messageType);
      final msg = await repo.find(messageId);
      
      if (msg == null) {
        iPrint('❌ 未找到要撤回的消息: messageId=$messageId');
        return false;
      }
      
      // 检查是否可以撤回
      if (!await canRevokeMessage(msg)) {
        iPrint('❌ 消息不符合撤回条件: messageId=$messageId');
        return false;
      }
      
      final currentUid = UserRepoLocal.to.currentUid;
      final revokeMessage = {
        'id': Xid().toString(),
        'type': messageType,
        'from': currentUid,
        'to': msg.fromId == currentUid ? msg.toId! : msg.fromId,
        'payload': {
          'msg_type': 'custom',
          'action': 'message_revoke',
          'original_msg_id': messageId,
        },
      };
      
      iPrint('🔄 发送撤回消息请求: ${json.encode(revokeMessage)}');

      // 先添加到重试队列（确保消息会被重试）
      _messageRetry.addToRetryQueue(revokeMessage['id'].toString(), messageType);

      // 通过事件发送消息（fire-and-forget）
      AppEventBus.fire(WebSocketMessageSendRequestEvent(
        message: json.encode(revokeMessage),
        messageId: revokeMessage['id'].toString(),
      ));

      return true; // 返回 true 表示已提交发送请求
    } catch (e, s) {
      iPrint('❌ 发送撤回消息异常: $e; $s');
      return false;
    }
  }

  /// 发送编辑消息请求
  /// Send edit message request.
  Future<bool> sendEditMessage(String messageId, String messageType, String newContent) async {
    try {
      final repo = MessageService.to.getMessageRepo(messageType);
      final msg = await repo.find(messageId);
      
      if (msg == null) {
        iPrint('❌ 未找到要编辑的消息: messageId=$messageId');
        return false;
      }
      
      // 检查是否可以编辑
      if (!await canEditMessage(msg)) {
        iPrint('❌ 消息不符合编辑条件: messageId=$messageId');
        return false;
      }
      
      final currentUid = UserRepoLocal.to.currentUid;
      final editMessage = {
        'id': Xid().toString(),
        'type': messageType,
        'from': currentUid,
        'to': msg.fromId == currentUid ? msg.toId! : msg.fromId,
        'payload': {
          'msg_type': 'text',
          'action': 'message_edit',
          'original_msg_id': messageId,
          'content': newContent,
        },
      };
      
      iPrint('🔄 发送编辑消息请求: ${json.encode(editMessage)}');

      // 先添加到重试队列（确保消息会被重试）
      _messageRetry.addToRetryQueue(editMessage['id'].toString(), messageType);

      // 通过事件发送消息（fire-and-forget）
      AppEventBus.fire(WebSocketMessageSendRequestEvent(
        message: json.encode(editMessage),
        messageId: editMessage['id'].toString(),
      ));

      return true; // 返回 true 表示已提交发送请求
    } catch (e, s) {
      iPrint("❌ 发送编辑消息异常: $e; $s");
      return false;
    }
  }

  /// 检查消息是否可以撤回
  /// Check if message can be revoked.
  Future<bool> canRevokeMessage(MessageModel msg) async {
    try {
      // 只能撤回自己的消息
      final currentUid = UserRepoLocal.to.currentUid;
      if (msg.fromId != currentUid) {
        iPrint('❌ 不能撤回他人的消息: messageId=${msg.id}');
        return false;
      }
      
      // 检查消息类型是否支持撤回
      final payload = msg.payload;
      final msgType = payload['msg_type'] as String? ?? '';
      
      // 文本、图片、语音、视频、文件、位置消息可以撤回
      final supportedTypes = ['text', 'image', 'voice', 'video', 'file', 'location'];
      if (!supportedTypes.contains(msgType)) {
        iPrint('❌ 该类型消息不支持撤回: msgType=$msgType');
        return false;
      }
      
      // 检查时间限制（2分钟内可以撤回）
      final now = DateTimeHelper.millisecond();
      final messageTime = msg.createdAt;
      final timeDiff = now - messageTime;
      const revokeTimeLimit = 2 * 60 * 1000; // 2分钟
      
      if (timeDiff > revokeTimeLimit) {
        iPrint('❌ 消息超过撤回时间限制: timeDiff=${timeDiff}ms, limit=${revokeTimeLimit}ms');
        return false;
      }
      
      // 检查消息状态
      if (msg.status != IMBoyMessageStatus.sent) {
        iPrint('❌ 消息状态不支持撤回: status=${msg.status}');
        return false;
      }
      
      return true;
    } catch (e, s) {
      iPrint("❌ 检查撤回条件异常: $e; $s");
      return false;
    }
  }

  /// 检查消息是否可以编辑
  /// Check if message can be edited.
  Future<bool> canEditMessage(MessageModel msg) async {
    try {
      // 只能编辑自己的消息
      final currentUid = UserRepoLocal.to.currentUid;
      if (msg.fromId != currentUid) {
        iPrint('❌ 不能编辑他人的消息: messageId=${msg.id}');
        return false;
      }
      
      // 检查消息类型是否支持编辑
      final msgType = msg.payload['msg_type'] as String? ?? '';
      
      // 目前只支持编辑文本消息
      if (msgType != 'text') {
        iPrint('❌ 该类型消息不支持编辑: msgType=$msgType');
        return false;
      }
      
      // 检查时间限制（15分钟内可以编辑）
      final now = DateTimeHelper.millisecond();
      final messageTime = msg.createdAt;
      final timeDiff = now - messageTime;
      const editTimeLimit = 15 * 60 * 1000; // 15分钟
      
      if (timeDiff > editTimeLimit) {
        iPrint('❌ 消息超过编辑时间限制: timeDiff=${timeDiff}ms, limit=${editTimeLimit}ms');
        return false;
      }
      
      // 检查消息状态
      if (msg.status != IMBoyMessageStatus.sent) {
        iPrint('❌ 消息状态不支持编辑: status=${msg.status}');
        return false;
      }
      
      // 检查是否已经被撤回
      final customType = msg.payload['custom_type'] as String? ?? '';
      if (['my_revoked', 'peer_revoked'].contains(customType)) {
        iPrint('❌ 已撤回的消息不能编辑: customType=$customType');
        return false;
      }
      
      return true;
    } catch (e, s) {
      iPrint("❌ 检查编辑条件异常: $e; $s");
      return false;
    }
  }
}
