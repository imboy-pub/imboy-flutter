/// 消息长按操作能力决策 —— 纯函数（纯 Dart，零外部依赖）。
///
/// slice-C-3c / T4.2b: `_onMessageLongPress` 中 `isSentByMe` 依赖
/// `UserRepoLocal.to.currentUid` 单例,`canRetry` 为两条件组合,均内联在
/// Widget 方法体中零测试覆盖。提取后注入 currentUid,可独立单测钉死矩阵契约。
///
/// T4.2b: 入参 `messageStatus` 由 `flutter_chat_core.MessageStatus` 改为域
/// [MessageStatus]（边界映射在调用点 chat_page 完成），本文件从而成为纯 Dart
/// 领域策略,归属 domain/policy。
///
/// **LongPressCapabilities** 携带长按菜单能力矩阵:
///   - isSentByMe             = (authorId == currentUid)
///   - canRetry               = isSentByMe && status == error
///   - canRevoke              = isSentByMe  (derived getter)
///   - canDeleteForEveryone   = isSentByMe  (derived getter)
///
/// ⚠️ 语义边界（勿与 [Message.canRevoke] 混淆）:
///   此处 `canRevoke = isSentByMe` 是**长按菜单"撤回"入口的可见性门控**
///   （粗粒度,仅判断是否本人发送）。撤回操作的**真实可行性**（本人 ∧
///   类型∈revocable ∧ ≤2min ∧ status==sent）由领域实体 `Message.canRevoke()`
///   负责,二者语义正交,不可合并。
library;

import 'package:imboy/modules/messaging/domain/message_status.dart';

/// 消息长按操作能力集合。
///
/// 由 [resolveLongPressCapabilities] 计算,作为不可变值对象传入 `showMessageActionMenu`。
class LongPressCapabilities {
  const LongPressCapabilities({
    required this.isSentByMe,
    required this.canRetry,
  });

  /// 消息是否由当前用户发出。
  final bool isSentByMe;

  /// 是否可重试(仅自己发送的 error 状态消息)。
  final bool canRetry;

  /// 是否可撤回(= isSentByMe,菜单入口门控,非领域撤回不变量)。
  bool get canRevoke => isSentByMe;

  /// 是否可全员删除(= isSentByMe)。
  bool get canDeleteForEveryone => isSentByMe;
}

/// 计算消息长按操作能力矩阵。
///
/// - [messageAuthorId] 消息的 authorId
/// - [currentUid]      当前登录用户 id(注入以避免 UserRepoLocal.to 单例)
/// - [messageStatus]   消息当前状态(域 [MessageStatus])
LongPressCapabilities resolveLongPressCapabilities({
  required String messageAuthorId,
  required String currentUid,
  required MessageStatus messageStatus,
}) {
  final isSentByMe = messageAuthorId == currentUid;
  return LongPressCapabilities(
    isSentByMe: isSentByMe,
    canRetry: isSentByMe && messageStatus == MessageStatus.error,
  );
}
