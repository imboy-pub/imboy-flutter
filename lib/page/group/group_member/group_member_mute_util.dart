/// 群成员禁言状态更新（纯函数模块，无 Flutter 依赖，可在纯单测下运行）。
///
/// BUG-11 修复支撑：原 `group_member_page.dart` 在 S2C 禁言/解禁事件回调中
/// 对 `_memberList[idx].muteUntilMs` 原地赋值，违反项目不可变性约定，
/// 多处持有同一 Model 引用时会产生幽灵状态。此处提供不可变更新：
/// 返回**新列表**（仅替换匹配成员为 copyWith 新实例），原列表与原实例不被修改。
library;

import 'package:imboy/store/model/group_member_model.dart';

/// 返回将 [userId] 对应成员的禁言截止时间更新为 [muteUntilMs] 后的**新列表**。
///
/// - [muteUntilMs] 传 `null` 表示解禁（显式置空 muteUntilMs）。
/// - 若列表中无匹配 [userId]，返回与入参等价的新列表（不抛异常）。
/// - 不修改入参 [members] 及其中任何 Model 实例（不可变更新）。
List<GroupMemberModel> applyMemberMuteUpdate(
  List<GroupMemberModel> members,
  String userId,
  int? muteUntilMs,
) {
  return [
    for (final m in members)
      if (m.userId.toString() == userId)
        m.copyWith(
          muteUntilMs: muteUntilMs,
          clearMuteUntil: muteUntilMs == null,
        )
      else
        m,
  ];
}
