import 'dart:convert';

import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/websocket.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// Legacy compatibility surface. External callers should now import
// `package:imboy/modules/messaging/public.dart`; this file remains the action
// implementation behind the messaging facade until internal migration ends.
/// Temporary compatibility wrapper for the messaging module shell.
/// New callers should prefer `package:imboy/modules/messaging/public.dart`.
///
/// MessageActions
/// 消息操作功能，包含撤回、编辑等操作
/// Message operations including revoke, edit, etc.
///
/// Compatibility note:
/// New module-facing callers should prefer
/// `package:imboy/modules/messaging/public.dart`. This class stays as the
/// temporary action implementation behind the messaging module facade.
class MessageActions {
  /// 单例实例
  static MessageActions? _instance;

  /// 获取单例实例
  static MessageActions get instance {
    _instance ??= MessageActions._internal();
    return _instance!;
  }

  /// 私有构造函数
  MessageActions._internal() {
    // 消息操作模块初始化
    // Message actions module initialization
  }

  final MessageRetry _messageRetry = MessageRetry.instance;
  // 缓存常用仓库实例，避免重复 new。
  // Cache repository instances to avoid repeated instantiation.
  final ConversationRepo _conversationRepo = ConversationRepo();

  /// Handle action-based messages
  /// 处理基于action的消息（C2C/C2G/C2S 的消息操作）
  ///
  /// 职责：处理用户主动发起的消息操作
  /// - 消息已读：message_read
  /// - 表情回复：message_reaction
  /// - 消息撤回：message_revoke, message_revoke_ack
  /// - 消息编辑：message_edit, message_edit_ack
  ///
  /// 注意：S2C 消息的 action（服务端通知）在 MessageS2CService.switchS2C 中处理
  Future<void> handleActionMessage(String action, Map data) async {
    iPrint(
      "🔄 处理action消息: action=$action, msgId=${data['id']}, type=${data['type']}",
    );

    try {
      switch (action) {
        case 'message_read':
          await _handleReadAction(data);
          break;
        case 'message_read_ack':
          await _handleReadAckAction(data);
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
        case 'message_input':
          await _handleInputAction(data);
          break;
        default:
          iPrint('⚠️ [handleActionMessage] 未知的action类型: $action');
      }
    } catch (e, s) {
      iPrint(
        '❌ [handleActionMessage] 处理action消息异常: action=$action, error=$e\nstacktrace=$s',
      );
    }
  }

  Future<void> _handleReadAction(Map data) async {
    try {
      final msgType = parseModelString(data['type']);
      final msgId = parseModelString(data['id']);
      final payload = parseModelJsonMap(data['payload']) ?? {};
      final fromId = parseModelString(data['from']);
      final currentUid = UserRepoLocal.to.currentUid;

      if (fromId == currentUid) return;

      final idsRaw = payload['msg_ids'];
      final ids = idsRaw is List
          ? idsRaw.map((e) => e.toString()).toList()
          : <String>[];
      if (ids.isEmpty) {
        // 直接发送 ACK 确认
        AckManager.to.sendAckDirect(msgType, msgId);
        return;
      }

      final repo = MessageService.to.getMessageRepo(msgType);
      final updated = <Message>[];
      for (final id in ids) {
        // 发布状态更新事件
        AppEventBus.fire(
          MessageStatusUpdateRequestedEvent(
            messageId: id,
            messageType: msgType,
            newStatus: IMBoyMessageStatus.seen,
          ),
        );
        // 注意：原代码使用了返回值，这里需要从 repo 重新获取
        final m = await repo.find(id);
        if (m != null && m.status == IMBoyMessageStatus.seen) {
          // 注意：阅后即焚标记已移至 Chat Provider 处理
          // Chat Provider 会监听 MessageStatusUpdateRequestedEvent 并处理
          updated.add(await m.toTypeMessage());
        }
      }
      if (updated.isNotEmpty) {
        AppEventBus.fireData(updated);
      }

      // 直接发送 ACK 确认
      AckManager.to.sendAckDirect(msgType, msgId);
    } catch (e, s) {
      iPrint('❌ [_handleReadAction] 处理已读消息失败: error=$e\nstacktrace=$s');
    }
  }

