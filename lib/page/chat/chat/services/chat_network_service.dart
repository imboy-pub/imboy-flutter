import 'dart:convert';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/modules/security_privacy/public.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 消息网络发送服务
///
/// 负责消息的 WebSocket 发送、E2EE 加密、重试逻辑以及
/// 添加消息到本地会话等功能。
///
/// 从 ChatNotifier 提取，保持公共 API 不变。
class ChatNetworkService {
  const ChatNetworkService();

  // ===== 添加消息到会话 =====

  /// 添加消息到会话（同时写库 + 发 WebSocket）
  Future<void> addMessage({
    required Ref ref,
    required SqliteChatService chatService,
    required String fromId,
    required String toId,
    required String? avatar,
    required String title,
    required String type,
    required Message message,
    bool sendToServer = true,
    required Future<void> Function() syncMessagesToState,
  }) async {
    iPrint(
      '📤 [ChatNetworkService.addMessage] 开始: msgId=${message.id}, type=$type, toId=$toId, sendToServer=$sendToServer',
    );
    try {
      final String subtitle = MessageModel.conversationSubtitle(message);
      final String msgType = MessageModel.conversationMsgType(message);
      final int createdAt = DateTimeHelper.millisecond();

      final ConversationRepo repo = ConversationRepo();
      ConversationModel? conversation = await repo.findByPeerId(type, toId);

      iPrint(
        '📤 [ChatNetworkService.addMessage] 会话查找: conversation=${conversation != null ? conversation.uk3 : 'null'}',
      );

      if (conversation == null) {
        conversation = await ref
            .read(conversationProvider.notifier)
            .createConversation(
              type: type,
              peerId: toId,
              avatar: avatar ?? '',
              title: title,
              subtitle: "",
              lastTime: createdAt,
            );
        iPrint('📤 [ChatNetworkService.addMessage] 创建新会话: ${conversation.uk3}');
      }

      if (conversation.id > 0) {
        final updates = <String, dynamic>{
          ConversationRepo.subtitle: subtitle,
          ConversationRepo.msgType: msgType,
          ConversationRepo.lastMsgId: message.id,
          ConversationRepo.lastTime: createdAt,
          ConversationRepo.lastMsgStatus: sendToServer ? 10 : 11,
          ConversationRepo.unreadNum: conversation.unreadNum,
          ConversationRepo.isShow: 1,
        };
        if (title.isNotEmpty) {
          updates[ConversationRepo.title] = title;
        }
        await repo.updateById(conversation.id, updates);
        iPrint(
          '📤 [ChatNetworkService.addMessage] 更新会话完成: ${conversation.uk3}',
        );
      }

      final MessageModel obj = getMsgFromTMsg(type, conversation.uk3, message);
      final String tb = MessageRepo.getTableName(conversation.type);
      iPrint(
        '📤 [ChatNetworkService.addMessage] 准备插入数据库: table=$tb, msgId=${obj.id}',
      );
      try {
        final insertResult = await (MessageRepo(tableName: tb)).insert(obj);
        iPrint(
          '📤 [ChatNetworkService.addMessage] 数据库插入完成: msgId=${obj.id}, result=$insertResult',
        );
      } catch (e) {
        iPrint(
          '❌ [ChatNetworkService.addMessage] 数据库插入异常: msgId=${obj.id}, error=$e',
        );
        rethrow;
      }

      AppEventBus.fireData(conversation);
      iPrint(
        "📤 [ChatNetworkService.addMessage] 发送事件到 EventBus: msgId=${message.id}, type: $type, toId: $toId, sendToServer=$sendToServer",
      );

      if (sendToServer) {
        iPrint('📤 [ChatNetworkService.addMessage] 准备通过 WebSocket 发送消息');
        await sendWsMsg(obj);
        iPrint(
          '📤 [ChatNetworkService.addMessage] WebSocket 发送完成: msgId=${obj.id}',
        );
      }

      if (message is ImageMessage) {
        ref
            .read(imageGalleryProvider.notifier)
            .pushToLast(message.id, message.source);
      }

      iPrint('✅ [ChatNetworkService.addMessage] 完成: msgId=${message.id}');

      await syncMessagesToState();
    } catch (e, stack) {
      iPrint(
        '❌ [ChatNetworkService.addMessage] 异常: msgId=${message.id}, error=$e',
      );
      iPrint('❌ [ChatNetworkService.addMessage] stackTrace: $stack');
      rethrow;
    }
  }

