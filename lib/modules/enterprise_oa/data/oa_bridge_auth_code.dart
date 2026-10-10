/// OA JSBridge 按需取码服务（计划 2026-10-10 T1）。
///
/// 把 H5 经 imboyJSBridge 的 `getAuthCode` 请求接到既有 OA SSO 签发链路
/// （`POST /api/v1/oa/sso/code`，Human JWT 由 HttpClient 认证基建注入）：
/// - 应用裁决：H5 可选传 `application_key`（公开标识，等同 OAuth
///   client_id）；未传且当前企业恰有一个已登记 OA 应用时用它；多候选回
///   `ambiguous_application`，无候选回 `app_not_configured`。用户/企业
///   身份不来自 H5——后端按 JWT 校验 active member 与 identity mapping。
/// - nonce：复用 domain/oa_sso_issue.dart 的 CSPRNG 生成（即 OA 侧
///   state 原值；INT-14 exchange 的绑定校验必需回传，故随 code 交还 H5）。
/// - 秘密边界：只回一次性 code 信封（code/state/expires_in/redirect_uri/
///   application_key），不回 IMBoy Token/JWT/刷新凭证；code 不落盘不缓存。
library;

import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/web_view.dart' show ImboyBridgeAuthCode;
import 'package:imboy/modules/enterprise_oa/domain/oa_sso_issue.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';

/// 签发出口签名（与 OaSsoIssueLauncher.launch 同构；生产传
/// `ApiOaSsoIssueLauncher(organizationId: …).launch` 的 tear-off，
/// 测试注入 fake——与 OaTabPage 的注入形态一致）。
typedef OaBridgeIssueFn = Future<OaSsoIssueResult> Function({
  required String applicationKey,
  required String redirectUri,
  required String nonce,
});

/// 应用裁决结果：config 非空即命中；否则 errorCode 为
/// `app_not_configured`（无候选/指定 key 无匹配，统一不区分以免
/// 枚举 oracle）或 `ambiguous_application`（未指定且多候选）。
typedef OaAppSelection = ({
  EnterpriseOaRuntimeConfig? config,
  String? errorCode,
});

/// 纯函数：从已登记 entries 中裁决取码应用。
OaAppSelection selectOaApplication(
  List<EnterpriseOaRuntimeConfig> entries,
  String? applicationKey,
) {
  final available = entries.where((e) => e.runtimeEntryEnabled).toList();
  if (applicationKey != null) {
    for (final entry in available) {
      if (entry.applicationKey == applicationKey) {
        return (config: entry, errorCode: null);
      }
    }
    return (config: null, errorCode: 'app_not_configured');
  }
  switch (available.length) {
    case 1:
      return (config: available.single, errorCode: null);
    case 0:
      return (config: null, errorCode: 'app_not_configured');
    default:
      return (config: null, errorCode: 'ambiguous_application');
  }
}

/// getAuthCode 服务：应用裁决 -> nonce -> 签发 -> 协议面结果。
class OaBridgeAuthCodeService {
  const OaBridgeAuthCodeService({required this.issue, this.nonceGenerator});

  final OaBridgeIssueFn issue;

  /// nonce 生成注入（测试固定值；缺省 CSPRNG）。
  final String Function()? nonceGenerator;

  Future<ImboyBridgeAuthCode> getAuthCode({
    required List<EnterpriseOaRuntimeConfig> entries,
    String? applicationKey,
  }) async {
    final selection = selectOaApplication(entries, applicationKey);
    final app = selection.config;
    if (app == null) {
      return ImboyBridgeAuthCode.failure(
        selection.errorCode ?? 'app_not_configured',
      );
    }
    final String nonce = nonceGenerator?.call() ?? generateOaSsoNonce();
    final OaSsoIssueResult result;
    try {
      result = await issue(
        applicationKey: app.applicationKey,
        redirectUri: app.redirectUri,
        nonce: nonce,
      );
    } on Object catch (error) {
      // 与 OaTabPage 同口径：签发出口抛异常按网络类失败归一。
      iPrint('[OaBridgeAuthCode] issue threw: ${error.runtimeType}');
      return const ImboyBridgeAuthCode.failure('network');
    }
    switch (result) {
      case OaSsoCodeIssued(
        :final code,
        :final redirectUri,
        :final expiresInSeconds,
      ):
        return ImboyBridgeAuthCode.success(
          code: code,
          state: nonce,
          expiresInSeconds: expiresInSeconds,
          redirectUri: redirectUri,
          applicationKey: app.applicationKey,
        );
      case OaSsoIssueFailed(:final kind):
        return ImboyBridgeAuthCode.failure(kind.wireName);
    }
  }
}
