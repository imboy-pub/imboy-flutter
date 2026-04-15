/// 消息长按操作能力决策 —— 纯函数(仅依赖 flutter_chat_core)
///
/// slice-C-3c: `_onMessageLongPress` 中 `isSentByMe` 依赖
/// `UserRepoLocal.to.currentUid` 单例,`canRetry` 为两条件组合,均内联在
/// Widget 方法体中零测试覆盖。提取后注入 currentUid,可独立单测钉死矩阵契约。
///
/// **LongPressCapabilities** 携带能力矩阵:
///   - isSentByMe             = (authorId == currentUid)
///   - canRetry               = isSentByMe && status == error
///   - canRevoke              = isSentByMe  (derived getter)
///   - canDeleteForEveryone   = isSentByMe  (derived getter)
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';

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

  /// 是否可撤回(= isSentByMe,独立 getter 便于阅读)。
  bool get canRevoke => isSentByMe;

  /// 是否可全员删除(= isSentByMe)。
  bool get canDeleteForEveryone => isSentByMe;
}

/// 计算消息长按操作能力矩阵。
///
/// - [messageAuthorId] 消息的 authorId
/// - [currentUid]      当前登录用户 id(注入以避免 UserRepoLocal.to 单例)
/// - [messageStatus]   消息当前状态
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
