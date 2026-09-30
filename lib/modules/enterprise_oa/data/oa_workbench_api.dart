import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_webview_policy.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 服务端条目必须属于所请求企业；复用 OA 配置与 exact-origin 校验。
List<EnterpriseOaRuntimeConfig> parseOaWorkbenchEntries(
  Object? payload,
  EntityId organizationId,
) {
  if (organizationId.isEmpty ||
      payload is! Map ||
      payload['entries'] is! List) {
    return const [];
  }
  final configs = <EnterpriseOaRuntimeConfig>[];
  for (final entry in (payload['entries'] as List).take(20)) {
    if (entry is! Map ||
        entry['kind'] != 'oa' ||
        entry['organization_id']?.toString() != organizationId) {
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
  Future<List<EnterpriseOaRuntimeConfig>> entries(
    EntityId organizationId,
  ) async {
    final response = await get(
      '/api/v1/workbench/entries',
      queryParameters: {'organization_id': organizationId},
    );
    if (!response.ok) {
      throw StateError('OA configuration request failed: ${response.code}');
    }
    return parseOaWorkbenchEntries(response.payload, organizationId);
  }
}
