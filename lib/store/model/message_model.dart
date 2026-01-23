import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/assets.dart' show AssetsService;
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// enum MsgType { custom, file, image, text, unsupported }

/// All possible statuses message can have.
// enum Status { delivered, error, seen, sending, sent }
class IMBoyMessageStatus {
  // ==================== 发送状态 (10-19) ====================

  /// 发送中
  static const int sending = 10;

  /// 已发送
  static const int sent = 11;

  // ==================== 投递/阅读状态 (20-29) ====================

  /// 未读 已投递
  static const int delivered = 20;

  /// 已读
  static const int seen = 21;

  // ==================== 撤回状态 (30-39) ====================

  /// 对方撤回（peer_revoked）
  ///
  /// 消息被对方撤回，msg_type 保留原始内容类型（text/image等）
  /// 状态码 30 表示对方撤回，与 payload.custom_type 配合使用
  static const int peerRevoked = 30;

  /// 自己撤回（my_revoked）
  ///
  /// 消息被自己撤回，msg_type 保留原始内容类型（text/image等）
  /// 状态码 31 表示自己撤回，与 payload.custom_type 配合使用
  static const int myRevoked = 31;

  // ==================== 错误状态 (40-49) ====================

  /// 错误（发送失败）
  static const int error = 41;

  // ==================== 辅助方法 ====================

  /// 判断是否为发送状态（10-19）
  static bool isSendingStatus(int? status) {
    return status != null && status >= 10 && status < 20;
  }

  /// 判断是否为撤回状态（30-39）
  static bool isRevokedStatus(int? status) {
    return status != null && status >= 30 && status < 40;
  }

  /// 判断是否为错误状态（40-49）
  static bool isErrorStatus(int? status) {
    return status != null && status >= 40;
  }

  /// 判断消息是否显示为撤回状态
  ///
  /// WebSocket API v2.0: 检查 status 字段（30=peer_revoked, 31=my_revoked）
  static bool isRevoked(MessageModel msg) {
    return isRevokedStatus(msg.status);
  }

  /// 获取撤回状态的文本描述
  static String getRevokedStatusText(int? status) {
    switch (status) {
      case peerRevoked:
        return '对方撤回';
      case myRevoked:
        return '已撤回';
      default:
        return '已撤回';
    }
  }

  /// 判断是否为对方撤回
  static bool isPeerRevoked(int? status) {
    return status == peerRevoked;
  }

  /// 判断是否为自己撤回
  static bool isMyRevoked(int? status) {
    return status == myRevoked;
  }
}

class ReEditMessage {
  final String text;
  final String? messageId; // 添加消息ID字段，用于编辑消息

  ReEditMessage({required this.text, this.messageId});
}

class MessageModel {
  int autoId;
  String? id;
  String? type; // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
  String? fromId; // 等价于数据库的 from
  String? toId; // 等价于数据库的 to

  // WebSocket API v2.0 新增字段
  // 根据 type 决定是否存在：
  // - C2C/C2G/C2S: msgType 有值，action 为 null
  // - S2C: action 有值，msgType 为 null
  String? msgType; // 仅 C2C/C2G/C2S 消息有值, S2C 可能有值
  String? action; // 仅 S2C 消息有值
  Map<String, dynamic>? e2ee; // 仅 C2C/C2G 加密时有值

  // payload 类型改为 dynamic，支持 Map 或 String（加密后的 JSON 字符串）
  dynamic payload;
  int createdAt; // 消息创建时间 毫秒时间戳
  // type_userId_peerId
  String conversationUk3;

  // from id is author bool true | false
  int isAuthor;
  int topicId;

  // enum Status { delivered, error, seen, sending, sent }
  // MessageStatus status;
  // 10 发送中 sending;  11 已发送 send; 20 (未读 已投递) delivered;  21 已读 seen; 41 错误（发送失败） error;
  int? status;

  MessageModel(
    this.id, {
    required this.autoId,
    required this.type,
    required this.status,
    required this.fromId,
    required this.toId,
    required this.payload,
    required this.isAuthor,
    required this.conversationUk3,
    this.topicId = 0,
    this.createdAt = 0,
    this.msgType,
    this.action,
    this.e2ee,
  });

