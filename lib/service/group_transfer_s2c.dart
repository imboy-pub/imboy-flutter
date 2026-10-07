/// S2C `group_transfer` 通知的 payload 解析 + 分派 —— Q05/AC10 纯函数切片。
///
/// 后端合约（主计划 docs/design/2026-10-07-phase1-delivery-quality-plan.md
/// Q05 / 调查设计 §5.1；服务端 group_event_handler 的 owner_transferred 分支，
/// payload 键为 binary）：
///   Action  = <<"group_transfer">>
///   接收者  = 全体成员（含旧主/新主），save（离线可补）
///   Payload = #{
///     <<"gid">>            => integer(),  // TSID 群 ID
///     <<"from_owner_uid">> => integer(),  // 旧主 uid（转让后降为普通成员）
///     <<"to_owner_uid">>   => integer()   // 新主 uid（转让后成为群主）
///   }
///
/// 客户端语义（AC10）：按 gid 刷新群详情/群列表本地缓存的 owner 归属
/// （group.owner_uid 直接驱动群列表 owner/manager/join 视图查询与群详情
/// 展示），并更新旧主/新主的本地成员角色；若当前会话正是该群，经
/// GroupMemberRoleEvent 复用 chat_page 既有订阅（按 gid + 当前用户过滤）
/// 刷新自己的角色展示。不做导航跳转。
///
/// gid 按 JSON integer（TSID）或数字串下发，统一 `_asInt` 归一，
/// 缺字段/类型漂移防御（对齐 _handleGroupMemberLeave 的 W2R6 教训）。
library;

/// 解析结果（sealed）：
///   - `GroupTransferPayload`：gid 合法
///   - `GroupTransferParseError`：必需字段非法
sealed class GroupTransferParseResult {
  const GroupTransferParseResult();
}

/// 合法 payload 的结构化视图。
final class GroupTransferPayload extends GroupTransferParseResult {
  /// 群 ID（必需，>0）
  final int gid;

  /// 旧主 uid（可选，<=0 表示后端未带，跳过旧主角色写）
  final int fromOwnerUid;

  /// 新主 uid（可选，<=0 表示后端未带，跳过新主角色写与 owner_uid 回填）
  final int toOwnerUid;

  const GroupTransferPayload({
    required this.gid,
    required this.fromOwnerUid,
    required this.toOwnerUid,
  });
}

/// 解析失败。`reason` 为稳定的机器可读码：
///   - `'invalid_gid'` gid 缺失或 <= 0
final class GroupTransferParseError extends GroupTransferParseResult {
  final String reason;
  const GroupTransferParseError(this.reason);
}

GroupTransferParseResult parseGroupTransferPayload(
  Map<String, dynamic> payload,
) {
  final gid = _asInt(payload['gid']);
  if (gid == null || gid <= 0) {
    return const GroupTransferParseError('invalid_gid');
  }

  final fromOwnerUid = _asInt(payload['from_owner_uid']) ?? 0;
  final toOwnerUid = _asInt(payload['to_owner_uid']) ?? 0;

  return GroupTransferPayload(
    gid: gid,
    fromOwnerUid: fromOwnerUid,
    toOwnerUid: toOwnerUid,
  );
}

/// 副作用分派：解析 + 写 Repo + 广播事件。
///
/// 通过函数注入隔离 `GroupRepo` / `GroupMemberRepo` 与 `AppEventBus`，
/// 便于单元测试（对齐 group_member_role_s2c 的切片模式）。
///
/// 契约：
///   - 非法 payload → 三个回调都不调用，仅 `log` 原因
///   - 合法 payload →
///     1. `toOwnerUid > 0` 时 `await applyOwnerUpdate(gid, toOwnerUid)`
///     2. `fromOwnerUid > 0` 时 `await applyRoleUpdate(gid, fromOwnerUid, roleMember)`
///     3. `toOwnerUid > 0` 时 `await applyRoleUpdate(gid, toOwnerUid, roleOwner)`
///     4. 最后 `fireEvent(payload)`（广播不被本地写失败拖垮）
///   - 任一 `apply*` 抛异常被吞下并 `log`，**不影响后续步骤与 `fireEvent`**
Future<void> handleGroupTransferS2C({
  required Map<String, dynamic> payload,
  required Future<void> Function(int gid, int toOwnerUid) applyOwnerUpdate,
  required Future<void> Function(int gid, int userId, int role) applyRoleUpdate,
  required void Function(GroupTransferPayload payload) fireEvent,
  void Function(String message)? log,
}) async {
  final logFn = log ?? (_) {};
  final parsed = parseGroupTransferPayload(payload);
  switch (parsed) {
    case GroupTransferParseError(:final reason):
      logFn('[group_transfer] parse_failed reason=$reason payload=$payload');
      return;
    case GroupTransferPayload():
      if (parsed.toOwnerUid > 0) {
        try {
          await applyOwnerUpdate(parsed.gid, parsed.toOwnerUid);
        } on Object catch (e, st) {
          logFn(
            '[group_transfer] owner_update_failed gid=${parsed.gid} '
            'toOwnerUid=${parsed.toOwnerUid} err=$e\n$st',
          );
        }
      }
      if (parsed.fromOwnerUid > 0) {
        try {
          await applyRoleUpdate(
            parsed.gid,
            parsed.fromOwnerUid,
            groupTransferRoleMember,
          );
        } on Object catch (e, st) {
          logFn(
            '[group_transfer] role_update_failed gid=${parsed.gid} '
            'userId=${parsed.fromOwnerUid} role=$groupTransferRoleMember '
            'err=$e\n$st',
          );
        }
      }
      if (parsed.toOwnerUid > 0) {
        try {
          await applyRoleUpdate(
            parsed.gid,
            parsed.toOwnerUid,
            groupTransferRoleOwner,
          );
        } on Object catch (e, st) {
          logFn(
            '[group_transfer] role_update_failed gid=${parsed.gid} '
            'userId=${parsed.toOwnerUid} role=$groupTransferRoleOwner '
            'err=$e\n$st',
          );
        }
      }
      fireEvent(parsed);
  }
}

/// 角色常量（对齐后端 `imboy/src/logic/group_role.hrl` 与
/// group_member_role_s2c.dart 的注释表）：
///   1 = 普通成员 / 4 = 群主。
/// 服务端 do_transfer 事务内旧主 update_role(ROLE_MEMBER)、
/// 新主 update_role(ROLE_OWNER)，此处镜像同一终态。
const int groupTransferRoleMember = 1; // ROLE_MEMBER
const int groupTransferRoleOwner = 4; // ROLE_OWNER

int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}
