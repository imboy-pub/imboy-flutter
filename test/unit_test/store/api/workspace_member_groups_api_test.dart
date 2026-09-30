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
    expect(uri, '/api/v1/workspaces/100/groups');
    calls.add(queryParameters!);
    return pages.removeAt(0);
  }
}

Map<String, dynamic> _group(int id) => {
  'id': id,
  'scope': 'workspace',
  'workspace_id': 100,
  'status': 1,
  'title': 'Group $id',
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
  test('完整消费三页，传本人模式、游标和限额，不漏第 201 个群', () async {
    final api = _Api([
      _page(List.generate(200, (i) => _group(i + 1)), more: true, next: 200),
      _page([_group(201)], more: true, next: 201),
      _page([_group(202)]),
    ]);
    expect(
      (await api.memberGroups('100')).map((g) => g.groupId),
      List.generate(202, (i) => i + 1),
    );
    expect(api.calls, [
      for (final cursor in [0, 200, 201])
        {'member_only': 1, 'limit': 200, 'cursor': cursor},
    ]);
  });

  test('中途请求失败抛出原错误，不返回前页部分群', () async {
    final api = _Api([
      _page([_group(1)], more: true, next: 1),
      IMBoyHttpResponse.failure(errCode: 403, errMsg: 'denied'),
    ]);
    await expectLater(
      api.memberGroups('100'),
      throwsA(isA<WorkspaceApiException>().having((e) => e.code, 'code', 403)),
    );
  });

  final invalid = <String, IMBoyHttpResponse>{
    '旧服务端没有分页契约': IMBoyHttpResponse.success({
      'workspace_id': 100,
      'list': [_group(1)],
    }),
    '跨工作区信封': IMBoyHttpResponse.success({
      'workspace_id': 200,
      'list': <Map<String, dynamic>>[],
      'has_more': false,
      'next_cursor': 0,
    }),
    '跨工作区资源': _page([
      {..._group(1), 'workspace_id': 200},
    ]),
    '个人资源': _page([
      {..._group(1), 'scope': 'personal'},
    ]),
    '禁用群': _page([
      {..._group(1), 'status': 0},
    ]),
    '重复资源': _page([_group(1), _group(1)]),
    '不前进的游标': _page([_group(1)], more: true, next: 0),
    '空的非末页': _page([], more: true, next: 1),
    '末页游标非零': _page([_group(1)], next: 1),
  };
  for (final item in invalid.entries) {
    test('${item.key}显示错误，不能当作空列表', () async {
      await expectLater(
        _Api([item.value]).memberGroups('100'),
        throwsA(isA<WorkspaceApiException>()),
      );
    });
  }

  test('重复加载不复用上次取到的群列表', () async {
    final api = _Api([
      _page([_group(1)]),
      _page([_group(2)]),
    ]);
    expect((await api.memberGroups('100')).single.groupId, 1);
    expect((await api.memberGroups('100')).single.groupId, 2);
    expect(api.calls.length, 2);
  });
}
