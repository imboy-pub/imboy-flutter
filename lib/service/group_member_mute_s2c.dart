/// S2C `group_member_mute` 通知的 payload 解析 —— 纯函数切片。
///
/// 后端 `group_member_logic:mute_notice/4` 广播的 payload 形状：
///   {
///     "gid": int,
///     "mute_until": int (ms),
///     "remaining_seconds": int,
///     "duration_text": String,
///     "admin_nickname": String
///   }
///
/// **slice-1-finalize（2026-04-15）**：后端 `mute_notice/4` 已补 `user_id`
/// 字段。客户端解析向后兼容：老后端不带 user_id 时 `userId == ''`，调用方
/// 应据此跳过 Repo 写入，仅做群级 toast；新后端带 user_id 时调用方可定位
/// 具体成员行调用 `GroupMemberRepo.update`。
///
/// 将解析抽成纯函数便于单元测试 —— 不触碰 `AppEventBus` / `EasyLoading` /
/// `SqliteService` 等副作用依赖。
library;

/// 解析结果（sealed）：
///   - `GroupMemberMutePayload` 字段齐全、合法
///   - `GroupMemberMuteParseError` 必需字段缺失或非法
sealed class GroupMemberMuteParseResult {
  const GroupMemberMuteParseResult();
}

/// 合法 payload 的结构化视图。
final class GroupMemberMutePayload extends GroupMemberMuteParseResult {
  /// 群 ID（必需，>0）
  final int gid;

  /// 禁言到期时间戳，毫秒 epoch（必需，>0）
  final int muteUntilMs;

  /// 剩余秒数（来自后端计算，可选，缺失默认 0）
  final int remainingSeconds;

  /// 可读的禁言时长文案，如 "10分钟"（可选，缺失默认 ''）
  final String durationText;

  /// 执行禁言的管理员昵称（可选，缺失默认 ''）
  final String adminNickname;

  /// 被禁言成员的 user_id（TSID 字符串）。
  ///
  /// - 后端 `mute_notice/4` payload 含 `<<"user_id">> => UserId`（slice-1-finalize）
  /// - 老版本后端不带此字段时为 `''`；调用方应跳过 Repo 写入，仅做群级 toast
  /// - 数字 / 字符串混入均归一化为字符串；`0` / 空白归一化为 `''`
  final String userId;

  const GroupMemberMutePayload({
    required this.gid,
    required this.muteUntilMs,
    required this.remainingSeconds,
    required this.durationText,
    required this.adminNickname,
    this.userId = '',
  });
}

/// 解禁 payload（slice-9b）。
///
/// 后端 `group_member_logic:unmute/3` 复用同一 S2C `group_member_mute` action，
/// 通过 `mute_until == 0` 作为解禁信号。客户端据此将 Repo 的 `mute_until`
/// 字段置空（调用方收到此 variant 后调用 `GroupMemberRepo.update` with
/// `{mute_until: null}`，`containsKey` 分支会显式写 NULL）。
///
/// 字段与 `GroupMemberMutePayload` 对齐，但省略 `muteUntilMs` / `remainingSeconds`
/// / `durationText`（解禁语义下无意义）。
final class GroupMemberUnmutePayload extends GroupMemberMuteParseResult {
  /// 群 ID（必需，>0）
  final int gid;

  /// 被解禁成员的 user_id（TSID 字符串）。老后端不带此字段时为 `''`，
  /// 调用方应跳过 Repo 写入、仅做群级 toast。
  final String userId;

  /// 执行解禁的管理员昵称（可选，缺失默认 ''）
  final String adminNickname;

  const GroupMemberUnmutePayload({
    required this.gid,
    required this.userId,
    required this.adminNickname,
  });
}

/// 解析失败。`reason` 为稳定的机器可读码：
///   - `'invalid_gid'`：gid 缺失或 <= 0
///   - `'invalid_mute_until'`：mute_until 缺失或 < 0（**0 视为解禁信号，不再报错**）
final class GroupMemberMuteParseError extends GroupMemberMuteParseResult {
  final String reason;
  const GroupMemberMuteParseError(this.reason);
}

/// 解析 S2C `group_member_mute` payload。
///
/// 契约：
///   - `gid` 与 `mute_until` 为必需字段，缺失或 <= 0 则返回错误
///   - 其它字段缺失时填默认值（0 / ''），不视为错误（向后兼容）
///   - 支持 int 或可转换为 int 的 String（WebSocket JSON 解码偶发字符串）
GroupMemberMuteParseResult parseGroupMemberMutePayload(
  Map<String, dynamic> payload,
) {
  final gid = _asInt(payload['gid']);
  if (gid == null || gid <= 0) {
    return const GroupMemberMuteParseError('invalid_gid');
  }

  final muteUntilMs = _asInt(payload['mute_until']);
  if (muteUntilMs == null || muteUntilMs < 0) {
    return const GroupMemberMuteParseError('invalid_mute_until');
  }

  // slice-9b：mute_until == 0 为解禁信号（后端复用 mute_notice/4 广播）
  if (muteUntilMs == 0) {
    return GroupMemberUnmutePayload(
      gid: gid,
      userId: _asUserId(payload['user_id']),
      adminNickname: payload['admin_nickname']?.toString() ?? '',
    );
  }

  return GroupMemberMutePayload(
    gid: gid,
    muteUntilMs: muteUntilMs,
    remainingSeconds: _asInt(payload['remaining_seconds']) ?? 0,
    durationText: payload['duration_text']?.toString() ?? '',
    adminNickname: payload['admin_nickname']?.toString() ?? '',
    userId: _asUserId(payload['user_id']),
  );
}

/// 将 user_id 归一化为字符串。
///
/// - `null` / 缺失 → `''`
/// - `0` / `'0'` / 空白 → `''`（防止后端 fallback 0 污染）
/// - int / num → `toString()`
/// - String → trim 后保留
String _asUserId(Object? raw) {
  if (raw == null) return '';
  if (raw is num) {
    if (raw == 0) return '';
    return raw.toString();
  }
  final s = raw.toString().trim();
  if (s.isEmpty || s == '0') return '';
  return s;
}

int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}
