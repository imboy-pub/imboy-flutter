/// 坐席会话运行状态机（§12.5.1 / CSM-02）
///
/// 纯 Dart（零 Flutter / 零 IO 依赖），在 CSM-01 `cs_seat_gate`（入口
/// 语义）之上扩展会话内写权限降级语义：
///
/// ```
/// writable --403(suspend/seat disabled)--> readOnlySuspended
/// writable --409(offboarding)-----------> offboardingRequired
/// writable --transfer OK / 服务端回显他人经办 -> transferredAway
/// writable --close OK ------------------> closed --(rating 回显)--> rated
/// readOnly* --下一成功读（恢复）--------> writable（仅 suspend 可恢复）
/// ```
///
/// 降级语义（任务 §12.7 CSM-02 第 4 条）：任何一次写请求拿到 403
/// （suspend / seat disabled / 无 assignment）或 offboarding 409 后——
/// 1. 清写入口（[canSend] = false）；2. 停后台发送/轮询
/// （[shouldPoll] = false）；3. UI 展示可解释只读态（[explainKey]）。
/// offboarding 为终态（本机会话内不自动恢复）；suspend 在后续读成功时
/// 允许恢复（服务端权威状态以恢复后的请求结果为准）。
///
/// APP-M02-A04 转接生命周期：transfer 成功（或服务端权威回显经办人已非
/// 当前坐席）后旧坐席**立即只读**（transferredAway：清写入口、停后台
/// 收发，本机终态）；目标坐席侧进入 writable 由其自身 claim/detail
/// 权威回显驱动。
///
/// 读写分离：[canSend] 只管写入口（发送/附件/转接/关闭）；[canDownload]
/// 管**已授权内容代理的附件查看**——closed/rated 只读态仍可查看历史与
/// 附件（服务端仍是唯一权威，撤权后其代理面 403 即降级），但 suspend /
/// offboarding / transferredAway（凭证已被拒或经办权已离开）不再发请求。
library;

/// 会话运行阶段。
enum CsSeatSessionPhase {
  /// 可写：可发送 / 可转接 / 可关闭。
  writable('writable'),

  /// 只读（坐席被 suspend 或 seat disabled）：清写入口 + 停后台发送。
  readOnlySuspended('readOnlySuspended'),

  /// 只读（离职交接中）：清写入口 + 停后台发送；本机会话内终态。
  offboardingRequired('offboardingRequired'),

  /// 只读（会话已转交他人）：旧坐席立即只读；本机会话内终态。
  transferredAway('transferredAway'),

  /// 会话已关闭：输入禁用，等待访客评分（坐席端只展示评分状态，不代评）。
  closed('closed'),

  /// 访客已评分：终态只读。
  rated('rated');

  final String wireName;

  const CsSeatSessionPhase(this.wireName);
}

/// 坐席会话运行状态机。
class CsSeatSessionMachine {
  CsSeatSessionPhase _phase;

  /// 构造时可声明初始阶段（打开已关闭会话等场景）。
  CsSeatSessionMachine({
    CsSeatSessionPhase initial = CsSeatSessionPhase.writable,
  }) : _phase = initial;

  CsSeatSessionPhase get phase => _phase;

  /// 是否可写（发送 / 附件 / 转接 / 关闭入口）。
  bool get canSend => _phase == CsSeatSessionPhase.writable;

  /// 是否可经授权内容代理查看附件（读面）：
  /// - writable / closed / rated：可（服务端代理仍是唯一权威）；
  /// - readOnlySuspended / offboardingRequired / transferredAway：不可
  ///  （旧凭证已被拒 / 经办权已离开，不再发请求）。
  bool get canDownload =>
      _phase == CsSeatSessionPhase.writable ||
      _phase == CsSeatSessionPhase.closed ||
      _phase == CsSeatSessionPhase.rated;

  /// 是否继续后台发送/增量收发（降级后一律停止，避免把失败请求打成风暴）。
  bool get shouldPoll =>
      _phase == CsSeatSessionPhase.writable ||
      _phase == CsSeatSessionPhase.closed;

  /// 可解释只读态的 i18n key（writable 时为空串）。
  ///
  /// 键名只表达语义（readOnlySuspended / offboardingRequired /
  /// transferredAway / closed / rated），文案映射在 UI 层 i18n，
  /// 本机不硬编码。
  String get explainKey =>
      _phase == CsSeatSessionPhase.writable ? '' : _phase.wireName;

  /// HTTP 403（suspend / seat disabled / assignment 结束）：清写入口、
  /// 停后台发送、进入可解释只读态。
  bool markSuspended() {
    if (_phase == CsSeatSessionPhase.closed ||
        _phase == CsSeatSessionPhase.rated ||
        _phase == CsSeatSessionPhase.offboardingRequired ||
        _phase == CsSeatSessionPhase.transferredAway) {
      return false;
    }
    _phase = CsSeatSessionPhase.readOnlySuspended;
    return true;
  }

  /// Reading authority can end even after a conversation closes or is rated.
  /// No server closure/rating fact survives a revoked read projection.
  void revokeReadAuthority() {
    _phase = CsSeatSessionPhase.readOnlySuspended;
  }

  /// HTTP 409 offboarding_required：清写入口、停后台发送；本机终态。
  bool markOffboarding() {
    if (_phase == CsSeatSessionPhase.offboardingRequired ||
        _phase == CsSeatSessionPhase.rated) {
      return false;
    }
    _phase = CsSeatSessionPhase.offboardingRequired;
    return true;
  }

  /// 会话已转交他人（transfer 成功 / 服务端回显经办人已非当前坐席）：
  /// 旧坐席立即只读；本机终态。
  bool markTransferredAway() {
    if (_phase == CsSeatSessionPhase.transferredAway ||
        _phase == CsSeatSessionPhase.closed ||
        _phase == CsSeatSessionPhase.rated ||
        _phase == CsSeatSessionPhase.offboardingRequired) {
      return false;
    }
    _phase = CsSeatSessionPhase.transferredAway;
    return true;
  }

  /// close 成功（或服务端回显 closed）：输入禁用，等待访客评分。
  bool markClosed() {
    if (_phase == CsSeatSessionPhase.closed ||
        _phase == CsSeatSessionPhase.rated) {
      return false;
    }
    _phase = CsSeatSessionPhase.closed;
    return true;
  }

  /// 服务端回显 rating（访客已评）：终态只读。
  bool markRated() {
    if (_phase == CsSeatSessionPhase.rated) return false;
    _phase = CsSeatSessionPhase.rated;
    return true;
  }

  /// suspend 只读态下的恢复口：后续读请求成功（服务端未再拒绝）时回到
  /// writable。offboarding / transferredAway / closed / rated 不可经此恢复。
  bool restoreFromSuspension() {
    if (_phase != CsSeatSessionPhase.readOnlySuspended) return false;
    _phase = CsSeatSessionPhase.writable;
    return true;
  }
}
