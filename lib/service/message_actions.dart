import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/sqlite.dart';
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
// 充血域类型统一前缀 ddd，避免与 flutter_chat_core 的 Message/MessageStatus 冲突。
import 'package:imboy/modules/identity/domain/value/user_id.dart' as ddd;
import 'package:imboy/modules/messaging/domain/message.dart' as ddd;
import 'package:imboy/modules/messaging/domain/message_status.dart' as ddd;
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/modules/messaging/domain/value/message_id.dart' as ddd;
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

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

  @visibleForTesting
  static Future<MessageModel?> Function(String type, String id)?
  messageLoaderForTest;

  /// 客户端已实现的 action 分发集合。
  ///
  /// 必须与 [handleActionMessage] 的 switch 分支逐项对齐：新增分支时同步加
  /// 到这里，否则该 action 会被当成「未实现」。
  ///
  /// 注意语义：**未实现的 action 不是错误**。未知 action 视为向前兼容的新
  /// 控制帧，忽略并回 ACK 是既定设计（见 inbound_ack_ordering_test 里刻意
  /// 构造的 `future-compatible-action`）。本集合用于识别另一种组合——
  /// 服务端把可渲染的**内容类型**同时写进 msg_type 和未实现的 action 时，
  /// 整条消息会被 action 分发吞掉。历史事故：转发消息写
  /// `msg_type=forward` + `action=forward`，收发双方都收不到任何东西。
  static const Set<String> knownActions = <String>{
    C2SAction.messageRead,
    C2SAction.messageReadAck,
    C2SAction.messageReaction,
    C2SAction.messageRevoke,
    C2SAction.messageRevokeAck,
    C2SAction.messageEdit,
    C2SAction.messageEditAck,
    C2SAction.messageInput,
    C2SAction.e2eeRoomKey,
  };

  /// action 是否已被客户端实现（未实现的按向前兼容忽略并回 ACK）
  static bool handlesAction(String action) => knownActions.contains(action);

  /// 该 msg_type 是否代表「一个携带内容的消息帧」
  ///
  /// 判据刻意**不看类型是否已注册**：真正的历史事故是 `forward`——它既未注册、
  /// 又被写进 action，如果这里要求「类型可渲染」才报警，最该被抓住的那一例
  /// 反而静默通过。只要服务端同时给了非空 msg_type 和客户端没实现的 action，
  /// 这条消息就一定会被 action 分发吞掉，无论类型认不认识。
  ///
  /// `custom` 是控制帧载体，排除。
  static bool isContentMsgType(String msgType) =>
      msgType.isNotEmpty && msgType != MessageType.custom;

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
  Future<bool> handleActionMessage(
    String action,
    Map<String, dynamic> data,
  ) async {
    iPrint(
      "🔄 处理action消息: action=$action, msgId=${data['id']}, type=${data['type']}",
    );

    try {
      switch (action) {
        case C2SAction.messageRead:
          await _handleReadAction(data);
          break;
        case C2SAction.messageReadAck:
          await _handleReadAckAction(data);
          break;
        case C2SAction.messageReaction:
          await _handleReactionAction(data);
          break;
        case C2SAction.messageRevoke:
          await _handleRevokeAction(data, isAck: false);
          break;
        case C2SAction.messageRevokeAck:
          await _handleRevokeAction(data, isAck: true);
          break;
        case C2SAction.messageEdit:
          await _handleEditAction(data, isAck: false);
          break;
        case C2SAction.messageEditAck:
          await _handleEditAction(data, isAck: true);
          break;
        case C2SAction.messageInput:
          await _handleInputAction(data);
          break;
        case C2SAction.e2eeRoomKey:
          // P0-B B4：Megolm 群会话密钥分发（不渲染、不落聊天库）
          return await GroupSessionService.to.handleRoomKeyMessage(data);
        default:
          iPrint('⚠️ [handleActionMessage] 未知的action类型: $action');
      }
      return true;
    } on Object catch (e) {
      iPrint(
        '❌ [handleActionMessage] 处理action消息异常: '
        'action=$action, error=${e.runtimeType}',
      );
      return false;
    }
  }

  Future<void> _handleReadAction(Map<String, dynamic> data) async {
    try {
      final msgType = parseModelString(data['type']);
      final payload = parseModelJsonMap(data['payload']) ?? {};
      final fromId = parseModelString(data['from']);
      final currentUid = UserRepoLocal.to.currentUid;

      if (fromId == currentUid) return;

      final idsRaw = payload['msg_ids'];
      final ids = idsRaw is List
          ? idsRaw.map((e) => e.toString()).toList()
          : <String>[];
      if (ids.isEmpty) return;

      final repo = MessageService.to.getMessageRepo(msgType);
      await _updateReadMessages(repo, ids);
    } on Object catch (e) {
      iPrint('❌ [_handleReadAction] 处理已读消息失败: ${e.runtimeType}');
      rethrow;
    }
  }

  /// 处理消息已读确认（message_read_ack）
  /// 当对方确认收到并查看了我们发送的消息时触发
  Future<void> _handleReadAckAction(Map<String, dynamic> data) async {
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
        return;
      }

      final payload = parseModelJsonMap(data['payload']) ?? {};
      final msgIdsRaw = payload['msg_ids'];
      final msgIds = msgIdsRaw is List
          ? msgIdsRaw.map((e) => e.toString()).toList()
          : <String>[];

      iPrint('📖 [_handleReadAckAction] 处理已读确认: msgId=$msgId, msgIds=$msgIds');

      if (msgIds.isEmpty) return;

      final repo = MessageService.to.getMessageRepo(msgType);
      await _updateReadMessages(repo, msgIds);
    } on Object catch (e) {
      iPrint('❌ [_handleReadAckAction] 处理已读确认失败: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> _updateReadMessages(MessageRepo repo, List<String> ids) async {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    void requireCurrent() {
      if (uid.isEmpty ||
          session.currentUid != uid ||
          !session.isCurrentSession(generation) ||
          session.isClearingSession) {
        throw StateError('read action session changed');
      }
    }

    requireCurrent();
    final updated = <Message>[];
    for (final id in ids) {
      requireCurrent();
      final message = await MessageService.to.updateStatus(
        repo,
        id,
        IMBoyMessageStatus.seen,
      );
      requireCurrent();
      if (message == null) throw StateError('read target update failed');
      final converted = await message.toTypeMessage();
      requireCurrent();
      updated.add(converted);
    }
    requireCurrent();
    if (updated.isNotEmpty) AppEventBus.fireData(updated);
  }

  Future<void> _handleReactionAction(Map<String, dynamic> data) async {
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    void requireCurrent() {
      if (uid.isEmpty ||
          session.currentUid != uid ||
          !session.isCurrentSession(generation) ||
          session.isClearingSession) {
        throw StateError('reaction action session changed');
      }
    }

    try {
      requireCurrent();
      final msgType = parseModelString(data['type']);
      final payload = parseModelJsonMap(data['payload']) ?? {};

      final originalMsgId = payload['original_msg_id']?.toString() ?? '';
      final emoji = payload['emoji']?.toString() ?? '';
      final op = payload['op']?.toString() ?? '';
      final reactorId =
          payload['user_id']?.toString() ?? data['from']?.toString() ?? '';

      if (originalMsgId.isEmpty || emoji.isEmpty || reactorId.isEmpty) {
        throw const FormatException('invalid reaction action');
      }

      final repo = MessageService.to.getMessageRepo(msgType);
      final msg = await repo.find(originalMsgId);
      requireCurrent();
      if (msg == null) throw StateError('reaction target missing');

      final newPayload = Map<String, dynamic>.from(msg.payloadMap);
      final reactionsRaw = newPayload['reactions'];
      final reactions = reactionsRaw is Map<String, dynamic>
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
      final updatedRows = await repo.update({
        'id': originalMsgId,
        'payload': json.encode(newPayload),
      });
      requireCurrent();
      if (updatedRows != 1) throw StateError('reaction target update failed');

      final updated = await repo.find(originalMsgId);
      requireCurrent();
      if (updated == null) throw StateError('updated reaction missing');
      final converted = await updated.toTypeMessage();
      requireCurrent();
      AppEventBus.fireData([converted], 'List<Message>');
    } on Object catch (e) {
      iPrint('❌ [_handleReactionAction] 处理消息表情失败: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Handle revoke action messages
  /// 处理撤回action消息
  Future<void> _handleRevokeAction(
    Map<String, dynamic> data, {
    required bool isAck,
  }) async {
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
  Future<void> _processRevokeAck(
    Map<String, dynamic> data,
    String originalMsgId,
  ) async {
    final msgType = parseModelString(data['type']);
    final currentUid = UserRepoLocal.to.currentUid;
    final generation = UserRepoLocal.to.sessionGeneration;
    void requireCurrent() {
      if (currentUid.isEmpty ||
          UserRepoLocal.to.currentUid != currentUid ||
          !UserRepoLocal.to.isCurrentSession(generation) ||
          UserRepoLocal.to.isClearingSession) {
        throw StateError('revoke ACK session changed');
      }
    }

    requireCurrent();

    final revokeMsgId = parseModelString(data['id']);

    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);
    requireCurrent();

    if (originalMsg == null) {
      throw StateError('revoke ACK target missing');
    }

    // 检查是否是我们自己撤回的
    final isMyRevoke = originalMsg.fromId.toString() == currentUid;
    if (parseModelString(data['from']) != originalMsg.fromId.toString() ||
        parseModelString(data['to']) != originalMsg.toId.toString() ||
        (msgType == 'C2C' &&
            !isMyRevoke &&
            originalMsg.toId.toString() != currentUid)) {
      throw StateError('revoke ACK sender or target mismatch');
    }

    if (isMyRevoke) {
      // 自己撤回的确认 - 使用公共撤回方法
      await MessageActions.convertMessageToRevoked(
        originalMsg: originalMsg,
        repo: repo,
        revokeUserId: currentUid,
        isMyRevoke: true, // 自己撤回
        requireCurrent: requireCurrent,
      );
      requireCurrent();
    } else {
      // 对方撤回的通知
      await _processPeerRevoke(originalMsg, repo, data, requireCurrent);
      requireCurrent();
    }
    if (isMyRevoke &&
        revokeMsgId.isNotEmpty &&
        UserRepoLocal.to.currentUid == currentUid &&
        UserRepoLocal.to.isCurrentSession(generation) &&
        !UserRepoLocal.to.isClearingSession) {
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: revokeMsgId,
          messageType: msgType,
          reason: 'revoked',
          ownerUid: currentUid,
          sessionGeneration: generation,
        ),
      );
    }
  }

  /// Process revoke request
  /// 处理撤回请求
  Future<void> _processRevokeRequest(
    Map<String, dynamic> data,
    String originalMsgId,
  ) async {
    final msgType = parseModelString(data['type']);
    final fromId = parseModelString(data['from']);
    final currentUid = UserRepoLocal.to.currentUid;
    final generation = UserRepoLocal.to.sessionGeneration;
    void requireCurrent() {
      if (currentUid.isEmpty ||
          UserRepoLocal.to.currentUid != currentUid ||
          !UserRepoLocal.to.isCurrentSession(generation) ||
          UserRepoLocal.to.isClearingSession) {
        throw StateError('revoke request session changed');
      }
    }

    requireCurrent();

    // 只有消息接收者才需要处理撤回请求
    if (fromId == currentUid) {
      iPrint('🔄 这是自己发送的撤回请求，无需处理');
      return;
    }

    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);
    requireCurrent();

    if (originalMsg == null) {
      throw StateError('revoke target missing');
    }
    final toId = parseModelString(data['to']);
    if (originalMsg.fromId.toString() != fromId ||
        originalMsg.toId.toString() != toId ||
        (msgType == 'C2C' && toId != currentUid)) {
      throw StateError('revoke sender or target mismatch');
    }

    // 处理对方撤回
    await _processPeerRevoke(originalMsg, repo, data, requireCurrent);
    requireCurrent();

    // 发送撤回确认 (v2.0 格式)
    final ackMessage = {
      'id': data['id'],
      'type': msgType,
      'from': currentUid,
      'to': fromId,
      // v2.0: 字段提升到顶层
      'msg_type': 'custom',
      'action': C2SAction.messageRevokeAck,
      'e2ee': '',
      'payload': {
        'original_msg_id': originalMsgId,
        'revoked_at': DateTimeHelper.millisecond(),
      },
    };

    iPrint(
      '🔄 发送撤回确认ACK (v2.0): msgId=${data['id']}, action=message_revoke_ack, original_msg_id=$originalMsgId',
    );
    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(ackMessage),
        messageId: data['id'] as String,
      ),
    );
  }

  /// Handle edit action messages
  /// 处理编辑action消息
  Future<void> _handleEditAction(
    Map<String, dynamic> data, {
    required bool isAck,
  }) async {
    final session = UserRepoLocal.to;
    final ownerUid = session.currentUid;
    final generation = session.sessionGeneration;
    void requireCurrent() {
      if (ownerUid.isEmpty ||
          session.currentUid != ownerUid ||
          !session.isCurrentSession(generation) ||
          session.isClearingSession) {
        throw StateError('edit action session changed');
      }
    }

    requireCurrent();
    final msgType = parseModelString(data['type']);
    final msgId = parseModelString(data['id']);
    final payload = parseModelJsonMap(data['payload']) ?? {};
    final originalMsgId = parseModelString(payload['original_msg_id']);
    final newContent = parseModelString(payload['content']);

    if (_hasEncryptedEnvelope(data) && !isAck) {
      final metadata = parseModelJsonMap(data['e2ee']) ?? {};
      final editOf = parseModelString(metadata['edit_of']);
      if (editOf.isEmpty || originalMsgId.isEmpty || editOf != originalMsgId) {
        throw const FormatException('encrypted edit target mismatch');
      }
    }

    iPrint(
      "🔄 处理编辑action: isAck=$isAck, msgType=$msgType, msgId=$msgId, originalMsgId=$originalMsgId",
    );

    if (isAck) {
      // 处理编辑确认
      await _processEditAck(data, originalMsgId, newContent, requireCurrent);
    } else {
      // 处理编辑请求
      await _processEditRequest(
        data,
        originalMsgId,
        newContent,
        requireCurrent,
      );
    }
  }

  /// Process edit acknowledgment
  /// 处理编辑确认
  Future<void> _processEditAck(
    Map<String, dynamic> data,
    String originalMsgId,
    String newContent,
    void Function() requireCurrent,
  ) async {
    final msgType = parseModelString(data['type']);
    final payload = parseModelJsonMap(data['payload']) ?? {};
    final currentUid = UserRepoLocal.to.currentUid;
    final generation = UserRepoLocal.to.sessionGeneration;

    final editMsgId = parseModelString(data['id']);

    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);
    requireCurrent();

    if (originalMsg == null) {
      throw StateError('edit ACK target missing');
    }

    // 检查是否是我们自己编辑的
    final isMyEdit = originalMsg.fromId.toString() == currentUid;

    if (isMyEdit) {
      if (parseModelString(data['from']) != currentUid ||
          parseModelString(data['to']) != originalMsg.toId.toString()) {
        throw StateError('edit ACK sender or target mismatch');
      }
      // 自己编辑的确认
      final updatedRows = await _updateEditForSession(
        repo,
        originalMsg,
        newContent,
        payload['edited_at'],
        requireCurrent,
      );
      requireCurrent();
      if (updatedRows != 1) throw StateError('edit target update failed');

      final updatedMsg = await repo.find(originalMsgId);
      requireCurrent();
      if (updatedMsg == null) throw StateError('edited message missing');
      final updatedMessage = await updatedMsg.toTypeMessage();
      requireCurrent();
      AppEventBus.fireData([updatedMessage], 'List<Message>');
    } else {
      final fromId = parseModelString(data['from']);
      final toId = parseModelString(data['to']);
      if (fromId != originalMsg.fromId.toString() ||
          toId != originalMsg.toId.toString() ||
          (msgType == 'C2C' && toId != currentUid)) {
        throw StateError('edit ACK sender or target mismatch');
      }
      await _processPeerEdit(
        originalMsg,
        repo,
        data,
        newContent,
        requireCurrent,
      );
    }
    requireCurrent();
    if (isMyEdit && editMsgId.isNotEmpty) {
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: editMsgId,
          messageType: msgType,
          reason: 'edited',
          ownerUid: currentUid,
          sessionGeneration: generation,
        ),
      );
    }
  }

  /// Process edit request
  /// 处理编辑请求
  Future<void> _processEditRequest(
    Map<String, dynamic> data,
    String originalMsgId,
    String newContent,
    void Function() requireCurrent,
  ) async {
    final msgType = parseModelString(data['type']);
    final fromId = parseModelString(data['from']);
    final currentUid = UserRepoLocal.to.currentUid;

    // 只有消息接收者才需要处理编辑请求
    if (fromId == currentUid) {
      // E2EE 编辑由服务端原样回显给发送者，外层 action 仍为
      // message_edit 以保持 PFv3 header binding；把它按本地 ACK 应用。
      if (_hasEncryptedEnvelope(data)) {
        await _processEditAck(data, originalMsgId, newContent, requireCurrent);
      } else {
        iPrint('🔄 这是自己发送的编辑请求，无需处理');
      }
      return;
    }

    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);
    requireCurrent();

    if (originalMsg == null) {
      throw StateError('edit target missing');
    }
    final toId = parseModelString(data['to']);
    if (originalMsg.fromId.toString() != fromId ||
        originalMsg.toId.toString() != toId ||
        (msgType == 'C2C' && toId != currentUid)) {
      throw StateError('edit sender or target mismatch');
    }

    // 处理对方编辑
    await _processPeerEdit(originalMsg, repo, data, newContent, requireCurrent);
    requireCurrent();

    // E2EE 编辑的服务端回显已经同时作为发送者/接收者的确认，
    // 不再发送一个包含正文的明文 ACK。
    if (_hasEncryptedEnvelope(data)) return;

    // 发送编辑确认 (v2.0 格式)
    final ackMessage = {
      'id': data['id'],
      'type': msgType,
      'from': currentUid,
      'to': fromId,
      // v2.0: 字段提升到顶层
      'msg_type': 'text',
      'action': C2SAction.messageEditAck,
      'e2ee': '',
      'payload': {
        'original_msg_id': originalMsgId,
        'content': newContent,
        'edited_at': DateTimeHelper.millisecond(),
      },
    };

    iPrint(
      '🔄 发送编辑确认ACK (v2.0): msgId=${data['id']}, action=message_edit_ack, original_msg_id=$originalMsgId',
    );
    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(ackMessage),
        messageId: data['id'] as String,
      ),
    );
  }

  /// Process peer edit
  /// 处理对方编辑
  Future<void> _processPeerEdit(
    MessageModel msg,
    MessageRepo repo,
    Map<String, dynamic> data,
    String newContent,
    void Function() requireCurrent,
  ) async {
    try {
      final payload = parseModelJsonMap(data['payload']) ?? {};

      iPrint('🔄 处理对方编辑消息: msgId=${msg.id}');

      // 更新数据库
      final updateResult = await _updateEditForSession(
        repo,
        msg,
        newContent,
        payload['edited_at'],
        requireCurrent,
      );
      requireCurrent();
      if (updateResult != 1) throw StateError('edit target update failed');

      iPrint('🔄 对方编辑更新数据库结果: $updateResult, msgId=${msg.id}');

      // 重新获取更新后的消息
      final updatedMsg = await repo.find(msg.id.toString());
      requireCurrent();
      if (updatedMsg == null) throw StateError('edited message missing');
      iPrint('🔄 重新获取更新后的消息成功: msgId=${updatedMsg.id}');

      final updatedMessage = await updatedMsg.toTypeMessage();
      requireCurrent();
      iPrint('🔄 触发编辑消息更新事件: msgId=${updatedMsg.id}');

      AppEventBus.fireData([updatedMessage], 'List<Message>');
    } on Object catch (e) {
      iPrint('❌ 处理对方编辑消息异常: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<int> _updateEditForSession(
    MessageRepo repo,
    MessageModel original,
    String content,
    dynamic editedAt,
    void Function() requireCurrent,
  ) async {
    final database = await SqliteService.to.db;
    requireCurrent();
    if (database == null) throw StateError('edit database unavailable');
    final updatedConv = await database.transaction((txn) async {
      requireCurrent();
      final current = await repo.find(original.id.toString(), txn: txn);
      requireCurrent();
      if (current == null ||
          current.fromId != original.fromId ||
          current.toId != original.toId ||
          current.type != original.type ||
          current.msgType != original.msgType ||
          current.status == IMBoyMessageStatus.peerRevoked ||
          current.status == IMBoyMessageStatus.myRevoked) {
        throw StateError('edit target changed or revoked');
      }
      final payload = Map<String, dynamic>.from(current.payloadMap);
      payload['text'] = content;
      payload['edited_at'] = editedAt ?? DateTimeHelper.millisecond();
      payload['is_edited'] = true;
      final rows = await repo.update({
        'id': current.id,
        'payload': json.encode(payload),
      }, txn: txn);
      requireCurrent();
      if (rows != 1) throw StateError('edit target update failed');
      final peerId =
          current.type == 'C2C' &&
              current.fromId.toString() != UserRepoLocal.to.currentUid
          ? current.fromId.toString()
          : current.toId.toString();
      if (peerId.isEmpty || current.type == null) return null;
      final conv = await _conversationRepo.findByPeerId(
        current.type!,
        peerId,
        txn: txn,
      );
      requireCurrent();
      if (conv == null || conv.lastMsgId != current.id) return null;
      final conversationRows = await _conversationRepo.updateById(conv.id, {
        ConversationRepo.msgType: 'text',
        ConversationRepo.subtitle: content,
      }, txn: txn);
      requireCurrent();
      if (conversationRows != 1) {
        throw StateError('edit conversation update failed');
      }
      final updated = await _conversationRepo.findById(conv.id, txn: txn);
      requireCurrent();
      if (updated == null) throw StateError('edit conversation missing');
      return updated;
    });
    requireCurrent();
    SqliteService.to.clearQueryCache(repo.tableName);
    if (updatedConv != null) AppEventBus.fireData(updatedConv);
    return 1;
  }

  /// 处理对方撤回消息的通用方法
  /// Process peer revoke message
  /// 使用公共辅助类 MessageActionHelpers 消除代码重复
  Future<void> _processPeerRevoke(
    MessageModel msg,
    MessageRepo repo,
    Map<String, dynamic> data,
    void Function() requireCurrent,
  ) async {
    try {
      // 使用公共静态方法处理撤回（isMyRevoke = false 表示对方撤回）
      await MessageActions.convertMessageToRevoked(
        originalMsg: msg,
        repo: repo,
        revokeUserId: data['from'] as String,
        isMyRevoke: false, // 对方撤回
        requireCurrent: requireCurrent,
      );
      requireCurrent();
    } on Object catch (e) {
      iPrint('❌ 处理对方撤回消息异常: ${e.runtimeType}');
      rethrow;
    }
  }

  /// 发送撤回消息请求
  /// Send revoke message request.
  Future<bool> sendRevokeMessage(String messageId, String messageType) async {
    final session = UserRepoLocal.to;
    final currentUid = session.currentUid;
    final generation = session.sessionGeneration;
    bool current() =>
        currentUid.isNotEmpty &&
        session.currentUid == currentUid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession;
    if (!current()) return false;
    try {
      final loader = messageLoaderForTest;
      final msg = await (loader != null
          ? loader(messageType, messageId)
          : MessageService.to.getMessageRepo(messageType).find(messageId));
      if (!current()) return false;

      if (msg == null) {
        iPrint('❌ 未找到要撤回的消息: messageId=$messageId');
        return false;
      }

      // 检查是否可以撤回
      if (!canRevokeMessage(msg)) {
        iPrint('❌ 消息不符合撤回条件: messageId=$messageId');
        return false;
      }

      final String toUid = msg.fromId.toString() == currentUid
          ? msg.toId.toString()
          : msg.fromId.toString();

      // v2.0: msg_type/action 字段提升到顶层
      final revokeMessage = {
        'id': Xid().toString(),
        'type': messageType,
        'from': currentUid,
        'to': toUid,
        // v2.0: 字段提升到顶层
        'msg_type': 'custom',
        'action': C2SAction.messageRevoke,
        'e2ee': '',
        'payload': {'original_msg_id': messageId},
      };

      iPrint(
        '🔄 发送撤回消息请求 (v2.0): msgId=${revokeMessage['id']}, action=message_revoke, original_msg_id=$messageId',
      );

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
          sessionGeneration: generation,
        ),
      );

      return true; // 返回 true 表示已提交发送请求
    } on Object catch (e, s) {
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
    final session = UserRepoLocal.to;
    final currentUid = session.currentUid;
    final generation = session.sessionGeneration;
    bool current() =>
        currentUid.isNotEmpty &&
        session.currentUid == currentUid &&
        session.isCurrentSession(generation) &&
        !session.isClearingSession;
    if (!current()) return false;
    try {
      final loader = messageLoaderForTest;
      final msg = await (loader != null
          ? loader(messageType, messageId)
          : MessageService.to.getMessageRepo(messageType).find(messageId));
      if (!current()) return false;

      if (msg == null) {
        iPrint('❌ 未找到要编辑的消息: messageId=$messageId');
        return false;
      }

      // 检查是否可以编辑
      if (!canEditMessage(msg)) {
        iPrint('❌ 消息不符合编辑条件: messageId=$messageId');
        return false;
      }

      // v2.0: msg_type/action 字段提升到顶层
      final editMessage = {
        'id': Xid().toString(),
        'type': messageType,
        'from': currentUid,
        'to': msg.fromId.toString() == currentUid
            ? msg.toId.toString()
            : msg.fromId.toString(),
        // v2.0: 字段提升到顶层
        'msg_type': 'text',
        'action': C2SAction.messageEdit,
        'e2ee': '',
        'payload': {'original_msg_id': messageId, 'content': newContent},
      };

      iPrint(
        '🔄 发送编辑消息请求 (v2.0): msgId=${editMessage['id']}, action=message_edit, original_msg_id=$messageId',
      );

      // 统一经过 ChatNetworkService，确保 E2EE 策略、加密失败和重试
      // 语义与普通内容消息一致；服务端只会看到 edit_of 元数据。
      return await const ChatNetworkService().sendMessage(editMessage);
    } on Object catch (e, s) {
      iPrint("❌ 发送编辑消息异常: $e; $s");
      return false;
    }
  }

  bool _hasEncryptedEnvelope(Map<String, dynamic> data) {
    final e2ee = data['e2ee'];
    if (e2ee is Map) return e2ee.isNotEmpty;
    return e2ee is String && e2ee.isNotEmpty;
  }

  /// 检查消息是否可以撤回
  /// Check if message can be revoked.
  bool canRevokeMessage(MessageModel msg) {
    try {
      // T1.5：撤回规则已内聚到充血实体 Message.canRevoke()（本人 + 类型∈
      // revocableTypes + ≤2min + status==sent）。此处仅做 store→domain 边界
      // 映射并注入 currentUid/now，规则与原实现逐字等价（行为不变）。
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
      );
      final ok = _toDomainMessage(msg)
          .canRevoke(currentUid: _currentUserId(), now: now);
      if (!ok) {
        iPrint('❌ 消息不满足撤回条件: messageId=${msg.id}, status=${msg.status}');
      }
      return ok;
    } on Object catch (e, s) {
      iPrint("❌ 检查撤回条件异常: $e; $s");
      return false;
    }
  }

  /// 检查消息是否可以编辑
  /// Check if message can be edited.
  bool canEditMessage(MessageModel msg) {
    try {
      // T1.5：编辑规则已内聚到充血实体 Message.canEdit()（本人 + 类型==text
      // + ≤15min + status==sent）。status==sent 已蕴含「未撤回」，故原冗余的
      // isRevokedStatus 校验无需保留。此处仅做边界映射 + 注入 currentUid/now。
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
      );
      final ok = _toDomainMessage(msg)
          .canEdit(currentUid: _currentUserId(), now: now);
      if (!ok) {
        iPrint('❌ 消息不满足编辑条件: messageId=${msg.id}, status=${msg.status}');
      }
      return ok;
    } on Object catch (e, s) {
      iPrint("❌ 检查编辑条件异常: $e; $s");
      return false;
    }
  }

  /// 当前登录用户 ID 值对象（未登录/空串时 UserId.parse 抛错，由调用方 try 捕获
  /// → 返回 false，与原 `fromId != currentUid` 不匹配的行为等价）。
  ddd.UserId _currentUserId() => ddd.UserId.parse(UserRepoLocal.to.currentUid);

  /// store 层 MessageModel → 充血域实体 Message 的边界映射（T1.5）。
  /// canRevoke/canEdit 不使用 id，但实体构造需 MessageId；空 id/fromId 将由
  /// 值对象构造期拒绝（抛错 → 调用方返回 false，安全且不可撤回/编辑）。
  ddd.Message _toDomainMessage(MessageModel msg) => ddd.Message(
    id: ddd.MessageId.parse(msg.id.toString()),
    fromId: ddd.UserId.parse(msg.fromId.toString()),
    msgType: msg.msgType ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(msg.createdAt),
    status: _domainStatus(msg.status),
  );

  /// store 层 IMBoyMessageStatus（int）→ 域 MessageStatus 枚举映射。
  /// 未知/null 落 error（非 sent → canRevoke/canEdit 返回 false，与原
  /// `status != IMBoyMessageStatus.sent` 行为一致）。
  ddd.MessageStatus _domainStatus(int? code) => switch (code) {
    IMBoyMessageStatus.sending => ddd.MessageStatus.sending,
    IMBoyMessageStatus.sent => ddd.MessageStatus.sent,
    IMBoyMessageStatus.delivered => ddd.MessageStatus.delivered,
    IMBoyMessageStatus.seen => ddd.MessageStatus.seen,
    IMBoyMessageStatus.peerRevoked ||
    IMBoyMessageStatus.myRevoked => ddd.MessageStatus.revoked,
    _ => ddd.MessageStatus.error,
  };

  /// 处理输入状态消息
  Future<void> _handleInputAction(Map<String, dynamic> data) async {
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
    } on Object catch (e) {
      iPrint('❌ [_handleInputAction] 处理输入状态异常: ${e.runtimeType}');
      rethrow;
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

      // 统一走 JSON action=message_input（后端 registry 路由 c2c_input 转发）。
      // 曾有的 0x25 二进制分支：后端从无该帧类型路由（收到即回
      // unsupported_frame_type ERROR 帧），toId 为数字 TSID 时必然抢跑，
      // typing 在 v2 连接上从未生效，已删除。
      final inputMessage = {
        'id': Xid().toString(),
        'type': chatType,
        'from': currentUid,
        'to': toId,
        'msg_type': 'custom',
        'action': C2SAction.messageInput,
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
    } on Object catch (e, s) {
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
    void Function()? requireCurrent,
  }) async {
    try {
      final session = UserRepoLocal.to;
      final ownerUid = session.currentUid;
      final generation = session.sessionGeneration;
      void checkSession() {
        requireCurrent?.call();
        if (ownerUid.isEmpty ||
            session.currentUid != ownerUid ||
            !session.isCurrentSession(generation) ||
            session.isClearingSession) {
          throw StateError('revoke session changed');
        }
      }

      checkSession();
      // 获取联系人信息（静态方法中创建新的仓库实例）
      final contactRepo = ContactRepo();
      final contact = await contactRepo.findByUid(revokeUserId);
      checkSession();
      iPrint("🔄 获取联系人信息: ${contact?.nickname ?? '未知用户'}");

      // 根据撤回类型设置状态码
      final revokeStatus = isMyRevoke
          ? IMBoyMessageStatus
                .myRevoked // 31: 自己撤回
          : IMBoyMessageStatus.peerRevoked; // 30: 对方撤回

      iPrint(
        '🔄 处理撤回消息: originalMsgId=${originalMsg.id}, '
        'isMyRevoke=$isMyRevoke, status=$revokeStatus',
      );

      // 更新数据库
      // WebSocket API v2.0: msg_type 保留原始内容类型，status 标识撤回状态
      final database = await SqliteService.to.db;
      checkSession();
      if (database == null) throw StateError('revoke database unavailable');
      final updatedConv = await database.transaction((txn) async {
        checkSession();
        final current = await repo.find(originalMsg.id.toString(), txn: txn);
        checkSession();
        if (current == null ||
            current.fromId != originalMsg.fromId ||
            current.toId != originalMsg.toId ||
            current.type != originalMsg.type ||
            current.msgType != originalMsg.msgType) {
          throw StateError('revoke target changed');
        }
        final newPayload = <String, dynamic>{
          'peer_name': contact?.nickname ?? '',
          'text': originalText ?? current.payload['text'] ?? '',
          'revoke_time': DateTimeHelper.millisecond(),
          'revoke_user': revokeUserId,
        };
        final rows = await repo.update({
          'id': current.id,
          'status': revokeStatus,
          'payload': json.encode(newPayload),
        }, txn: txn);
        checkSession();
        if (rows != 1) throw StateError('revoke target update failed');
        final peerId =
            current.type == 'C2C' && current.fromId.toString() != ownerUid
            ? current.fromId.toString()
            : current.toId.toString();
        if (peerId.isEmpty || current.type == null) return null;
        final conversations = ConversationRepo();
        final conversation = await conversations.findByPeerId(
          current.type!,
          peerId,
          txn: txn,
        );
        checkSession();
        if (conversation == null || conversation.lastMsgId != current.id) {
          return null;
        }
        final conversationRows = await conversations.updateById(
          conversation.id,
          {
            ConversationRepo.lastMsgStatus: revokeStatus,
            ConversationRepo.payload: json.encode(newPayload),
          },
          txn: txn,
        );
        checkSession();
        if (conversationRows != 1) {
          throw StateError('revoke conversation update failed');
        }
        final updated = await conversations.findById(conversation.id, txn: txn);
        checkSession();
        if (updated == null) throw StateError('revoke conversation missing');
        return updated;
      });
      checkSession();
      SqliteService.to.clearQueryCache(repo.tableName);
      if (updatedConv != null) AppEventBus.fireData(updatedConv);

      // 重新获取更新后的消息
      final updatedMsg = await repo.find(originalMsg.id.toString());
      checkSession();
      if (updatedMsg == null) throw StateError('revoked message missing');
      iPrint('🔄 重新获取更新后的消息成功: msgId=${updatedMsg.id}');

      final updatedMessage = await updatedMsg.toTypeMessage();
      checkSession();
      iPrint('🔄 触发撤回消息更新事件: msgId=${updatedMsg.id}');

      AppEventBus.fireData([updatedMessage], 'List<Message>');
    } on Object catch (e) {
      iPrint('❌ [convertMessageToRevoked] 处理异常: ${e.runtimeType}');
      rethrow;
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
    } on Object catch (e, s) {
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
    } on Object catch (e, s) {
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
    final ownerUid = UserRepoLocal.to.currentUid;
    final generation = UserRepoLocal.to.sessionGeneration;
    try {
      // 1. 打印调试日志
      iPrint('🚫 [NOT_A_FRIEND] msgId=$msgId, chatType=$chatType');

      // 2. 通过事件总线通知 UI 显示错误提示
      try {
        AppEventBus.fire(
          AppErrorEvent(
            message: t.chat.notFriendCannotSend,
            errorType: 'not_a_friend',
          ),
        );
        iPrint('✅ [NOT_A_FRIEND] 已发送错误提示事件');
      } on Object catch (e) {
        iPrint('[message_actions] iPrint error: $e');
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
              ownerUid: ownerUid,
              sessionGeneration: generation,
              notifyUI: true,
            ),
          );
          iPrint('✅ [NOT_A_FRIEND] 消息状态已更新为 error: msgId=$msgId');
        } on Object catch (e) {
          iPrint('[message_actions] iPrint error: $e');
        }

        try {
          // 从重试队列移除（不重试）
          AppEventBus.fire(
            RemoveFromRetryQueueRequestedEvent(
              messageId: msgId,
              messageType: chatType,
              ownerUid: ownerUid,
              sessionGeneration: generation,
              reason: 'not_a_friend',
            ),
          );
          iPrint('🗑️ [NOT_A_FRIEND] 消息已从重试队列移除: msgId=$msgId');
        } on Object catch (e) {
          iPrint('[message_actions] iPrint error: $e');
        }
      }
    } on Object catch (e, s) {
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
    final ownerUid = UserRepoLocal.to.currentUid;
    final generation = UserRepoLocal.to.sessionGeneration;
    try {
      // 1. 打印调试日志
      iPrint('🚫 [DENYLIST] msgId=$msgId, chatType=$chatType');

      // 2. 通过事件总线通知 UI 显示错误提示
      try {
        AppEventBus.fire(
          AppErrorEvent(
            message: t.common.chatErrorInDenylist,
            errorType: 'in_denylist',
          ),
        );
        iPrint('✅ [DENYLIST] 已发送错误提示事件');
      } on Object catch (e) {
        iPrint('[message_actions] iPrint error: $e');
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
              ownerUid: ownerUid,
              sessionGeneration: generation,
              notifyUI: true,
            ),
          );
          iPrint('✅ [DENYLIST] 消息状态已更新为 error: msgId=$msgId');
        } on Object catch (e) {
          iPrint('[message_actions] iPrint error: $e');
        }

        try {
          // 从重试队列移除（不重试）
          AppEventBus.fire(
            RemoveFromRetryQueueRequestedEvent(
              messageId: msgId,
              messageType: chatType,
              ownerUid: ownerUid,
              sessionGeneration: generation,
              reason: 'in_denylist',
            ),
          );
          iPrint('🗑️ [DENYLIST] 消息已从重试队列移除: msgId=$msgId');
        } on Object catch (e) {
          iPrint('[message_actions] iPrint error: $e');
        }
      }
    } on Object catch (e, s) {
      iPrint('❌ [handleDenylistError] 处理异常: error=$e\nstacktrace=$s');
    }
  }
}
