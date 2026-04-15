/// 群消息免打扰的本地持久化 —— slice-6 (C6 持久化子切片) GREEN-21。
///
/// ## 设计取舍
///
/// 免打扰是**用户-设备本地偏好**（不跨端同步，不影响服务端状态），
/// 因此用 KV 存储而非数据库列：
///   - 避开 v20 migration（规避 `file_picker → win32` 环境债务牵连）
///   - 键名 stable（`group_notice_disabled:${gid}`），grep 可定位
///   - 函数注入 read/write → 纯函数单测，不依赖 `StorageService.to` 单例
///
/// ## 调用侧接线（伪代码）
///
/// ```dart
/// // 读
/// final disabled = readNoticeDisabled(
///   gid,
///   readBool: StorageService.to.getBool,
/// );
///
/// // 写
/// await setNoticeDisabled(
///   gid,
///   true,
///   writeBool: StorageService.to.setBool,
/// );
/// ```
///
/// 与 `shouldNotifyGroupMessage`（slice-5）组合：
///
/// ```dart
/// final shouldPush = shouldNotifyGroupMessage(
///   noticeDisabled: readNoticeDisabled(gid, readBool: StorageService.to.getBool),
///   fromSelf: msg.fromId == currentUid,
///   isMentioned: ..., // slice-?（@ 模块）
/// );
/// ```
library;

/// KV 键格式。**不要硬编码此字符串到调用侧**，一律走本函数以便将来迁移。
String groupNoticeDisabledKey(int gid) => 'group_notice_disabled:$gid';

/// 读取某群的免打扰状态。
///
/// - `gid <= 0` → 直接返回 `false`，不调 [readBool]（防止 KV 脏键读取）
/// - [readBool] 返回 `null`（未设置）→ 默认 `false`
bool readNoticeDisabled(
  int gid, {
  required bool? Function(String key) readBool,
}) {
  if (gid <= 0) return false;
  return readBool(groupNoticeDisabledKey(gid)) ?? false;
}

/// 写入某群的免打扰状态。
///
/// - `gid <= 0` → 直接返回，不调 [writeBool]（防止 KV 脏键污染）
/// - `disabled == false` 时**覆盖写 false** 而非 remove：保持语义明确
///   （"显式关闭" vs "从未设置" 在未来若做审计可区分）
Future<void> setNoticeDisabled(
  int gid,
  bool disabled, {
  required Future<void> Function(String key, bool value) writeBool,
}) async {
  if (gid <= 0) return;
  await writeBool(groupNoticeDisabledKey(gid), disabled);
}