  factory MessageModel.fromJson(Map<String, dynamic> data) {
    // 解析 type
    final type = data[MessageRepo.type] as String? ?? 'C2C';

    // WebSocket API v2.0: 从顶层读取 msg_type、action、e2ee
    // 根据 type 决定读取哪些字段
    final msgType = type == 'S2C' ? null : (data['msg_type'] as String?);
    final action = type == 'S2C' ? (data['action'] as String?) : null;

    // 解析 e2ee 字段（仅 C2C/C2G 有）
    Map<String, dynamic>? e2eeData;
    if (type != 'S2C' && data['e2ee'] != null) {
      if (data['e2ee'] is String) {
        final e2eeStr = data['e2ee'] as String;
        // 检查字符串非空后再解析
        if (e2eeStr.isNotEmpty) {
          try {
            e2eeData = jsonDecode(e2eeStr) as Map<String, dynamic>?;
          } catch (e) {
            debugPrint('MessageModel: e2ee 解析失败: $e');
          }
        }
      } else if (data['e2ee'] is Map<String, dynamic>) {
        e2eeData = data['e2ee'] as Map<String, dynamic>;
      }
    }

    // 解析 payload - 支持 Map 或 String
    dynamic p;
    if (data[MessageRepo.payload] == null || data[MessageRepo.payload] == "") {
      p = <String, dynamic>{};
    } else if (data[MessageRepo.payload] is String) {
      // 尝试解析为 JSON
      try {
        p = jsonDecode("${data[MessageRepo.payload]}");
      } catch (e) {
        // 如果解析失败，保持为 String（可能是加密数据）
        p = data[MessageRepo.payload];
      }
    } else if (data[MessageRepo.payload] is Map<String, dynamic>) {
      p = data[MessageRepo.payload];
    } else {
      p = data[MessageRepo.payload];
    }

    return MessageModel(
      data[MessageRepo.id] ?? '',
      autoId: data[MessageRepo.autoId] ?? 0,
      type: type,
      status: int.parse('${data[MessageRepo.status] ?? 0}'),
      fromId: data[MessageRepo.from] ?? '',
      toId: data[MessageRepo.to] ?? '',
      payload: p,
      createdAt: DateTimeHelper.parseTimestamp(
        data[MessageRepo.createdAt],
        defaultValue: 0,
      ),
      isAuthor: data[MessageRepo.isAuthor] ?? 0,
      topicId: data[MessageRepo.topicId] ?? 0,
      conversationUk3: data[MessageRepo.conversationUk3] ?? '',
      msgType: msgType,
      action: action,
      e2ee: e2eeData,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = <String, dynamic>{};
    data[MessageRepo.id] = id;
    data[MessageRepo.autoId] = autoId;
    data[MessageRepo.type] = type;
    data[MessageRepo.status] = status;
    data[MessageRepo.from] = fromId;
    data[MessageRepo.to] = toId;
    data[MessageRepo.createdAt] = createdAt;
    data[MessageRepo.isAuthor] = isAuthor;
    data[MessageRepo.topicId] = topicId;
    data[MessageRepo.conversationUk3] = conversationUk3;

    // WebSocket API v2.0: 根据 type 写入对应字段到顶层
    final currentType = type ?? 'C2C';

    // 仅 C2C/C2G/C2S 消息写入 msg_type 和 e2ee
    if (currentType != 'S2C') {
      if (msgType != null) {
        data['msg_type'] = msgType;
      }
      if (e2ee != null && e2ee!.isNotEmpty) {
        data['e2ee'] = json.encode(e2ee);
      }
    }

    // 仅 S2C 消息写入 action
    if (currentType == 'S2C' && action != null) {
      data['action'] = action;
    }

    // payload 序列化
    if (payload is Map) {
      data[MessageRepo.payload] = json.encode(payload);
    } else if (payload is String) {
      data[MessageRepo.payload] = payload;
    } else {
      data[MessageRepo.payload] = json.encode(payload);
    }

    // debugPrint("> on MessageModel toMap $data");
    return data;
  }

  /// 10 发送中 sending;  11 已发送 sent;
  /// 20 未读 delivered;  21 已读 seen;
  /// 41 错误（发送失败） error;
  ///  enum MessageStatus { delivered, error, seen, sending, sent }
  MessageStatus get typesStatus {
    if (status == IMBoyMessageStatus.sending) {
      return MessageStatus.sending;
    } else if (status == IMBoyMessageStatus.sent) {
      return MessageStatus.sent;
    } else if (status == IMBoyMessageStatus.delivered) {
      return MessageStatus.delivered;
    } else if (status == IMBoyMessageStatus.seen) {
      return MessageStatus.seen;
    } else if (status == IMBoyMessageStatus.error) {
      return MessageStatus.error;
    }
    return MessageStatus.error;
  }

  /// 获取消息类型枚举（兼容 flutter_chat_core）
  ///
  /// WebSocket API v2.0: 优先使用顶层的 msgType 字段
  /// 返回 MsgTypeEnum 用于 UI 类型判断
  MsgTypeEnum get customMsgType {
    // WebSocket API v2.0: 优先使用顶层的 msgType 字段
    final typeValue = msgType ?? (payload is Map ? payload['msg_type'] : null);

    // 使用 MsgTypeEnumExtension.fromValue 进行转换
    return MsgTypeEnumExtension.fromValue(typeValue) ?? MsgTypeEnum.unsupported;
  }

  /// 获取会话列表中显示的消息类型（MessageModel 版本）
  ///
  /// 直接从数据库字段读取，不依赖 metadata
  ///
  /// ## 返回值说明
  /// - 基础类型：text, image, file, audio, video, location, quote
  /// - 撤回消息：保留原始类型（如 text），UI 根据 action 判断撤回状态
  static String conversationMsgTypeFromModel(MessageModel model) {
    // 直接从数据库字段读取（v2.0 规范）
    final msgType = model.msgType;
    if (msgType != null && msgType.isNotEmpty) {
      return msgType;
    }
    return MessageType.unsupported;
  }

  /// 获取会话列表中显示的消息类型（flutter_chat_core Message 版本）
  ///
  /// 从 metadata 读取（兼容 flutter_chat_core）
  ///
  /// ## 返回值说明
  /// - 基础类型：text, image, file, audio, video, location, quote
  /// - 撤回消息：保留原始类型（如 text），UI 根据 action 判断撤回状态
  static String conversationMsgType(Message message) {
    // 1. 优先从顶层 metadata 获取 msg_type（v2.0 规范）
    final topMsgType = message.metadata?['msg_type'];
    if (topMsgType is String && topMsgType.isNotEmpty) {
      return topMsgType;
    }

    // 2. 兼容 flutter_chat_core 的 Message 子类型
    if (message is TextMessage) {
      return MessageType.text;
    } else if (message is ImageMessage) {
      return MessageType.image;
    } else if (message is FileMessage) {
      return MessageType.file;
    } else if (message is CustomMessage) {
      // CustomMessage 也可能包含 msg_type
      final customMsgType = message.metadata?['msg_type'];
      if (customMsgType is String && customMsgType.isNotEmpty) {
        return customMsgType;
      }
      // 兼容旧的 custom_type（用于自定义消息子类型）
      return message.metadata?['custom_type'] ?? MessageType.unsupported;
    }

    return MessageType.unsupported;
  }

  /// 获取会话副标题（MessageModel 版本）
  ///
  /// 直接从 MessageModel 读取，避免 toTypeMessage 转换
  ///
  /// ## 规则
  /// - text: 显示文本内容
  /// - image: [图片]
  /// - video: [视频]
  /// - audio: [语音]
  /// - file: [文件] 或文件名
  /// - quote: 引用的文本内容
  /// - location: 位置标题
  static String conversationSubtitleFromModel(MessageModel model) {
    // WebSocket API v2.0: 优先检查 status 字段（撤回状态 30-39）
    if (IMBoyMessageStatus.isRevokedStatus(model.status)) {
      // 撤回消息的预览由 conversationModel 另外处理
      return '';
    }

    final msgType = model.msgType ?? MessageType.unsupported;
    final payload = model.payload is Map
        ? model.payload as Map<String, dynamic>
        : {};

    switch (msgType) {
      case MessageType.text:
        // 文本消息：直接返回文本
        return payload['text']?.toString() ?? '';

      case MessageType.image:
        return '[图片]';

      case MessageType.video:
        return '[视频]';

      case MessageType.audio:
      case MessageType.voice:
        return '[语音]';

      case MessageType.file:
        // 文件消息：显示文件名或 [文件]
        final filename =
            payload['filename']?.toString() ??
            payload['name']?.toString() ??
            '';
        return filename.isNotEmpty ? '📄 $filename' : '[文件]';

      case MessageType.quote:
        // 引用消息：显示引用的文本
        return payload['quote_text']?.toString() ?? '[引用]';

      case MessageType.location:
        // 位置消息：显示位置标题
        return payload['title']?.toString() ?? '[位置]';

      case MessageType.custom:
        // 自定义消息：根据 custom_type 处理
        final customType = payload['custom_type']?.toString() ?? '';
        if (customType == 'visit_card') {
          return payload['title']?.toString() ?? '[名片]';
        }
        return '';

      default:
        // 其他类型不显示副标题
        return '';
    }
  }

  /// 获取会话副标题（flutter_chat_core Message 版本）
  ///
  /// 从 metadata 读取（兼容 flutter_chat_core）
  ///
  /// ## 规则
  /// - text: 显示文本内容
  /// - image: [图片]
  /// - video: [视频]
  /// - audio: [语音]
  /// - file: [文件] 或文件名
  /// - quote: 引用的文本内容
  /// - location: 位置标题
  static String conversationSubtitle(Message message) {
    final metadata = message.metadata ?? {};

    // WebSocket API v2.0: 优先检查 status 字段（撤回状态 30-39）
    final status = metadata['status'] as int?;
    if (IMBoyMessageStatus.isRevokedStatus(status)) {
      // 撤回消息的预览由 conversationModel 另外处理
      return '';
    }

    final msgType = conversationMsgType(message);

    switch (msgType) {
      case MessageType.text:
        // 文本消息：直接返回文本
        if (message is TextMessage) {
          return message.text;
        }
        return metadata['text']?.toString() ?? '';

      case MessageType.image:
        return '[图片]';

      case MessageType.video:
        return '[视频]';

      case MessageType.audio:
      case MessageType.voice:
        return '[语音]';

      case MessageType.file:
        // 文件消息：显示文件名或 [文件]
        final filename =
            metadata['filename']?.toString() ??
            metadata['name']?.toString() ??
            '';
        return filename.isNotEmpty ? '📄 $filename' : '[文件]';

      case MessageType.quote:
        // 引用消息：显示引用的文本
        return metadata['quote_text']?.toString() ?? '[引用]';

      case MessageType.location:
        // 位置消息：显示位置标题
        return metadata['title']?.toString() ?? '[位置]';

      case MessageType.custom:
        // 自定义消息：根据 custom_type 处理
        final customType = metadata['custom_type']?.toString() ?? '';
        if (customType == 'visit_card') {
          return metadata['title']?.toString() ?? '[名片]';
        }
        return '';

      default:
        // 其他类型不显示副标题
        return '';
    }
  }

  int toStatus(MessageStatus status) {
    if (status == MessageStatus.sending) {
      return IMBoyMessageStatus.sending;
    } else if (status == MessageStatus.sent) {
      return IMBoyMessageStatus.sent;
    } else if (status == MessageStatus.delivered) {
      return IMBoyMessageStatus.delivered;
    } else if (status == MessageStatus.seen) {
      return IMBoyMessageStatus.seen;
    } else if (status == MessageStatus.error) {
      return IMBoyMessageStatus.error;
    }
    return IMBoyMessageStatus.error;
  }

  Future<ContactModel?> get to async {
    return await ContactRepo().findByUid(toId!);
  }

  Future<ContactModel?> get from async {
    return await ContactRepo().findByUid(fromId!);
  }

  Future<Message> toTypeMessage() async {
    // WebSocket API v2.0: 兼容新的 payload 结构（可能是 Map 或 String）
    Map<String, dynamic> payloadData;

    if (payload is String) {
      // payload 是加密的 JSON 字符串（E2EE 消息）
      if (e2ee != null && e2ee!.isNotEmpty) {
        // 尝试解密 E2EE 消息
        try {
          final ciphertext = payload;
          final decryptedJson = await E2EEService.decryptE2EEMessage(
            ciphertext: ciphertext,
            e2ee: e2ee!,
          );
          payloadData = jsonDecode(decryptedJson) as Map<String, dynamic>;
          iPrint('✅ toTypeMessage: E2EE 解密成功，id=$id');
        } catch (e) {
          iPrint('⚠️ toTypeMessage: E2EE 解密失败，id=$id, error=$e');
          return TextMessage(
            authorId: fromId!,
            createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
            id: id!,
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
        // payload 是 String 但没有 e2ee 元数据，尝试 JSON 解析（可能是旧数据）
        try {
          payloadData = jsonDecode(payload) as Map<String, dynamic>;
        } catch (e) {
          iPrint('⚠️ toTypeMessage: payload 解析失败，id=$id, error=$e');
          return TextMessage(
            authorId: fromId!,
            createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
            id: id!,
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
      payloadData = payload;
    } else {
      iPrint('⚠️ toTypeMessage: payload 无效或为空，id=$id, payload=$payload');
      return TextMessage(
        authorId: fromId!,
        createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
        id: id!,
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

    // 验证 msg_type 有效性
    if (currentMsgType == null || currentMsgType.isEmpty) {
      iPrint('❌ [toTypeMessage] msg_type 为空或无效，id=$id');
      return TextMessage(
        authorId: fromId!,
        createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
        id: id!,
        text: '[无效消息]',
        status: MessageStatus.error,
        metadata: {
          'conversation_uk3': conversationUk3,
          'peer_id': toId,
          'error': 'invalid_msg_type',
        },
      );
    }

    String sysPrompt = payloadData['sys_prompt'] ?? '';
    Message? message;
    // enum MessageType { custom, file, image, text, unsupported }
    // WebSocket API v2.0: 将 msgType 和 status 添加到 metadata，供 UI 层使用
    Map<String, dynamic> metadata = {
      'conversation_uk3': conversationUk3,
      'sys_prompt': sysPrompt,
      'peer_id': toId,
      'msg_type': currentMsgType, // 添加 msg_type 到 metadata
      'status': status, // 添加 status 到 metadata
    };
    String nickname = '';
    String avatar = '';
    if (fromId == UserRepoLocal.to.currentUid) {
      nickname = UserRepoLocal.to.current.nickname;
      avatar = UserRepoLocal.to.current.avatar;
    } else {
      ContactModel? cm = await ContactRepo().findByUid(fromId!);
      nickname = cm?.nickname ?? '';
      avatar = cm?.avatar ?? '';
    }
    User author = User(
      id: fromId!,
      imageSource: avatar,
      // payload['peer_name'] 目前只在收到撤回消息的时候才存在 peer_name
      name: nickname.isEmpty
          ? (payloadData['peer_name'] ??
                (payloadData['quote_msg_author_name'] ?? ''))
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
        id: id!,
        createdAt: createdDt,
        metadata: {...metadata, ...payloadData},
      );
    } else if (currentMsgType == 'text') {
      message = TextMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: id!,
        // peerId: toId,
        text: payloadData['text'],
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (currentMsgType == 'image') {
      message = ImageMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: id!,
        // peerId: toId,
        text: payloadData['name'] ?? '',
        size: payloadData['size'] ?? 0,
        source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
        width: (payloadData['width'] ?? 0) / 1.0,
        height: (payloadData['height'] ?? 0) / 1.0,
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (currentMsgType == 'file') {
      message = FileMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: id!,
        // peerId: toId,
        name: payloadData['name'] ?? '',
        size: payloadData['size'] ?? 0,
        source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (currentMsgType == 'video' || currentMsgType == 'voice') {
      // 视频/语音消息：使用 VideoMessage 或 AudioMessage
      if (currentMsgType == 'video') {
        message = VideoMessage(
          authorId: author.id,
          createdAt: createdDt,
          id: id!,
          // peerId: toId,
          source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
          text: payloadData['name'] ?? '',
          name: payloadData['name'] ?? '',
          size: payloadData['size'] ?? 0,
          width: (payloadData['width'] ?? 0) / 1.0,
          height: (payloadData['height'] ?? 0) / 1.0,
          status: typesStatus,
          metadata: {...metadata, ...payloadData},
        );
      } else {
        // voice/audio 消息使用 AudioMessage
        message = AudioMessage(
          authorId: author.id,
          createdAt: createdDt,
          id: id!,
          // peerId: toId,
          source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
          text: payloadData['name'] ?? '',
          size: payloadData['size'] ?? 0,
          duration: payloadData['duration_ms'] ?? 0,
          waveform: payloadData['waveform'] != null
              ? List<double>.from(payloadData['waveform'])
              : null,
          status: typesStatus,
          metadata: {...metadata, ...payloadData},
        );
      }
    } else if (payloadData['custom_type'] == 'quote') {
      message = CustomMessage(
        authorId: author.id,
        id: id!,
        createdAt: createdDt,
        // peerId: toId,
        metadata: {...metadata, ...payloadData},
      );
    } else if (currentMsgType == 'textStream' ||
        currentMsgType == 'text_stream') {
      // 文本流消息：使用 TextMessage，带额外的流式 metadata
      message = TextMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: id!,
        text: payloadData['text'] ?? '',
        status: typesStatus,
        metadata: {
          ...metadata,
          ...payloadData,
          'index': payloadData['index'] ?? 0,
          'is_end': payloadData['is_end'] ?? false,
          'stream_id': payloadData['stream_id'],
        },
      );
    } else if (currentMsgType == 'imageMulti' ||
        currentMsgType == 'image_multi') {
      // 多图消息：使用 CustomMessage，带 images 数组
      message = CustomMessage(
        authorId: author.id,
        id: id!,
        createdAt: createdDt,
        metadata: {
          ...metadata,
          ...payloadData,
          'images': payloadData['images'] ?? [],
          'total': payloadData['total'] ?? 0,
        },
      );
    } else if (currentMsgType == 'custom') {
      message = CustomMessage(
        authorId: author.id,
        id: id!,
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
        id: id!,
        createdAt: createdDt,
        metadata: {
          ...metadata,
          ...payloadData,
          'unsupported': true,
          'error': 'unknown_msg_type',
          'original_type': currentMsgType,
        },
      );
    }

    // debugPrint("> on toTypeMessage md ${toJson().toString()}");
    return message;
  }

  static MessageModel fromMessage(Message message) {
    final Map<String, dynamic> payload = {};

    // WebSocket API v2.0: 提取 msg_type 到顶层字段
    String? msgType;

    // 根据不同类型的消息提取特定字段
    if (message is TextMessage) {
      msgType = 'text';
      payload['msg_type'] = 'text';
      payload['text'] = message.text;
      payload.addAll(message.metadata ?? {});
    } else if (message is ImageMessage) {
      msgType = 'image';
      payload['msg_type'] = 'image';
      payload['name'] = message.text;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload['width'] = message.width;
      payload['height'] = message.height;
      payload.addAll(message.metadata ?? {});
    } else if (message is FileMessage) {
      msgType = 'file';
      payload['msg_type'] = 'file';
      payload['name'] = message.name;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload.addAll(message.metadata ?? {});
    } else if (message is VideoMessage) {
      msgType = 'video';
      payload['msg_type'] = 'video';
      payload['name'] = message.name ?? message.text;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload['width'] = message.width;
      payload['height'] = message.height;
      payload.addAll(message.metadata ?? {});
    } else if (message is AudioMessage) {
      msgType = 'voice'; // WebSocket API v2.0 使用 'voice'
      payload['msg_type'] = 'voice';
      payload['name'] = message.text;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload['duration_ms'] = message.duration;
      if (message.waveform != null) {
        payload['waveform'] = message.waveform;
      }
      payload.addAll(message.metadata ?? {});
    } else if (message is CustomMessage) {
      msgType = 'custom';
      payload['msg_type'] = 'custom';
      if (message.metadata?['custom_type'] != null) {
        payload['custom_type'] = message.metadata!['custom_type'];
      }
      payload.addAll(message.metadata ?? {});
    }

    // 从metadata中提取可能存在的额外字段
    final metadata = message.metadata ?? {};
    // final sysPrompt = metadata['sys_prompt'] ?? '';
    final peerId = metadata['peer_id'] ?? '';
    final conversationUk3 = metadata['conversation_uk3'] ?? '';
    final type = payload['type'] ?? 'C2C';

    return MessageModel(
      message.id,
      autoId: 0,
      type: type,
      fromId: message.authorId,
      toId: peerId,
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == UserRepoLocal.to.currentUid ? 1 : 0,
      topicId: payload['topic_id'] ?? 0,
      conversationUk3: conversationUk3,
      status: 0,
      // WebSocket API v2.0: 设置顶层字段
      msgType: type == 'S2C' ? null : msgType,
      action: type == 'S2C' ? (metadata['action'] as String?) : null,
      e2ee: type == 'S2C' ? null : (metadata['e2ee'] as Map<String, dynamic>?),
    );
  }
}