  /// 处理消息已读确认（message_read_ack）
  /// 当对方确认收到并查看了我们发送的消息时触发
  Future<void> _handleReadAckAction(Map data) async {
    try {
      final msgType = parseModelString(data['type']);
      final msgId = parseModelString(data['id']);
      final fromId = parseModelString(data['from']);
      final currentUid = UserRepoLocal.to.currentUid;

      // 只有消息发送者才需要处理已读确认
      if (fromId != currentUid) {
        iPrint(
          '⚠️ [_handleReadAckAction] 不是发送自己的消息，忽略: fromId=$fromId, currentUid=$currentUid',
        );
        // 仍然发送 ACK 确认
        AckManager.to.sendAckDirect(msgType, msgId);
        return;
      }

      final payload = parseModelJsonMap(data['payload']) ?? {};
      final msgIdsRaw = payload['msg_ids'];
      final msgIds = msgIdsRaw is List
          ? msgIdsRaw.map((e) => e.toString()).toList()
          : <String>[];

      iPrint('📖 [_handleReadAckAction] 处理已读确认: msgId=$msgId, msgIds=$msgIds');

      if (msgIds.isEmpty) {
        // 单条消息已读确认
        // 发送 ACK 确认
        AckManager.to.sendAckDirect(msgType, msgId);
        return;
      }

      final repo = MessageService.to.getMessageRepo(msgType);
      final updated = <Message>[];

      for (final id in msgIds) {
        // 发布状态更新事件（更新为已读状态）
        AppEventBus.fire(
          MessageStatusUpdateRequestedEvent(
            messageId: id,
            messageType: msgType,
            newStatus: IMBoyMessageStatus.seen,
          ),
        );

        final m = await repo.find(id);
        if (m != null) {
          updated.add(await m.toTypeMessage());
        }
      }

      if (updated.isNotEmpty) {
        AppEventBus.fireData(updated);
      }

      // 发送 ACK 确认
      AckManager.to.sendAckDirect(msgType, msgId);
    } catch (e, s) {
      iPrint('❌ [_handleReadAckAction] 处理已读确认失败: error=$e\nstacktrace=$s');
    }
  }

  Future<void> _handleReactionAction(Map data) async {
    try {
      final msgType = parseModelString(data['type']);
      final msgId = parseModelString(data['id']);
      final payload = parseModelJsonMap(data['payload']) ?? {};

      final originalMsgId = payload['original_msg_id']?.toString() ?? '';
      final emoji = payload['emoji']?.toString() ?? '';
      final op = payload['op']?.toString() ?? '';
      final reactorId =
          payload['user_id']?.toString() ?? data['from']?.toString() ?? '';

      if (originalMsgId.isEmpty || emoji.isEmpty || reactorId.isEmpty) {
        // 直接发送 ACK 确认
        AckManager.to.sendAckDirect(msgType, msgId);
        return;
      }

      final repo = MessageService.to.getMessageRepo(msgType);
      final msg = await repo.find(originalMsgId);
      if (msg == null) {
        // 直接发送 ACK 确认
        AckManager.to.sendAckDirect(msgType, msgId);
        return;
      }

      final newPayload = Map<String, dynamic>.from(msg.payload);
      final reactionsRaw = newPayload['reactions'];
      final reactions = reactionsRaw is Map
          ? reactionsRaw.cast<String, dynamic>()
          : <String, dynamic>{};
      final usersRaw = reactions[emoji];
      final users = usersRaw is List
          ? usersRaw.map((e) => e.toString()).toList()
          : <String>[];

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

      // 直接发送 ACK 确认
      AckManager.to.sendAckDirect(msgType, msgId);
    } catch (e, s) {
      iPrint('❌ [_handleReactionAction] 处理消息表情失败: error=$e\nstacktrace=$s');
    }
  }

  /// Handle revoke action messages
  /// 处理撤回action消息
  Future<void> _handleRevokeAction(Map data, {required bool isAck}) async {
    final msgType = parseModelString(data['type']);
    final msgId = parseModelString(data['id']);
    final payload = parseModelJsonMap(data['payload']) ?? {};
    final originalMsgId = parseModelString(payload['original_msg_id']);

    iPrint(
      "🔄 处理撤回action: isAck=$isAck, msgType=$msgType, msgId=$msgId, originalMsgId=$originalMsgId",
    );

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
    final msgType = parseModelString(data['type']);
    final currentUid = UserRepoLocal.to.currentUid;

    // 【重要】从重试队列中移除撤回消息
    final revokeMsgId = parseModelString(data['id']);
    if (revokeMsgId.isNotEmpty) {
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: revokeMsgId,
          messageType: msgType,
          reason: 'revoked',
        ),
      );
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
    final isMyRevoke = originalMsg.fromId.toString() == currentUid;

