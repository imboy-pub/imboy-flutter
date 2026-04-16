// 频道邀请 — 联系人过滤与业务决策纯函数
//
// 零外部依赖：不引用 ContactModel / SqliteService / Riverpod，
// 方便在 model-only 单测中直接使用 Map 数据。
// ---------------------------------------------------------------------------
// filterContactsForInvitation
// ---------------------------------------------------------------------------

/// 从联系人候选列表中剔除已有待处理邀请的人，返回可被邀请的联系人列表。
///
/// [contacts]         联系人列表，每个元素至少包含 `peer_id`（int）字段。
/// [pendingInviteeIds] 已有待处理邀请的被邀请者 UID 集合（字符串形式）。
///
/// 匹配规则：将 `peer_id` toString() 后与 pendingInviteeIds 比较，
/// 保证 int/String 类型互通。
List<Map<String, dynamic>> filterContactsForInvitation(
  List<Map<String, dynamic>> contacts, {
  required List<String> pendingInviteeIds,
}) {
  if (contacts.isEmpty) return [];
  if (pendingInviteeIds.isEmpty) return List.of(contacts);

  final pendingSet = pendingInviteeIds.toSet();
  return contacts
      .where((c) => !pendingSet.contains(c['peer_id']?.toString()))
      .toList();
}

// ---------------------------------------------------------------------------
// canSendChannelInvitation
// ---------------------------------------------------------------------------

/// 判断是否可以通过邀请流程添加订阅者。
///
/// 只有私有频道（type == 'private'）才需要邀请；
/// 公开频道和付费频道不走邀请流程。
bool canSendChannelInvitation(String channelType) =>
    channelType == 'private';

// ---------------------------------------------------------------------------
// extractPendingInviteeIds
// ---------------------------------------------------------------------------

/// 从已发邀请列表中提取待处理（status == 0）的被邀请者 UID 列表。
///
/// [sentInvitations] 后端返回的已发邀请列表，每条记录至少含：
///   - `invitee_uid`（String）
///   - `status`（int，0 = 待处理，1 = 已接受，2 = 已拒绝，3 = 已过期，4 = 已取消）
///
/// 跳过 invitee_uid 为空或 null 的记录，防止脏数据混入过滤集合。
List<String> extractPendingInviteeIds(
  List<Map<String, dynamic>> sentInvitations,
) {
  return sentInvitations
      .where((inv) {
        final status = inv['status'];
        return status == 0;
      })
      .map((inv) => (inv['invitee_uid'] as String? ?? '').trim())
      .where((uid) => uid.isNotEmpty)
      .toList();
}
