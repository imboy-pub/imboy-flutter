/// OA SSO 一次性 code 签发域逻辑（EPGZ-06 W3 / plan §7.2）
///
/// 纯 Dart（零 Flutter / 零 IO；随机源显式注入），对应 A5 冻结合同
/// （checkpoint EPGZ-05-IMPL「给 A6」节）：
///
/// 1. **签发** `POST /api/v1/oa/sso/code`（Human JWT）：
///    - 请求：`application_key`(8..128) / `redirect_uri`(与 OA 预注册
///      allowlist 逐字节一致) / `nonce`(16..128, [A-Za-z0-9_-]，客户端
///      CSPRNG 生成，**即后续重定向 state 原值**)；
///    - 成功 payload：`{"code":"oa_sso_<43>","expires_in":60,"redirect_uri"}`，
///      `expires_in` 恒 60s；明文 code 仅此一次出现，Flutter 不持久化。
/// 2. **WebView 打开**：`<redirect_uri>?code=<code>&state=<nonce 原值>`
///    ——state 必须原样回传（跨端点绑定链）。
/// 3. **交换**（OA backend → INT-14）Flutter 不参与；code 一次性，
///    失效/重复消费统一映射 sessionExpired 终态（不重试同 code）。
///
/// 错误映射（issue 侧整数信封 → W1 状态机目标态）：
///
/// | HTTP/信封码 | OaSsoIssueFailureKind | 目标 OaTabStatus |
/// |---|---|---|
/// | 网络不可达/超时 | network | error（可重试） |
/// | 400 invalid_param | badRequest | error（配置/编程错误，仅日志） |
/// | 403 forbidden（非 active 成员/无 mapping） | forbidden | error |
/// | 404 not_found（key 不可解析/app 停用/org 非 active/多义） | notFound | error |
/// | 500 | server | error |
/// | 401（无/坏 Human JWT） | unauthorized | sessionExpired |
///
/// 401 不落 oaUnauthorized：W1 状态机把 oaUnauthorized 语义钉死为
/// 「OA 服务返回 401（ready 态）」，issue 侧 401 是 IMBoy 侧登录态失效
/// （既有认证基建会触发重新登录），重启 SSO 前需先恢复登录——与
/// sessionExpired 的 `requiresSsoRestart` 动作一致，故映射到该态。
library;

import 'dart:math' show Random;

import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';

/// 签发请求 nonce / 重定向 state 的合法字符集（A5 合同：[A-Za-z0-9_-]）。
const String _nonceAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';

/// nonce 生成长度（合同区间 16..128 内取 32，256-bit 熵的一半以上，
/// base64url 字符集下 32 字符 ≈ 190-bit 熵，足够绑定单次跳转）。
const int oaSsoNonceLength = 32;

/// A5 合同：code 有效期恒 60 秒（服务端不可配置；客户端仅用于倒计时 UI）。
const int oaSsoCodeExpiresInSeconds = 60;

/// 用 CSPRNG（默认 [Random.secure]）生成 SSO nonce（即重定向 state 原值）。
///
/// [random] 显式注入供测试；生产调用必须用安全随机源。
String generateOaSsoNonce([Random? random]) {
  final Random r = random ?? Random.secure();
  final String nonce = String.fromCharCodes(
    List<int>.generate(
      oaSsoNonceLength,
      (_) => _nonceAlphabet.codeUnitAt(r.nextInt(_nonceAlphabet.length)),
    ),
  );
  assert(isValidOaSsoNonce(nonce), 'generated nonce must satisfy contract');
  return nonce;
}

/// 校验 nonce 是否满足 A5 合同形态：16..128 字符的 [A-Za-z0-9_-]。
bool isValidOaSsoNonce(String value) {
  if (value.length < 16 || value.length > 128) return false;
  final RegExp pattern = RegExp('^[A-Za-z0-9_-]{${value.length}}\$');
  return pattern.hasMatch(value);
}

/// 构造 WebView 打开 URL：`<redirect_uri>?code=<code>&state=<nonce>`。
///
/// 纯函数：query 参数逐对编码追加（保留 redirect_uri 既有 query，
/// code/state 作为附加参数；OA 侧按 state 原值回传校验）。
/// 不做 origin 校验——调用方（协调器）负责先用 [evaluateOrigin] 验证。
String buildOaSsoLaunchUrl({
  required String redirectUri,
  required String code,
  required String state,
}) {
  final Uri? base = Uri.tryParse(redirectUri);
  if (base == null) return redirectUri;
  final Map<String, String> query =
      Map<String, String>.from(base.queryParameters)
        ..['code'] = code
        ..['state'] = state;
  return base.replace(queryParameters: query).toString();
}

/// 签发端点失败类别（issue 侧；见库文档映射表）。
enum OaSsoIssueFailureKind {
  network('network'),
  badRequest('badRequest'),
  unauthorized('unauthorized'),
  forbidden('forbidden'),
  notFound('notFound'),
  server('server'),
  unknown('unknown');

  final String wireName;

  const OaSsoIssueFailureKind(this.wireName);
}

/// 签发结果：成功携带一次性 code 三元组；失败携带类别。
sealed class OaSsoIssueResult {
  const OaSsoIssueResult();
}

final class OaSsoCodeIssued extends OaSsoIssueResult {
  const OaSsoCodeIssued({
    required this.code,
    required this.redirectUri,
    required this.expiresInSeconds,
  });

  /// 一次性 opaque code（明文仅此一次出现，调用方不得持久化）。
  final String code;

  /// 服务端回显的 redirect_uri（exact，与预注册一致）。
  final String redirectUri;

  /// 恒 60（合同钉死；仅用于倒计时 UI，不参与逻辑判定）。
  final int expiresInSeconds;
}

final class OaSsoIssueFailed extends OaSsoIssueResult {
  const OaSsoIssueFailed(this.kind);

  final OaSsoIssueFailureKind kind;
}

/// issue 侧失败 → W1 状态机目标态（见库文档映射表）。
///
/// 返回的是「目标态」；实际迁移仍由 OaTabStateMachine 的合法边
/// fail-closed 裁决（如 unauthorized 目标 sessionExpired 从 loading 进入
/// 是合法边；协调器按目标态调用对应 mark 方法）。
OaTabStatus targetStatusForIssueFailure(OaSsoIssueFailureKind kind) {
  switch (kind) {
    case OaSsoIssueFailureKind.unauthorized:
      return OaTabStatus.sessionExpired;
    case OaSsoIssueFailureKind.network:
    case OaSsoIssueFailureKind.badRequest:
    case OaSsoIssueFailureKind.forbidden:
    case OaSsoIssueFailureKind.notFound:
    case OaSsoIssueFailureKind.server:
    case OaSsoIssueFailureKind.unknown:
      return OaTabStatus.error;
  }
}