    if (isMyRevoke) {
      // 自己撤回的确认 - 使用公共撤回方法
      await MessageActions.convertMessageToRevoked(
        originalMsg: originalMsg,
        repo: repo,
        revokeUserId: currentUid,
        isMyRevoke: true, // 自己撤回
      );

      // 重新获取更新后的消息用于触发UI更新
      final updatedMsg = await repo.find(originalMsgId);
      if (updatedMsg != null) {
        AppEventBus.fireData([
          await updatedMsg.toTypeMessage(),
        ], 'List<Message>');
        await _updateConversationAfterRevoke(updatedMsg);
      }
    } else {
      // 对方撤回的通知
      await _processPeerRevoke(originalMsg, repo, data);
    }

    // 发送ACK
    AckManager.to.sendAckDirect(msgType, parseModelString(data['id']));
  }

  /// Process revoke request
  /// 处理撤回请求
  Future<void> _processRevokeRequest(Map data, String originalMsgId) async {
    final msgType = parseModelString(data['type']);
    final fromId = parseModelString(data['from']);
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

    // 发送撤回确认 (v2.0 格式)
    final ackMessage = {
      'id': data['id'],
      'type': msgType,
      'from': currentUid,
      'to': fromId,
      // v2.0: 字段提升到顶层
      'msg_type': 'custom',
      'action': 'message_revoke_ack',
      'e2ee': '',
      'payload': {
        'original_msg_id': originalMsgId,
        'revoked_at': DateTimeHelper.millisecond(),
      },
    };

    iPrint('🔄 发送撤回确认ACK (v2.0): ${json.encode(ackMessage)}');
    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(ackMessage),
        messageId: data['id'],
      ),
    );
  }

  /// Handle edit action messages
  /// 处理编辑action消息
  Future<void> _handleEditAction(Map data, {required bool isAck}) async {
    final msgType = parseModelString(data['type']);
    final msgId = parseModelString(data['id']);
    final payload = parseModelJsonMap(data['payload']) ?? {};
    final originalMsgId = parseModelString(payload['original_msg_id']);
    final newContent = parseModelString(payload['content']);

    iPrint(
      "🔄 处理编辑action: isAck=$isAck, msgType=$msgType, msgId=$msgId, originalMsgId=$originalMsgId",
    );

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
  Future<void> _processEditAck(
    Map data,
    String originalMsgId,
    String newContent,
  ) async {
    final msgType = parseModelString(data['type']);
    final payload = parseModelJsonMap(data['payload']) ?? {};
    final currentUid = UserRepoLocal.to.currentUid;

    // 【重要】从重试队列中移除编辑消息
    final editMsgId = parseModelString(data['id']);
    if (editMsgId.isNotEmpty) {
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: editMsgId,
          messageType: msgType,
          reason: 'edited',
        ),
      );
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
    final isMyEdit = originalMsg.fromId.toString() == currentUid;

    if (isMyEdit) {
      // 自己编辑的确认
      final newPayload = Map<String, dynamic>.from(originalMsg.payload);
      newPayload['text'] = newContent;
      newPayload['edited_at'] =
          payload['edited_at'] ?? DateTimeHelper.millisecond();
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
    AckManager.to.sendAckDirect(msgType, parseModelString(data['id']));
  }

  /// Process edit request
  /// 处理编辑请求
  Future<void> _processEditRequest(
    Map data,
    String originalMsgId,
    String newContent,
  ) async {
    final msgType = parseModelString(data['type']);
    final fromId = parseModelString(data['from']);
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

    // 发送编辑确认 (v2.0 格式)
    final ackMessage = {
      'id': data['id'],
      'type': msgType,
      'from': currentUid,
      'to': fromId,
      // v2.0: 字段提升到顶层
      'msg_type': 'text',
      'action': 'message_edit_ack',
      'e2ee': '',
      'payload': {
        'original_msg_id': originalMsgId,
        'content': newContent,
        'edited_at': DateTimeHelper.millisecond(),
      },
    };

    iPrint('🔄 发送编辑确认ACK (v2.0): ${json.encode(ackMessage)}');
    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(ackMessage),
        messageId: data['id'],
      ),
    );
  }

  /// Process peer edit
  /// 处理对方编辑
  Future<void> _processPeerEdit(
    MessageModel msg,
    MessageRepo repo,
    Map data,
    String newContent,
  ) async {
    try {
      final payload = parseModelJsonMap(data['payload']) ?? {};

      // 构建新的payload
      final newPayload = Map<String, dynamic>.from(msg.payload);
      newPayload['text'] = newContent;
      newPayload['edited_at'] =
          payload['edited_at'] ?? DateTimeHelper.millisecond();
      newPayload['is_edited'] = true;

      iPrint('🔄 处理对方编辑消息: msgId=${msg.id}, newContent=$newContent');

      // 更新数据库
      final updateResult = await repo.update({
        'id': msg.id,
        'status': IMBoyMessageStatus.sent,
        'payload': json.encode(newPayload),
      });

      iPrint('🔄 对方编辑更新数据库结果: $updateResult, msgId=${msg.id}');

      // 重新获取更新后的消息
      final updatedMsg = await repo.find(msg.id.toString());
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
  Future<void> _updateConversationAfterEdit(
    MessageModel msg,
    String newContent,
  ) async {
    try {
      iPrint(
        '更新会话编辑状态: msgId=${msg.id}, type=${msg.type}, newContent=$newContent',
      );

      // 确定对话的peerId
      String peerId;
      if (msg.type == 'C2C') {
        peerId = msg.fromId.toString() == UserRepoLocal.to.currentUid
            ? msg.toId.toString()
            : msg.fromId.toString();
      } else if (msg.type == 'C2G') {
        peerId = msg.toId.toString();
      } else {
        peerId = msg.toId.toString();
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
      // conv.lastMsgId 为 int（旧契约），msg.id 为 String（新契约 / Xid base32hex）
      if (conv.lastMsgId.toString() == msg.id) {
        iPrint(
          '更新会话最后消息: conversationId=${conv.id}, lastMsgId=${conv.lastMsgId}',
        );

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
  /// 使用公共辅助类 MessageActionHelpers 消除代码重复
  Future<void> _processPeerRevoke(
    MessageModel msg,
    MessageRepo repo,
    Map data,
  ) async {
    try {
      // 保存原始消息内容（如果是文本消息）
      final originalText = msg.payload['text'] ?? '';

      // 使用公共静态方法处理撤回（isMyRevoke = false 表示对方撤回）
      await MessageActions.convertMessageToRevoked(
        originalMsg: msg,
        repo: repo,
        revokeUserId: data['from'],
        originalText: originalText,
        isMyRevoke: false, // 对方撤回
      );

      // 更新会话
      await _updateConversationAfterRevoke(msg);
    } catch (e, s) {
      iPrint('❌ 处理对方撤回消息异常: $e; $s');
    }
  }

  /// Update conversation record after revoke
  /// 撤回后同步更新会话列表
  Future<void> _updateConversationAfterRevoke(MessageModel msg) async {
    try {
      iPrint(
        '更新会话撤回状态: msgId=${msg.id}, type=${msg.type}, status=${msg.status}',
      );

      // 确定对话的peerId
      String peerId;
      if (msg.type == 'C2C') {
        peerId = msg.fromId.toString() == UserRepoLocal.to.currentUid
            ? msg.toId.toString()
            : msg.fromId.toString();
      } else if (msg.type == 'C2G') {
        peerId = msg.toId.toString();
      } else {
        peerId = msg.toId.toString();
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
      // conv.lastMsgId 为 int（旧契约），msg.id 为 String（新契约 / Xid base32hex）
      if (conv.lastMsgId.toString() == msg.id) {
        iPrint(
          '更新会话最后消息: conversationId=${conv.id}, lastMsgId=${conv.lastMsgId}',
        );

        // WebSocket API v2.0: 保留原始 msgType，使用 status 标识撤回状态
        // 更新会话数据库记录
        final updateResult = await _conversationRepo.updateById(conv.id, {
          ConversationRepo.lastMsgStatus: msg.status, // 30 或 31
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
      final String toUid = msg.fromId.toString() == currentUid ? msg.toId.toString() : msg.fromId.toString();

      if (WebSocketService.to.framing == FramingMode.v2) {
        final int? numericMsgId = int.tryParse(messageId);
        if (numericMsgId != null) {
          final bytes = ImboyFrame.recall(numericMsgId);
          WebSocketService.to.sendDirect(bytes);
          iPrint('🔄 发送 v2 二进制撤回请求: msgId=$messageId');
          return true;
        }
      }

      // v2.0: msg_type/action 字段提升到顶层
      final revokeMessage = {
        'id': Xid().toString(),
        'type': messageType,
        'from': currentUid,
        'to': toUid,
        // v2.0: 字段提升到顶层
        'msg_type': 'custom',
        'action': 'message_revoke',
        'e2ee': '',
        'payload': {'original_msg_id': messageId},
      };

      iPrint('🔄 发送撤回消息请求 (v2.0): ${json.encode(revokeMessage)}');

      // 先添加到重试队列（确保消息会被重试）
      _messageRetry.addToRetryQueue(
        revokeMessage['id'].toString(),
        messageType,
      );

      // 通过事件发送消息（fire-and-forget）
      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(revokeMessage),
          messageId: revokeMessage['id'].toString(),
        ),
      );

      return true; // 返回 true 表示已提交发送请求
    } catch (e, s) {
      iPrint('❌ 发送撤回消息异常: $e; $s');
      return false;
    }
  }

  /// 发送编辑消息请求
  /// Send edit message request.
  Future<bool> sendEditMessage(
    String messageId,
    String messageType,
    String newContent,
  ) async {
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
      // v2.0: msg_type/action 字段提升到顶层
      final editMessage = {
        'id': Xid().toString(),
        'type': messageType,
        'from': currentUid,
        'to': msg.fromId.toString() == currentUid ? msg.toId.toString() : msg.fromId.toString(),
        // v2.0: 字段提升到顶层
        'msg_type': 'text',
        'action': 'message_edit',
        'e2ee': '',
        'payload': {'original_msg_id': messageId, 'content': newContent},
      };

      iPrint('🔄 发送编辑消息请求 (v2.0): ${json.encode(editMessage)}');

      // 先添加到重试队列（确保消息会被重试）
      _messageRetry.addToRetryQueue(editMessage['id'].toString(), messageType);

      // 通过事件发送消息（fire-and-forget）
      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(editMessage),
          messageId: editMessage['id'].toString(),
        ),
      );

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
      if (msg.fromId.toString() != currentUid) {
        iPrint('❌ 不能撤回他人的消息: messageId=${msg.id}');
        return false;
      }

      // WebSocket API v2.0: 从顶层 msgType 字段读取消息类型
      final msgType = msg.msgType ?? '';

      // 文本、图片、语音、视频、文件、位置消息可以撤回
      final supportedTypes = [
        'text',
        'image',
        'voice',
        'video',
        'file',
        'location',
      ];
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
        iPrint(
          '❌ 消息超过撤回时间限制: timeDiff=${timeDiff}ms, limit=${revokeTimeLimit}ms',
        );
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
      if (msg.fromId.toString() != currentUid) {
        iPrint('❌ 不能编辑他人的消息: messageId=${msg.id}');
        return false;
      }

      // WebSocket API v2.0: 从顶层 msgType 字段读取消息类型
      final msgType = msg.msgType ?? '';

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
        iPrint(
          '❌ 消息超过编辑时间限制: timeDiff=${timeDiff}ms, limit=${editTimeLimit}ms',
        );
        return false;
      }

      // 检查消息状态
      if (msg.status != IMBoyMessageStatus.sent) {
        iPrint('❌ 消息状态不支持编辑: status=${msg.status}');
        return false;
      }

      // 检查是否已经被撤回
      if (IMBoyMessageStatus.isRevokedStatus(msg.status)) {
        iPrint('❌ 已撤回的消息不能编辑: status=${msg.status}');
        return false;
      }

      return true;
    } catch (e, s) {
      iPrint("❌ 检查编辑条件异常: $e; $s");
      return false;
    }
  }

  /// 处理输入状态消息
  Future<void> _handleInputAction(Map data) async {
    try {
      final msgType = parseModelString(data['type']);
      final fromId = parseModelString(data['from']);
      final payload = parseModelJsonMap(data['payload']) ?? {};
      final statusStr = payload['status']?.toString() ?? 'start';

      final currentUid = UserRepoLocal.to.currentUid;
      if (fromId == currentUid) return;

      final TypingStatus status = statusStr == 'stop'
          ? TypingStatus.stop
          : TypingStatus.start;

      // 获取 conversationUk3
      // 如果是 C2C，conversationUk3 应该由 fromId 决定（因为是对方发来的）
      // 如果是 C2G，conversationUk3 应该由 toId (groupId) 决定
      String conversationUk3 = '';
      if (msgType == 'C2C') {
        // C2C: peerId 就是对方ID (fromId)
        // uk3 = ConversationModel.getUk3(msgType, fromId, currentUid)
        // 但这里为了简便，我们直接使用 ConversationModel 的辅助方法或者通过 Repo 查找
        final conv = await _conversationRepo.findByPeerId(msgType, fromId);
        if (conv != null) {
          conversationUk3 = conv.uk3;
        }
      } else if (msgType == 'C2G') {
        final groupId = parseModelString(data['to']);
        final conv = await _conversationRepo.findByPeerId(msgType, groupId);
        if (conv != null) {
          conversationUk3 = conv.uk3;
        }
      }

      if (conversationUk3.isNotEmpty) {
        AppEventBus.fire(
          MessageTypingEvent(
            conversationUk3: conversationUk3,
            typierId: fromId,
            status: status,
          ),
        );
        // iPrint('✅ [INPUT] 触发输入状态事件: from=$fromId, status=$status');
      }
    } catch (e, s) {
      iPrint('❌ [_handleInputAction] 处理输入状态异常: $e; $s');
    }
  }

  /// 发送输入状态
  /// Send input status (typing/stopped)
  Future<void> sendInputStatus({
    required String conversationUk3,
    required String toId,
    required String chatType,
    required TypingStatus status,
  }) async {
    try {
      final currentUid = UserRepoLocal.to.currentUid;
      final statusStr = status == TypingStatus.start ? 'start' : 'stop';

      if (WebSocketService.to.framing == FramingMode.v2) {
        final int? numericConvId = int.tryParse(toId);
        if (numericConvId != null) {
          final bytes = ImboyFrame.typing(numericConvId, status == TypingStatus.start);
          WebSocketService.to.sendDirect(bytes);
          iPrint('🔄 发送 v2 二进制输入状态: $statusStr, to=$toId');
          return;
        }
      }

      final inputMessage = {
        'id': Xid().toString(),
        'type': chatType,
        'from': currentUid,
        'to': toId,
        'msg_type': 'custom',
        'action': 'message_input',
        'e2ee': '',
        'payload': {'status': statusStr},
      };

      // iPrint('🔄 发送输入状态: $statusStr, to=$toId');

      // 通过事件发送消息（fire-and-forget）
      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(inputMessage),
          messageId: inputMessage['id'].toString(),
        ),
      );
    } catch (e, s) {
      iPrint('❌ [sendInputStatus] 发送异常: $e; $s');
    }
  }

  // ============================================
  // 公共静态方法（供 MessageS2CService 调用）
  // ============================================

  /// 将消息转换为撤回提示
  ///
  /// 用于：
  /// - MessageActions._processPeerRevoke: 用户撤回自己的消息
  /// - MessageS2CService._handleC2CRevoke: 服务端通知对方撤回了消息
  ///
  /// 参数：
  /// - [originalMsg]: 原始消息
  /// - [repo]: 消息仓库
  /// - [revokeUserId]: 执行撤回操作的用户ID
  /// - [originalText]: 原始消息文本（可选，优先从消息中获取）
  /// - [isMyRevoke]: 是否为自己撤回（默认 true）
  static Future<void> convertMessageToRevoked({
    required MessageModel originalMsg,
    required MessageRepo repo,
    required String revokeUserId,
    String? originalText,
    bool isMyRevoke = false,
  }) async {
    try {
      // 获取联系人信息（静态方法中创建新的仓库实例）
      final contactRepo = ContactRepo();
      final contact = await contactRepo.findByUid(revokeUserId);
      iPrint("🔄 获取联系人信息: ${contact?.nickname ?? '未知用户'}");

      // 保存原始消息内容（如果是文本消息）
      final text = originalText ?? originalMsg.payload['text'] ?? '';

      // 根据撤回类型设置状态码
      final revokeStatus = isMyRevoke
          ? IMBoyMessageStatus
                .myRevoked // 31: 自己撤回
          : IMBoyMessageStatus.peerRevoked; // 30: 对方撤回

      // 构建新的 payload（保留撤回相关信息供 UI 使用）
      final newPayload = <String, dynamic>{
        'peer_name': contact?.nickname ?? '',
        'text': text, // 保留原始文本内容
        'revoke_time': DateTimeHelper.millisecond(),
        'revoke_user': revokeUserId, // 记录撤回操作的用户ID
      };

      iPrint(
        '🔄 处理撤回消息: originalMsgId=${originalMsg.id}, '
        'isMyRevoke=$isMyRevoke, status=$revokeStatus',
      );

      // 更新数据库
      // WebSocket API v2.0: msg_type 保留原始内容类型，status 标识撤回状态
      final updateResult = await repo.update({
        'id': originalMsg.id,
        'status': revokeStatus, // 30 或 31
        'payload': json.encode(newPayload),
      });

      iPrint('🔄 撤回更新数据库结果: $updateResult, originalMsgId=${originalMsg.id}');

      // 重新获取更新后的消息
      final updatedMsg = await repo.find(originalMsg.id.toString());
      if (updatedMsg != null) {
        iPrint('🔄 重新获取更新后的消息成功: ${updatedMsg.toJson()}');

        final updatedMessage = await updatedMsg.toTypeMessage();
        iPrint('🔄 触发撤回消息更新事件: msgId=${updatedMsg.id}');

        // 更新 UI
        AppEventBus.fireData([updatedMessage], 'List<Message>');
      } else {
        iPrint('❌ 重新获取更新后的消息失败');
      }
    } catch (e, s) {
      iPrint('❌ [convertMessageToRevoked] 处理异常: $e; $s');
    }
  }

  /// 处理 C2C 消息删除（双方）
  ///
  /// 用于：
  /// - MessageS2CService._handleC2CDelEveryone
  static Future<void> handleC2CDeleteMessage({
    required String oldMsgId,
    required String from,
    required String to,
  }) async {
    try {
      final currentUid = UserRepoLocal.to.currentUid;
      final peerId = currentUid == from ? to : from;

      // 静态方法中创建新的仓库实例
      final conversationRepo = ConversationRepo();
      final conversation = await conversationRepo.findByPeerId('C2C', peerId);
      final messageRepo = MessageRepo(tableName: MessageRepo.c2cTable);
      final oldMsg = await messageRepo.find(oldMsgId);

      iPrint(
        '🗑️ C2C 删除检查: conversation=${conversation != null}, oldMsg=${oldMsg != null}',
      );

      if (conversation == null || oldMsg == null) {
        return;
      }

      final msg = await oldMsg.toTypeMessage();
      // 发布删除消息事件，由聊天界面订阅处理
      AppEventBus.fire(
        ChatExtendEvent(
          type: 'delete_msg',
          payload: {'conversation': conversation, 'msg': msg},
        ),
      );
    } catch (e, s) {
      iPrint('❌ [handleC2CDeleteMessage] 处理异常: $e; $s');
    }
  }

  /// 处理 C2G 消息删除（所有人）
  ///
  /// 用于：
  /// - MessageS2CService._handleC2GDelEveryone
  static Future<void> handleC2GDeleteMessage({
    required String oldMsgId,
    required String groupId,
  }) async {
    try {
      // 静态方法中创建新的仓库实例
      final conversationRepo = ConversationRepo();
      final conversation = await conversationRepo.findByPeerId('C2G', groupId);
      final messageRepo = MessageRepo(tableName: MessageRepo.c2gTable);
      final oldMsg = await messageRepo.find(oldMsgId);

      iPrint(
        '🗑️ C2G 删除检查: conversation=${conversation != null}, oldMsg=${oldMsg != null}',
      );

      if (conversation == null || oldMsg == null) {
        return;
      }

      final msg = await oldMsg.toTypeMessage();
      // 发布删除消息事件，由聊天界面订阅处理
      AppEventBus.fire(
        ChatExtendEvent(
          type: 'delete_msg',
          payload: {'conversation': conversation, 'msg': msg},
        ),
      );
    } catch (e, s) {
      iPrint('❌ [handleC2GDeleteMessage] 处理异常: $e; $s');
    }
  }

  /// 处理非好友错误
  ///
  /// 用于：
  /// - MessageS2CService._handleNotAFriend
  ///
  /// 参数：
  /// - [msgId]: 消息ID
  /// - [chatType]: 会话类型 (C2C/C2G)
  static Future<void> handleNotAFriendError({
    required String? msgId,
    required String chatType,
  }) async {
    try {
      // 1. 打印调试日志
      iPrint('🚫 [NOT_A_FRIEND] msgId=$msgId, chatType=$chatType');
      debugPrint('🚫 [NOT_A_FRIEND] 无法发送消息 - 非好友关系');

      // 2. 通过事件总线通知 UI 显示错误提示
      try {
        AppEventBus.fire(
          AppErrorEvent(message: '非好友关系，无法发送消息', errorType: 'not_a_friend'),
        );
        iPrint('✅ [NOT_A_FRIEND] 已发送错误提示事件');
      } catch (e) {
        debugPrint('⚠️ [NOT_A_FRIEND] 发送事件失败: $e');
      }

      // 3. 更新消息状态为失败
      // 4. 从重试队列移除
      if (msgId != null && msgId.isNotEmpty) {
        try {
          // 更新消息状态为 error（失败）
          AppEventBus.fire(
            MessageStatusUpdateRequestedEvent(
              messageId: msgId,
              messageType: chatType,
              newStatus: 41, // IMBoyMessageStatus.error
              notifyUI: true,
            ),
          );
          iPrint('✅ [NOT_A_FRIEND] 消息状态已更新为 error: msgId=$msgId');
        } catch (e) {
          debugPrint('⚠️ [NOT_A_FRIEND] 更新消息状态失败: $e');
        }

        try {
          // 从重试队列移除（不重试）
          AppEventBus.fire(
            RemoveFromRetryQueueRequestedEvent(
              messageId: msgId,
              messageType: chatType,
              reason: 'not_a_friend',
            ),
          );
          iPrint('🗑️ [NOT_A_FRIEND] 消息已从重试队列移除: msgId=$msgId');
        } catch (e) {
          debugPrint('⚠️ [NOT_A_FRIEND] 从重试队列移除失败: $e');
        }
      }
    } catch (e, s) {
      iPrint('❌ [handleNotAFriendError] 处理异常: error=$e\nstacktrace=$s');
    }
  }

  /// 处理黑名单错误（对方将您加入黑名单）
  ///
  /// 当服务端返回 `in_denylist` 事件时调用，说明接收方已将发送方加入黑名单。
  ///
  /// 处理流程：
  /// 1. 打印调试日志
  /// 2. 通过事件总线通知 UI 显示错误提示
  /// 3. 更新消息状态为失败（status=41）
  /// 4. 从重试队列移除（停止重试）
  ///
  /// 参数：
  /// - [msgId]: 消息ID
  /// - [chatType]: 会话类型 (C2C/C2G)
  static Future<void> handleDenylistError({
    required String? msgId,
    required String chatType,
  }) async {
    try {
      // 1. 打印调试日志
      iPrint('🚫 [DENYLIST] msgId=$msgId, chatType=$chatType');
      debugPrint('🚫 [DENYLIST] 无法发送消息 - 对方已将您加入黑名单');

      // 2. 通过事件总线通知 UI 显示错误提示
      try {
        AppEventBus.fire(
          AppErrorEvent(
            message: t.chatErrorInDenylist,
            errorType: 'in_denylist',
          ),
        );
        iPrint('✅ [DENYLIST] 已发送错误提示事件');
      } catch (e) {
        debugPrint('⚠️ [DENYLIST] 发送事件失败: $e');
      }

      // 3. 更新消息状态为失败
      // 4. 从重试队列移除
      if (msgId != null && msgId.isNotEmpty) {
        try {
          // 更新消息状态为 error（失败）
          AppEventBus.fire(
            MessageStatusUpdateRequestedEvent(
              messageId: msgId,
              messageType: chatType,
              newStatus: 41, // IMBoyMessageStatus.error
              notifyUI: true,
            ),
          );
          iPrint('✅ [DENYLIST] 消息状态已更新为 error: msgId=$msgId');
        } catch (e) {
          debugPrint('⚠️ [DENYLIST] 更新消息状态失败: $e');
        }

        try {
          // 从重试队列移除（不重试）
          AppEventBus.fire(
            RemoveFromRetryQueueRequestedEvent(
              messageId: msgId,
              messageType: chatType,
              reason: 'in_denylist',
            ),
          );
          iPrint('🗑️ [DENYLIST] 消息已从重试队列移除: msgId=$msgId');
        } catch (e) {
          debugPrint('⚠️ [DENYLIST] 从重试队列移除失败: $e');
        }
      }
    } catch (e, s) {
      iPrint('❌ [handleDenylistError] 处理异常: error=$e\nstacktrace=$s');
    }
  }
}
