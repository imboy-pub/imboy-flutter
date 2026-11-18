import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/page/web_shell/web_group_info_panel.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';

import 'dart:convert';

class _Groups extends GroupApi {
  _Groups(this.response);
  final IMBoyHttpResponse response;
  String? path;
  Map<String, dynamic>? query;
  dynamic requestOptions;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    dynamic options,
    dynamic cancelToken,
    dynamic onReceiveProgress,
    dynamic httpTransformer,
  }) async {
    path = uri;
    query = queryParameters;
    requestOptions = options;
    return response;
  }
}

class _Members extends GroupMemberApi {
  _Members(this.response);
  final IMBoyHttpResponse response;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    dynamic options,
    dynamic cancelToken,
    dynamic onReceiveProgress,
    dynamic httpTransformer,
  }) async => response;
}

void main() {
  test('Actual notice page SELECT binds absent group to the authorized request', () {
    const noticeId = '9007199254740993123';
    const userId = '9007199254740993125';
    const wire =
        '{"code":0,"payload":{"list":[{"notice_id":$noticeId,"user_id":$userId,"edit_user_id":1,"body":"PUBLISHED","status":1,"expired_at":null,"updated_at":0,"created_at":0}],"total":1}}';
    final payload = (jsonDecode(
      rewriteChannelIds(wire, ChannelResponseShape.groupNotice),
    ) as Map)['payload'];
    final notices = parseWebGroupNoticePreview(payload, '100');
    expect(notices, hasLength(1));
    expect(notices.single.groupId, '100');
    expect(notices.single.id, noticeId);
    expect(notices.single.publisherId, userId);
    expect(notices.single.content, 'PUBLISHED');
  });
  test('Explicit foreign group identity remains rejected', () {
    expect(
      () => parseWebGroupNoticePreview({
        'list': [
          {'notice_id': '3', 'group_id': '200', 'body': 'FOREIGN', 'status': 1},
        ],
      }, '100'),
      throwsFormatException,
    );
  });
  test('Read-only notice preview does not expose management drafts or withdrawn rows', () {
    final rows = [
      for (final status in [0, 1, 2])
        {'notice_id': '$status', 'body': 'BODY_$status', 'status': status},
    ];
    final notices = parseWebGroupNoticePreview({'list': rows}, '100');
    expect(notices.map((n) => n.content), ['BODY_1']);
  });
  test('Strict group read preserves denial instead of returning an empty cached group', () async {
    final api = _Groups(
      IMBoyHttpResponse.failure(errCode: 403, errMsg: 'DENIED'),
    );
    await expectLater(
      api.detail(
        gid: '9007199254740993',
        strict: true,
        syncEncryptionMode: false,
      ),
      throwsA(isA<BadRequestException>().having((e) => e.code, 'code', 403)),
    );
  });
  test(
    'Explicit read-only detail retains the existing E2EE-bearing GET response',
    () async {
      final api = _Groups(
        IMBoyHttpResponse.success({'id': '9007199254740993', 'e2ee_mode': 1}),
      );
      final result = await api.detail(
        gid: '9007199254740993',
        strict: true,
        syncEncryptionMode: false,
      );
      expect(result['id'], '9007199254740993');
      expect(api.query, {'gid': '9007199254740993'});
    },
  );
  test('Member preview propagates denial while native default keeps its nullable contract', () async {
    final api = _Members(
      IMBoyHttpResponse.failure(errCode: 403, errMsg: 'DENIED'),
    );
    await expectLater(
      api.page(gid: '9007199254740993', strict: true),
      throwsA(
        isA<GroupMemberApiException>().having((e) => e.code, 'code', 403),
      ),
    );
    expect(await api.page(gid: '9007199254740993'), isNull);
  });
  test(
    'Shared notice read preserves the configured client and opaque group ID',
    () async {
      final api = _Groups(
        IMBoyHttpResponse.success({
          'list': <Map<String, dynamic>>[],
          'total': 0,
        }),
      );
      await GroupApi.announcementsPage(gid: '9007199254740993', client: api);
      expect(api.path, '/api/v1/group_notice/page');
      expect(api.query, {'gid': '9007199254740993', 'page': 1, 'size': 20});
      expect(api.requestOptions.responseDecoder, isNotNull);
    },
  );
}
