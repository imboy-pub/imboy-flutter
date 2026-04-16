import 'package:imboy/store/api/group_member_api.dart';

/// 禁言操作的结构化结果（sealed，switch 必须穷尽）。
///
/// 使用 sealed 类而非 bool / Exception：
///   - 调用方必须显式处理每种失败形态，不会"偷懒返回 false"
///   - 新增分支（如 `MutePermissionDenied`）时编译器逼所有调用点更新
sealed class MuteResult {
  const MuteResult();
}

/// 禁言成功；[muteUntilMs] 为本地推算的解禁时间戳（毫秒 epoch），
/// 用于乐观更新 UI / 本地缓存。服务端权威值以 S2C `group_member_mute`
/// 通知为准，不一致时以通知覆盖。
final class MuteSuccess extends MuteResult {
  final int muteUntilMs;
  const MuteSuccess(this.muteUntilMs);
}

/// 入参校验失败（duration 非正数等）。**不**代表网络错误。
final class MuteValidationError extends MuteResult {
  final String message;
  const MuteValidationError(this.message);
}

/// API 调用完成但服务端返回失败。`message` 可能为空（API 层未透传）。
final class MuteApiFailure extends MuteResult {
  final String? message;
  const MuteApiFailure([this.message]);
}

/// 解禁操作结果（sealed）。与 `MuteResult` 对称但独立，避免类型混用。
sealed class UnmuteResult {
  const UnmuteResult();
}

/// 解禁成功。权威 `mute_until=null` 以 S2C `group_member_mute` 通知为准
///（后端解禁走同一 action，payload 携带 mute_until=0 / 省略）。
final class UnmuteSuccess extends UnmuteResult {
  const UnmuteSuccess();
}

/// 入参校验失败（gid / userId 为空）。不发起网络请求。
final class UnmuteValidationError extends UnmuteResult {
  final String message;
  const UnmuteValidationError(this.message);
}

/// API 完成但服务端返回失败。
final class UnmuteApiFailure extends UnmuteResult {
  final String? message;
  const UnmuteApiFailure([this.message]);
}

/// 群成员禁言服务 —— 前端业务门面层。
///
/// 职责：
///   1. 前置入参校验（`durationSec <= 0` 直接拦截，避免无谓请求）
///   2. 调用 `GroupMemberApi.mute`
///   3. 推算 `muteUntilMs = now + durationSec * 1000`
///   4. 将 API 层抛出的 `ArgumentError`（二次防线）转成 `MuteValidationError`
///
/// 非职责（本切片不做）：
///   - 本地 Repo 持久化：`GroupMemberRepo` 依赖 `SqliteService.to` 单例，
///     待 Repo 支持注入或通过 S2C 通知统一落库后再接入。TODO(slice-2)
///   - 解除禁言：后端尚未提供 `unmute` action，前端不应传 `duration=0`
class GroupMemberMuteService {
  GroupMemberMuteService({
    GroupMemberApi? api,
    int Function()? clock,
  })  : _api = api ?? GroupMemberApi(),
        _clock = clock ?? _defaultClock;

  final GroupMemberApi _api;
  final int Function() _clock;

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

  /// 禁言指定群成员 [durationSec] 秒。
  /// 返回 sealed [MuteResult]，调用方必须穷尽处理。
  Future<MuteResult> mute({
    required String gid,
    required String userId,
    required int durationSec,
  }) async {
    if (durationSec <= 0) {
      return const MuteValidationError('禁言时长必须大于 0 秒');
    }

    try {
      final ok = await _api.mute(
        gid: gid,
        userId: userId,
        duration: durationSec,
      );
      if (!ok) return const MuteApiFailure();
      final muteUntilMs = _clock() + durationSec * 1000;
      return MuteSuccess(muteUntilMs);
    } on ArgumentError catch (e) {
      // API 层二次校验命中（理论上前置校验已经挡掉，但保留作为防御）
      return MuteValidationError(e.message?.toString() ?? 'invalid duration');
    }
  }

  /// 解除指定群成员的禁言。
  ///
  /// 前置校验：gid / userId 均非空。成功后权威 `mute_until` 归零由 S2C
  /// `group_member_mute` 通知统一下发，本方法不做乐观本地写入。
  Future<UnmuteResult> unmute({
    required String gid,
    required String userId,
  }) async {
    if (gid.isEmpty) {
      return const UnmuteValidationError('gid 不能为空');
    }
    if (userId.isEmpty) {
      return const UnmuteValidationError('userId 不能为空');
    }
    final ok = await _api.unmute(gid: gid, userId: userId);
    if (!ok) return const UnmuteApiFailure();
    return const UnmuteSuccess();
  }
}
