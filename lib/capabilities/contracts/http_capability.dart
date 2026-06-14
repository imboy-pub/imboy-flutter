abstract interface class HttpCapability {
  Future<HttpResponse> get(String path, {Map<String, String>? headers});
  Future<HttpResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });
  Future<HttpResponse> put(String path, {Object? body});
  Future<HttpResponse> delete(String path);
  Future<HttpResponse> upload(
    String path,
    String filePath, {
    String field = 'file',
  });
}

final class HttpResponse {
  const HttpResponse({
    required this.statusCode,
    required this.data,
    this.headers = const {},
  });
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
