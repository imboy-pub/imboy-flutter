/// 客服坐席会话状态机（amendment §2.4 / plan §5.2）
///
/// 纯 Dart（零 Flutter / 零 IO 依赖），可单测全分支（APP-A04）：
///
/// ```
/// queued --claim--> active --close--> closed --rate--> rated
///                    active --transfer--> transferring
///                    transferring --transferAccepted--> active
///                    transferring --close--> closed
/// ```
///
/// suspend 拒绝分支（amendment §3 APP-A04）：`suspended == true` 时
/// 一切前进事件（claim/transfer/close/rate）被拒绝，状态不变——对应
/// plan EB-D07「suspended 立即让所有企业业务授权失败」。
library;

/// 坐席会话状态。
enum CsSessionStatus {
  queued('queued'),
  active('active'),
  transferring('transferring'),
  closed('closed'),
  rated('rated');

  final String wireName;

  const CsSessionStatus(this.wireName);
}

/// 坐席会话状态机。
class CsSessionMachine {
  final String sessionId;

  /// 当前坐席是否被 suspend（服务端权威状态的本地镜像，可随状态刷新）。
  bool suspended;

  CsSessionStatus _status = CsSessionStatus.queued;

  CsSessionMachine({required this.sessionId, this.suspended = false});

  CsSessionStatus get status => _status;

  /// queue→claim：接单进入 active。
  bool claim() {
    return _advance(from: {CsSessionStatus.queued}, to: CsSessionStatus.active);
  }

  /// active→transferring（转出给 [toIdentityId] 对应的业务身份）。
  bool transfer({required String toIdentityId}) {
    if (toIdentityId.isEmpty) return false;
    return _advance(
      from: {CsSessionStatus.active},
      to: CsSessionStatus.transferring,
    );
  }

  /// transferring→active：对端接受，本坐席继续经办（或新经办接手完成）。
  bool transferAccepted() {
    return _advance(
      from: {CsSessionStatus.transferring},
      to: CsSessionStatus.active,
    );
  }

  /// active|transferring→closed。
  bool close() {
    return _advance(
      from: {CsSessionStatus.active, CsSessionStatus.transferring},
      to: CsSessionStatus.closed,
    );
  }

  /// closed→rated（score 1..5）。
  bool rate({required int score}) {
    if (score < 1 || score > 5) return false;
    return _advance(from: {CsSessionStatus.closed}, to: CsSessionStatus.rated);
  }

  /// 统一前进守卫：非法来源状态 / suspend → 拒绝且状态不变。
  bool _advance({
    required Set<CsSessionStatus> from,
    required CsSessionStatus to,
  }) {
    if (suspended) return false;
    if (!from.contains(_status)) return false;
    _status = to;
    return true;
  }
}