  // ===== 消息模型转换 =====

  /// 从UI层消息模型转换为数据库模型（可供外部调用）
  /// WebSocket API v2.0: msg_type 字段提升到顶层，payload 只包含内容
  MessageModel getMsgFromTMsg(
    String type,
    String conversationUk3,
    Message message,
  ) {
    if (message.id.isEmpty) {
      iPrint('[ERROR] getMsgFromTMsg: Message ID cannot be empty');
      throw ArgumentError('Message ID cannot be empty');
    }
    if (message.authorId.isEmpty) {
      iPrint('[ERROR] getMsgFromTMsg: Message authorId cannot be empty');
      throw ArgumentError('Message authorId cannot be empty');
    }
    if (message.createdAt == null) {
      iPrint('[ERROR] getMsgFromTMsg: Message createdAt cannot be null');
      throw ArgumentError('Message createdAt cannot be null');
    }

    Map<String, dynamic> payload = {};
    final metadata = message.metadata ?? <String, dynamic>{};

    String msgType = '';

    if (message is TextMessage) {
      msgType = 'text';
      payload = {"text": message.text};
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is ImageMessage) {
      msgType = 'image';
      payload = {
        "name": message.text,
        "text": message.text,
        "size": message.size,
        "uri": message.source,
        "width": message.width,
        "height": message.height,
        "thumbhash": message.thumbhash,
      };
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is FileMessage) {
      msgType = 'file';
      payload = {
        "name": message.name,
        "text": message.name,
        "size": message.size,
        "uri": message.source,
        "mime_type": message.mimeType,
        "file_hash256":
            message.metadata?["file_hash256"] ?? message.metadata?["md5"],
      };
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is VideoMessage) {
      msgType = 'video';
      payload = {
        "name": message.name ?? (message.text ?? ''),
        "size": message.size,
        "uri": message.source,
        "width": message.width,
        "height": message.height,
      };
      if (message.text != null) {
        payload['text'] = message.text;
      }
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is AudioMessage) {
      msgType = 'voice';
      payload = {
        "uri": message.source,
        "duration_ms": message.duration.inMilliseconds,
        "size": message.size,
      };
      if (message.text != null) {
        payload['name'] = message.text;
      }
      if (message.waveform != null) {
        payload['waveform'] = message.waveform;
      }
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is TextStreamMessage) {
      msgType = 'textStream';
      payload = {"stream_id": message.streamId};
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is SystemMessage) {
      msgType = 'system';
      payload = Map<String, dynamic>.from(metadata);
      payload.remove('msg_type');
      payload.remove('action');
      payload.remove('e2ee');
    } else if (message is CustomMessage) {
      final customMsgType = message.metadata?['msg_type']?.toString() ?? '';
      msgType = customMsgType.isNotEmpty ? customMsgType : 'custom';
      final cleanMetadata = Map<String, dynamic>.from(message.metadata ?? {});
      cleanMetadata.remove('msg_type');
      cleanMetadata.remove('action');
      cleanMetadata.remove('e2ee');
      payload = {...cleanMetadata};
    } else {
      msgType = 'unsupported';
      iPrint(
        '[WARN] getMsgFromTMsg: 未知的消息类型: ${message.runtimeType}，默认使用 unsupported',
      );
      payload = {
        'error': 'unknown_message_type',
        'runtime_type': message.runtimeType.toString(),
      };
    }

    final String sysPrompt = message.metadata?['sys_prompt'] as String? ?? '';
    if (strNoEmpty(sysPrompt)) {
      payload['sys_prompt'] = sysPrompt;
    }
    payload['peer_id'] = message.metadata?['peer_id'];

    final MessageModel obj = MessageModel(
      message.id,
      autoId: 0,
      type: type,
      fromId: int.tryParse(message.authorId) ?? 0,
      toId: int.tryParse(message.metadata?['peer_id']?.toString() ?? '') ?? 0,
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == UserRepoLocal.to.currentUid ? 1 : 0,
      conversationUk3: conversationUk3,
      status: IMBoyMessageStatus.sending,
      msgType: msgType,
      action: '',
    );
    obj.status = obj.toStatus(message.status ?? MessageStatus.sending);
    return obj;
  }

