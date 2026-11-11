/// 合并转发构建输入 DTO —— 轻量消息快照（W2-G / chat_history_bundle_v1）。
///
/// `HistoryBundleBuilder` 不直接依赖 `MessageModel`（保持纯 Dart、零平台/
/// store 依赖，与 W1-A `MessageSelectionTraits` / W1-C `ChatExportEntry`
/// 同一口径）。上层（W3-I / Central Wiring）从 `MessageModel` 边界映射：
///
/// | 本 DTO 字段 | MessageModel 来源 |
/// |-------------|-------------------|
/// | msgType | `msgType`（原始值，归一在 builder 内完成） |
/// | sourceMessageId | `id`（仅进内存中的附件任务，**绝不进 bundle JSON**） |
/// | sourceChatType | `type`（'C2C' / 'C2G'，附件重封装绑定输入） |
/// | sourceFromUid / sourceToUid | `fromId` / `toId`（附件重封装绑定输入） |
/// | senderName | 联系人昵称/群名片（显示名，不含 uid） |
/// | sentAtMs | `createdAt` |
/// | payload | `payloadMap`（E2EE 行须先解密成功，失败行标 e2eeFailedPlaceholder） |
/// | status | 域 `MessageStatus`（`typesStatus` 边界映射） |
/// | e2eeFailedPlaceholder | UI `metadata['_e2ee_failed'] == true` |
/// | burnReadAtMs | `payloadMap['burn_read_at']`（>0 即焚毁行） |
///
/// ⚠️ 进入构建的消息**必须全部可合并**（上层多选阶段已按 §4.4 过滤）；
/// 仍出现不可合并项时 builder 整体拒绝并返回错误码，不静默跳过。
library;

import 'package:imboy/modules/messaging/domain/message_status.dart';

/// 单条待合并消息的最小快照（不可变）。
class HistoryBundleSourceMessage {
  const HistoryBundleSourceMessage({
    required this.sourceMessageId,
    required this.sourceChatType,
    required this.sourceFromUid,
    required this.sourceToUid,
    required this.sentAtMs,
    required this.status,
    this.msgType,
    this.senderName,
    this.payload = const <String, dynamic>{},
    this.e2eeFailedPlaceholder = false,
    this.burnReadAtMs = 0,
  });

  /// 原始 msg_type（未归一；S2C/系统行可为 null）。
  final String? msgType;

  /// 原消息 id（Xid）。只用于附件转发任务的源绑定，禁止写入 bundle。
  final String sourceMessageId;

  /// 原消息会话类型（'C2C' / 'C2G'；附件重封装 `sourceChatType` 入参）。
  final String sourceChatType;

  /// 原消息发送方 uid（附件重封装 `sourceFromUid` 入参）。
  final String sourceFromUid;

  /// 原消息接收方 uid（附件重封装 `sourceToUid` 入参）。
  final String sourceToUid;

  /// 发送者显示名（进 entries[].sender_name）。
  final String? senderName;

  /// 消息创建时间（毫秒时间戳；排序键）。
  final int sentAtMs;

  /// 已解码 payload（E2EE 行须解密成功后才进入构建）。
  final Map<String, dynamic> payload;

  /// 域消息状态；sending/error/revoked 一律整体拒绝。
  final MessageStatus status;

  /// E2EE 解密失败占位行（整体拒绝，reason `rejected_e2ee_failed`）。
  final bool e2eeFailedPlaceholder;

  /// 阅后即焚时间戳（毫秒）；>0 整体拒绝。
  final int burnReadAtMs;
}
