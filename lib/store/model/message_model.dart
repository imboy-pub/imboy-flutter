import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/assets.dart' show AssetsService;
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/message_type_normalizer.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// enum MsgType { custom, file, image, text, unsupported }

/// ImBoy 消息状态定义
///
/// 完整的状态定义文档：doc/message_status_definition.md
///
/// ## 状态码分类
/// - **10-19**: 发送状态（消息正在发送、已发送）
/// - **20-29**: 投递/阅读状态（已投递、已读）
/// - **30-39**: 撤回状态（对方撤回、自己撤回）
/// - **40-49**: 错误状态（发送失败）
///
/// ## 重要说明
/// - `sent (11)`: 只表示客户端已成功通过 WebSocket 发送消息
///   - ⚠️ 不保证服务端已接收或投递
///   - ⚠️ 真正的投递确认需要 ACK 机制
/// - `delivered (20)`: 服务端已成功投递（需要接收方 ACK 确认）
/// - `seen (21)`: 接收方已阅读
///
/// ## 后端协议对齐
/// - ACK 确认机制：../imboy/doc/api/websocket-api-2.md
/// - WebSocket API v2.0：../imboy/doc/api/websocket-api-2.md
class IMBoyMessageStatus {
  // ==================== 发送状态 (10-19) ====================

  /// 发送中
  ///
  /// 含义：消息正在通过 WebSocket 发送到服务端
  /// 触发时机：用户点击发送按钮，消息进入发送队列
  /// UI 表现：显示发送中图标（转圈或单勾）
  /// 流转：→ sent (11) 或 error (41)
  static const int sending = 10;

  /// 已发送
  ///
  /// 含义：客户端已成功通过 WebSocket 发送消息
  /// 重要说明：
  ///   - ⚠️ 只表示客户端发送成功
  ///   - ⚠️ 不保证服务端已接收或投递
  ///   - 服务端确认需要 ACK 机制
  /// 触发时机：WebSocket sink.add() 成功执行
  /// UI 表现：显示单勾图标
  /// 流转：→ delivered (20) / seen (21) / error (41) / 撤回状态
  static const int sent = 11;

  // ==================== 投递/阅读状态 (20-29) ====================

  /// 已投递
  ///
  /// 含义：服务端已成功投递消息给接收方
  /// 确认机制：
  ///   - 接收方发送 ACK（CLIENT_ACK,C2C,msg_id,did）
  ///   - 服务端返回确认（CLIENT_ACK_CONFIRM）
  ///   - 发送方收到服务端通知
  /// 触发时机：收到服务端的投递确认
  /// UI 表现：显示双勾图标（灰色）
  /// 流转：→ seen (21) 或撤回状态
  static const int delivered = 20;

  /// 已读
  ///
  /// 含义：接收方已阅读消息
  /// 触发时机：
  ///   - 接收方打开聊天界面
  ///   - 接收方长时间停留在消息上
  /// UI 表现：显示双勾图标（蓝色）
  /// 流转：→ 撤回状态（终态）
  static const int seen = 21;

  // ==================== 撤回状态 (30-39) ====================

  /// 对方撤回（peer_revoked）
  ///
  /// 含义：消息被对方撤回
  /// 触发时机：对方执行撤回操作，收到服务端的 C2C_REVOKE S2C 消息
  /// UI 表现：显示"对方撤回"文字，原消息内容不可见
  /// 状态码：30 表示对方撤回
  /// 流转：终态
  static const int peerRevoked = 30;

  /// 自己撤回（my_revoked）
  ///
  /// 含义：消息被自己撤回
  /// 触发时机：用户执行撤回操作（2分钟内）
  /// 约束条件：只能撤回 2 分钟内发送的消息
  /// UI 表现：显示"已撤回"文字，原消息内容不可见
  /// 状态码：31 表示自己撤回
  /// 流转：终态
  static const int myRevoked = 31;

  // ==================== 错误状态 (40-49) ====================

  /// 错误（发送失败）
  ///
  /// 含义：消息发送失败
  /// 触发时机：
  ///   - WebSocket 连接断开
  ///   - 网络不可用
  ///   - 服务端返回错误
  ///   - 超时未投递
  /// UI 表现：显示红色感叹号，提供"重新发送"按钮
  /// 流转：→ sending (10)（用户重试时）
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
  // String 类型对齐 backend `binary()` msg_id 契约（imboy/src/ds/message_ds.erl:566
  // is_non_empty_binary 校验）。Xid 等 base32hex 字符串 ID 在 SQLite INTEGER 列上
  // 通过 type affinity 直接落库（接收侧 batchInsertOfflineMessages 已是该模式）。
  String id;
  String? type; // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
  int fromId; // 等价于数据库的 from
  int toId; // 等价于数据库的 to

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
    final type = parseModelString(data[MessageRepo.type], defaultValue: 'C2C');
    final fromRaw = data[MessageRepo.from] ?? data['from'];
    final toRaw = data[MessageRepo.to] ?? data['to'];

