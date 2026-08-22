import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

/// 群组发现 API Provider
final groupDiscoveryApiProvider = Provider<GroupDiscoveryApi>((ref) {
  return GroupDiscoveryApi.to;
});

/// 群组发现 API 客户端（公开群检索/发现/分类）
///
/// 后端 group_discovery_handler；仅返回公开群（type=1 且 status=1）。
/// TSID 以 JSON integer 传输，http 层已做大整数安全转换，统一走
/// parseModelInt 兼容 int/String 两种形态。
class GroupDiscoveryApi extends HttpClient {
  GroupDiscoveryApi._();

  static final GroupDiscoveryApi _instance = GroupDiscoveryApi._();

  static GroupDiscoveryApi get to => _instance;

  /// 发现页公开群列表 GET /api/v1/group/discover
  Future<Map<String, dynamic>?> discover({
    int page = 1,
    int size = 10,
    int? categoryId,
    String sort = 'popular',
  }) async {
    final params = <String, dynamic>{'page': page, 'size': size, 'sort': sort};
    if (categoryId != null) params['category_id'] = categoryId;
    return _payload(API.groupDiscover, params);
  }

  /// 全文搜索公开群 GET /api/v1/group/search
  Future<Map<String, dynamic>?> search(
    String q, {
    int page = 1,
    int size = 10,
    int? categoryId,
  }) async {
    final params = <String, dynamic>{'q': q, 'page': page, 'size': size};
    if (categoryId != null) params['category_id'] = categoryId;
    return _payload(API.groupSearch, params);
  }

  /// 公开群分类 GET /api/v1/group/categories
  Future<List<Map<String, dynamic>>> categories() async {
    final payload = await _payload(API.groupCategories, const {});
    return (payload?['list'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> _payload(
    String path,
    Map<String, dynamic> params,
  ) async {
    IMBoyHttpResponse resp = await get(path, queryParameters: params);
    iPrint("> on GroupDiscoveryApi $path resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
  }
}
