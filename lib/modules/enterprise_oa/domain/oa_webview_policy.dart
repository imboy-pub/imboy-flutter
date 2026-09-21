/// OA WebView exact-origin 导航策略（EPGZ-06 W1 / plan §7.2）
///
/// 纯 Dart（零 Flutter / 零 IO 依赖）。plan §7.2 要求：
/// - OA H5 只在**唯一 exact HTTPS origin** 内加载与导航；
/// - Flutter WebView 不得注入 IMBoy JWT / Application secret；
/// - 域名跳转必须有稳定 UI 状态（→ OaTabStatus.originMismatch）。
///
/// 「exact origin」判定 = scheme + host + port 三元组逐一完全相等
/// （默认端口按 scheme 归一：https=443、http=80，归一后相等视为同一
/// origin）。子域、前缀仿冒（`oa.example.com.evil.com`）、端口差异、
/// scheme 降级（http）、非 http(s) scheme（javascript:/file:/intent:/data:）
/// 一律 deny。策略自身非法（allowed origin 非 https / 无 host / 解析失败）
/// 时 fail-closed：拒绝一切导航。
///
/// W1 只交付策略纯函数与导航回调接口；真实 WebView 的
/// NavigationDelegate 接线在 W3 集成波次（A0 持 lease 协调时）完成。
library;

/// origin 判定结论。
enum OaOriginVerdict {
  /// scheme+host+port 与允许 origin 完全一致，放行。
  allow('allow'),

  /// 被拒绝：域名/host 不匹配（域名跳转）。
  denyHostMismatch('denyHostMismatch'),

  /// 被拒绝：端口不同。
  denyPortMismatch('denyPortMismatch'),

  /// 被拒绝：scheme 不同（含 http 降级）。
  denySchemeMismatch('denySchemeMismatch'),

  /// 被拒绝：非 http(s) scheme（javascript:/file:/intent:/data: 等）。
  denyUnsupportedScheme('denyUnsupportedScheme'),

  /// 被拒绝：URL 无法解析或为空。
  denyMalformedUrl('denyMalformedUrl'),

  /// 被拒绝：策略自身非法（allowed origin 非 https/无 host/解析失败），
  /// fail-closed 拒绝一切。
  denyPolicyInvalid('denyPolicyInvalid');

  final String wireName;

  const OaOriginVerdict(this.wireName);

  bool get isAllow => this == OaOriginVerdict.allow;

  /// 是否属于「域名跳转」类拦截（用于 originMismatch UI 状态）。
  /// host/port/scheme 不一致都意味着页面试图离开授权 origin。
  bool get isMismatch =>
      this == OaOriginVerdict.denyHostMismatch ||
      this == OaOriginVerdict.denyPortMismatch ||
      this == OaOriginVerdict.denySchemeMismatch;
}

/// 规范化 origin：`scheme://host[:port]`（scheme/host 小写；端口为 scheme
/// 默认值时省略）。非法输入返回 null。
///
/// 标准 URL 的 origin 定义即 scheme+host+port；path/query/fragment/userinfo
/// 不参与比较（userinfo 伪装由 [evaluateOrigin] 交给 Uri.host 解析规避：
/// `https://evil.com@oa.example.com` 的 host 是 oa.example.com）。
String? normalizeOrigin(String raw) {
  final Uri? uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  final String scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return null;
  final String host = uri.host.toLowerCase();
  final int effectivePort = uri.hasPort || uri.port != 0
      ? uri.port
      : _defaultPort(scheme);
  final int normalizedPort =
      effectivePort == 0 || effectivePort == _defaultPort(scheme)
      ? 0
      : effectivePort;
  return normalizedPort == 0
      ? '$scheme://$host'
      : '$scheme://$host:$normalizedPort';
}

int _defaultPort(String scheme) => scheme == 'https' ? 443 : 80;

