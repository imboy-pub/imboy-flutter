// 联系人标签过滤 — 纯函数决策内核
//
// 零外部依赖：不引用 ContactModel / SqliteService / Riverpod，
// 方便在 model-only 单测中直接使用 Map 数据（避开 sqflite→win32 传递链）。
//
// 调用场景：
//   - 联系人主页"按标签筛选"视图
//   - 好友选择器（建群 / 转发 / 朋友圈 @）的标签联动
//   - 标签详情页 (`contact_tag_detail_page`) 的 UID 展示过滤
// ---------------------------------------------------------------------------

/// 从联系人候选列表中按 UID 集合筛选，返回属于该集合的联系人子集。
///
/// [contacts]  联系人列表，每个元素至少包含 `peer_id`（int 或 String）字段。
/// [tagUids]   标签关联的 UID 列表（字符串形式，如 TSID）。
///
/// 匹配规则：
///   - contacts 元素的 `peer_id` 经 `toString()` 与 tagUids 比较，
///     保证 int/String 类型互通（后端 TSID BIGINT 字符串化约定）。
///   - tagUids 中的空白字符 trim 后再匹配；全空白条目被丢弃。
///
/// 语义约定：
///   - contacts 为空 → 返回空列表
///   - tagUids 为空或归一化后为空集 → 返回空列表（标签无成员即无人命中）
///   - 保持 contacts 原顺序（调用方通常已 A-Z 排序，不破坏）
///   - 返回新列表（不修改原 contacts）
List<Map<String, dynamic>> filterContactsByTagUids(
  List<Map<String, dynamic>> contacts, {
  required List<String> tagUids,
}) {
  if (contacts.isEmpty) return <Map<String, dynamic>>[];

  final tagSet = tagUids
      .map((u) => u.trim())
      .where((u) => u.isNotEmpty)
      .toSet();
  if (tagSet.isEmpty) return <Map<String, dynamic>>[];

  return contacts.where((c) {
    final raw = c['peer_id'];
    if (raw == null) return false;
    return tagSet.contains(raw.toString());
  }).toList();
}

/// 计算多个标签的 UID 并集（OR 语义：任一标签命中即入选）。
///
/// [tagUidsPerTag] 每个标签的 UID 列表（标签顺序敏感）。
///
/// 语义约定：
///   - 空白字符 trim 后丢弃
///   - 去重（同一 UID 只出现一次）
///   - 保序（按首次出现的标签顺序）
///   - 返回新列表（调用方可安全修改）
List<String> unionTagUids(List<List<String>> tagUidsPerTag) {
  final seen = <String>{};
  final out = <String>[];
  for (final list in tagUidsPerTag) {
    for (final uid in list) {
      final t = uid.trim();
      if (t.isEmpty) continue;
      if (seen.add(t)) {
        out.add(t);
      }
    }
  }
  return out;
}
