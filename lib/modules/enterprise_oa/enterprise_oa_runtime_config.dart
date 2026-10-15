/// OA Tab 运行时配置解析（EPGZ-06 W3 / plan §7.3）。
///
/// 把构建期注入（`--dart-define`，W4 白标 flavor 构建配方下发）汇聚成
/// [EnterpriseOaRuntimeConfig]：brand 部分（origin/label/entry）交由 W1 的
/// [EnterpriseOaBrandConfig.fromJson] 容错解析；SSO 部分（application_key /
/// redirect_uri）是本文件新增的部署标识（非 secret——application_key 是
/// OA 应用标识符，等同 OAuth client_id 的公开性；secret 永不进 Dart 侧）。
///
/// **入口可见性（fail-closed）**：[runtimeEntryEnabled] = brand.oaEntryEnabled
/// **且** SSO 所需字段齐备（application_key 形态合法 + redirect_uri 与
/// oaOrigin exact 同源）。配置残缺的部署静默隐藏 Tab，而不是放出一个
/// 必然失败的单点登录入口（对齐 W1「origin 非法 → 入口不出现」规则）。
///
/// dart-define 键（构建配方与 Gradle manifestPlaceholders 同源下发）：
///
/// ```text
/// IMBOY_WL_FLAVOR                  flavorId（gzCustomer / standard）
/// IMBOY_WL_APPLICATION_ID          applicationId 覆盖（白标）
/// IMBOY_WL_DISPLAY_NAME            应用显示名
/// IMBOY_WL_PRIMARY_COLOR           #RRGGBB 主色
/// IMBOY_WL_ACCENT_COLOR            #RRGGBB 强调色（可缺省）
/// IMBOY_WL_OA_LABEL                OA Tab 显示名（如「办公」）
/// IMBOY_WL_OA_ORIGIN               OA H5 唯一 exact HTTPS origin
/// IMBOY_WL_OA_ENTRY_ENABLED        "true"/"false"
/// IMBOY_WL_OA_APPLICATION_KEY      OA 应用标识（A5 合同 8..128）
/// IMBOY_WL_OA_REDIRECT_URI         OA 预注册 redirect（须与 origin exact 同源）
/// ```
///
/// `String.fromEnvironment` 是编译期常量：环境源只读一次并缓存
/// （[_cachedBuild]，[resetForTest] 供测试复位）。
library;

import 'package:imboy/modules/enterprise_oa/domain/enterprise_oa_brand_config.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_webview_policy.dart';

/// OA Tab 运行时配置（brand + SSO 部署标识）。
class EnterpriseOaRuntimeConfig {
  const EnterpriseOaRuntimeConfig({
    required this.brand,
    required this.applicationKey,
    required this.redirectUri,
    this.loginStartUri = '',
  });

  /// 白标/OA 构建期品牌配置（W1 模型）。
  final EnterpriseOaBrandConfig brand;

  /// OA 应用标识（公开标识符，非 secret；空 = 未配置）。
  final String applicationKey;

  /// OA 预注册 redirect_uri（exact；空 = 未配置）。
  final String redirectUri;
  final String loginStartUri;
  bool get inboundLoginEnabled {
    final uri = Uri.tryParse(loginStartUri);
    return isValidApplicationKey(applicationKey) &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        loginStartUri.length <= 2048 &&
        evaluateOrigin(brand.oaOrigin, loginStartUri) == OaOriginVerdict.allow;
  }

  /// 未配置 OA 的标准形态（imboy 原生 standard：无 OA Tab）。
  static const EnterpriseOaRuntimeConfig fallback = EnterpriseOaRuntimeConfig(
    brand: EnterpriseOaBrandConfig.fallback,
    applicationKey: '',
    redirectUri: '',
  );

  /// application_key 合法形态：8..128 字符（A5 合同；再收紧到可打印
  /// 非空白，防 dart-define 注入畸形值）。
  static bool isValidApplicationKey(String value) {
    if (value.length < 8 || value.length > 128) return false;
    return !value.contains(RegExp(r'\s'));
  }

  /// redirect_uri 与 brand.oaOrigin 是否 exact 同源（复用 W1 纯函数）。
  bool get redirectUriMatchesOrigin {
    if (brand.oaOrigin.isEmpty || redirectUri.isEmpty) return false;
    return evaluateOrigin(brand.oaOrigin, redirectUri) == OaOriginVerdict.allow;
  }