    // WebSocket API v2.0: 从顶层读取 msg_type、action、e2ee
    // 所有消息类型都可能包含这三个字段
    final msgType = parseModelNullableString(data['msg_type']);
    final action = parseModelNullableString(data['action']); // ✅ 所有类型都读取 action

    // 解析 e2ee 字段（仅 C2C/C2G 有）
    Map<String, dynamic>? e2eeData;
    if (type != 'S2C' && data['e2ee'] != null) {
      if (data['e2ee'] is String) {
        final e2eeStr = data['e2ee'] as String;
        // 检查字符串非空后再解析
        if (e2eeStr.isNotEmpty) {
          try {
            e2eeData = jsonDecode(e2eeStr) as Map<String, dynamic>?;
          } catch (_) {
            // e2ee 字段格式无效，忽略
          }
        }
      } else if (data['e2ee'] is Map) {
        e2eeData = parseModelJsonMap(data['e2ee']);
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
      parseModelString(data[MessageRepo.id]),
      autoId: parseModelInt(data[MessageRepo.autoId]),
      type: type,
      status: parseModelInt(data[MessageRepo.status]),
      fromId: parseModelInt(fromRaw),
      toId: parseModelInt(toRaw),
      payload: p,
      createdAt: DateTimeHelper.parseTimestamp(
        data[MessageRepo.createdAt],
        defaultValue: 0,
      ),
      isAuthor: parseModelInt(data[MessageRepo.isAuthor]),
      topicId: parseModelInt(data[MessageRepo.topicId]),
      conversationUk3: parseModelString(data[MessageRepo.conversationUk3]),
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

    // C2C/C2G/C2S 消息：写入 msg_type、action、e2ee
    // S2C 消息：写入 msg_type、action（不需要 e2ee）
    if (currentType != 'S2C') {
      // C2C/C2G/C2S: 写入 msg_type（非空检查）
      final msgTypeValue = msgType;
      if (msgTypeValue != null && msgTypeValue.isNotEmpty) {
        data['msg_type'] = msgTypeValue;
      }
      // C2C/C2G/C2S: 写入 action（默认为空字符串）
      data['action'] = action ?? '';
      // C2C/C2G/C2S: 写入 e2ee（必须是 Map 类型，不能是 JSON 字符串）
      if (e2ee != null && e2ee!.isNotEmpty) {
        data['e2ee'] = e2ee; // ✅ 修复：直接使用 Map，不要 json.encode()
      }
    } else {
      // S2C: 写入 msg_type 和 action（非空检查）
      final msgTypeValue = msgType;
      if (msgTypeValue != null && msgTypeValue.isNotEmpty) {
        data['msg_type'] = msgTypeValue;
      }
      if (action != null) {
        data['action'] = action;
      }
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

  /// 获取有效的消息类型（归一化后）
  ///
  /// 自动处理以下情况：
  /// 1. 去除首尾空白
  /// 2. custom → 保持 custom（不再依赖 payload 子类型字段）
  /// 3. 无效类型 → 'unsupported'
  ///
  /// ## 使用示例
  /// ```dart
  /// final msg = MessageModel(...);
  /// if (msg.effectiveMsgType == 'voice') {
  ///   // 处理语音消息
  /// }
  /// ```
  String get effectiveMsgType {
    // 使用 MessageTypeNormalizer 进行类型归一化
    return MessageTypeNormalizer.normalize(
      msgType: msgType,
      payload: payload is Map<String, dynamic>
          ? payload as Map<String, dynamic>
          : null,
    );
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

  /// 获取消息类型枚举
  ///
  /// WebSocket API v2.0: 仅使用顶层的 msgType 字段
  /// 返回 MsgTypeEnum 用于 UI 类型判断
  MsgTypeEnum get customMsgType {
    final typeValue = msgType;
    if (typeValue == null || typeValue.isEmpty) {
      return MsgTypeEnum.unsupported;
    }

    // 使用 MsgTypeEnumExtension.fromValue 进行转换
    return MsgTypeEnumExtension.fromValue(typeValue) ?? MsgTypeEnum.unsupported;
  }

  /// 获取会话列表中显示的消息类型（MessageModel 版本）
  ///
  /// 直接从数据库字段读取，不依赖 metadata
  ///
  /// ## 返回值说明
  /// - 基础类型：text, image, file, voice, video, location, quote
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
  /// - 基础类型：text, image, file, voice, video, location, quote
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
      // 不再从 payload 子类型字段推断
      return MessageType.unsupported;
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
  /// - voice: [语音]
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
        // 自定义消息不再通过 payload 子类型字段解析
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
  /// - voice: [语音]
  /// - file: [文件] 或文件名
  /// - quote: 引用的文本内容
  /// - location: 位置标题
  static String conversationSubtitle(Message message) {
    final metadata = message.metadata ?? {};

    // WebSocket API v2.0: 优先检查 status 字段（撤回状态 30-39）
    final statusValue = metadata['status'];
    final status = statusValue == null ? null : parseModelInt(statusValue);
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
        // 自定义消息不再通过 payload 子类型字段解析
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
    return await ContactRepo().findByUid(toId.toString());
  }

  Future<ContactModel?> get from async {
    return await ContactRepo().findByUid(fromId.toString());
  }

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
            ciphertext: ciphertext,
            e2ee: e2ee!,
          );
          final decoded = jsonDecode(decryptedJson);
          if (decoded is! Map<String, dynamic>) {
            throw FormatException('Expected JSON object, got ${decoded.runtimeType}');
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
          final decoded = jsonDecode(payload);
          if (decoded is! Map<String, dynamic>) {
            throw FormatException('Expected JSON object, got ${decoded.runtimeType}');
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
      payloadData = payload;
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

    String sysPrompt = payloadData['sys_prompt'] ?? '';
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
        text: payloadData['text'] ?? '',
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (effectiveMsgType == MessageType.image) {
      message = ImageMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: safeId,
        // peerId: toId,
        text: payloadData['name'] ?? '',
        size: payloadData['size'] ?? 0,
        source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
        width: (payloadData['width'] ?? 0) / 1.0,
        height: (payloadData['height'] ?? 0) / 1.0,
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (effectiveMsgType == MessageType.file) {
      message = FileMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: safeId,
        // peerId: toId,
        name: payloadData['name'] ?? '',
        size: payloadData['size'] ?? 0,
        source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (effectiveMsgType == MessageType.video || effectiveMsgType == MessageType.voice) {
      // 视频/语音消息：使用 VideoMessage 或 AudioMessage
      // 语音消息统一使用 voice 命名
      if (effectiveMsgType == MessageType.video) {
        message = VideoMessage(
          authorId: author.id,
          createdAt: createdDt,
          id: safeId,
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
        // voice 消息使用 AudioMessage
        message = AudioMessage(
          authorId: author.id,
          createdAt: createdDt,
          id: safeId,
          // peerId: toId,
          source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
          text: payloadData['name'] ?? '',
          size: payloadData['size'] ?? 0,
          duration: Duration(milliseconds: payloadData['duration_ms'] ?? 0),
          waveform: payloadData['waveform'] != null
              ? List<double>.from(payloadData['waveform'])
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
    } else if (effectiveMsgType == MessageType.imageMulti) {
      // 多图消息：使用 CustomMessage，带 images 数组
      message = CustomMessage(
        authorId: author.id,
        id: safeId,
        createdAt: createdDt,
        metadata: {
          ...metadata,
          ...payloadData,
          'images': payloadData['images'] ?? [],
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

  static MessageModel fromMessage(Message message, {String? currentUid}) {
    final Map<String, dynamic> payload = {};

    // WebSocket API v2.0: 提取 msg_type 到顶层字段
    String? msgType;

    // 根据不同类型的消息提取特定字段
    if (message is TextMessage) {
      msgType = 'text';
      payload['msg_type'] = 'text';
      payload['text'] = message.text;
      payload.addAll(message.metadata ?? {});
    } else if (message is TextStreamMessage) {
      msgType = 'textStream';
      payload['msg_type'] = 'textStream';
      payload['stream_id'] = message.streamId;
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
    } else if (message is TextStreamMessage) {
      msgType = 'textStream';
      payload['msg_type'] = 'textStream';
      payload['stream_id'] = message.streamId;
      payload.addAll(message.metadata ?? {});
    } else if (message is AudioMessage) {
      msgType = 'voice'; // WebSocket API v2.0 使用 'voice'
      payload['msg_type'] = 'voice';
      payload['name'] = message.text;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload['duration_ms'] = message.duration.inMilliseconds;
      if (message.waveform != null) {
        payload['waveform'] = message.waveform;
      }
      payload.addAll(message.metadata ?? {});
    } else if (message is SystemMessage) {
      msgType = 'system';
      payload['msg_type'] = 'system';
      payload.addAll(message.metadata ?? {});
    } else if (message is CustomMessage) {
      final customMsgType = parseModelNullableString(
        message.metadata?['msg_type'],
      );
      msgType = (customMsgType != null && customMsgType.isNotEmpty)
          ? customMsgType
          : 'custom';
      payload['msg_type'] = msgType;
      payload.addAll(message.metadata ?? {});
    }

    // 从metadata中提取可能存在的额外字段
    final metadata = message.metadata ?? {};
    // final sysPrompt = metadata['sys_prompt'] ?? '';
    final peerId = metadata['peer_id'] ?? '';
    final conversationUk3 = metadata['conversation_uk3'] ?? '';
    final type = payload['type'] ?? 'C2C';

    final uid = currentUid ?? UserRepoLocal.to.currentUid;
    return MessageModel(
      message.id,
      autoId: 0,
      type: type,
      fromId: parseModelInt(message.authorId),
      toId: parseModelInt(peerId),
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == uid ? 1 : 0,
      topicId: payload['topic_id'] ?? 0,
      conversationUk3: conversationUk3,
      status: 0,
      // WebSocket API v2.0: 设置顶层字段
      msgType: type == 'S2C' ? null : msgType,
      action: type == 'S2C'
          ? parseModelNullableString(metadata['action'])
          : null,
      e2ee: type == 'S2C' ? null : parseModelJsonMap(metadata['e2ee']),
    );
  }
}
