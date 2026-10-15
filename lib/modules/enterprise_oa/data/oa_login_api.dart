import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_config.dart';

class OaLoginApi extends HttpClient {
  OaLoginApi({String? backend})
    : super(conf: HttpConfig(baseUrl: backend), retryEnabled: false);
  Future<Map<String, dynamic>> exchange(
    String ticket,
    Map<String, dynamic> proof,
  ) => _request('exchange', {...proof, 'ticket': ticket});
  Future<Map<String, dynamic>> link(
    String pending,
    Map<String, dynamic> proof,
  ) => _request('link', {...proof, 'pending_token': pending});
  Future<Map<String, dynamic>> register(
    String pending,
    Map<String, dynamic> proof,
  ) => _request('register', {
    ...proof,
    'pending_token': pending,
    'confirm_create': true,
  });
  Future<Map<String, dynamic>> _request(
    String action,
    Map<String, dynamic> data,
  ) async {
    final response = await post('/api/v1/oa/login/$action', data: data);
    response.throwIfFailed();
    final payload = IMBoyHttpResponse.payloadAsMap(response.payload);
    if (payload.isEmpty) throw const FormatException('Invalid OA response');
    return payload;
  }
}
