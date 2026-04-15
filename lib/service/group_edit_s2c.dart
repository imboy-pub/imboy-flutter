/// S2C `group_edit` 通知的 payload 解析 —— slice-3 纯函数切片。
///
/// 后端 `group_handler:process_group_edit/5` 广播的 payload 形状
/// （`imboy/src/api/group_handler.erl:262-267`）：
///   Payload = Data#{<<"gid">> => Gid}
///   其中 Data 为调用方本次更新的任意字段（title / avatar /
///   introduction / type / join_limit / content_limit / member_max /
///   status / ...，随后端扩展），gid 为必需字段。
///
/// 设计要点：
///   - **不做字段白名单**：直接 passthrough，保证后端新增列时客户端
///     不需要同步升级解析器（前向兼容）。字段合法性由 `GroupRepo.update`
///     自行过滤未知列。
///   - **副本隔离**：返回的 `updates` 为独立 Map，避免调用方误改影响
///     原始 payload（被其它 handler 共享时很容易踩坑）。
///   - 将解析抽成纯函数便于单元测试 —— 不触碰 `AppEventBus` / `GroupRepo`
///     / `SqliteService` 等副作用依赖。
library;

/// 解析结果（sealed）：
///   - `GroupEditPayload`：gid 合法，updates 已剔除 gid
///   - `GroupEditParseError`：必需字段非法
sealed class GroupEditParseResult {
  const GroupEditParseResult();
}

/// 合法 payload 的结构化视图。
final class GroupEditPayload extends GroupEditParseResult {
  /// 群 ID（必需，>0）
  final int gid;

  /// 本次更新的字段集合（已剔除 gid）。
  /// 独立副本；调用方可自由修改不会影响原始入参。
  final Map<String, dynamic> updates;

  GroupEditPayload({required this.gid, required this.updates});
}

/// 解析失败。`reason` 为稳定的机器可读码：
///   - `'invalid_gid'`：gid 缺失或 <= 0
final class GroupEditParseError extends GroupEditParseResult {
  final String reason;
  const GroupEditParseError(this.reason);
}

/// 解析 S2C `group_edit` payload。
///
/// 契约：
///   - `gid` 必需，int 或可转 int 的 String，<= 0 视为非法
///   - 其它字段整体 passthrough 到 `updates`（不做白名单过滤）
///   - `updates` 可为空（仅含 gid 的 payload 合法，视为 no-op）
GroupEditParseResult parseGroupEditPayload(Map<String, dynamic> payload) {
  final gid = _asInt(payload['gid']);
  if (gid == null || gid <= 0) {
    return const GroupEditParseError('invalid_gid');
  }

  final updates = Map<String, dynamic>.from(payload)..remove('gid');
  return GroupEditPayload(gid: gid, updates: updates);
}

/// 副作用分派：解析 + 写 Repo + 广播事件。
///
/// 通过函数注入隔离 `GroupRepo` 与 `AppEventBus`，便于单元测试。
/// 真实接线见 `message_s2c.dart`。
///
/// 契约：
///   - 合法 payload：
///       - 若 `updates` 非空 → `await applyUpdate(gid, updates)`
///       - 总是调用 `fireEvent(gid, updates)`
///   - 非法 payload → 两个回调都不调用，仅 `log` 输出原因
///   - `applyUpdate` 抛异常被吞下并 log，**不影响 `fireEvent`**
///     （本地写失败不应阻塞广播通知）
Future<void> handleGroupEditS2C({
  required Map<String, dynamic> payload,
  required Future<void> Function(int gid, Map<String, dynamic> updates)
      applyUpdate,
  required void Function(int gid, Map<String, dynamic> updates) fireEvent,
  void Function(String message)? log,
}) async {
  final logFn = log ?? (_) {};
  final parsed = parseGroupEditPayload(payload);
  switch (parsed) {
    case GroupEditParseError(:final reason):
      logFn('[group_edit] parse_failed reason=$reason payload=$payload');
      return;
    case GroupEditPayload(:final gid, :final updates):
      if (updates.isNotEmpty) {
        try {
          await applyUpdate(gid, updates);
        } on Object catch (e, st) {
          logFn('[group_edit] apply_failed gid=$gid err=$e\n$st');
        }
      }
      fireEvent(gid, updates);
  }
}

int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}
