// 频道添加管理员 — 选人与角色决策纯函数
//
// 零外部依赖：不引用 ContactModel / SqliteService / Riverpod，
// 方便在 model-only 单测中直接使用 Map 数据。
// ---------------------------------------------------------------------------
// filterContactsForAdmin
// ---------------------------------------------------------------------------

/// 从联系人候选列表中剔除已是管理员的人，返回可被添加为管理员的联系人列表。
///
/// [contacts]        联系人列表，每个元素至少包含 `peer_id`（int）字段。
/// [existingAdminIds] 已是管理员的用户 ID 集合（字符串形式，对应后端返回值）。
///
/// 匹配规则：将 `peer_id` toString() 后与 existingAdminIds 比较，
/// 保证 int/String 类型互通。
List<Map<String, dynamic>> filterContactsForAdmin(
  List<Map<String, dynamic>> contacts, {
  required List<String> existingAdminIds,
}) {
  if (contacts.isEmpty) return [];
  if (existingAdminIds.isEmpty) return List.of(contacts);

  final adminSet = existingAdminIds.toSet();
  return contacts
      .where((c) => !adminSet.contains(c['peer_id']?.toString()))
      .toList();
}

// ---------------------------------------------------------------------------
// searchContactCandidates
// ---------------------------------------------------------------------------

/// 在候选列表中按关键字过滤，同时匹配 nickname / remark / account。
///
/// - 空关键字返回全部候选（不过滤）。
/// - 匹配策略：包含（contains），大小写不敏感。
List<Map<String, dynamic>> searchContactCandidates(
  List<Map<String, dynamic>> candidates,
  String keyword,
) {
  final kwd = keyword.trim();
  if (kwd.isEmpty) return List.of(candidates);

  final lower = kwd.toLowerCase();
  return candidates.where((c) {
    final nickname = (c['nickname'] as String? ?? '').toLowerCase();
    final account = (c['account'] as String? ?? '').toLowerCase();
    final remark = (c['remark'] as String? ?? '').toLowerCase();
    return nickname.contains(lower) ||
        account.contains(lower) ||
        remark.contains(lower);
  }).toList();
}

// ---------------------------------------------------------------------------
// validateAdminRole
// ---------------------------------------------------------------------------

/// 校验角色值是否为可手动指定的合法管理员角色。
///
/// 合法值：
/// - 1 = editor（可发布消息）
/// - 2 = admin（可管理频道）
///
/// 非法值：
/// - 0 = none / subscriber（无权限，不应手动指定）
/// - 3 = creator（由系统自动赋予，不允许手动设置）
/// - 其他任意值
bool validateAdminRole(int role) => role == 1 || role == 2;

// ---------------------------------------------------------------------------
// defaultAdminRole
// ---------------------------------------------------------------------------

/// 添加管理员时的默认角色：editor(1)。
///
/// 遵循最小权限原则：默认赋予编辑权限，
/// 创建者可在添加后手动升级为 admin(2)。
int defaultAdminRole() => 1;
