import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/assets.dart' show AssetsService;
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// MessageModel → flutter_chat_core.Message 富化映射 / enrichment mapper（T4.4b）。
///
/// **架构决策（2026-06-01，T4.4b）**：将原内联于 `MessageModel` 的运行时富化逻辑
/// （E2EE 解密、payload 解析、**作者昵称/头像取数**、消息子类型构造）迁出数据模型，
/// 落入 messaging 模块的 infrastructure 层——该层**允许**依赖仓储
/// （`ContactRepo`/`UserRepoLocal`）。由此 `store/model/message_model.dart`（数据层）
/// 不再反向 import 仓储层，消除分层违规（model → repository）。
///
/// **行为不变契约**：方法体逐字搬运自原 `MessageModel.toTypeMessage()`，零行为变更；
/// 调用方语法 `msg.toTypeMessage()` 经本 extension 保持不变，仅需 import 本文件。
///
/// **Architecture decision (T4.4b)**: moves the runtime enrichment out of the
/// data model into the messaging infrastructure layer (which may depend on
/// repositories), removing the `model → repository` layering violation. Method
/// body is a verbatim relocation — zero behavior change.
extension MessageModelMapper on MessageModel {
  Future<Message> toTypeMessage() async {
    // WebSocket API v2.0: payload 可能是 Map 或 String（E2EE 场景）
    Map<String, dynamic> payloadData;

    if (payload is String) {
      // payload 是加密的 JSON 字符串（E2EE 消息）
      if (e2ee != null && e2ee!.isNotEmpty) {
        // 尝试解密 E2EE 消息
        try {
          final ciphertext = payload;
          final decryptedJson = await E2EEService.decryptE2EEMessage(
            ciphertext: ciphertext as String,
            e2ee: e2ee!,
          );
          final decoded = jsonDecode(decryptedJson);
          if (decoded is! Map<String, dynamic>) {
            throw FormatException(
              'Expected JSON object, got ${decoded.runtimeType}',
            );
          }
          payloadData = decoded;
          iPrint('✅ toTypeMessage: E2EE 解密成功，id=$id');
        } catch (e) {
          iPrint('⚠️ toTypeMessage: E2EE 解密失败，id=$id, error=$e');
          return TextMessage(
            authorId: fromId.toString(),
            createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
            id: id.toString(),
            text: '[加密消息]',
            status: MessageStatus.error,
            metadata: {
              'conversation_uk3': conversationUk3,
              'peer_id': toId,
              'msg_type': msgType ?? 'custom',
              '_e2ee_failed': true,
              '_e2ee_reason': 'decrypt_failed',
              '_e2ee_error': e.toString(),
            },
          );
        }
      } else {
        // payload 是 String 但没有 e2ee 元数据，尝试 JSON 解析
        try {
          final decoded = jsonDecode(payload as String);
          if (decoded is! Map<String, dynamic>) {
            throw FormatException(
              'Expected JSON object, got ${decoded.runtimeType}',
            );
          }
          payloadData = decoded;
        } catch (e) {
          iPrint('⚠️ toTypeMessage: payload 解析失败，id=$id, error=$e');
          return TextMessage(
            authorId: fromId.toString(),
            createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
            id: id.toString(),
            text: '[加密消息]',
            status: MessageStatus.error,
            metadata: {
              'conversation_uk3': conversationUk3,
              'peer_id': toId,
              'error': 'encrypted_payload',
            },
          );
        }
      }
    } else if (payload is Map<String, dynamic>) {
      payloadData = payload as Map<String, dynamic>;
    } else {
      iPrint('⚠️ toTypeMessage: payload 无效或为空，id=$id, payload=$payload');
      return TextMessage(
        authorId: fromId.toString(),
        createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
        id: id.toString(),
        text: '[无效消息]',
        status: MessageStatus.error,
        metadata: {
          'conversation_uk3': conversationUk3,
          'peer_id': toId,
          'error': 'invalid_payload',
        },
      );
    }

    // WebSocket API v2.0: msgType 必须在顶层（不再兼容从 payload 读取）
    final currentMsgType = msgType;
    final currentType = type;
    final currentAction = action;

    // C1 修复: 将 int 类型 ID 转为 flutter_chat_core 期望的 String 类型
    final String safeFromId = fromId.toString();
    final String safeId = id.toString();

    // 验证 msg_type 有效性
    // WebSocket API v2.0 规范：
    // - S2C 消息：如果 action 有效，msg_type 可以为空（由 action 驱动消息处理）
    // - 非 S2C 消息（C2C/C2G/C2S）：msg_type 必须非空（由 msg_type 驱动消息类型）
    bool isValidMsgType = false;
    if (currentType == 'S2C') {
      // S2C 消息：如果 action 有效，msg_type 可以为空
      isValidMsgType = (currentAction != null && currentAction.isNotEmpty);
    } else {
      // 非 S2C 消息：msg_type 必须非空
      isValidMsgType = (currentMsgType != null && currentMsgType.isNotEmpty);
    }

    if (!isValidMsgType) {
      iPrint(
        '[ERROR] toTypeMessage: msg_type 为空或无效, id=$safeId, type=$currentType, action=$currentAction',
      );
      return TextMessage(
        authorId: safeFromId,
        createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
        id: safeId,
        text: '[无效消息类型]',
        status: MessageStatus.error,
        metadata: {
          'conversation_uk3': conversationUk3,
          'peer_id': toId,
          'error': 'invalid_msg_type',
          'original_type': currentType,
        },
      );
    }

    // C2 修复: 对于 S2C 消息，如果 msg_type 为空，将其视为 'custom' 类型
    // 对于非 S2C 消息，msg_type 必须非空
    //
    // 【重构】使用 effectiveMsgType getter 获取归一化后的类型
    // 该 getter 会自动处理：
    // 1. custom -> 保持 custom
    // 2. 去除首尾空白
    // 3. 无效类型 -> 'unsupported'
    String effectiveMsgType;
    if (currentType == 'S2C') {
      // S2C 消息：msg_type 可能为空，优先使用 custom
      // 对于 S2C 消息，我们直接使用 currentMsgType（如果有），否则使用 'custom'
      effectiveMsgType = currentMsgType ?? 'custom';
      if (effectiveMsgType.isEmpty) {
        effectiveMsgType = 'custom';
      }
    } else {
      // C2C/C2G/C2S 消息：使用 effectiveMsgType getter 进行归一化
      // 统一做消息类型归一化
      effectiveMsgType = this.effectiveMsgType;
      // 这里应该不会为空，因为已经通过了 isValidMsgType 检查
    }

    String sysPrompt = payloadData['sys_prompt'] as String? ?? '';
    Message? message;
    // enum MessageType { custom, file, image, text, unsupported }
    // WebSocket API v2.0: 将 msgType、status、action、effectiveMsgType 添加到 metadata，供 UI 层使用
    Map<String, dynamic> metadata = {
      'conversation_uk3': conversationUk3,
      'sys_prompt': sysPrompt,
      'peer_id': toId,
      'msg_type': currentMsgType, // 添加 msg_type 到 metadata（原始值）
      'effective_msg_type': effectiveMsgType, // 【重构】添加归一化后的类型，UI 层优先使用此字段
      'status': status, // 添加 status 到 metadata
      'auto_id': autoId, // 添加 auto_id 到 metadata，用于分页查询
      if (currentAction != null && currentAction.isNotEmpty)
        'action': currentAction, // 添加 action 到 metadata（S2C 消息需要）
    };
    String nickname = '';
    String avatar = '';
    if (safeFromId == UserRepoLocal.to.currentUid) {
      nickname = UserRepoLocal.to.current.nickname;
      avatar = UserRepoLocal.to.current.avatar;
    } else {
      ContactModel? cm = await ContactRepo().findByUid(safeFromId);
      nickname = cm?.nickname ?? '';
      avatar = cm?.avatar ?? '';
    }
    User author = User(
      id: safeFromId,
      imageSource: avatar,
      // payload['peer_name'] 目前只在收到撤回消息的时候才存在 peer_name
      name: nickname.isEmpty
          ? ((payloadData['peer_name'] ??
                    (payloadData['quote_msg_author_name'] ?? ''))
                as String?)
          : nickname,
    );
    DateTime createdDt = DateTimeHelper.millisecondToDateTime(createdAt);

    // WebSocket API v2.0: 优先检查 status 字段（撤回状态 30-39）
    // 撤回状态应该在所有类型检查之前处理，因为 msg_type 保留的是原始内容类型
    if (IMBoyMessageStatus.isRevokedStatus(status)) {
      // status = 30 (peer_revoked) 或 31 (my_revoked)
      // 使用 CustomMessage，UI 层会根据 status 渲染撤回样式
      message = CustomMessage(
        authorId: author.id,
        id: safeId,
        createdAt: createdDt,
        metadata: {...metadata, ...payloadData},
      );
    } else if (effectiveMsgType == MessageType.text) {
      message = TextMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: safeId,
        // peerId: toId,
        text: (payloadData['text'] ?? '') as String,
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (effectiveMsgType == MessageType.image) {
      message = ImageMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: safeId,
        // peerId: toId,
        text: (payloadData['name'] ?? '') as String,
        size: (payloadData['size'] ?? 0) as int?,
        source: AssetsService.viewUrl(
          (payloadData['uri'] ?? '') as String,
        ).toString(),
        width: ((payloadData['width'] ?? 0) as num) / 1.0,
        height: ((payloadData['height'] ?? 0) as num) / 1.0,
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (effectiveMsgType == MessageType.file) {
      message = FileMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: safeId,
        // peerId: toId,
        name: (payloadData['name'] ?? '') as String,
        size: (payloadData['size'] ?? 0) as int?,
        source: AssetsService.viewUrl(
          (payloadData['uri'] ?? '') as String,
        ).toString(),
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (effectiveMsgType == MessageType.video ||
        effectiveMsgType == MessageType.voice) {
      // 视频/语音消息：使用 VideoMessage 或 AudioMessage
      // 语音消息统一使用 voice 命名
      if (effectiveMsgType == MessageType.video) {
        message = VideoMessage(
          authorId: author.id,
          createdAt: createdDt,
          id: safeId,
          // peerId: toId,
          source: AssetsService.viewUrl(
            (payloadData['uri'] ?? '') as String,
          ).toString(),
          text: (payloadData['name'] ?? '') as String?,
          name: (payloadData['name'] ?? '') as String?,
          size: (payloadData['size'] ?? 0) as int?,
          width: ((payloadData['width'] ?? 0) as num) / 1.0,
          height: ((payloadData['height'] ?? 0) as num) / 1.0,
          status: typesStatus,
          metadata: {...metadata, ...payloadData},
        );
      } else {
        // voice 消息使用 AudioMessage
        message = AudioMessage(
          authorId: author.id,
          createdAt: createdDt,
          id: safeId,
          // peerId: toId,
          source: AssetsService.viewUrl(
            (payloadData['uri'] ?? '') as String,
          ).toString(),
          text: (payloadData['name'] ?? '') as String?,
          size: (payloadData['size'] ?? 0) as int?,
          duration: Duration(
            milliseconds: (payloadData['duration_ms'] ?? 0) as int,
          ),
          waveform: payloadData['waveform'] != null
              ? List<double>.from(payloadData['waveform'] as Iterable<dynamic>)
              : null,
          status: typesStatus,
          metadata: {...metadata, ...payloadData},
        );
      }
    } else if (effectiveMsgType == MessageType.quote) {
      message = CustomMessage(
        authorId: author.id,
        id: safeId,
        createdAt: createdDt,
        // peerId: toId,
        metadata: {...metadata, ...payloadData},
      );
    } else if (effectiveMsgType == MessageType.textStream) {
      // 文本流消息：使用 TextMessage，带额外的流式 metadata
      message = TextMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: safeId,
        text: (payloadData['text'] ?? '') as String,
        status: typesStatus,
        metadata: {
          ...metadata,
          ...payloadData,
          'index': payloadData['index'] ?? 0,
          'is_end': payloadData['is_end'] ?? false,
          'stream_id': payloadData['stream_id'],
        },
      );
    } else if (effectiveMsgType == MessageType.imageMulti) {
      // 多图消息：使用 CustomMessage，带 images 数组
      message = CustomMessage(
        authorId: author.id,
        id: safeId,
        createdAt: createdDt,
        metadata: {
          ...metadata,
          ...payloadData,
          'images': payloadData['images'] ?? <String>[],
          'total': payloadData['total'] ?? 0,
        },
      );
    } else if (effectiveMsgType == 'system') {
      // 系统消息：使用 CustomMessage，系统消息通常不需要复杂处理
      message = CustomMessage(
        authorId: author.id,
        id: safeId,
        createdAt: createdDt,
        metadata: {...metadata, ...payloadData, 'is_system': true},
      );
    } else if (effectiveMsgType == MessageType.custom) {
      message = CustomMessage(
        authorId: author.id,
        id: safeId,
        createdAt: createdDt,
        // peerId: toId,
        // status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else {
      // Fallback case for unknown message types
      // 使用 unsupported 标识
      message = CustomMessage(
        authorId: author.id,
        id: safeId,
        createdAt: createdDt,
        metadata: {
          ...metadata,
          ...payloadData,
          'unsupported': true,
          'error': 'unknown_msg_type',
          'original_type': effectiveMsgType,
        },
      );
    }

    // debugPrint("> on toTypeMessage md ${toJson().toString()}");
    return message;
  }
}
