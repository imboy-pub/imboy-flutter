import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_webview_policy.dart';

/// 解析工作台 OA 应用条目（定位修订 2026-10-12：organization 是业务对象，
/// 非授权边界——条目按实例返回，不再按企业过滤；organization_id 仅作
/// 业务归属回显）。保留 kind/形态/同源校验（fail-closed）。
List<EnterpriseOaRuntimeConfig> parseOaWorkbenchEntries(Object? payload) {
  if (payload is! Map || payload['entries'] is! List) {
    return const [];
  }
  final configs = <EnterpriseOaRuntimeConfig>[];
  for (final entry in (payload['entries'] as List).take(20)) {
    if (entry is! Map || entry['kind'] != 'oa') {
      continue;
    }
    final redirect = entry['redirect_uri'];
    final key = entry['application_key'];
    if (redirect is! String || key is! String || redirect.length > 2048) {
      continue;
    }
    final uri = Uri.tryParse(redirect);
    final origin = normalizeOrigin(redirect);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        origin == null ||
        !origin.startsWith('https://')) {
      continue;
    }
    final config = EnterpriseOaRuntimeConfig.fromMap({
      'IMBOY_WL_OA_ORIGIN': origin,
      'IMBOY_WL_OA_LABEL': entry['label'] is String ? entry['label'] : '',
      'IMBOY_WL_OA_ENTRY_ENABLED': true,
      'IMBOY_WL_OA_APPLICATION_KEY': key,
      'IMBOY_WL_OA_REDIRECT_URI': redirect,
    });
    if (config.runtimeEntryEnabled) configs.add(config);
  }
  return List.unmodifiable(configs);
}

class OaWorkbenchApi extends HttpClient {
  /// 实例内已登记 OA 应用发现（Human JWT 认证；org/成员/身份映射不参与）。
  Future<List<EnterpriseOaRuntimeConfig>> entries() async {
    final response = await get('/api/v1/workbench/entries');
    if (!response.ok) {
      throw StateError('OA configuration request failed: ${response.code}');
    }
    return parseOaWorkbenchEntries(response.payload);
  }
}