  /// 辅助：清理 metadata 并合并到 payload
  void _cleanAndAddMetadata(
    Map<String, dynamic> payload,
    Map<String, dynamic> metadata,
  ) {
    final cleanMetadata = Map<String, dynamic>.from(metadata);
    cleanMetadata.remove('msg_type');
    cleanMetadata.remove('action');
    cleanMetadata.remove('e2ee');
    payload.addAll(cleanMetadata);
  }

  // ===== WebSocket 发送 =====

  /// 通过 WebSocket 发送消息（含 E2EE 加密）
  Future<bool> sendWsMsg(MessageModel obj) async {
    iPrint('📤 [sendWsMsg] 开始: msgId=${obj.id}, status=${obj.status}');
    if (obj.status != IMBoyMessageStatus.sending) {
      iPrint(
        '⚠️ [sendWsMsg] 消息状态不是 sending，跳过发送: msgId=${obj.id}, status=${obj.status}',
      );
      return true;
    }

    final int clientSendTs = DateTimeHelper.millisecond();
    final Map<String, dynamic> payloadWithTs = Map<String, dynamic>.from(
      obj.payload as Map<dynamic, dynamic>,
    );
    payloadWithTs['client_send_ts'] = clientSendTs;

    final String msgType = obj.msgType ?? '';
    final String action = obj.action ?? '';
    Map<String, dynamic>? e2ee;
    dynamic finalPayload;

    final bool needEncrypt =
        action.isEmpty &&
        E2EEService.shouldEncryptOutgoingPayload(obj.type ?? 'C2C');

    if (needEncrypt) {
      try {
        final encrypted = await encryptPayload(
          chatType: obj.type ?? 'C2C',
          toId: obj.toId.toString(),
          plaintextMap: obj.payload as Map<String, dynamic>,
          action: action,
          removeKeys: ['client_send_ts'],
        );
        if (encrypted != null) {
          e2ee = encrypted['e2ee'] as Map<String, dynamic>;
          finalPayload = encrypted['payload'];
        } else {
          finalPayload = payloadWithTs;
        }
      } catch (e, stackTrace) {
        iPrint('❌ [E2EE] v2.0 加密失败: msgId=${obj.id}, error=$e');
        AppLogger.error(
          'E2EE加密失败(sendWsMsg) - msgId:${obj.id} msgType:${obj.type} to:${obj.toId}',
          e,
          stackTrace,
        );
        AppLoading.showToast(getE2EEErrorMessage(e));
        if (obj.id.isNotEmpty) {
          await updateMessageStatus(obj.id, IMBoyMessageStatus.error);
        }
        return false;
      }
    } else {
      finalPayload = payloadWithTs;
    }

    iPrint(
      '📤 [发送 v2.0] msgId: ${obj.id}, msg_type: $msgType, action: $action, e2ee: ${e2ee != null}',
    );

    final Map<String, dynamic> msg = {
      'id': obj.id,
      'type': obj.type,
      'from': obj.fromId,
      'to': obj.toId,
      'msg_type': msgType,
      'action': action,
      'e2ee': e2ee,
      'payload': finalPayload,
      'created_at': obj.createdAt,
    };

    if (obj.id.isEmpty) {
      iPrint('消息ID为空，无法发送');
      return false;
    }
    return await sendWithRetry(obj.id, msg);
  }

