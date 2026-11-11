/// 附件转发适配接口 —— W2-G 只定义接口 + 注入，不复制实现。
///
/// bundle 内附件类条目（image/imageMulti/voice/audio/video/file）在构建期
/// 只产出**占位快照**（仅显示字段，不含对象引用）；真实重传/重封装由本
/// 接口在发送前执行。实现方（Central Wiring / W3 接线）桥接到既有能力：
///
/// - 带 content key（E2EE）附件 → `AttachmentForward.reSeal` /
///   `reSealImages`（下载→认证解密→新绑定/新密钥→重上传，改写
///   uri / file_hash256 / size / descriptor）；
/// - 明文附件 → `PlainAttachmentForward.reupload`（下载→按目标 scope
///   重上传→回写对象引用）。
///
/// 调用契约（测试钉死）：
/// 1. [BundleAttachmentForwardRequest] 必须携带**新 message id**、目标
///    scope、目标会话标识与转发者 uid——附件必须按新 message ID、目标
///    会话和转发者重新封装（PLAN_SNAPSHOT §4.5）；
/// 2. 返回改写后的完整 entry payload（新 uri / file_hash256 / descriptor），
///    发送入口用 `HistoryBundleV1.withEntryPayload` 写回；
/// 3. 任一任务失败实现方抛异常，调用方**整条放弃发送**（无半转发状态，
///    与 send_to_provider 单条转发同语义）。
library;

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';

export 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart'
    show HistoryBundleBuildErrorCode;

/// 构建期产出的附件转发任务描述（内存对象，绝不序列化进 bundle）。
class BundleAttachmentForwardTask {
  const BundleAttachmentForwardTask({
    required this.entryIndex,
    required this.sourceMsgType,
    required this.sourceMessageId,
    required this.sourceChatType,
    required this.sourceFromUid,
    required this.sourceToUid,
    required this.sourcePayload,
  });

  /// 对应 bundle.entries 的下标（apply 时写回位置）。
  final int entryIndex;

  /// 归一后的源消息类型（image/imageMulti/voice/video/file）。
  final String sourceMsgType;

  /// 源消息 id（重封装 AAD 源绑定输入）。
  final String sourceMessageId;

  /// 源会话类型（'C2C'/'C2G'，重封装源绑定输入）。
  final String sourceChatType;

  /// 源消息发送方 uid（重封装源绑定输入）。
  final String sourceFromUid;

  /// 源消息接收方 uid（重封装源绑定输入）。
  final String sourceToUid;

  /// 完整源 payload（含 descriptor/uri；仅在内存中传给 adapter，
  /// 不进入 bundle JSON）。
  final Map<String, dynamic> sourcePayload;
}

/// 任务 + 目标绑定参数 → adapter 的完整调用请求。
class BundleAttachmentForwardRequest {
  const BundleAttachmentForwardRequest({
    required this.task,
    required this.newMessageId,
    required this.targetScope,
    required this.targetConversationUk3,
    required this.forwarderUid,
  });

  /// 待执行任务（含源绑定五元组）。
  final BundleAttachmentForwardTask task;

  /// 新消息 id（上传锚点 anchor_msg_id + 重封装 AAD 目标绑定）。
  final String newMessageId;

  /// 目标上传 scope（`ChatAttachmentHandler.deriveUploadScope` 产物：
  /// `'group'` / ``'c2c:<minUid>:<maxUid>'``）。
  final String targetScope;

  /// 目标会话标识（重封装 targetConversationId 绑定）。
  final String targetConversationUk3;

  /// 转发者 uid（重封装 sender_uid 绑定）。
  final String forwarderUid;
}

/// 附件转发适配器抽象。实现由 Central Wiring / W3 注入；本文件不 import
/// 任何具体转发实现。
abstract interface class BundleAttachmentForwarder {
  /// 执行单个附件任务，返回改写后的 entry payload（新 uri / file_hash256 /
  /// descriptor / size），失败抛异常（调用方整条放弃，无半转发状态）。
  Future<Map<String, dynamic>> forwardAttachment(
    BundleAttachmentForwardRequest request,
  );
}

/// 把构建期任务绑定为目标请求（纯函数，发送入口用）。
///
/// [newMessageId] 每目标会话独立生成（bundle 按目标单独构建，附件锚点
/// 同样按目标独立）；[targetScope] 用
/// `ChatAttachmentHandler.deriveUploadScope(target)` 计算。
List<BundleAttachmentForwardRequest> bindBundleAttachmentTasks({
  required List<BundleAttachmentForwardTask> tasks,
  required String newMessageId,
  required String targetScope,
  required String targetConversationUk3,
  required String forwarderUid,
}) {
  return [
    for (final task in tasks)
      BundleAttachmentForwardRequest(
        task: task,
        newMessageId: newMessageId,
        targetScope: targetScope,
        targetConversationUk3: targetConversationUk3,
        forwarderUid: forwarderUid,
      ),
  ];
}

/// 尺寸复检（附件写回后、发送前）。
///
/// 附件 payload 替换会改变序列化体积；发送入口在 `withEntryPayload` 之后
/// 必须重跑本检查（超限返回
/// [HistoryBundleBuildErrorCode.payloadTooLarge]，整条放弃）。
String? validateBundlePayloadSize(int serializedByteLength) {
  if (serializedByteLength > HistoryBundleContract.maxPayloadBytes) {
    return HistoryBundleBuildErrorCode.payloadTooLarge;
  }
  return null;
}
