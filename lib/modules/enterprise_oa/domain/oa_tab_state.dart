/// OA Tab 容器 UI 状态机（EPGZ-06 W1 / plan §7.2）
///
/// 纯 Dart（零 Flutter / 零 IO 依赖），时间与 URL 显式注入，可单测。
///
/// 覆盖 plan §7.2 要求的稳定 UI 状态：
/// 退出（loggedOut）、过期/重复消费（sessionExpired）、域名跳转
/// （originMismatch）、网络错误（error）、OA 401（oaUnauthorized），
/// 外加 loading / ready 两个常规态。
///
/// ```
/// loading --页面就绪-----------------------> ready
/// loading --网络/加载失败------------------> error --retry--> loading
/// loading/ready --SSO code 过期/重复消费---> sessionExpired --restartSso--> loading
/// ready --用户在 OA 内退出-----------------> loggedOut --restartSso--> loading
/// 任意导航 --exact-origin 拦截-------------> originMismatch --retry/restartSso--> loading
/// ready --OA 返回 401---------------------> oaUnauthorized --restartSso--> loading
/// ```
///
/// 状态迁移只允许上表边；非法迁移（如 terminal 态直接 markReady）
/// 返回 false 且状态不变（fail-closed），由调用方决定是否记日志。
///
/// W1 仅提供状态机与骨架渲染；ready 态的 WebView 内容、SSO code
/// 获取与重放由 W3 集成波次接线（A0 持 lease 协调）。
library;

/// OA Tab 容器的稳定 UI 状态。
enum OaTabStatus {
  /// 初次加载 / 重试中：展示加载态。
  loading('loading'),

  /// OA 页面已就绪（WebView 已挂载或骨架占位，W3 接真 WebView）。
  ready('ready'),

  /// 网络错误或页面加载失败：可重试。
  error('error'),

  /// SSO code 过期或已被消费（一次性 code 重复使用）：需重新单点登录。
  sessionExpired('sessionExpired'),

  /// 用户已在 OA 内退出或 OA 会话失效：需重新单点登录。
  loggedOut('loggedOut'),

  /// 域名跳转被 exact-origin 策略拦截：停止加载并提示。
  originMismatch('originMismatch'),

  /// OA 服务返回 401（登录态失效）：需重新单点登录。
  oaUnauthorized('oaUnauthorized');

  /// 与后端/日志对齐的稳定线名。
  final String wireName;

  const OaTabStatus(this.wireName);
}

/// 一次被拦截的域名跳转事实（供 UI 展示与审计上报，不含敏感参数）。
class OaOriginMismatchFact {
  const OaOriginMismatchFact({
    required this.attemptedUrl,
    required this.allowedOrigin,
  });

  /// 被拦截时 WebView 试图前往的 URL（策略层已 deny，未发生导航）。
  final String attemptedUrl;

  /// 当前配置的唯一允许 origin（https://host[:port]）。
  final String allowedOrigin;
}

/// OA Tab 容器状态机。
class OaTabStateMachine {
  OaTabStateMachine({OaTabStatus initial = OaTabStatus.loading})
    : _status = initial,
      _mismatchFact = null;

  OaTabStatus _status;
  OaOriginMismatchFact? _mismatchFact;

  OaTabStatus get status => _status;

  /// 最近一次域名跳转拦截事实；仅 [OaTabStatus.originMismatch] 态非 null。
  OaOriginMismatchFact? get mismatchFact => _mismatchFact;

  /// 是否处于可展示 OA 内容的状态。
  bool get isReady => _status == OaTabStatus.ready;

  /// 是否允许展示「重试」入口（只重试加载，不重走 SSO）。
  bool get canRetry =>
      _status == OaTabStatus.error || _status == OaTabStatus.originMismatch;

  /// 是否需要重新单点登录（SSO code 一次性，必须重新获取）。
  bool get requiresSsoRestart =>
      _status == OaTabStatus.sessionExpired ||
      _status == OaTabStatus.loggedOut ||
      _status == OaTabStatus.oaUnauthorized;

  /// 页面加载完成 → ready。
  bool markReady() {
    if (_status != OaTabStatus.loading) return false;
    _status = OaTabStatus.ready;
    return true;
  }

  /// 网络/加载失败 → error。仅 loading 态可进入。
  bool markError() {
    if (_status != OaTabStatus.loading) return false;
    _status = OaTabStatus.error;
    return true;
  }

  /// SSO code 过期/重复消费 → sessionExpired。loading/ready 均可触发
  /// （code 在跳转后由 OA backend 兑换，兑换结果回传前页面可能已 ready）。
  bool markSessionExpired() {
    switch (_status) {
      case OaTabStatus.loading:
      case OaTabStatus.ready:
        _status = OaTabStatus.sessionExpired;
        return true;
      default:
        return false;
    }
  }

  /// 用户在 OA 内退出 / OA 会话失效 → loggedOut。
  bool markLoggedOut() {
    if (_status != OaTabStatus.ready) return false;
    _status = OaTabStatus.loggedOut;
    return true;
  }

  /// 宿主身份撤销与页面内退出不同：任何状态都立即失效，旧回调不可复活。
  void invalidateSession() {
    _status = OaTabStatus.loggedOut;
    _mismatchFact = null;
  }

  /// 域名跳转被 exact-origin 拦截 → originMismatch。
  ///
  /// 任意非终态都可进入（loading 中重定向同样视为跳转事实）。
  /// 重复进入时以最新事实覆盖展示。
  bool markOriginMismatch({
    required String attemptedUrl,
    required String allowedOrigin,
  }) {
    switch (_status) {
      case OaTabStatus.loading:
      case OaTabStatus.ready:
      case OaTabStatus.originMismatch:
        _status = OaTabStatus.originMismatch;
        _mismatchFact = OaOriginMismatchFact(
          attemptedUrl: attemptedUrl,
          allowedOrigin: allowedOrigin,
        );
        return true;
      default:
        return false;
    }
  }

  /// OA 返回 401 → oaUnauthorized。仅 ready 态（页面已加载后回 401）。
  bool markOaUnauthorized() {
    if (_status != OaTabStatus.ready) return false;
    _status = OaTabStatus.oaUnauthorized;
    return true;
  }

  /// 重试加载（error / originMismatch → loading）。
  bool retry() {
    if (!canRetry) return false;
    _status = OaTabStatus.loading;
    _mismatchFact = null;
    return true;
  }

  /// 重新走 SSO（sessionExpired / loggedOut / oaUnauthorized / error /
  /// originMismatch → loading）。loggedOut 等终态只经此入口复活。
  bool restartSso() {
    switch (_status) {
      case OaTabStatus.sessionExpired:
      case OaTabStatus.loggedOut:
      case OaTabStatus.oaUnauthorized:
      case OaTabStatus.error:
      case OaTabStatus.originMismatch:
        _status = OaTabStatus.loading;
        _mismatchFact = null;
        return true;
      default:
        return false;
    }
  }
}
