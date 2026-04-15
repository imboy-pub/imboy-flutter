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
/// ⚠️ **已知后端契约缺口**：`mute_notice/4` 的第三个参数 `_UserId` 被忽略，
/// 因此 payload 中不包含被禁言的 `user_id`。slice-1 的客户端处理只能做
/// 「广播通知」（toast + 事件总线），无法直接更新 `group_member.mute_until`
/// 行。修复责任在后端：
///   - `imboy/src/logic/group_member_logic.erl:260-266` 的 Payload
///     需补 `<<"user_id">> => UserId`
///   - 修复后客户端应在此文件额外暴露 `userId` 字段并更新 Repo
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

  const GroupMemberMutePayload({
    required this.gid,
    required this.muteUntilMs,
    required this.remainingSeconds,
    required this.durationText,
    required this.adminNickname,
  });
}

/// 解析失败。`reason` 为稳定的机器可读码：
///   - `'invalid_gid'`：gid 缺失或 <= 0
///   - `'invalid_mute_until'`：mute_until 缺失或 <= 0
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
  if (muteUntilMs == null || muteUntilMs <= 0) {
    return const GroupMemberMuteParseError('invalid_mute_until');
  }

  return GroupMemberMutePayload(
    gid: gid,
    muteUntilMs: muteUntilMs,
    remainingSeconds: _asInt(payload['remaining_seconds']) ?? 0,
    durationText: payload['duration_text']?.toString() ?? '',
    adminNickname: payload['admin_nickname']?.toString() ?? '',
  );
}

int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}
