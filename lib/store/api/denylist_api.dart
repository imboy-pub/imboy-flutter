import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class DenylistApi extends HttpClient {
  Future<Map<String, dynamic>?> page({int page = 1, int size = 10}) async {
    IMBoyHttpResponse resp = await get(
      API.denylistPage,
      queryParameters: {'page': page, 'size': size},
    );
    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
  }

  /// 加入黑名单
  Future<Map<String, dynamic>?> add({required String deniedUserUid}) async {
    IMBoyHttpResponse resp = await post(
      API.denylistAdd,
      data: {"denied_user_id": deniedUserUid},
    );
    return resp.ok ? resp.payload as Map<String, dynamic>? : null;
  }

  /// 移除黑名单
  Future<bool> remove({required String deniedUserUid}) async {
    IMBoyHttpResponse resp = await post(
      API.denylistRemove,
      data: {"denied_user_id": deniedUserUid},
    );
    return resp.ok ? true : false;
  }
}
