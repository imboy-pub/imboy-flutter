import 'package:imboy/modules/identity/domain/value/user_id.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/modules/messaging/domain/value/message_id.dart';

/// 消息充血实体 / Message rich entity（T1.4）。
///
/// 业务不变量（撤回/编辑判定）内聚于实体，纯函数注入 `now` 与
/// `currentUid` 便于 fake time 测试。规则逐字镜像现状
/// （service/message_actions.dart canRevokeMessage/canEditMessage）：
///   撤回：本人 + 类型∈revocableTypes + ≤2min + status==sent
///   编辑：本人 + 类型==text + ≤15min + status==sent
/// 不可变：markRevoked/markRead 返回新实例。
/// 纯 Dart——禁止 import flutter/* 与 repository/*。
class Message {
  const Message({
    required this.id,
    required this.fromId,
    required this.msgType,
    required this.createdAt,
    required this.status,
  });

  final MessageId id;
  final UserId fromId;
  final String msgType;
  final DateTime createdAt;
  final MessageStatus status;

  /// 撤回时间窗（2 分钟）。
  static const Duration revokeWindow = Duration(minutes: 2);

  /// 编辑时间窗（15 分钟）。
  static const Duration editWindow = Duration(minutes: 15);

  /// 可撤回的消息类型。
  static const Set<String> revocableTypes = {
    'text',
    'image',
    'voice',
    'video',
    'file',
    'location',
  };

  /// 是否可撤回（纯函数，注入 now）。
  bool canRevoke({required UserId currentUid, required DateTime now}) {
    if (fromId != currentUid) return false;
    if (!revocableTypes.contains(msgType)) return false;
    if (now.difference(createdAt) > revokeWindow) return false;
    if (status != MessageStatus.sent) return false;
    return true;
  }

  /// 是否可编辑（纯函数，注入 now）。
  bool canEdit({required UserId currentUid, required DateTime now}) {
    if (fromId != currentUid) return false;
    if (msgType != 'text') return false;
    if (now.difference(createdAt) > editWindow) return false;
    if (status != MessageStatus.sent) return false;
    return true;
  }

  /// 标记为已撤回（返回新实例）。
  Message markRevoked() => _copyWith(status: MessageStatus.revoked);

  /// 标记为已读（返回新实例）。
  Message markRead() => _copyWith(status: MessageStatus.seen);

  Message _copyWith({MessageStatus? status}) => Message(
    id: id,
    fromId: fromId,
    msgType: msgType,
    createdAt: createdAt,
    status: status ?? this.status,
  );
}
