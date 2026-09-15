/// 离职交接 case 状态机（amendment §2.4 / plan EB-D07）
///
/// 纯 Dart。线性前进 + 失败终态：
///
/// ```
/// draft --freeze--> frozen --startTransfer--> transferring
///   --submitVerification--> verifying --complete--> completed
/// transferring|verifying --fail--> failed（终态）
/// ```
///
/// completed / failed 均为终态：任何前进事件被拒绝。
library;

/// 离职交接 case 状态。
enum CsOffboardingStatus {
  draft('draft'),
  frozen('frozen'),
  transferring('transferring'),
  verifying('verifying'),
  completed('completed'),
  failed('failed');

  final String wireName;

  const CsOffboardingStatus(this.wireName);

  bool get isTerminal => this == completed || this == failed;
}

/// 离职交接 case 状态机。
class CsOffboardingMachine {
  CsOffboardingStatus _status = CsOffboardingStatus.draft;

  CsOffboardingStatus get status => _status;

  /// draft→frozen（冻结企业写操作）。
  bool freeze() =>
      _advance(from: CsOffboardingStatus.draft, to: CsOffboardingStatus.frozen);

  /// frozen→transferring（开始 CAS 批量 rebind）。
  bool startTransfer() => _advance(
    from: CsOffboardingStatus.frozen,
    to: CsOffboardingStatus.transferring,
  );

  /// transferring→verifying（数量/hash/残留验证）。
  bool submitVerification() => _advance(
    from: CsOffboardingStatus.transferring,
    to: CsOffboardingStatus.verifying,
  );

  /// verifying→completed（verified 后 removed）。
  bool complete() => _advance(
    from: CsOffboardingStatus.verifying,
    to: CsOffboardingStatus.completed,
  );

  /// transferring|verifying→failed（终态）。
  bool fail() {
    if (_status == CsOffboardingStatus.transferring ||
        _status == CsOffboardingStatus.verifying) {
      _status = CsOffboardingStatus.failed;
      return true;
    }
    return false;
  }

  bool _advance({
    required CsOffboardingStatus from,
    required CsOffboardingStatus to,
  }) {
    if (_status.isTerminal) return false;
    if (_status != from) return false;
    _status = to;
    return true;
  }
}
