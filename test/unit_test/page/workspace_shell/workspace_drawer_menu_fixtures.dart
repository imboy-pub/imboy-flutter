part of 'workspace_drawer_menu_test.dart';

/// organizations/* 全链路 stub：mine 列表 + detail + default-workspace。
class _DetailAdapter implements HttpClientAdapter {
  _DetailAdapter({this.failDetail = false});

  final bool failDetail;
  int detailCalls = 0;

  ResponseBody _response(dynamic body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.contains('organizations/mine')) {
      return _response(_mineOf([_orgA, _orgB]));
    }
    if (path.endsWith('/organizations/$_orgB')) {
      detailCalls++;
      if (failDetail) {
        return _response({
          'code': 500,
          'msg': 'synthetic detail failure',
          'payload': null,
        });
      }
      return _response(
        _ok({
          'id': int.parse(_orgB),
          'name': '组织$_orgB',
          'member_role': 'member',
        }),
      );
    }
    if (path.endsWith('/organizations/$_orgB/default-workspace')) {
      return _response(
        _ok({
          'organization_id': int.parse(_orgB),
          'default_workspace_id': 9002,
        }),
      );
    }
    return _response(_ok(null));
  }

  @override
  void close({bool force = false}) {}
}

/// mine 返回业务错误（HTTP 200 + code≠0）：不触发重试拦截器的退避 Timer，
/// 用例结束时无挂起定时器。
class _FailAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'code': 500, 'msg': 'synthetic mine failure', 'payload': null}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
