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
/// 与通知管线的组合（Q09/G1 实际接线，2026-10-07）：
///
/// ```dart
/// // message.dart C7-α-2 判定处（C2G 分支）：
/// final bool dndHit = isGroupDndActive(
///   isMutedColumn: savedConv.isMuted,
///   kvNoticeDisabled: readNoticeDisabled(gid, readBool: StorageService.to.getBool),
/// );
/// // → shouldSuppressNotification(isMuted: dndHit ? 1 : 0, isMentioned: ...)
/// ```
///
/// 两个判定函数均在 `message_conversation_utils.dart`。
/// （本文件旧注释引用的 `shouldNotifyGroupMessage`（slice-5）从未实现，
/// 属幽灵引用，已由上述组合取代。）
///
/// 群详情页开关（group_detail_page）写入时除 KV 外还会把状态投影到
/// `conversation.is_muted` 列（会话列表角标/主源一致性）；KV 仍是本开关
/// 的真源——管线侧合并判定保证只写 KV 的存量记录同样生效。
library;

/// KV 键格式。**不要硬编码此字符串到调用侧**，一律走本函数以便将来迁移。
///
/// W09.a（channel-group-ux-v2.2 §6.7 C2G 群免打扰）：键升级为
/// **来源/账号/群**范围（`group_notice_disabled:$accountUid:$gid`）。
/// StorageService 是共享设备 KV，旧键 `group_notice_disabled:$gid`
/// 不含账号、无可信所有者——**保留不删，但绝不自动导入当前账号**，
/// 新键下默认 false，由用户显式重新设置。
String groupNoticeDisabledKey(String accountUid, Object gid) =>
    'group_notice_disabled:$accountUid:$gid';

/// 读取某账号在某群的免打扰状态（账号键隔离，J16.a）。
///
/// - `gid <= 0` 或 `accountUid` 为空（未登录）→ 直接返回 `false`，
///   不调 [readBool]（防止脏键读取/跨账号读旧共享键）
/// - [readBool] 返回 `null`（未设置）→ 默认 `false`
bool readNoticeDisabled(
  Object gid, {
  required String accountUid,
  required bool? Function(String key) readBool,
}) {
  if ((BigInt.tryParse(gid.toString()) ?? BigInt.zero) <= BigInt.zero ||
      accountUid.isEmpty) {
    return false;
  }
  return readBool(groupNoticeDisabledKey(accountUid, gid)) ?? false;
}

/// 写入某账号在某群的免打扰状态（账号键隔离）。
///
/// - `gid <= 0` 或 `accountUid` 为空 → 直接返回，不调 [writeBool]
///   （防止脏键污染/写进无主旧键域）
/// - `disabled == false` 时**覆盖写 false** 而非 remove：保持语义明确
///   （"显式关闭" vs "从未设置" 在未来若做审计可区分）
Future<void> setNoticeDisabled(
  Object gid,
  bool disabled, {
  required String accountUid,
  required Future<void> Function(String key, bool value) writeBool,
}) async {
  if ((BigInt.tryParse(gid.toString()) ?? BigInt.zero) <= BigInt.zero ||
      accountUid.isEmpty) {
    return;
  }
  await writeBool(groupNoticeDisabledKey(accountUid, gid), disabled);
}
