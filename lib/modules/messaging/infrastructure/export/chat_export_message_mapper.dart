/// flutter_chat_core [Message] → [ChatExportEntry] 边界映射（W3-J）。
///
/// 遵守 W1-C handoff DTO 白名单：**只填安全显示字段**——
/// senderName=显示名、msgType 原值（归一在准入/格式化内部）、
/// status→域枚举、text/quotedText/description 仅从 payload 白名单键
/// （text / quote_text / filename / name / title）提取。
/// 严禁带入 peer_id / conversation_uk3 / sender_did / sender_dtype /
/// content key / descriptor / burn_read_at / 服务端主键 / 成员列表。
///
/// 字段口径与多选 traits 提取（chat_message_item.dart
/// `messageSelectionTraitsOf`）一致；两处独立维护，改口径需同步。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;

import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart' as domain;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 批量映射选中消息为导出 DTO。
///
/// - [senderNameResolver]：发送者显示名解析（authorId → 昵称）。
///   缺省 = 仓储口径（自己→UserRepoLocal，他人→ContactRepo），与
///   message_model_mapper 一致；接线方也可传聊天页 UserCache 版本。
/// - **无 msg_type 的消息被丢弃**（metadata 缺失且消息类无兜底 →
///   与多选 fail-closed 同口径，正常不可能出现在选中集合里）。
Future<List<ChatExportEntry>> chatExportEntriesFromMessages(
  List<core.Message> messages, {
  Future<String> Function(core.UserID authorId)? senderNameResolver,
}) async {
  final entries = <ChatExportEntry>[];
  for (final message in messages) {
    final msgType = _msgTypeOf(message);
    if (msgType == null) continue;
    final metadata = message.metadata;
    entries.add(
      ChatExportEntry(
        msgType: msgType,
        senderName: await _senderNameOf(message, senderNameResolver),
        createdAt: message.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        status: _statusOf(message),
        text: _textOf(message),
        quotedText: _stringOf(metadata?['quote_text']),
        description: _descriptionOf(message),
        e2eeFailedPlaceholder: metadata?['_e2ee_failed'] == true,
        burnAfterRead:
            (parseModelNullableInt(metadata?['burn_read_at']) ?? 0) > 0,
      ),
    );
  }
  return entries;
}

/// metadata['msg_type'] 优先；缺失时按消息类兜底（CustomMessage/SystemMessage
/// 无兜底 → null → 丢弃，fail-closed）。
String? _msgTypeOf(core.Message message) {
  final metaType = message.metadata?['msg_type']?.toString();
  if (metaType != null && metaType.isNotEmpty) {
    return metaType;
  }
  if (message is core.TextMessage) return MessageType.text;
  if (message is core.ImageMessage) return MessageType.image;
  if (message is core.FileMessage) return MessageType.file;
  if (message is core.VideoMessage) return MessageType.video;
  if (message is core.AudioMessage) return MessageType.audio;
  return null;
}

/// flutter_chat_core 状态 → 域枚举（null → sent，与多选口径一致）。
domain.MessageStatus _statusOf(core.Message message) {
  switch (message.status) {
    case core.MessageStatus.error:
      return domain.MessageStatus.error;
    case core.MessageStatus.sending:
      return domain.MessageStatus.sending;
    case core.MessageStatus.delivered:
      return domain.MessageStatus.delivered;
    case core.MessageStatus.seen:
      return domain.MessageStatus.seen;
    case core.MessageStatus.sent:
      return domain.MessageStatus.sent;
    case null:
      return domain.MessageStatus.sent;
  }
}

/// 可见正文：TextMessage.text；其余类型从 metadata['text'] 提取。
String? _textOf(core.Message message) {
  if (message is core.TextMessage) {
    return message.text;
  }
  return _stringOf(message.metadata?['text']);
}

/// 安全描述（file 文件名 / location 标题 / 卡片标题）：
/// FileMessage.name 优先，其后 metadata 白名单 filename → name → title。
String? _descriptionOf(core.Message message) {
  if (message is core.FileMessage) {
    final name = message.name.trim();
    if (name.isNotEmpty) return name;
  }
  final metadata = message.metadata;
  for (final key in const ['filename', 'name', 'title']) {
    final value = _stringOf(metadata?[key]);
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String? _stringOf(Object? raw) {
  if (raw is String) return raw;
  return null;
}

/// 发送者显示名：注入 resolver 优先；空/缺失时回落 metadata 载荷名
/// （peer_name → quote_msg_author_name，与 message_model_mapper 的
/// User.name 兜底同源）；仍无 → 空串（导出内部标识是泄漏，宁空勿泄）。
Future<String> _senderNameOf(
  core.Message message,
  Future<String> Function(core.UserID)? resolver,
) async {
  final resolved = resolver != null
      ? (await resolver(message.authorId)).trim()
      : '';
  if (resolved.isNotEmpty) return resolved;
  final metadata = message.metadata;
  return _stringOf(
        metadata?['peer_name'] ?? metadata?['quote_msg_author_name'],
      ) ??
      '';
}

/// 缺省发送者名解析（仓储口径，与 message_model_mapper 同源）。
///
/// `autoFetch: false`：导出是读操作，禁止隐式发起联系人网络回填。
Future<String> defaultChatExportSenderName(core.UserID authorId) async {
  try {
    if (authorId.toString() == UserRepoLocal.to.currentUid) {
      return UserRepoLocal.to.current.nickname;
    }
    return (await ContactRepo().findByUid(
          authorId.toString(),
          autoFetch: false,
        ))?.nickname ??
        '';
  } on Object {
    // 仓储未就绪（测试/早退语境）：回落空串，不阻断导出。
    return '';
  }
}
