import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

/// R-04：处置申诉 API（薄适配层）。
/// 可用性由服务端 appeal feature 门控（未开放时接口返回明确错误文案）。
class AppealApi extends HttpClient {
  /// 针对我的处置动作列表（申诉入口）
  Future<List<Map<String, dynamic>>> myActions() async {
    IMBoyHttpResponse resp = await get(API.appealActions);
    resp.throwIfFailed();
    if (resp.payload is! Map<String, dynamic>) return [];
    final actions = (resp.payload as Map<String, dynamic>)['actions'];
    return actions is List
        ? actions.whereType<Map<String, dynamic>>().toList()
        : [];
  }

  /// 我提交的申诉列表（含终审状态）
  Future<List<Map<String, dynamic>>> myAppeals() async {
    IMBoyHttpResponse resp = await get(API.appealMy);
    resp.throwIfFailed();
    if (resp.payload is! Map<String, dynamic>) return [];
    final appeals = (resp.payload as Map<String, dynamic>)['appeals'];
    return appeals is List
        ? appeals.whereType<Map<String, dynamic>>().toList()
        : [];
  }

  /// 对处置动作发起一次申诉
  Future<bool> create({required int actionId, required String reason}) async {
    IMBoyHttpResponse resp = await post(
      API.appealCreate,
      data: {"action_id": actionId, "reason": reason},
    );
    return resp.ok;
  }
}
