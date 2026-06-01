import 'package:imboy/modules/identity/domain/value/user_id.dart';

/// 好友关系状态 / Friendship status（T3.5）。
///
/// 对齐后端 `friend_agg` 状态机：none/pending/friends/blocked。
enum FriendshipStatus {
  /// 无关系。
  none,

  /// 已申请待对方通过。
  pending,

  /// 已是好友。
  friends,

  /// 已拉黑。
  blocked,
}

/// 好友关系充血实体 / Friendship rich entity（T3.5）。
///
/// from→to 单向关系状态机，**逐字镜像后端 `friend_agg`** 的转换不变量：
///   none --request--> pending --accept--> friends
///   pending --reject--> none
///   {none|pending|friends} --block--> blocked --unblock--> none
///   friends --remove--> none
/// 转换方法返回新实例（不可变）；非法转换抛 [StateError]（对齐后端
/// {error, atom} 拒绝语义）。block 幂等。
/// 纯 Dart——禁止 import flutter/* 与 repository/*。
class Friendship {
  const Friendship({
    required this.from,
    required this.to,
    this.status = FriendshipStatus.none,
  });

  final UserId from;
  final UserId to;
  final FriendshipStatus status;

  /// ---- 查询谓词（供 UI 判定按钮可见性，纯查询）----

  bool get canRequest => status == FriendshipStatus.none;
  bool get canAccept => status == FriendshipStatus.pending;
  bool get canReject => status == FriendshipStatus.pending;
  bool get canUnblock => status == FriendshipStatus.blocked;
  bool get canRemove => status == FriendshipStatus.friends;
  bool get isFriend => status == FriendshipStatus.friends;
  bool get isBlocked => status == FriendshipStatus.blocked;

  /// ---- 状态转换（返回新实例；非法转换抛 StateError）----

  /// 发起申请：仅 none 态可发。
  Friendship request() {
    switch (status) {
      case FriendshipStatus.none:
        return _to(FriendshipStatus.pending);
      case FriendshipStatus.pending:
        throw StateError('already_requested');
      case FriendshipStatus.friends:
        throw StateError('already_friends');
      case FriendshipStatus.blocked:
        throw StateError('blocked');
    }
  }

  /// 通过申请：仅 pending 态可通过。
  Friendship accept() {
    if (status != FriendshipStatus.pending) {
      throw StateError('no_pending_request');
    }
    return _to(FriendshipStatus.friends);
  }

  /// 拒绝申请：仅 pending 态可拒绝，回到 none。
  Friendship reject() {
    if (status != FriendshipStatus.pending) {
      throw StateError('no_pending_request');
    }
    return _to(FriendshipStatus.none);
  }

  /// 拉黑：任意态可拉黑；已拉黑则幂等（返回自身）。
  Friendship block() {
    if (status == FriendshipStatus.blocked) return this;
    return _to(FriendshipStatus.blocked);
  }

  /// 解除拉黑：仅 blocked 态可解除，回到 none。
  Friendship unblock() {
    if (status != FriendshipStatus.blocked) {
      throw StateError('not_blocked');
    }
    return _to(FriendshipStatus.none);
  }

  /// 删除好友：仅 friends 态可删除，回到 none。
  Friendship remove() {
    if (status != FriendshipStatus.friends) {
      throw StateError('not_friends');
    }
    return _to(FriendshipStatus.none);
  }

  Friendship _to(FriendshipStatus next) =>
      Friendship(from: from, to: to, status: next);
}
