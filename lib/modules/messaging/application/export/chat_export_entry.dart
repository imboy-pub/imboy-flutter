/// 聊天导出条目 DTO —— 纯数据、零平台依赖（W1-C / chat_export_share_v1）。
///
/// 仅承载导出所需的「安全显示字段」：发送者显示名、创建时间、消息类型、
/// 可见正文/安全描述。映射层（W2-E/W3-J 接线时）从 `MessageModel` 构造
/// 本 DTO 时**只允许填显示字段**，从源头杜绝导出泄漏。
///
/// ⚠️ 禁止把下列内部字段搬进本 DTO（PLAN_SNAPSHOT §4.4/§4.5 禁止字段
/// 清单，导出输出不得出现）：
///   peer_id / conversation_uk3 / sender_did / sender_dtype /
///   E2EE content key / descriptor / burn_read_at / 服务端内部主键 /
///   原会话成员列表 / 原消息服务端 id
library;

import 'package:imboy/modules/messaging/domain/message_status.dart';

/// 单条消息的导出投影（不可变值对象）。
class ChatExportEntry {
  const ChatExportEntry({
    required this.msgType,
    required this.senderName,
    required this.createdAt,
    required this.status,
    this.text,
    this.quotedText,
    this.description,
    this.e2eeFailedPlaceholder = false,
    this.burnAfterRead = false,
  });

  /// 原始 msg_type（未归一）。准入与正文渲染时内部归一协议别称
  /// （audio→voice、channel_message→channel_card 等，见
  /// `chat_export_admission.dart`）。
  final String msgType;

  /// 发送者显示名（昵称/群名片）。转义在格式化层统一进行，此处存原值。
  final String senderName;

  /// 消息创建时间（本地时区）。导出按 createdAt 从旧到新稳定排序。
  final DateTime createdAt;

  /// 发送状态（域枚举）。`sending`/`error` 一律拒绝导出（内容不完整）。
  final MessageStatus status;

  /// text / textStream / quote / expression 的可见正文。
  final String? text;

  /// quote 被引用部分的可见文本（扁平化展示用）。
  final String? quotedText;

  /// 媒体/卡片的安全描述：文件名（file）、位置标题（location）、
  /// 卡片标题（channelCard / linkCard / 群协作卡等）。只放**单一显示字符串**，
  /// 禁止塞原始 payload Map。
  final String? description;

  /// E2EE 解密失败占位行（对应 UI metadata `_e2ee_failed`），拒绝导出。
  final bool e2eeFailedPlaceholder;

  /// 阅后即焚消息，v1 拒绝导出。
  final bool burnAfterRead;
}
