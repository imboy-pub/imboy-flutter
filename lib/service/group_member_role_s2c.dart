/// S2C `group_member_role` 通知的 payload 解析 + 分派 —— slice-4 纯函数切片。
///
/// 后端合约（`imboy/src/logic/group_member_logic.erl:351-376`）：
///   Action  = <<"group_member_role">>
///   Payload = #{
///     <<"gid">>            => integer(),
///     <<"user_id">>        => integer(),
///     <<"role">>           => 1..5,
///     <<"role_text">>      => binary(),
///     <<"nickname">>       => binary(),
///     <<"admin_nickname">> => binary(),
///     <<"updated_at">>     => integer()    // 秒级 epoch（elib_dt:now/0）
///   }
///
/// 角色常量（来自 `imboy/src/logic/group_role.hrl`）：
///   1 = 普通成员 / 2 = 嘉宾 / 3 = 管理员 / 4 = 群主 / 5 = 副群主
///
/// ⚠️ **UI 权限矩阵后续扩展**：`canMuteGroupMember`（slice-2）尚未覆盖
/// `role=5 副群主`。slice-4 范围内不修改 slice-2 的权限矩阵，但需在
/// 升级 UI 规则时同步考虑。
library;

/// 解析结果（sealed）：
///   - `GroupMemberRolePayload`：字段齐全合法
///   - `GroupMemberRoleParseError`：必需字段非法
sealed class GroupMemberRoleParseResult {
  const GroupMemberRoleParseResult();
}

/// 合法 payload 的结构化视图。
final class GroupMemberRolePayload extends GroupMemberRoleParseResult {
  /// 群 ID（必需，>0）
  final int gid;

  /// 被修改角色的成员 ID（必需，>0）
  final int userId;

  /// 新角色（必需，1..5）
  final int role;

  /// 角色文案（可选，缺失默认 ''）
  final String roleText;

  /// 被修改成员昵称（可选，缺失默认 ''）
  final String nickname;

  /// 执行操作的管理员昵称（可选，缺失默认 ''）
  final String adminNickname;

  /// 后端变更时间戳（秒级 epoch；可选，非法默认 0）
  final int updatedAt;

  const GroupMemberRolePayload({
    required this.gid,
    required this.userId,
    required this.role,
    required this.roleText,
    required this.nickname,
    required this.adminNickname,
    required this.updatedAt,
  });
}

/// 解析失败。`reason` 为稳定的机器可读码：
///   - `'invalid_gid'`      gid 缺失或 <= 0
///   - `'invalid_user_id'`  user_id 缺失或 <= 0
///   - `'invalid_role'`     role 缺失或超出 1..5
final class GroupMemberRoleParseError extends GroupMemberRoleParseResult {
  final String reason;
  const GroupMemberRoleParseError(this.reason);
}

/// 合法角色范围（与后端 `group_role.hrl` 对齐）
const int _roleMin = 1; // ROLE_MEMBER
const int _roleMax = 5; // ROLE_VICE_OWNER

GroupMemberRoleParseResult parseGroupMemberRolePayload(
  Map<String, dynamic> payload,
) {
  final gid = _asInt(payload['gid']);
  if (gid == null || gid <= 0) {
    return const GroupMemberRoleParseError('invalid_gid');
  }

  final userId = _asInt(payload['user_id']);
  if (userId == null || userId <= 0) {
    return const GroupMemberRoleParseError('invalid_user_id');
  }

  final role = _asInt(payload['role']);
  if (role == null || role < _roleMin || role > _roleMax) {
    return const GroupMemberRoleParseError('invalid_role');
  }

  final updatedAtRaw = _asInt(payload['updated_at']);
  final updatedAt = (updatedAtRaw != null && updatedAtRaw > 0)
      ? updatedAtRaw
      : 0;

  return GroupMemberRolePayload(
    gid: gid,
    userId: userId,
    role: role,
    roleText: payload['role_text']?.toString() ?? '',
    nickname: payload['nickname']?.toString() ?? '',
    adminNickname: payload['admin_nickname']?.toString() ?? '',
    updatedAt: updatedAt,
  );
}

/// 副作用分派：解析 + 写 Repo + 广播事件。
///
/// 通过函数注入隔离 `GroupMemberRepo` 与 `AppEventBus`，便于单元测试。
///
/// 契约：
///   - 合法 payload → `await applyRoleUpdate(gid, userId, role, updatedAt)`
///     然后 `fireEvent(payload)`
///   - 非法 payload → 两者都不调用，仅 `log` 原因
///   - `applyRoleUpdate` 抛异常被吞下并 `log`，**不影响 `fireEvent`**
///     （本地写失败不应阻塞广播）
Future<void> handleGroupMemberRoleS2C({
  required Map<String, dynamic> payload,
  required Future<void> Function(int gid, int userId, int role, int updatedAt)
  applyRoleUpdate,
  required void Function(GroupMemberRolePayload payload) fireEvent,
  void Function(String message)? log,
}) async {
  final logFn = log ?? (_) {};
  final parsed = parseGroupMemberRolePayload(payload);
  switch (parsed) {
    case GroupMemberRoleParseError(:final reason):
      logFn('[group_member_role] parse_failed reason=$reason payload=$payload');
      return;
    case GroupMemberRolePayload():
      try {
        await applyRoleUpdate(
          parsed.gid,
          parsed.userId,
          parsed.role,
          parsed.updatedAt,
        );
      } on Object catch (e, st) {
        logFn(
          '[group_member_role] apply_failed gid=${parsed.gid} '
          'userId=${parsed.userId} role=${parsed.role} err=$e\n$st',
        );
      }
      fireEvent(parsed);
  }
}

int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}
