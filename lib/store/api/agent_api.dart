import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

/// AI 助手 API 提供者的 Riverpod Provider
final agentApiProvider = Provider<AgentApi>((ref) {
  return AgentApi.to;
});

/// AI 助手 API 客户端（助手广场发现接口）
/// 采用单例模式，通过 AgentApi.to 访问实例
class AgentApi extends HttpClient {
  AgentApi._();

  static final AgentApi _instance = AgentApi._();

  static AgentApi get to => _instance;

  /// 助手广场分页列表 GET /api/v1/agent/list
  ///
  /// 服务端收口可见性（status=1 且 visibility=1），每项为精简卡片
  /// `{id, name, avatar, description}`；本接口不返回 account_type
  /// （广场内均为 AI 助手）。kwd 按助手昵称模糊匹配。
  Future<Map<String, dynamic>?> agentList({
    int page = 1,
    int size = 10,
    String kwd = '',
  }) async {
    IMBoyHttpResponse resp = await get(
      API.agentList,
      queryParameters: {'page': page, 'size': size, 'kwd': kwd},
    );

    iPrint("> on AgentApi/agentList resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
  }
}
