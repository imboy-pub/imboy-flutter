import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/account_local_task_registry.dart';

/// Native requests use the same signed HTTP wrapper as other app APIs.
PersonalHistoryApiClient createNativePersonalHistoryClient({
  required AccountLocalTaskOwner owner,
  required String instance,
  required CancelToken cancel,
  required void Function() guard,
}) => PersonalHistoryApiClient(
  clientInstance: instance,
  transport: (method, path, {queryParameters, data}) async {
    guard();
    final http = HttpClient.client;
    final url = Uri.parse(owner.endpoint).resolve(path).toString();
    Response<dynamic>? response;
    void observe(Response<dynamic> raw) {
      response = raw;
    }

    final options = Options(
      followRedirects: false,
      validateStatus: (status) => status != null,
      extra: {
        httpRequestGuard: guard,
        httpNoAutoRetry: true,
        httpObserveRawResponse: observe,
      },
    );
    final result = switch (method) {
      'GET' => await http.get(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancel,
      ),
      'POST' => await http.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancel,
      ),
      'PUT' => await http.put(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancel,
      ),
      _ => throw StateError('Unsupported native personal history method'),
    };
    guard();
    final envelope = response?.data;
    return PersonalHistoryTransportResult(
      httpStatus: response?.statusCode ?? 0,
      body: envelope is Map<String, dynamic>
          ? envelope
          : {'code': result.code, 'payload': result.payload},
    );
  },
);
