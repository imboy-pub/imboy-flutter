import 'package:imboy/config/const.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/http/http_response.dart';

class DenylistApiResult {
  const DenylistApiResult({required this.applied, this.payload});
  final bool applied;
  final Map<String, dynamic>? payload;
}

class DenylistApi extends HttpClient {
  Future<Map<String, dynamic>?> page({int page = 1, int size = 10}) async {
    IMBoyHttpResponse resp = await get(
      API.denylistPage,
      options: Options(
        responseDecoder: channelIdResponseDecoder(
          ChannelResponseShape.denylist,
        ),
      ),
      queryParameters: {'page': page, 'size': size},
    );
    // 链路：denylist_page(_error → AsyncStateView)
    resp.throwIfFailed();

    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  /// 非成功响应无法证明写入未发生，调用方须按结果未知处理。
  Future<DenylistApiResult> add({required String deniedUserUid}) async {
    final resp = await post(
      API.denylistAdd,
      data: {"denied_user_id": deniedUserUid},
      options: Options(extra: {httpNoAutoRetry: true}),
    );
    return DenylistApiResult(
      applied: resp.ok,
      payload: resp.payload is Map<String, dynamic>
          ? resp.payload as Map<String, dynamic>
          : null,
    );
  }

  Future<DenylistApiResult> remove({required String deniedUserUid}) async {
    final resp = await post(
      API.denylistRemove,
      data: {"denied_user_id": deniedUserUid},
      options: Options(extra: {httpNoAutoRetry: true}),
    );
    return DenylistApiResult(applied: resp.ok);
  }
}
