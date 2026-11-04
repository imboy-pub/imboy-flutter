part of 'talk_record_api.dart';

/// HTTP 头常量（talk_record 域新引入，集中定义防拼写漂移）。
class TalkRecordHttpHeaders {
  static const String idempotencyKey = 'Idempotency-Key';
  static const String ifMatch = 'If-Match';
  static const String etag = 'etag';
}

/// 带资源 ETag 的响应包装（§3/§11.2：每个可变资源 ETag/revision；
/// 客户端不得把 segment 的 ETag 用于 record 更新）。
class TalkRecordFetched<T> {
  final T data;

  /// 服务端响应 ETag；后续 If-Match 写操作原样回传。空表示响应未带。
  final String etag;

  const TalkRecordFetched(this.data, {this.etag = ''});

  bool get hasEtag => etag.isNotEmpty;
}

/// talk_record 域响应 ETag 捕获拦截器（独立组件，便于单测）。
///
/// 仅记录最近一次 talk-records 前缀响应的 ETag（[takeLast] 消费式读取，
/// 防跨请求串用）；同资源并发请求的时序竞态在 V1 由调用方串行化写操作
/// 规避（读取-修改-写入链路本身要求先 GET 再写）。
class TalkRecordEtagInterceptor extends Interceptor {
  String? _lastEtag;
  String _lastPath = '';

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final path = response.requestOptions.path;
    if (path.startsWith(API.talkRecords)) {
      _lastPath = path;
      _lastEtag = response.headers.value(TalkRecordHttpHeaders.etag);
    }
    handler.next(response);
  }

  /// 取走指定 uri 最近一次响应的 ETag（路径不匹配返回 null，不消费）。
  String? takeLast(String uri) {
    if (_lastPath != uri) return null;
    final value = _lastEtag;
    _lastEtag = null;
    _lastPath = '';
    return value;
  }
}