  /// SSO 配置是否齐备（key + redirect 同源）。
  bool get ssoConfigComplete =>
      isValidApplicationKey(applicationKey) && redirectUriMatchesOrigin;

  /// **Tab 入口最终可见性**（fail-closed，见库文档）。
  bool get runtimeEntryEnabled => brand.oaEntryEnabled && ssoConfigComplete;

  /// 主导航 Tab 显示名（白标 label 优先，i18n `enterpriseOa.title` 兜底
  /// 由导航层处理；这里只给白标覆盖值）。
  String get oaTabLabel => brand.oaLabel;

  /// 从 dart-define 汇聚 Map 解析（纯函数，测试直测）。
  factory EnterpriseOaRuntimeConfig.fromMap(Map<String, dynamic> defines) {
    final EnterpriseOaBrandConfig brand = EnterpriseOaBrandConfig.fromJson({
      'flavor_id': defines['IMBOY_WL_FLAVOR'],
      'application_id': defines['IMBOY_WL_APPLICATION_ID'],
      'display_name': defines['IMBOY_WL_DISPLAY_NAME'],
      'primary_color': defines['IMBOY_WL_PRIMARY_COLOR'],
      'accent_color': defines['IMBOY_WL_ACCENT_COLOR'],
      'oa_label': defines['IMBOY_WL_OA_LABEL'],
      'oa_origin': defines['IMBOY_WL_OA_ORIGIN'],
      'oa_entry_enabled':
          defines['IMBOY_WL_OA_ENTRY_ENABLED'] == 'true' ||
          defines['IMBOY_WL_OA_ENTRY_ENABLED'] == true,
    });
    final String applicationKey =
        defines['IMBOY_WL_OA_APPLICATION_KEY']?.toString().trim() ?? '';
    final String redirectUri =
        defines['IMBOY_WL_OA_REDIRECT_URI']?.toString().trim() ?? '';
    return EnterpriseOaRuntimeConfig(
      brand: brand,
      applicationKey: applicationKey,
      redirectUri: redirectUri,
      loginStartUri:
          defines['IMBOY_WL_OA_LOGIN_START_URI']?.toString().trim() ?? '',
    );
  }
}

/// 构建环境（dart-define）原始值（编译期常量；空字符串 = 未注入）。
const Map<String, String> _buildDefines = <String, String>{
  'IMBOY_WL_OA_LOGIN_START_URI': String.fromEnvironment(
    'IMBOY_WL_OA_LOGIN_START_URI',
  ),
  'IMBOY_WL_FLAVOR': String.fromEnvironment('IMBOY_WL_FLAVOR'),
  'IMBOY_WL_APPLICATION_ID': String.fromEnvironment('IMBOY_WL_APPLICATION_ID'),
  'IMBOY_WL_DISPLAY_NAME': String.fromEnvironment('IMBOY_WL_DISPLAY_NAME'),
  'IMBOY_WL_PRIMARY_COLOR': String.fromEnvironment('IMBOY_WL_PRIMARY_COLOR'),
  'IMBOY_WL_ACCENT_COLOR': String.fromEnvironment('IMBOY_WL_ACCENT_COLOR'),
  'IMBOY_WL_OA_LABEL': String.fromEnvironment('IMBOY_WL_OA_LABEL'),
  'IMBOY_WL_OA_ORIGIN': String.fromEnvironment('IMBOY_WL_OA_ORIGIN'),
  'IMBOY_WL_OA_ENTRY_ENABLED': String.fromEnvironment(
    'IMBOY_WL_OA_ENTRY_ENABLED',
  ),
  'IMBOY_WL_OA_APPLICATION_KEY': String.fromEnvironment(
    'IMBOY_WL_OA_APPLICATION_KEY',
  ),
  'IMBOY_WL_OA_REDIRECT_URI': String.fromEnvironment(
    'IMBOY_WL_OA_REDIRECT_URI',
  ),
};

EnterpriseOaRuntimeConfig? _cachedBuild;

/// 解析当前构建的 OA 运行时配置（dart-define 源；结果缓存）。
EnterpriseOaRuntimeConfig resolveEnterpriseOaRuntimeConfig() {
  return _cachedBuild ??= EnterpriseOaRuntimeConfig.fromMap(_buildDefines);
}

/// 测试复位缓存（生产代码不得调用）。
void resetEnterpriseOaRuntimeConfigForTest() {
  _cachedBuild = null;
}
