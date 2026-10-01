import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/workspace_api.dart';

class _Api extends WorkspaceApi {
  _Api(this.pages);
  final List<IMBoyHttpResponse> pages;
  final calls = <Map<String, dynamic>>[];

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, '/api/v1/workspaces/100/channels');
    calls.add(queryParameters!);
    return pages.removeAt(0);
  }
}

Map<String, dynamic> _channel(int id) => {
  'id': id,
  'scope': 'workspace',
  'workspace_id': 100,
  'status': 1,
  'name': 'Channel $id',
};
IMBoyHttpResponse _page(
  List<Map<String, dynamic>> groups, {
  bool more = false,
  int next = 0,
}) => IMBoyHttpResponse.success({
  'workspace_id': 100,
  'list': groups,
  'has_more': more,
  'next_cursor': next,
});

void main() {
  test('完整消费三页，传分页模式、游标和限额，不漏第 201 个频道', () async {
    final api = _Api([
      _page(
        List.generate(200, (i) => _channel(300 - i)),
        more: true,
        next: 101,
      ),
      _page([_channel(100)], more: true, next: 100),
      _page([_channel(99)]),
    ]);
    expect(
      (await api.channels('100')).map((g) => g.id),
      List.generate(202, (i) => 300 - i),
    );
    expect(api.calls, [
      for (final cursor in [0, 101, 100])
        {'paged': 1, 'limit': 200, 'cursor': cursor},
    ]);
  });

  test('中途请求失败抛出原错误，不返回前页部分频道', () async {
    final api = _Api([
      _page([_channel(1)], more: true, next: 1),
      IMBoyHttpResponse.failure(errCode: 403, errMsg: 'denied'),
    ]);
    await expectLater(
      api.channels('100'),
      throwsA(isA<WorkspaceApiException>().having((e) => e.code, 'code', 403)),
    );
  });

  final invalid = <String, IMBoyHttpResponse>{
    '旧服务端没有分页契约': IMBoyHttpResponse.success({
      'workspace_id': 100,
      'list': [_channel(1)],
    }),
    '跨工作区信封': IMBoyHttpResponse.success({
      'workspace_id': 200,
      'list': <Map<String, dynamic>>[],
      'has_more': false,
      'next_cursor': 0,
    }),
    '跨工作区资源': _page([
      {..._channel(1), 'workspace_id': 200},
    ]),
    '个人资源': _page([
      {..._channel(1), 'scope': 'personal'},
    ]),
    '禁用频道': _page([
      {..._channel(1), 'status': 0},
    ]),
    '重复资源': _page([_channel(1), _channel(1)]),
    '倒序错误': _page([_channel(1), _channel(2)]),
    '超范围ID': _page([
      {..._channel(1), 'id': '9223372036854775808'},
    ]),
    '不前进的游标': _page([_channel(1)], more: true, next: 0),
    '空的非末页': _page([], more: true, next: 1),
    '末页游标非零': _page([_channel(1)], next: 1),
  };
  for (final item in invalid.entries) {
    test('${item.key}显示错误，不能当作空列表', () async {
      await expectLater(
        _Api([item.value]).channels('100'),
        throwsA(isA<WorkspaceApiException>()),
      );
    });
  }

  test('下一页倒退到已显示频道时拒绝整份结果', () async {
    await expectLater(
      _Api([
        _page([_channel(2)], more: true, next: 2),
        _page([_channel(3)]),
      ]).channels('100'),
      throwsA(isA<WorkspaceApiException>()),
    );
  });

  test('归档与全部模式保留筛选条件', () async {
    for (final status in ['archived', 'all']) {
      final api = _Api([
        _page([
          {..._channel(1), 'status': 0},
        ]),
      ]);
      expect((await api.channels('100', status: status)).single.id, 1);
      expect(api.calls.single['status'], status);
    }
  });

  test('重复加载不复用上次取到的频道列表', () async {
    final api = _Api([
      _page([_channel(1)]),
      _page([_channel(2)]),
    ]);
    expect((await api.channels('100')).single.id, 1);
    expect((await api.channels('100')).single.id, 2);
    expect(api.calls.length, 2);
  });
}