  /// 直接发送消息（不经过数据库），含 E2EE 加密
  Future<bool> sendMessage(Map<String, dynamic> msg) async {
    iPrint('ChatNetworkService.sendMessage: ${json.encode(msg)}');

    final String chatType = msg['type']?.toString() ?? '';
    final String msgAction = msg['action']?.toString() ?? '';
    final dynamic originalPayload = msg['payload'];

    if (!msg.containsKey('msg_type') &&
        originalPayload is Map<String, dynamic>) {
      msg['msg_type'] = originalPayload['msg_type']?.toString() ?? '';
    }
    if (!msg.containsKey('action')) {
      msg['action'] = msgAction;
    }

    if (originalPayload is Map<String, dynamic>) {
      final payload = Map<String, dynamic>.from(originalPayload);

      final bool needEncrypt =
          msgAction.isEmpty &&
          E2EEService.shouldEncryptOutgoingPayload(chatType);

      if (needEncrypt) {
        try {
          final String toUid = msg['to']?.toString() ?? '';
          final encrypted = await encryptPayload(
            chatType: chatType,
            toId: toUid,
            plaintextMap: payload,
            action: msgAction,
            removeKeys: ['msg_type'],
          );
          if (encrypted != null) {
            msg['e2ee'] = encrypted['e2ee'];
            msg['payload'] = encrypted['payload'];
            iPrint(
              'ChatNetworkService.sendMessage: E2EE v2.0 加密成功 (${msg['id']})',
            );
          }
        } catch (e, stackTrace) {
          iPrint('ChatNetworkService.sendMessage: E2EE v2.0 加密失败: $e');
          AppLogger.error(
            'E2EE加密失败 - msgId:${msg['id']?.toString()} msgType:${msg['type']?.toString()} to:${msg['to']?.toString()}',
            e,
            stackTrace,
          );
          AppLoading.showToast(getE2EEErrorMessage(e));
          return false;
        }
      } else {
        final cleanPayload = Map<String, dynamic>.from(payload);
        cleanPayload.remove('msg_type');
        cleanPayload.remove('action');
        cleanPayload.remove('e2ee');
        msg['payload'] = cleanPayload;
      }
    }

    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(msg),
        messageId: msg['id']?.toString(),
      ),
    );

    final String? msgId = msg['id']?.toString();
    if (msgId != null && msgId.isNotEmpty) {
      final String type = msg['type']?.toString() ?? 'C2C';
      MessageRetry.instance.addToRetryQueue(msgId, type);
    }

    iPrint('ChatNetworkService.sendMessage已提交: ${msg['id']}');
    return true;
  }

  /// 带重试机制的消息发送
  Future<bool> sendWithRetry(String messageId, Map<String, dynamic> msg) async {
    try {
      iPrint(
        '📤 [sendWithRetry] 开始发送: msgId=$messageId, type=${msg['type']}, msgType=${msg['msg_type']}',
      );

      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(msg),
          messageId: messageId,
        ),
      );

      final String type = msg['type']?.toString() ?? 'C2C';
      MessageRetry.instance.addToRetryQueue(messageId, type);

      iPrint('✅ [sendWithRetry] 消息已提交到重试队列: msgId=$messageId');
      return true;
    } catch (e) {
      iPrint('❌ [sendWithRetry] 消息发送失败: msgId=$messageId, 错误: $e');
      await updateMessageStatus(messageId, IMBoyMessageStatus.error);
      return false;
    }
  }

  /// 更新消息状态
  Future<void> updateMessageStatus(String messageId, int status) async {
    try {
      final bool found = await MessageRepo.updateStatusInAnyTable(
        messageId,
        status,
      );
      if (found) {
        for (final String tableType in ['C2C', 'C2G', 'C2S']) {
          final String tb = MessageRepo.getTableName(tableType);
          final repo = MessageRepo(tableName: tb);
          final msg = await repo.find(messageId);
          if (msg != null) {
            final updatedMessage = await msg.toTypeMessage();
            AppEventBus.fireData([updatedMessage], 'List<Message>');
            break;
          }
        }
      }
    } catch (e) {
      iPrint('更新消息状态失败: $messageId, $e');
    }
  }

  // ===== E2EE 加密 =====

  /// E2EE 加密 payload
  /// 返回加密后的 {e2ee, payload}，或 null 表示不需要加密
  /// 失败时抛出异常，调用方负责处理
  Future<Map<String, dynamic>?> encryptPayload({
    required String chatType,
    required String toId,
    required Map<String, dynamic> plaintextMap,
    required String action,
    List<String> removeKeys = const [],
  }) async {
    final bool needEncrypt =
        action.isEmpty && E2EEService.shouldEncryptOutgoingPayload(chatType);
    if (!needEncrypt) return null;

    final deviceKeys = await (chatType == 'C2G'
        ? E2EEService.getGroupDevicePublicKeys(toId)
        : E2EEService.getUserDevicePublicKeys(toId));
    final didToPem = deviceKeys['didToPem'] ?? {};
    if (didToPem.isEmpty) {
      throw Exception('no_recipient_keys');
    }
    // 零信任契约：kid 取后端返回的 key_id（device_id→key_id 映射）；
    // 缺失时回退 device_id 兼容旧数据，避免发送中断。
    final didToKid = deviceKeys['didToKid'] ?? {};

    final recipients = <RecipientDevice>[];
    for (final entry in didToPem.entries) {
      recipients.add(
        RecipientDevice(
          deviceId: entry.key,
          keyId: didToKid[entry.key] ?? entry.key,
          publicKey: entry.value,
        ),
      );
    }

    final plaintextPayload = Map<String, dynamic>.from(plaintextMap);
    for (final key in removeKeys) {
      plaintextPayload.remove(key);
    }
    final plaintext = jsonEncode(plaintextPayload);

    final result = await E2EEService.buildE2EEData(
      plaintext: plaintext,
      recipients: recipients,
    );

    return {
      'e2ee': result['e2ee'] as Map<String, dynamic>,
      'payload': result['ciphertext'] as String,
    };
  }

  /// 生成 E2EE 加密失败的用户友好错误消息
  String getE2EEErrorMessage(dynamic error) {
    final String errorStr = error.toString().toLowerCase();

    if (errorStr.contains('no_recipient_keys') ||
        errorStr.contains('设备密钥') ||
        errorStr.contains('device.*key')) {
      return t.common.e2eeErrNoRecipientKey;
    }
    if (errorStr.contains('timeout') || errorStr.contains('超时')) {
      return t.error.e2eeErrTimeout;
    }
    if (errorStr.contains('network') || errorStr.contains('网络')) {
      return t.error.e2eeErrNetwork;
    }
    if (errorStr.contains('invalid') || errorStr.contains('格式')) {
      return t.chat.e2eeErrInvalidFormat;
    }
    return t.main.e2eeErrDefault;
  }

  // ===== 群组操作 =====

  /// 获取群组标题
  Future<String> groupTitle(String gid, String prefix, int num) async {
    final String prefix2 = strNoEmpty(prefix) ? prefix : t.chat.groupChat;
    if (num > 0) {
      return "$prefix2($num)";
    } else {
      final GroupModel? g = await GroupDetailService().detail(gid: gid);
      final int memberCount = g?.memberCount ?? 0;
      if (memberCount > 0) {
        return "$prefix2($memberCount)";
      }
      return prefix2;
    }
  }

  // ===== 队列操作（read receipts / reactions）=====

  /// 构建已读回执消息体（v2.0 格式）
  Map<String, dynamic> buildReadReceiptItem(
    String type,
    String peerId,
    List<String> msgIds,
    int now,
  ) {
    return <String, dynamic>{
      'id': Xid().toString(),
      'type': type,
      'from': UserRepoLocal.to.currentUid,
      'to': peerId,
      'msg_type': 'custom',
      'action': 'message_read',
      'e2ee': '',
      'payload': {'msg_ids': msgIds, 'read_at': now},
      'created_at': now,
    };
  }
}
