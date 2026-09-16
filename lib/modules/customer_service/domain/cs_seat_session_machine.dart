/// 坐席会话运行状态机（§12.5.1 / CSM-02）
///
/// 纯 Dart（零 Flutter / 零 IO 依赖），在 CSM-01 `cs_seat_gate`（入口
/// 语义）之上扩展会话内写权限降级语义：
///
/// ```
/// writable --403(suspend/seat disabled)--> readOnlySuspended
/// writable --409(offboarding)-----------> offboardingRequired
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
library;

/// 会话运行阶段。
enum CsSeatSessionPhase {
  /// 可写：可发送 / 可转接 / 可关闭。
  writable('writable'),

  /// 只读（坐席被 suspend 或 seat disabled）：清写入口 + 停后台发送。
  readOnlySuspended('readOnlySuspended'),

  /// 只读（离职交接中）：清写入口 + 停后台发送；本机会话内终态。
  offboardingRequired('offboardingRequired'),

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

  /// 是否可写（发送 / 转接 / 关闭入口）。
  bool get canSend => _phase == CsSeatSessionPhase.writable;

  /// 是否继续后台发送/增量轮询（降级后一律停止，避免把失败请求打成风暴）。
  bool get shouldPoll =>
      _phase == CsSeatSessionPhase.writable ||
      _phase == CsSeatSessionPhase.closed;

  /// 可解释只读态的 i18n key（writable 时为空串）。
  ///
  /// 键名只表达语义（readOnlySuspended / offboardingRequired / closed /
  /// rated），文案映射在 UI 层 i18n，本机不硬编码。
  String get explainKey =>
      _phase == CsSeatSessionPhase.writable ? '' : _phase.wireName;

  /// HTTP 403（suspend / seat disabled / assignment 结束）：清写入口、
  /// 停后台发送、进入可解释只读态。
  bool markSuspended() {
    if (_phase == CsSeatSessionPhase.closed ||
        _phase == CsSeatSessionPhase.rated ||
        _phase == CsSeatSessionPhase.offboardingRequired) {
      return false;
    }
    _phase = CsSeatSessionPhase.readOnlySuspended;
    return true;
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
  /// writable。offboarding / closed / rated 不可经此恢复。
  bool restoreFromSuspension() {
    if (_phase != CsSeatSessionPhase.readOnlySuspended) return false;
    _phase = CsSeatSessionPhase.writable;
    return true;
  }
}
