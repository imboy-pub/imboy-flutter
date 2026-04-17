/// 朋友圈好友选择器决策纯函数（Slice B-1）。
///
/// 零外部依赖（只引 dart:core），避开 sqflite→win32 传递测试链。
/// 负责：
///   - 单 uid 切换（加入 / 移除）
///   - 标签批量切换（标签全选 / 全取消）
///   - 输出规范化（去重 + 过滤空白 + 稳定排序）
library;

/// 切换单个 uid 的选中状态。
///
/// - uid 为空 / 全空白 → 原样返回（不做任何修改）
/// - uid 已存在 → 移除
/// - uid 不存在 → 添加
///
/// 始终返回**新副本**，不修改入参（不可变语义）。
Set<String> togglePickedUid(Set<String> current, String uid) {
  final trimmed = uid.trim();
  if (trimmed.isEmpty) return Set<String>.from(current);
  final next = Set<String>.from(current);
  if (next.contains(trimmed)) {
    next.remove(trimmed);
  } else {
    next.add(trimmed);
  }
  return next;
}

/// 批量切换某个标签下的所有好友 uid。
///
/// - select=true → 把 tagUids 全部加入 current
/// - select=false → 把 tagUids 全部从 current 移除
/// - tagUids 内空白 / 空串元素会被忽略
///
/// 始终返回**新副本**。
Set<String> applyTagToggle(
  Set<String> current,
  List<String> tagUids, {
  required bool select,
}) {
  final next = Set<String>.from(current);
  for (final raw in tagUids) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    if (select) {
      next.add(trimmed);
    } else {
      next.remove(trimmed);
    }
  }
  return next;
}

/// 将选中的 uid 集合规范化为提交给服务端的 payload。
///
/// - 过滤空 / 全空白
/// - 去重（Set 天然去重，此处仅二次保险）
/// - 按字典序排序保证 payload 确定性（便于对比、缓存、测试断言）
List<String> sortUidsForPayload(Set<String> selected) {
  final list = selected
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList(growable: false);
  list.sort();
  return list;
}

/// 判断标签下的 uid 在当前选中集里是**全选** / **部分选** / **未选**。
///
/// 用于 UI 上展示 Tag Chip 的三态（已选/半选/未选）。
TagSelectionState resolveTagSelectionState(
  Set<String> current,
  List<String> tagUids,
) {
  final normalized = tagUids
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  if (normalized.isEmpty) return TagSelectionState.none;
  final hit = normalized.where(current.contains).length;
  if (hit == 0) return TagSelectionState.none;
  if (hit == normalized.length) return TagSelectionState.all;
  return TagSelectionState.partial;
}

/// 标签选中三态。
enum TagSelectionState { none, partial, all }