/// exact-origin 判定主函数。
///
/// [allowedOrigin] 允许的 origin（必须 https；见 [normalizeOrigin]）。
/// [url] WebView 即将前往的实际 URL。
///
/// 返回 [OaOriginVerdict]；只有三元组完全一致才是 allow。
OaOriginVerdict evaluateOrigin(String allowedOrigin, String url) {
  final String? allowed = normalizeOrigin(allowedOrigin);
  if (allowed == null) return OaOriginVerdict.denyPolicyInvalid;
  if (!allowed.startsWith('https://')) {
    // OA origin 必须 HTTPS（plan §7.2：exact HTTPS origin allowlist）。
    return OaOriginVerdict.denyPolicyInvalid;
  }

  final String trimmed = url.trim();
  if (trimmed.isEmpty) return OaOriginVerdict.denyMalformedUrl;
  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    return OaOriginVerdict.denyMalformedUrl;
  }

  // scheme 判定先于 host 校验：javascript:/file:/data: 等 scheme 常
  // 无 host（如 `intent:#Intent;...`、`data:text/html,...`），必须归入
  // denyUnsupportedScheme 而不是笼统的 malformed。
  final String scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') {
    return OaOriginVerdict.denyUnsupportedScheme;
  }
  if (uri.host.isEmpty) return OaOriginVerdict.denyMalformedUrl;

  // 逐元组比较（与 normalizeOrigin 相同的端口归一规则）。
  final String host = uri.host.toLowerCase();
  final String allowedHost = _hostOf(allowed);
  final String allowedScheme = _schemeOf(allowed);
  final int allowedPort = _portOf(allowed);

  if (scheme != allowedScheme) return OaOriginVerdict.denySchemeMismatch;
  if (host != allowedHost) return OaOriginVerdict.denyHostMismatch;

  final int port = uri.hasPort || uri.port != 0
      ? uri.port
      : _defaultPort(scheme);
  final int normalizedPort = port == _defaultPort(scheme) ? 0 : port;
  final int normalizedAllowedPort = allowedPort == _defaultPort(allowedScheme)
      ? 0
      : allowedPort;
  if (normalizedPort != normalizedAllowedPort) {
    return OaOriginVerdict.denyPortMismatch;
  }

  return OaOriginVerdict.allow;
}

String _schemeOf(String origin) => origin.split('://').first;

String _hostOf(String origin) {
  final String rest = origin.substring(origin.indexOf('://') + 3);
  final int colon = rest.indexOf(':');
  return colon == -1 ? rest : rest.substring(0, colon);
}

int _portOf(String origin) {
  final int colon = origin.lastIndexOf(':');
  // origin 已由 normalizeOrigin 产出：若有第二个冒号必为端口分隔。
  final int schemeColon = origin.indexOf(':');
  if (colon <= schemeColon) return 0;
  return int.tryParse(origin.substring(colon + 1)) ?? 0;
}

/// 一次导航请求的处置决定（骨架阶段即定下回调合同，W3 接
/// webview_flutter NavigationDelegate）。
enum OaNavigationAction {
  /// 放行本次导航。
  proceed('proceed'),

  /// 拒绝并停留在当前页（宿主需阻止加载并保持原页面）。
  cancel('cancel'),

  /// 拒绝且属于离开授权 origin 的跳转：宿主除阻止加载外，还应把
  /// OA Tab 状态机置为 originMismatch（`markOriginMismatch`）。
  cancelAsMismatch('cancelAsMismatch');

  final String wireName;

  const OaNavigationAction(this.wireName);
}

/// 导航事件处理接口（骨架契约）。
///
/// W3 的 WebView 容器实现本接口，把 [onNavigationRequested] 接到
/// `NavigationDelegate.shouldOverrideUrlLoading` / `onPageStarted`，
/// 并按返回的 [OaNavigationAction] 调用 controller API。
/// 策略本身无状态，可安全复用。
abstract interface class OaNavigationHandler {
  /// 请求加载 [url] 前的授权裁决。
  ///
  /// 默认实现走 exact-origin 策略：allow → proceed；isMismatch →
  /// cancelAsMismatch；其余 deny → cancel。
  OaNavigationAction onNavigationRequested(String url);
}

/// 策略默认实现：单一允许 origin 的 exact 校验。
class ExactOriginNavigationHandler implements OaNavigationHandler {
  const ExactOriginNavigationHandler({required this.allowedOrigin});

  /// 唯一允许的 HTTPS origin（通常来自 EnterpriseOaBrandConfig.oaOrigin）。
  final String allowedOrigin;

  @override
  OaNavigationAction onNavigationRequested(String url) {
    final OaOriginVerdict verdict = evaluateOrigin(allowedOrigin, url);
    if (verdict.isAllow) return OaNavigationAction.proceed;
    if (verdict.isMismatch) return OaNavigationAction.cancelAsMismatch;
    return OaNavigationAction.cancel;
  }
}
